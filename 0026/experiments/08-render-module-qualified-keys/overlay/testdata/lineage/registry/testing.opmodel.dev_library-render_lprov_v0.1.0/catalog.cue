package lprov

import (
	c "opmodel.dev/core@v2"
	l0 "testing.opmodel.dev/library-render/lin@v0"
	l1 "testing.opmodel.dev/library-render/lin@v1"
)

c.#Catalog
metadata: {modulePath: "testing.opmodel.dev/library-render/lprov@v0", version: "0.1.0", description: "backup provider serving both lin majors"}
_tx: "testing.opmodel.dev/library-render/lprov/transformers"
#transformers: {
	"\(_tx)/backup-lin-v0@0.1.0": {
		metadata: {name: "backup-lin-v0", fqn: "\(_tx)/backup-lin-v0@0.1.0", description: "backup for lin@v0"}
		requiredTraits: (l0.#BackupTrait.metadata.fqn): l0.#BackupTrait
		#transform: {#component: _, output: {apiVersion: "backup/v1", kind: "Schedule", metadata: name: #component.#names.resourceName, metadata: annotations: "built-by": "lprov-for-lin-v0"}}
	}
	"\(_tx)/backup-lin-v1@0.1.0": {
		metadata: {name: "backup-lin-v1", fqn: "\(_tx)/backup-lin-v1@0.1.0", description: "backup for lin@v1"}
		requiredTraits: (l1.#BackupTrait.metadata.fqn): l1.#BackupTrait
		#transform: {#component: _, output: {apiVersion: "backup/v1", kind: "Schedule", metadata: name: #component.#names.resourceName, metadata: annotations: "built-by": "lprov-for-lin-v1"}}
	}
}
