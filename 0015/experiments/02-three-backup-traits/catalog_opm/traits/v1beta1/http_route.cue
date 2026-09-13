package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#HttpRouteTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "http-route"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/http-route@v1beta1"
		description:    "HTTP routing rules for a workload"
		labels: {
			"trait.opmodel.dev/category": "network"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	spec: httpRoute: #HttpRouteSchema
}

#HttpRoute: c.#Component & {
	#traits: (#HttpRouteTrait.metadata.fqn): #HttpRouteTrait
}

/////////////////////////////////////////////////////////////////
//// HTTP Route Schemas
//// Shared route mixins (#RouteRuleBase, #RouteAttachmentSchema,
//// #RouteHeaderMatch) live in _route_common.cue.
/////////////////////////////////////////////////////////////////

#HttpRouteMatchSchema: {
	path?: {
		type:   "PathPrefix" | "Exact" | "RegularExpression"
		value!: string
	}
	headers?: [...#RouteHeaderMatch]
	method?: "GET" | "POST" | "PUT" | "DELETE" | "PATCH" | "HEAD" | "OPTIONS"
}

#HttpRouteRuleSchema: #RouteRuleBase & {
	matches?: [...#HttpRouteMatchSchema]
}

#HttpRouteSchema: #RouteAttachmentSchema & {
	hostnames?: [...string]
	rules: [#HttpRouteRuleSchema, ...#HttpRouteRuleSchema]
}
