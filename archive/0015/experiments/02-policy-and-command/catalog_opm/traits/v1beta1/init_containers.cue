package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#InitContainersTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "init-containers"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/init-containers@v1beta1"
		description:    "A trait to specify init containers for a workload"
		labels: {
			"trait.opmodel.dev/category": "workload"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	spec: initContainers: [...#InitContainersSchema]
}

#InitContainers: c.#Component & {
	#traits: (#InitContainersTrait.metadata.fqn): #InitContainersTrait
}

// Init container shape — alias of #ContainerSchema. Note: K8s only honours
// startupProbe on traditional init containers; native sidecar init containers
// (restartPolicy: Always, K8s >= 1.28) support all three probe types.
#InitContainersSchema: res.#ContainerSchema
