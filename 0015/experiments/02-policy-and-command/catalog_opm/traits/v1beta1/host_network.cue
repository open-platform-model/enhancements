package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

// Enables hostNetwork: true on the pod spec, sharing the node's network
// namespace. Required for workloads that must bind to host interfaces
// directly (e.g. MetalLB speaker for ARP/NDP).
#HostNetworkTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "host-network"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/host-network@v1beta1"
		description:    "Share the node's network namespace (hostNetwork: true)"
		labels: {
			"trait.opmodel.dev/category": "network"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	spec: hostNetwork: bool
}

#HostNetwork: c.#Component & {
	#traits: (#HostNetworkTrait.metadata.fqn): #HostNetworkTrait
}
