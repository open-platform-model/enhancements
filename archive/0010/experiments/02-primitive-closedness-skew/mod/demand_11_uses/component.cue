// A module authored against catalog A build 1.1.0 that USES the field 1.1.0
// added. This is the decisive demand: a provider built on 1.0.0 has never
// heard of `retention`.
package demand

import (
	s "test.example/skew/schema"
	b "test.example/skew/catalog_v1_1"
)

components: web: s.#Component & {
	metadata: name: "web"

	#resources: (b.#BackupResource.metadata.fqn): b.#BackupResource & {
		spec: backup: {
			schedule:  "0 2 * * *"
			retention: "30d"
		}
	}
}
