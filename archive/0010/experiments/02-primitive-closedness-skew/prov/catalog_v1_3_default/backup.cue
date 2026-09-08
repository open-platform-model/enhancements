// Build 1.3.0 of catalog A — adds nothing and removes nothing, but CHANGES AN
// EXISTING FIELD'S DEFAULT (`mode` flips from "retain" to "delete"). Legal
// under a naive reading of "add, never remove", and it moves rendered output
// for every component that left `mode` unset.
package catalog_v1_3_default

import s "test.example/skew/schema"

#BackupResource: s.#Resource & {
	metadata: {
		name:           "backup"
		modulePath:     "test.example/cat-a/resources"
		apiVersion:     "v1"
		catalogVersion: "1.3.0"
		description:    "Generic backup contract, fulfilled by a platform provider"
	}

	spec: backup: {
		schedule!:  string
		mode:       *"delete" | "retain" | "delete" // ← default flipped in 1.3.0
		retention?: string
	}
}
