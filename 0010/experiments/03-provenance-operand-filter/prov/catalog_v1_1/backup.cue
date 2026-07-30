// Build 1.1.0 of catalog A. ADDITIVE against 1.0.0 — one new optional field,
// `retention`. Same contract major (`v1`), so the FQN is unchanged.
package catalog_v1_1

import s "test.example/skew/schema"

#BackupResource: s.#Resource & {
	metadata: {
		name:           "backup"
		modulePath:     "test.example/cat-a/resources"
		apiVersion:     "v1"
		catalogVersion: "1.1.0"
		description:    "Generic backup contract, fulfilled by a platform provider"
	}

	spec: backup: {
		schedule!:  string
		mode:       *"retain" | "retain" | "delete"
		retention?: string // ← added in 1.1.0
	}
}
