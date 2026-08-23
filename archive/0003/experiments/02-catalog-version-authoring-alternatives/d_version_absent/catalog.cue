// Variant D — NO VERSION FIELD IN THE SOURCE SCHEMA AT ALL.
//
// The catalog analogue of the "CLI stamps everything, we don't commit a
// version number" option. `metadata` declares no `version` field; a publisher
// would inject one at push time.
//
// What this variant measures: whether a version-free catalog source tree can
// even be evaluated — i.e. whether the derived identity (fqn) that the rest
// of OPM keys on can exist without a version in the file. If it cannot, the
// option is structurally dead for catalogs the same way it is for modules.
package d_version_absent

import "enhancements.opmodel.dev/0003/experiments/02-catalog-version-authoring-alternatives/schema"

#Catalog: {
	kind: "Catalog"
	M=metadata: {
		modulePath!: schema.#ModulePathType
		// version: deliberately absent — supplied by the publisher, never committed.
		fqn: schema.#CatalogFQNType & "\(modulePath)@\(version)"
	}
	#transformers: [schema.#FQNType]: schema.#ComponentTransformer & {
		metadata: {
			modulePath: "\(M.modulePath)/transformers"
			version:    M.version
		}
	}
}

_ModulePath: "example.com/cat"

catalog: #Catalog & {
	metadata: modulePath: _ModulePath
}

shipped: catalogFQN: catalog.metadata.fqn
