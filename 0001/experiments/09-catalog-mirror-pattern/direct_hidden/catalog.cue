// Direct variant in production mode — bare `metadata.modulePath` reference
// inside the pattern, AND no public projection. Mirrors how the real
// `core/catalog.cue` is structured: `#transformers` is hidden, and modules /
// consumers don't typically read it from public fields (the kernel reads it
// at materialize time, but that's runtime Go code, not vet).
//
// CUE scoping mechanism: inside the pattern's nested `metadata: { ... }`
// block, a bare `metadata.modulePath` reference walks back up to the
// closest parent field named `metadata` — which is the inner field being
// constructed itself. The reference self-embeds (the field tries to
// interpolate its own under-construction modulePath into its own
// modulePath), which evaluates to a non-concrete value rather than
// resolving to the outer `#Catalog.metadata`.
//
// Expected: plain `cue vet` AND `cue vet -c` BOTH pass SILENTLY (the trap).
// `cue eval --all` (traversing hidden fields) surfaces the unresolved
// interpolation. Compare with `direct/` (same schema bug, but a public
// `stamped:` projection forces concretization and surfaces the error at
// plain vet). This variant demonstrates the genuine production failure
// mode: CI on `core/catalog.cue` with `cue vet` alone would miss this.
package direct_hidden

import "enhancements.opmodel.dev/0001/experiments/09-catalog-mirror-pattern/schema"

#Catalog: {
	kind: "Catalog"
	metadata: {
		modulePath!: schema.#ModulePathType
		version!:    schema.#VersionType
	}
	#transformers: [schema.#FQNType]: schema.#ComponentTransformer & {
		metadata: {
			modulePath: "\(metadata.modulePath)/transformers"
			version:    metadata.version
		}
	}
}

instance: #Catalog & {
	metadata: {
		modulePath: "example.com/cat"
		version:    "1.0.0"
	}
	#transformers: {
		"example.com/cat/transformers/foo@1.0.0": {
			metadata: name: "foo"
		}
	}
}
