// Build 1.1.0 of the pattern-constraint shape. ADDITIVE — `retention?` is
// added inside the value definition the pattern constraint applies.
package catalog_v1_1p

import s "test.example/skew/schema"

#BackupSetSchema: {
	name!:      string // auto-populated from the map key, as catalog_opm does
	schedule!:  string
	mode:       *"retain" | "retain" | "delete"
	retention?: string // ← added in 1.1.0
}

#BackupSetResource: s.#Resource & {
	metadata: {
		name:           "backup-set"
		modulePath:     "test.example/cat-a/resources"
		apiVersion:     "v1"
		catalogVersion: "1.1.0"
		description:    "Generic multi-target backup contract"
	}

	spec: backupSet: [setName=string]: #BackupSetSchema & {name: string | *setName}
}
