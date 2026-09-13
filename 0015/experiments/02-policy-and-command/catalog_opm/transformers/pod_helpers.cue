package transformers

/////////////////////////////////////////////////////////////////
//// Pod template helpers
////
//// Shared by every workload transformer (Deployment, StatefulSet, DaemonSet,
//// Job, CronJob) so the pod-template metadata and scheduling rules are built
//// in exactly one place.
/////////////////////////////////////////////////////////////////

// WHY: Usage:
//   template: metadata: (#PodTemplateMetadata & {
//       #comp:     #component
//       #labels:    #context.componentLabels
//   }).out
//
// The merge is plain unification, deliberately. If a podMetadata label
// collides with a context label, CUE fails at compile time — and that is the
// correct outcome, because #labels is ALSO the workload's
// `spec.selector.matchLabels`, which Kubernetes makes immutable. A "user wins"
// override would desync the pod labels from the selector and the workload
// would never become ready; failing loudly beats shipping that.

// Pod-template metadata: context labels merged with #PodMetadataTrait labels,
// plus pod-only annotations.
#PodTemplateMetadata: {
	#comp!: _
	#labels!: [string]: string

	out: {
		labels: {
			#labels
			if #comp.spec.podMetadata != _|_ if #comp.spec.podMetadata.labels != _|_ {
				#comp.spec.podMetadata.labels
			}
		}

		// Pod annotations come from the trait ONLY. #context.componentAnnotations
		// already lands on the workload object; copying it here too would put a
		// single authored annotation in two places.
		if #comp.spec.podMetadata != _|_ if #comp.spec.podMetadata.annotations != _|_ {
			annotations: #comp.spec.podMetadata.annotations
		}
	}
}

// WHY: Embed the result
// directly into the pod spec:
//
//   spec: {
//       (#PodSchedulingFields & {#comp: #component}).out
//       ...
//   }

// Pod-spec scheduling fields from #PodSchedulingTrait.
// Emits nothing when the trait is absent, so embedding is always safe.
#PodSchedulingFields: {
	#comp!: _

	out: {
		if #comp.spec.podScheduling != _|_ {
			let _sched = #comp.spec.podScheduling
			if _sched.nodeSelector != _|_ {nodeSelector: _sched.nodeSelector}
			if _sched.tolerations != _|_ {tolerations: _sched.tolerations}
			if _sched.priorityClassName != _|_ {priorityClassName: _sched.priorityClassName}
		}
	}
}
