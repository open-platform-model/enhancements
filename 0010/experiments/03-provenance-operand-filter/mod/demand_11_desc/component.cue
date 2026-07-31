// A module authored against a 1.1.0 build whose only difference from the
// provider's 1.0.0 build, once `catalogVersion` is out of the comparison, is
// the primitive's `description`. The component stays inside the fields both
// builds share, so the contract surfaces agree completely.
package demand

import (
	s "test.example/skew/schema"
	b "test.example/skew/catalog_v1_1_desc"
)

components: web: s.#Component & {
	metadata: name: "web"

	#resources: (b.#BackupResource.metadata.fqn): b.#BackupResource & {
		spec: backup: schedule: "0 2 * * *"
	}
}
