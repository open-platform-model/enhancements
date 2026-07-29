// The pattern-constraint counterpart of supply_10: a provider compiled
// against build 1.0.0 of the map-shaped contract.
package supply

import (
	s "test.example/skew/schema"
	b "test.example/skew/catalog_v1_0p"
)

transformer: s.#ComponentTransformer & {
	metadata: {
		name:           "k8up-backup-set"
		modulePath:     "test.example/cat-k8up/transformers"
		apiVersion:     "v1"
		catalogVersion: "2.4.0"
		description:    "Fulfils the multi-target backup contract with k8up"
	}

	requiredResources: (b.#BackupSetResource.metadata.fqn): b.#BackupSetResource
}
