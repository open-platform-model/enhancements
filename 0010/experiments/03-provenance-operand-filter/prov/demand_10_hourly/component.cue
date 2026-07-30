// A module authored against build 1.0.0 setting a `schedule` value that is
// legal in 1.0.0 (`string`) and illegal in the narrowed 1.2.0
// (`"daily" | "weekly"`). Pairs with supply_12 to measure whether a BROKEN
// additive promise is caught at match time.
package demand

import (
	s "test.example/skew/schema"
	b "test.example/skew/catalog_v1_0"
)

components: web: s.#Component & {
	metadata: name: "web"

	#resources: (b.#BackupResource.metadata.fqn): b.#BackupResource & {
		spec: backup: schedule: "hourly"
	}
}
