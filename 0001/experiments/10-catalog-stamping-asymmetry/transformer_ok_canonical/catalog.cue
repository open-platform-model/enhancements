// Transformer writes the canonical `<id.ModulePath>/transformers` subpath
// + canonical version literally. Expected: vet clean — pattern unifies
// cleanly with the author's literals because they match the stamped values.
package transformer_ok_canonical

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
			modulePath:  "\(id.ModulePath)/transformers"
			version:     id.Version
			description: "canonical subpath + version written by author; unifies with pattern"
		}
	}
}

stamped: #transformers["example.com/cat/transformers/foo@0.0.0-dev"].metadata
