// Transformer writes the wrong version literal — `9.9.9` against the
// catalog's `id.Version` (`0.0.0-dev`). Expected: vet FAILS — pattern
// stamps version = id.Version, author writes "9.9.9", unification conflict.
package transformer_wrong_version

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
	"example.com/cat/transformers/foo@9.9.9": {
		metadata: {
			name:        "foo"
			modulePath:  "\(id.ModulePath)/transformers"
			version:     "9.9.9" // wrong: catalog version is id.Version
			description: "wrong version; pattern stamps id.Version; unification conflict"
		}
	}
}
