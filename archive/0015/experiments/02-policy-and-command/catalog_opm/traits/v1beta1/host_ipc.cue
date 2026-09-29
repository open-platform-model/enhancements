package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

// Enables hostIPC: true on the pod spec, sharing the node's IPC namespace.
// Required for workloads that use shared memory or IPC mechanisms with host
// processes.
#HostIPCTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "host-ipc"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/host-ipc@v1beta1"
		description:    "Share the node's IPC namespace (hostIPC: true)"
		labels: {
			"trait.opmodel.dev/category": "security"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	spec: hostIpc: bool
}

#HostIPC: c.#Component & {
	#traits: (#HostIPCTrait.metadata.fqn): #HostIPCTrait
}
