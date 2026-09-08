// A module authored against build 1.1.0 that does NOT use the added field.
// The control for demand_11_uses: same build on both, only the component's
// own values differ.
package demand

import (
	s "test.example/skew/schema"
	b "test.example/skew/catalog_v1_1"
)

components: web: s.#Component & {
	metadata: name: "web"

	#resources: (b.#BackupResource.metadata.fqn): b.#BackupResource & {
		spec: backup: schedule: "0 2 * * *"
	}
}
