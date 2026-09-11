// Copied shape: catalog_opm/opm/catalog.cue. Provider catalog: imports the
// declaring catalog for the trait VALUE and catalog_opm for the volumes
// value (the dependency structure 0015 05-risks names as chosen).
package k8up

import (
	c "opmodel.dev/core@v2"
	id "testing.opmodel.dev/experiments/0015/k8up/identity"
	t "testing.opmodel.dev/experiments/0015/k8up/transformers"
)

c.#Catalog
metadata: {
	modulePath:  id.ModulePath
	version:     id.Version
	description: "Experiment 0015/01: K8up provider for the backup trait"
}

#transformers: {
	(t.#BackupScheduleTransformer.metadata.fqn): t.#BackupScheduleTransformer
}
