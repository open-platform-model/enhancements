// catalog_a root file. Embeds c.#Catalog modules-pattern style. One
// transformer entry that references catalog_b's resource via the
// transformers/foo_transformer.cue import.
package catalog_a

import (
	s  "test.example/cross-catalog/schema"
	id "test.example/cross-catalog/catalog_a/identity"
	t  "test.example/cross-catalog/catalog_a/transformers"
)

s.#Catalog
metadata: {
	modulePath: id.ModulePath
	version:    id.Version
}
#transformers: {
	"test.example/a/transformers/foo@1.0.0": t.#FooTransformer
}
