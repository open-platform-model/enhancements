// Transformer writes a typo in the subpath — `/trasnformers` instead of
// `/transformers`. Expected: vet FAILS — the pattern constraint unifies
// the author's literal against the stamped value, conflict surfaces with
// "conflicting values" pointing at the offending file.
package transformer_typo_subpath

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
	"example.com/cat/trasnformers/foo@0.0.0-dev": {
		metadata: {
			name:        "foo"
			modulePath:  "\(id.ModulePath)/trasnformers" // typo: trasnformers
			version:     id.Version
			description: "typo subpath; pattern stamps /transformers; unification conflict"
		}
	}
}
