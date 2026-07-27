// Variant E — DEFAULT RETAINED + A SCHEMA-LEVEL "NOT THE DEV SENTINEL" GUARD.
//
// Enhancement 0001's 05-risks.md proposes, as the mitigation for "author
// forgets to stamp and publishes the dev default", a "CI guard that rejects
// publishes of 0.0.0-dev tags". This variant asks whether that guard can live
// in the SCHEMA instead of in a publish task — which would make it
// unbypassable rather than task-discipline-dependent.
//
// What this variant measures: whether CUE can express "may be the dev
// sentinel during development, must not be at publish" in one definition. If
// the guard is unconditional it fires during development too, destroying the
// zero-friction property (0001 D8) the default exists to provide — meaning
// the guard MUST live outside the schema, and is therefore bypassable by
// `cue mod publish`.
package e_default_with_cue_guard

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

_id: {
	ModulePath: "example.com/cat"
	Version:    schema.#VersionType | *"0.0.0-dev"
}

catalog: #Catalog & {
	metadata: {
		modulePath: _id.ModulePath
		version:    _id.Version
	}
}

// The guard, expressed in CUE. Unconditional by construction: CUE has no
// notion of "publish time" to condition on.
_publishGuard: catalog.metadata.version & !="0.0.0-dev"

shipped: {
	catalogFQN:     catalog.metadata.fqn
	catalogVersion: catalog.metadata.version
	guard:          _publishGuard
}
