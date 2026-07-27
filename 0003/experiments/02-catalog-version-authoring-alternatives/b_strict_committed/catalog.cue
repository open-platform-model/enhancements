// Variant B — STRICT COMMITTED VERSION (0003 D3/D4 applied to #Catalog).
//
// `metadata.version` is required with NO default, exactly as
// core/src/module.cue:22 already declares it for #Module, and the identity
// package commits a concrete SemVer instead of a sentinel. Publish DERIVES
// the release tag from it (0003 D4); nothing is stamped, so published bytes
// equal source bytes.
//
// What this variant measures: whether removing the default keeps the source
// tree vettable, and what FQNs the committed tree ships.
package b_strict_committed

import "enhancements.opmodel.dev/0003/experiments/02-catalog-version-authoring-alternatives/schema"

#Catalog: {
	kind: "Catalog"
	M=metadata: {
		modulePath!: schema.#ModulePathType
		version!:    schema.#VersionType // no default: the independent variable
		fqn:         schema.#CatalogFQNType & "\(modulePath)@\(version)"
	}
	#transformers: [schema.#FQNType]: schema.#ComponentTransformer & {
		metadata: {
			modulePath: "\(M.modulePath)/transformers"
			version:    M.version
		}
	}
}

// Identity as committed — a real SemVer, in the tree, in git. No sentinel.
_id: {
	ModulePath: "example.com/cat"
	Version:    "1.0.0-alpha.2"
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
