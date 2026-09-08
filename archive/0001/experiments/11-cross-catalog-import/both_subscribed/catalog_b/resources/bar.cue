// catalog_b's resource that catalog_a's transformer references.
package resources

import (
	s  "test.example/cross-catalog/schema"
	id "test.example/cross-catalog/catalog_b/identity"
)

#BarResource: s.#Resource & {
	metadata: {
		name:       "bar"
		modulePath: "\(id.ModulePath)/resources"
		version:    id.Version
	}
	spec: bar: int | *0
}
