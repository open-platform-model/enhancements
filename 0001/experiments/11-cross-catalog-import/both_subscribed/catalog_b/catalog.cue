// catalog_b root — no transformers, just a resource. Catalog identity stamped.
package catalog_b

import (
	s  "test.example/cross-catalog/schema"
	id "test.example/cross-catalog/catalog_b/identity"
)

s.#Catalog
metadata: {
	modulePath: id.ModulePath
	version:    id.Version
}
#transformers: {}
