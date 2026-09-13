package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
)

#StatelessWorkloadSchema: {
	container:       res.#ContainerSchema
	scaling?:        tr.#ScalingSchema
	restartPolicy?:  tr.#RestartPolicySchema
	updateStrategy?: tr.#UpdateStrategySchema
	sidecarContainers?: [...tr.#SidecarContainersSchema]
	initContainers?: [...tr.#InitContainersSchema]
	securityContext?: res.#SecurityContextSchema
	hostPid?:         bool
	hostIpc?:         bool
}

#StatelessWorkloadBlueprint: c.#Blueprint & {
	metadata: {
		modulePath:     "\(id.kindPrefix.blueprints)/v1beta1"
		name:           "stateless-workload"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.blueprints)/stateless-workload@v1beta1"
		description:    "A stateless workload with no requirement for stable identity or storage"
	}

	// Answers the container resource's required matching key (0010 D36):
	// attaching this blueprint is what completes a component's matching
	// identity. Matching reads matchLabels; metadata.labels on the wrapper
	// below stays as a transitional duplicate until the kernel's matcher
	// flips its read (0010 library-matching).
	matchLabels: "core.opmodel.dev/workload-type": "stateless"

	composedResources: [
		res.#ContainerResource,
	]

	composedTraits: [
		tr.#ScalingTrait,
		tr.#RestartPolicyTrait,
		tr.#UpdateStrategyTrait,
		tr.#SidecarContainersTrait,
		tr.#InitContainersTrait,
	]

	spec: statelessWorkload: #StatelessWorkloadSchema
}

#StatelessWorkload: c.#Component & {
	metadata: labels: {
		"core.opmodel.dev/workload-type": "stateless"
	}

	#blueprints: (#StatelessWorkloadBlueprint.metadata.fqn): #StatelessWorkloadBlueprint

	res.#Container
	tr.#Scaling
	tr.#RestartPolicy
	tr.#UpdateStrategy
	tr.#SidecarContainers

	tr.#InitContainers

	// WHY: The `if … != _|_` guards MUST stay hoisted at component level (outside
	// the spec block): a guard whose condition references a nested non-scalar
	// field from *inside* the spec struct trips a CUE evaluator closedness
	// regression (v0.17.0-alpha.2 through v0.17.0) that rejects the guarded
	// field as "field not allowed". Hoisting is semantics-preserving.

	// Override spec to propagate values from statelessWorkload.
	// See docs/cue-guard-closedness-workaround.md in the catalog_opm repo.
	spec: {
		statelessWorkload: #StatelessWorkloadSchema
		container:         spec.statelessWorkload.container
	}
	if spec.statelessWorkload.scaling != _|_ {
		spec: scaling: spec.statelessWorkload.scaling
	}
	if spec.statelessWorkload.restartPolicy != _|_ {
		spec: restartPolicy: spec.statelessWorkload.restartPolicy
	}
	if spec.statelessWorkload.updateStrategy != _|_ {
		spec: updateStrategy: spec.statelessWorkload.updateStrategy
	}
	if spec.statelessWorkload.sidecarContainers != _|_ {
		spec: sidecarContainers: spec.statelessWorkload.sidecarContainers
	}
	if spec.statelessWorkload.initContainers != _|_ {
		spec: initContainers: spec.statelessWorkload.initContainers
	}
}
