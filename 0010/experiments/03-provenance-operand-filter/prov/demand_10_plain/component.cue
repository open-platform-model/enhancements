// A module authored against build 1.0.0 — older than the provider. The
// provider-ahead direction, which the additive promise is supposed to make
// free.
package demand

import (
	s "test.example/skew/schema"
	b "test.example/skew/catalog_v1_0"
)

components: web: s.#Component & {
	metadata: name: "web"

	#resources: (b.#BackupResource.metadata.fqn): b.#BackupResource & {
		spec: backup: schedule: "0 2 * * *"
	}
}
