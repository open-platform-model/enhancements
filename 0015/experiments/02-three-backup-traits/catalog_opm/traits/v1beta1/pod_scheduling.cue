package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#PodSchedulingTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "pod-scheduling"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/pod-scheduling@v1beta1"
		description:    "Where a workload's pods are allowed and preferred to run"
		labels: {
			"trait.opmodel.dev/category": "workload"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	spec: podScheduling: #PodSchedulingSchema
}

#PodScheduling: c.#Component & {
	#traits: (#PodSchedulingTrait.metadata.fqn): #PodSchedulingTrait
}

// Named `podScheduling`, not `scheduling`, because a one-character difference
// from the existing `scaling` trait is a reading hazard in module bodies.
//
// `affinity` and `topologySpreadConstraints` are deliberately omitted: both are
// large schemas with no consumer yet. Add them when a module needs them.
#PodSchedulingSchema: {
	// Node labels a pod requires. The common case is a single
	// "kubernetes.io/os": "linux" on node agents.
	nodeSelector?: [string]: string

	// Taints this pod tolerates. Node-critical agents (CNI plugins, per-node
	// proxies) must tolerate every taint or they skip exactly the nodes that
	// need them most.
	tolerations?: [...#TolerationSchema]

	// Scheduling priority and eviction order. "system-node-critical" and
	// "system-cluster-critical" are the built-in classes; anything else must be
	// a PriorityClass that already exists in the cluster — this trait does not
	// create one.
	priorityClassName?: string
}

// A `key`-less toleration with operator "Exists" tolerates EVERY taint, which
// is why `key` is optional. `value` is meaningful only with operator "Equal".
#TolerationSchema: {
	key?:      string
	operator?: "Exists" | "Equal"
	value?:    string
	effect?:   "NoSchedule" | "PreferNoSchedule" | "NoExecute"
	// Only valid with effect "NoExecute": how long the pod stays bound after
	// the taint appears. Omit to stay forever.
	tolerationSeconds?: int
}
