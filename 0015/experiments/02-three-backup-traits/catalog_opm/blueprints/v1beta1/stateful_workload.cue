package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
)

#StatefulWorkloadSchema: {
	container: res.#ContainerSchema
	volumes?: [string]: res.#VolumeSchema
	scaling?:        tr.#ScalingSchema
	restartPolicy?:  tr.#RestartPolicySchema
	updateStrategy?: tr.#UpdateStrategySchema
	sidecarContainers?: [...tr.#SidecarContainersSchema]
	initContainers?: [...tr.#InitContainersSchema]
}

#StatefulWorkloadBlueprint: c.#Blueprint & {
	metadata: {
		modulePath:     "\(id.kindPrefix.blueprints)/v1beta1"
		name:           "stateful-workload"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.blueprints)/stateful-workload@v1beta1"
		description:    "A stateful workload with stable identity and persistent storage requirements"
	}

	// Answers the container resource's required matching key (0010 D36):
	// attaching this blueprint is what completes a component's matching
	// identity. Matching reads matchLabels; metadata.labels on the wrapper
	// below stays as a transitional duplicate until the kernel's matcher
	// flips its read (0010 library-matching).
	matchLabels: "core.opmodel.dev/workload-type": "stateful"

	// The StatefulSet name is a DNS label (pod DNS <sts>-<n>.<svc>...): no
	// dots, 63 runes (0019 D21). Kept beside the container resource's
	// conditional (D23) and load-bearing, not redundant: on this path the
	// workload-type key is answered HERE, never on the container entry, so
	// the container's conditional cannot fire (measured, cue v0.17.1; see
	// docs/name-constraints.md).
	#nameConstraint: c.#NameType

	composedResources: [
		res.#ContainerResource,
		res.#VolumesResource,
	]

	composedTraits: [
		tr.#ScalingTrait,
		tr.#RestartPolicyTrait,
		tr.#UpdateStrategyTrait,
		tr.#SidecarContainersTrait,
		tr.#InitContainersTrait,
	]

	spec: statefulWorkload: #StatefulWorkloadSchema
}

#StatefulWorkload: c.#Component & {
	metadata: labels: {
		"core.opmodel.dev/workload-type": "stateful"
	}

	#blueprints: (#StatefulWorkloadBlueprint.metadata.fqn): #StatefulWorkloadBlueprint

	res.#Container
	res.#Volumes
	tr.#Scaling
	tr.#RestartPolicy
	tr.#UpdateStrategy
	tr.#SidecarContainers
	tr.#InitContainers

	// Override spec to propagate values from statefulWorkload.
	//
	// Guards hoisted at component level — do not move back inside the spec
	// block (CUE v0.17.0 closedness regression; see
	// docs/cue-guard-closedness-workaround.md in the catalog_opm repo).
	spec: {
		statefulWorkload: #StatefulWorkloadSchema
		container:        spec.statefulWorkload.container
	}
	if spec.statefulWorkload.volumes != _|_ {
		spec: volumes: spec.statefulWorkload.volumes
	}
	if spec.statefulWorkload.scaling != _|_ {
		spec: scaling: spec.statefulWorkload.scaling
	}
	if spec.statefulWorkload.restartPolicy != _|_ {
		spec: restartPolicy: spec.statefulWorkload.restartPolicy
	}
	if spec.statefulWorkload.updateStrategy != _|_ {
		spec: updateStrategy: spec.statefulWorkload.updateStrategy
	}
	if spec.statefulWorkload.sidecarContainers != _|_ {
		spec: sidecarContainers: spec.statefulWorkload.sidecarContainers
	}
	if spec.statefulWorkload.initContainers != _|_ {
		spec: initContainers: spec.statefulWorkload.initContainers
	}
}
