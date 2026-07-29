// Build 1.0.0 of catalog A. Ships the `backup@v1` contract.
package catalog_v1_0

import s "test.example/skew/schema"

#BackupResource: s.#Resource & {
	metadata: {
		name:           "backup"
		modulePath:     "test.example/cat-a/resources"
		apiVersion:     "v1"
		catalogVersion: "1.0.0"
		description:    "Generic backup contract, fulfilled by a platform provider"
	}

	spec: backup: {
		schedule!: string
		mode:      *"retain" | "retain" | "delete"
	}
}
