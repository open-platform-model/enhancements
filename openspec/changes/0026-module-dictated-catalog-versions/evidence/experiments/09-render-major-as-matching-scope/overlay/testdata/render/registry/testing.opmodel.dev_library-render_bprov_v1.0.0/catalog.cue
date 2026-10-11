package bprov

import (
	c "opmodel.dev/core@v2"
	m "testing.opmodel.dev/library-render/maj@v1"
)

c.#Catalog
metadata: {modulePath: "testing.opmodel.dev/library-render/bprov@v1", version: "1.0.0", description: "backup provider"}
_version: "1.0.0"
_tx: "testing.opmodel.dev/library-render/bprov/transformers"
#transformers: "\(_tx)/backup-transformer@\(_version)": {
	metadata: {name: "backup-transformer", fqn: "\(_tx)/backup-transformer@\(_version)", description: "backup"}
	requiredTraits: (m.#BackupTrait.metadata.fqn): m.#BackupTrait
	#transform: {#component: _, output: {apiVersion: "backup/v1", kind: "Schedule", metadata: name: #component.#names.resourceName}}
}
