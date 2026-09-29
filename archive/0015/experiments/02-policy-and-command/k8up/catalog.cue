// Copied shape: catalog_opm/opm/catalog.cue. Provider catalog for BOTH
// contracts: the two-engine `backup` and the k8up-only `backup-command`.
// Imports the declaring catalog for the trait values and catalog_opm for
// the resource values (the dependency structure 0015 05-risks names).
package k8up

import (
	c "opmodel.dev/core@v2"
	id "testing.opmodel.dev/experiments/0015/exp02/k8up/identity"
	t "testing.opmodel.dev/experiments/0015/exp02/k8up/transformers"
)

c.#Catalog
metadata: {
	modulePath:  id.ModulePath
	version:     id.Version
	description: "Experiment 0015/02: K8up provider for the backup and backup-command traits"
}

#transformers: {
	(t.#BackupScheduleTransformer.metadata.fqn): t.#BackupScheduleTransformer
	(t.#PreBackupPodTransformer.metadata.fqn):   t.#PreBackupPodTransformer
}
