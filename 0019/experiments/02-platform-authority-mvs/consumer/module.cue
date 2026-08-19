// A minimal real #Module. Deliberately minimal: this experiment's claim is
// about which catalog version a build RESOLVES, not about rendering, so the
// module carries the smallest component that still makes the catalog a genuine
// import rather than an unused dependency entry.
//
// The component body is copied verbatim from the `config` component of
// library/testdata/modules/web_app/components.cue (via
// ../01-purecue-render-flow/web_app/components.cue), so it is a real shape and
// not an invented one.
package consumer

import (
	m "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	catalog "opmodel.dev/catalogs/opm@v2"
)

m.#Module

metadata: {
	modulePath:  "experiments.opmodel.dev/0019/authority/consumer@v0"
	name:        "consumer"
	version:     "1.0.0"
	description: "Minimal consumer module for the 0019 MVS authority probe"
}

#components: {
	config: {
		metadata: name: "config"
		res.#ConfigMaps

		spec: configMaps: {
			"app-config": {
				immutable: false
				data: {
					"LOG_LEVEL":      "info"
					"FEATURE_FLAG_A": "on"
				}
			}
		}
	}
}

// The version THIS module's own build resolved for the catalog path. In a
// single build shared with the platform there is only one answer, which is
// exactly the property under test.
#catalogVersionResolved: catalog.metadata.version
