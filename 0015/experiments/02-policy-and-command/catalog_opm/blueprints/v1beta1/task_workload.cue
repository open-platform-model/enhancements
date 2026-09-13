package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
)

#TaskWorkloadSchema: {
	container:      res.#ContainerSchema
	jobConfig?:     tr.#JobConfigSchema
	restartPolicy?: tr.#RestartPolicySchema
	sidecarContainers?: [...tr.#SidecarContainersSchema]
	initContainers?: [...tr.#InitContainersSchema]
}

#TaskWorkloadBlueprint: c.#Blueprint & {
	metadata: {
		modulePath:     "\(id.kindPrefix.blueprints)/v1beta1"
		name:           "task-workload"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.blueprints)/task-workload@v1beta1"
		description:    "A one-time task workload that runs to completion (Job)"
	}

	// Answers the container resource's required matching key (0010 D36):
	// attaching this blueprint is what completes a component's matching
	// identity. Matching reads matchLabels; metadata.labels on the wrapper
	// below stays as a transitional duplicate until the kernel's matcher
	// flips its read (0010 library-matching).
	matchLabels: "core.opmodel.dev/workload-type": "task"

	composedResources: [
		res.#ContainerResource,
	]

	composedTraits: [
		tr.#JobConfigTrait,
		tr.#RestartPolicyTrait,
		tr.#SidecarContainersTrait,
		tr.#InitContainersTrait,
	]

	spec: taskWorkload: #TaskWorkloadSchema
}

#TaskWorkload: c.#Component & {
	metadata: labels: {
		"core.opmodel.dev/workload-type": "task"
	}

	#blueprints: (#TaskWorkloadBlueprint.metadata.fqn): #TaskWorkloadBlueprint

	res.#Container
	tr.#JobConfig
	tr.#RestartPolicy
	tr.#SidecarContainers
	tr.#InitContainers

	// Override spec to propagate values from taskWorkload.
	//
	// Guards hoisted at component level — do not move back inside the spec
	// block (CUE v0.17.0 closedness regression; see
	// docs/cue-guard-closedness-workaround.md in the catalog_opm repo).
	spec: {
		taskWorkload: #TaskWorkloadSchema
		container:    spec.taskWorkload.container
	}
	if spec.taskWorkload.jobConfig != _|_ {
		spec: jobConfig: spec.taskWorkload.jobConfig
	}
	if spec.taskWorkload.restartPolicy != _|_ {
		spec: restartPolicy: spec.taskWorkload.restartPolicy
	}
	if spec.taskWorkload.sidecarContainers != _|_ {
		spec: sidecarContainers: spec.taskWorkload.sidecarContainers
	}
	if spec.taskWorkload.initContainers != _|_ {
		spec: initContainers: spec.taskWorkload.initContainers
	}
}
