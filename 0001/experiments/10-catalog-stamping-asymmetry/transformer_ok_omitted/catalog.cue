// Transformer omits `metadata.modulePath` entirely; the `#Catalog.#transformers`
// pattern constraint stamps it. Expected: vet clean; eval --all shows the
// transformer's modulePath = "example.com/cat/transformers" and version = "0.0.0-dev".
package transformer_ok_omitted

import (
	s  "enhancements.opmodel.dev/0001/experiments/10-catalog-stamping-asymmetry/schema"
	id "enhancements.opmodel.dev/0001/experiments/10-catalog-stamping-asymmetry/identity"
)

s.#Catalog
metadata: {
	modulePath: id.ModulePath
	version:    id.Version
}
#transformers: {
	"example.com/cat/transformers/foo@0.0.0-dev": {
		metadata: {
			name:        "foo"
			description: "no modulePath / version written by author; pattern stamps both"
		}
	}
}

// Public projection to expose the stamped values.
stamped: #transformers["example.com/cat/transformers/foo@0.0.0-dev"].metadata
