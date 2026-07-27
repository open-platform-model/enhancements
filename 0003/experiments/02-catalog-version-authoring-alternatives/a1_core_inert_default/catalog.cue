// Variant A1 — CORE'S LITERAL DECLARATION, NOTHING ELSE SUPPLYING A VERSION.
//
// `version!: #VersionType | *"0.0.0-dev"` is copied verbatim from
// core/src/catalog.cue:63 (2026-07-25). core/SPEC.md:576 describes it as a
// source-tree default: "metadata.version defaults to 0.0.0-dev in a source
// tree so cue vet is cheap during development."
//
// What this variant measures: whether that default is REAL. A required field
// (`!`) carrying a disjunction default is the shape under test — if the
// requirement wins, the documented default never applies and the catalog's
// dev-time ergonomics actually come from somewhere else entirely.
package a1_core_inert_default

import "enhancements.opmodel.dev/0003/experiments/02-catalog-version-authoring-alternatives/schema"

#Catalog: {
	kind: "Catalog"
	M=metadata: {
		modulePath!: schema.#ModulePathType
		version!:    schema.#VersionType | *"0.0.0-dev" // verbatim from core/src/catalog.cue:63
		fqn:         schema.#CatalogFQNType & "\(modulePath)@\(version)"
	}
	#transformers: [schema.#FQNType]: schema.#ComponentTransformer & {
		metadata: {
			modulePath: "\(M.modulePath)/transformers"
			version:    M.version
		}
	}
}

// The author writes only a modulePath and relies on the documented default.
catalog: #Catalog & {
	metadata: modulePath: "example.com/cat"
}

shipped: {
	catalogFQN:     catalog.metadata.fqn
	catalogVersion: catalog.metadata.version
}
