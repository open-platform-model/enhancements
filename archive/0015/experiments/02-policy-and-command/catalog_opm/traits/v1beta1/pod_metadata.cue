package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#PodMetadataTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "pod-metadata"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/pod-metadata@v1beta1"
		description:    "Labels and annotations applied to the pod template, not to the workload object"
		labels: {
			"trait.opmodel.dev/category": "workload"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	spec: podMetadata: #PodMetadataSchema
}

#PodMetadata: c.#Component & {
	#traits: (#PodMetadataTrait.metadata.fqn): #PodMetadataTrait
}

// WHY this trait exists rather than reusing component metadata: a component's
// `metadata.labels` flow into #context.componentLabels, which the workload
// transformers use for BOTH the pod template labels and `spec.selector.
// matchLabels` — and a selector is IMMUTABLE in Kubernetes. Routing a semantic
// pod label (Istio's `istio.io/dataplane-mode: none`, or
// `sidecar.istio.io/inject: "false"`) through component metadata would weld it
// into the selector, so it could never be changed or removed without deleting
// and recreating the workload.

// Pod-template metadata, distinct from the workload object's own metadata.
// Labels set here are merged with the context labels and land on the pod
// template ONLY; the selector is left alone.
#PodMetadataSchema: {
	// Merged with #context.componentLabels onto the pod template. A key that
	// collides with a context label is a hard error rather than an override:
	// silently winning would desync the pod labels from the (immutable)
	// selector and the workload would never become ready.
	labels?: [string]: string

	// Applied to the pod template only. Deliberately NOT merged with
	// #context.componentAnnotations — those already land on the workload
	// object, and conflating the two is how an annotation meant for one ends
	// up on both.
	annotations?: [string]: string
}
