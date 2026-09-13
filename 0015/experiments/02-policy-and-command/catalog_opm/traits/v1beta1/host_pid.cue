package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

// Enables hostPID: true on the pod spec, sharing the node's PID namespace.
// Required for workloads that must observe or signal host processes.
#HostPIDTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "host-pid"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/host-pid@v1beta1"
		description:    "Share the node's PID namespace (hostPID: true)"
		labels: {
			"trait.opmodel.dev/category": "security"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	spec: hostPid: bool
}

#HostPID: c.#Component & {
	#traits: (#HostPIDTrait.metadata.fqn): #HostPIDTrait
}
