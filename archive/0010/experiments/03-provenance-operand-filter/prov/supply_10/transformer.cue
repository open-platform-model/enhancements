// The provider catalog's transformer, compiled against catalog A build 1.0.0 —
// the build the module in demand_11_uses has moved past.
//
// The provider is a DIFFERENT catalog (`cat-k8up`) with its own release
// cadence; only the contract FQN it requires is shared.
package supply

import (
	s "test.example/skew/schema"
	b "test.example/skew/catalog_v1_0"
)

transformer: s.#ComponentTransformer & {
	metadata: {
		name:           "k8up-backup"
		modulePath:     "test.example/cat-k8up/transformers"
		apiVersion:     "v1"
		catalogVersion: "2.4.0"
		description:    "Fulfils the backup contract with k8up"
	}

	requiredResources: (b.#BackupResource.metadata.fqn): b.#BackupResource
}
