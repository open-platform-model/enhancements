// A catalog transformer, as an author writes it. Same absences as the
// resource: identity is not hand-written.
package transformers

import (
	c "enhancements.opmodel.dev/0003/exp05/core"
	id "enhancements.opmodel.dev/0003/exp05/cat/identity"
	res "enhancements.opmodel.dev/0003/exp05/cat/resources"
)

#ConfigMapTransformer: c.#ComponentTransformer & {
	metadata: {
		name:       "configmap-transformer"
		modulePath: (c.#SplitPath & {in: id.ModulePath}).registryPath + "/transformers@" + (c.#SplitPath & {in: id.ModulePath}).major
		version:    id.Version
	}

	// Matching is on the resource's MAJOR-keyed fqn, so this transformer
	// serves every 1.x build of the catalog that ships config-maps.
	requiredResources: [res.#ConfigMapsResource.metadata.fqn]
}
