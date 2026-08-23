// Variant A2 — THE PRODUCTION SHAPE (status quo as actually built).
//
// Mirrors catalog_opm/src/identity/identity.cue (2026-07-25): the real
// `*"0.0.0-dev"` default lives on a PLAIN (non-required) field in the sibling
// identity package, and the catalog's required `metadata.version` is filled
// from it. Publish-time stamping (0001 D9/D19) overwrites `Version` in a temp
// build dir via `identity/version_override.cue`.
//
// What this variant measures: what the COMMITTED tree ships when nobody
// stamps — i.e. what a consumer resolving this catalog from a local checkout
// (the sanctioned `cue.mod/local-module.cue` dev workflow) observes.
package a2_identity_supplied_dev

import "enhancements.opmodel.dev/0003/experiments/02-catalog-version-authoring-alternatives/schema"

#Catalog: {
	kind: "Catalog"
	M=metadata: {
		modulePath!: schema.#ModulePathType
		version!:    schema.#VersionType | *"0.0.0-dev"
		fqn:         schema.#CatalogFQNType & "\(modulePath)@\(version)"
	}
	#transformers: [schema.#FQNType]: schema.#ComponentTransformer & {
		metadata: {
			modulePath: "\(M.modulePath)/transformers"
			version:    M.version
		}
	}
}

// Stand-in for the sibling `identity` package. Note `Version` is NOT marked
// required here — that is what makes its default actually apply.
_id: {
	ModulePath: "example.com/cat"
	Version:    schema.#VersionType | *"0.0.0-dev"
}

#FooTransformer: schema.#ComponentTransformer & {
	metadata: {
		name:        "foo"
		modulePath:  "\(_id.ModulePath)/transformers"
		version:     _id.Version
		description: "demo transformer"
	}
}

catalog: #Catalog & {
	metadata: {
		modulePath: _id.ModulePath
		version:    _id.Version
	}
	#transformers: {
		(#FooTransformer.metadata.fqn): #FooTransformer
	}
}

shipped: {
	catalogFQN:     catalog.metadata.fqn
	catalogVersion: catalog.metadata.version
	transformerFQN: #FooTransformer.metadata.fqn
}
