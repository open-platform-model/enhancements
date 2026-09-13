// The declaring catalog: publishes backup (provider-fulfilled),
// backup-producer (provider-fulfilled) and backup-owned (catalog-
// fulfilled), and ships exactly one transformer, the backup-owned
// projection. #transformers is no longer empty, unlike experiments 01/02.
package contracts

import (
	c "opmodel.dev/core@v2"
	id "testing.opmodel.dev/experiments/0015/exp02/contracts/identity"
	t "testing.opmodel.dev/experiments/0015/exp02/contracts/transformers"
)

c.#Catalog
metadata: {
	modulePath:  id.ModulePath
	version:     id.Version
	description: "Experiment 0015/02: declaring catalog for backup, backup-producer and backup-owned"
}

#transformers: (t.#BackupConfigTransformer.metadata.fqn): t.#BackupConfigTransformer
