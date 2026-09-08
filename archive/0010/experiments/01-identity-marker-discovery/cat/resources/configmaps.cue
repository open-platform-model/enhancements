// Catalog leaf, written the way catalog_opm/src/resources/configmap.cue is
// written today. UNCHANGED BY THIS ENHANCEMENT except that `modulePath` now
// carries the major — which it gets by interpolating id.ModulePath, so the
// author writes no version and no major anywhere.
package resources

import (
	c "example.com/exp0010/core"
	id "example.com/exp0010/cat/identity"
)

#ConfigMapsResource: c.#Resource & {
	metadata: {
		// CHANGED from today's `modulePath: "\(id.ModulePath)/resources"`.
		// Under D1 the major is terminal, so appending "/resources" would yield
		// ".../demo@v1/resources". The splice lives in identity.cue (see the
		// FINDING there); the leaf still names no version and no major.
		modulePath: id.Prefix.resources

		// D12: the catalog build this definition came from. Required, and read
		// by the matcher — not informational.
		version: id.Version

		name:        "config-maps"
		description: "A ConfigMap definition for external configuration"
		labels: "resource.opmodel.dev/category": "config"
	}

	spec: configMaps: [cmName=string]: {
		name:      string | *cmName
		data?:     [string]: string
		immutable: bool | *false
	}
}

#ConfigMaps: c.#Component & {
	#resources: (#ConfigMapsResource.metadata.fqn): #ConfigMapsResource
}
