// Copied shape: catalog_opm/opm/catalog.cue. Second provider for the same
// contract: the "generic enough for both engines" arm, and the second
// claimant for the over-subscription case.
package velero

import (
	c "opmodel.dev/core@v2"
	id "testing.opmodel.dev/experiments/0015/velero/identity"
	t "testing.opmodel.dev/experiments/0015/velero/transformers"
)

c.#Catalog
metadata: {
	modulePath:  id.ModulePath
	version:     id.Version
	description: "Experiment 0015/01: Velero provider for the backup trait"
}

#transformers: {
	(t.#BackupScheduleTransformer.metadata.fqn): t.#BackupScheduleTransformer
}
