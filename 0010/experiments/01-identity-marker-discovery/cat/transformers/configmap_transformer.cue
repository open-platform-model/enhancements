// Catalog leaf, written the way catalog_opm/src/transformers/
// configmap_transformer.cue is written today.
//
// Note the double supply of `version` (D12), which is deliberate:
//   - this file sets `version: id.Version` at the definition site, and
//   - #Catalog's #transformers pattern constraint ALSO stamps it.
// They must agree, and they do because both read the same identity package.
// The pattern constraint is the only STRUCTURAL guarantee available — it owns
// the #transformers map — while resources and traits are reached transitively
// and have no site for a constraint to attach to.
package transformers

import (
	c "example.com/exp0010/core"
	id "example.com/exp0010/cat/identity"
	res "example.com/exp0010/cat/resources"
)

#ConfigMapTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:  id.Prefix.transformers
		version:     id.Version
		name:        "configmap-transformer"
		description: "Converts ConfigMaps resources to Kubernetes ConfigMaps"
		labels: {
			"core.opmodel.dev/resource-category": "config"
			"core.opmodel.dev/resource-type":     "configmap"
		}
	}

	requiredLabels: {}
	requiredResources: (res.#ConfigMapsResource.metadata.fqn): res.#ConfigMapsResource
	optionalResources: {}
}
