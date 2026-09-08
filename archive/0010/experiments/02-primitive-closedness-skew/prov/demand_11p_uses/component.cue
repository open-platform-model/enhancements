// The pattern-constraint shape of demand_11_uses: a module on build 1.1.0
// setting the field 1.1.0 added, inside a map the resource spec opens with a
// pattern constraint.
package demand

import (
	s "test.example/skew/schema"
	b "test.example/skew/catalog_v1_1p"
)

components: web: s.#Component & {
	metadata: name: "web"

	#resources: (b.#BackupSetResource.metadata.fqn): b.#BackupSetResource & {
		spec: backupSet: data: {
			schedule:  "0 2 * * *"
			retention: "30d"
		}
	}
}
