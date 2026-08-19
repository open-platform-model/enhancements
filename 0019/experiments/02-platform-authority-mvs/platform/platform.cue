// The platform, authored under the proposed schema: it IMPORTS its catalog and
// embeds the transformer map directly into the registry entry.
//
// Note what is absent: no `version` string anywhere. What build this platform
// runs is stated once, in cue.mod/module.cue, and nowhere else. The probe reads
// the resolved version off the catalog's own stamped metadata, and run.sh
// compares that against the pin it wrote, so no assertion in this experiment
// depends on a version restated as data.
package platform

import (
	catalog "opmodel.dev/catalogs/opm@v2"
)

#PlatformV2

metadata: {
	name:        "authority-probe"
	description: "Platform fixture for the 0019 MVS authority probe"
}

type: "kubernetes"

#registry: {
	"opmodel.dev/catalogs/opm@v2": {
		enable:        true
		#transformers: catalog.#transformers
	}
}

// The version this build actually resolved for the catalog path, read off the
// catalog's own stamped metadata rather than inferred or restated.
#catalogVersionResolved: catalog.metadata.version
