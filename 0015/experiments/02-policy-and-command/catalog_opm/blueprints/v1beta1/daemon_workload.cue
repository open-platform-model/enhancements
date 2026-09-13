package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
)

#DaemonWorkloadSchema: {
	container:       res.#ContainerSchema
	restartPolicy?:  tr.#RestartPolicySchema
	updateStrategy?: tr.#UpdateStrategySchema
	sidecarContainers?: [...tr.#SidecarContainersSchema]
	initContainers?: [...tr.#InitContainersSchema]
}

#DaemonWorkloadBlueprint: c.#Blueprint & {
	metadata: {
		modulePath:     "\(id.kindPrefix.blueprints)/v1beta1"
		name:           "daemon-workload"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.blueprints)/daemon-workload@v1beta1"
		description:    "A daemon workload that runs on all (or selected) nodes in a cluster"
	}

	// Answers the container resource's required matching key (0010 D36):
	// attaching this blueprint is what completes a component's matching
	// identity. Matching reads matchLabels; metadata.labels on the wrapper
	// below stays as a transitional duplicate until the kernel's matcher
	// flips its read (0010 library-matching).
	matchLabels: "core.opmodel.dev/workload-type": "daemon"

	composedResources: [
		res.#ContainerResource,
	]

	composedTraits: [
		tr.#RestartPolicyTrait,
		tr.#UpdateStrategyTrait,
		tr.#SidecarContainersTrait,
		tr.#InitContainersTrait,
	]

	spec: daemonWorkload: #DaemonWorkloadSchema
}

#DaemonWorkload: c.#Component & {
	metadata: labels: {
		"core.opmodel.dev/workload-type": "daemon"
	}

	#blueprints: (#DaemonWorkloadBlueprint.metadata.fqn): #DaemonWorkloadBlueprint

	res.#Container
	tr.#RestartPolicy
	tr.#UpdateStrategy
	tr.#SidecarContainers
	tr.#InitContainers

	// Override spec to propagate values from daemonWorkload.
	//
	// Guards hoisted at component level — do not move back inside the spec
	// block (CUE v0.17.0 closedness regression; see
	// docs/cue-guard-closedness-workaround.md in the catalog_opm repo).
	spec: {
		daemonWorkload: #DaemonWorkloadSchema
		container:      spec.daemonWorkload.container
	}
	if spec.daemonWorkload.restartPolicy != _|_ {
		spec: restartPolicy: spec.daemonWorkload.restartPolicy
	}
	if spec.daemonWorkload.updateStrategy != _|_ {
		spec: updateStrategy: spec.daemonWorkload.updateStrategy
	}
	if spec.daemonWorkload.sidecarContainers != _|_ {
		spec: sidecarContainers: spec.daemonWorkload.sidecarContainers
	}
	if spec.daemonWorkload.initContainers != _|_ {
		spec: initContainers: spec.daemonWorkload.initContainers
	}
}
