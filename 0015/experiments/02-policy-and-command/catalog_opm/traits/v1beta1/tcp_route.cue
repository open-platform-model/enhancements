package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#TcpRouteTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "tcp-route"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/tcp-route@v1beta1"
		description:    "TCP port-forwarding rules for a workload"
		labels: {
			"trait.opmodel.dev/category": "network"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	spec: tcpRoute: #TcpRouteSchema
}

#TcpRoute: c.#Component & {
	#traits: (#TcpRouteTrait.metadata.fqn): #TcpRouteTrait
}

// No L7 match fields for TCP.
#TcpRouteRuleSchema: #RouteRuleBase

#TcpRouteSchema: #RouteAttachmentSchema & {
	rules: [#TcpRouteRuleSchema, ...#TcpRouteRuleSchema]
}
