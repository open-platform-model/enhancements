// Variant C — STRICT, AUTHOR FORGOT TO SET IT (control for variant B).
//
// Same schema as B (`version!` with no default), but the author commits no
// concrete version. This is the case D8's `*"0.0.0-dev"` default exists to
// make painless, so it is the exact cost of removing the default.
//
// What this variant measures: HOW LOUDLY the omission fails, and at which
// command. `cue vet` and `cue vet -c` may disagree — the distinction decides
// whether a strict schema is self-enforcing at dev time or needs a
// concreteness flag in CI.
package c_strict_missing

import "enhancements.opmodel.dev/0003/experiments/02-catalog-version-authoring-alternatives/schema"

#Catalog: {
	kind: "Catalog"
	M=metadata: {
		modulePath!: schema.#ModulePathType
		version!:    schema.#VersionType
		fqn:         schema.#CatalogFQNType & "\(modulePath)@\(version)"
	}
	#transformers: [schema.#FQNType]: schema.#ComponentTransformer & {
		metadata: {
			modulePath: "\(M.modulePath)/transformers"
			version:    M.version
		}
	}
}

_ModulePath: "example.com/cat"

// No _Version, and the catalog instance sets no version — the author simply
// forgot, or is mid-development and has not picked one yet.
catalog: #Catalog & {
	metadata: modulePath: _ModulePath
}

shipped: {
	catalogFQN:     catalog.metadata.fqn
	catalogVersion: catalog.metadata.version
}
