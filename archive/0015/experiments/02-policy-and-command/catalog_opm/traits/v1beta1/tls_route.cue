package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#TlsRouteTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "tls-route"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/tls-route@v1beta1"
		description:    "TLS routing rules (passthrough or terminate) for a workload"
		labels: {
			"trait.opmodel.dev/category": "network"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	spec: tlsRoute: #TlsRouteSchema
}

#TlsRoute: c.#Component & {
	#traits: (#TlsRouteTrait.metadata.fqn): #TlsRouteTrait
}

// No L7 match fields for TLS.
#TlsRouteRuleSchema: #RouteRuleBase

#TlsRouteSchema: #RouteAttachmentSchema & {
	hostnames?: [...string]
	rules: [#TlsRouteRuleSchema, ...#TlsRouteRuleSchema]
}
