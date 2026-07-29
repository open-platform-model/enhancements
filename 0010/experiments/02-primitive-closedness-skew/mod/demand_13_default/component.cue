// A module authored against build 1.3.0, leaving `mode` unset so the build's
// default supplies it. Pairs with supply_10, whose build defaults the same
// field the other way — neither side adds nor removes anything.
package demand

import (
	s "test.example/skew/schema"
	b "test.example/skew/catalog_v1_3_default"
)

components: web: s.#Component & {
	metadata: name: "web"

	#resources: (b.#BackupResource.metadata.fqn): b.#BackupResource & {
		spec: backup: schedule: "0 2 * * *"
	}
}
