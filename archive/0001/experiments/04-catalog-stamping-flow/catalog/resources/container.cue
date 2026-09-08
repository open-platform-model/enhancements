// Subpackage demonstrating cross-package access to the root `Catalog`
// constant. Every primitive sources `metadata.version` and `metadata.modulePath`
// from `catalog.Catalog`, so the stamp at publish time propagates uniformly.
package resources

import "opmodel.dev/experiments/0001/04/catalog"

#ContainerResource: catalog.#Resource & {
	metadata: {
		name:       "container"
		modulePath: "\(catalog.Catalog.ModulePath)/resources/workload"
		version:    catalog.Catalog.Version
	}
	spec: image!: string
}

// One concrete instance for the export pipeline to grep.
container_resource: #ContainerResource & {
	spec: image: "demo:latest"
}
