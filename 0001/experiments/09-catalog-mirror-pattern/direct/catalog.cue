// Direct variant — naive `metadata.modulePath` reference inside the
// pattern constraint, with no mirror and no alias. Uses a public
// `stamped:` projection to force concretization at vet time.
//
// CUE scoping mechanism: inside the inner `metadata: { ... }` block,
// `metadata.modulePath` walks back up to the closest parent field named
// `metadata` — which is the inner field being constructed itself. The
// reference self-embeds (the field tries to interpolate its own
// under-construction `modulePath` into its own `modulePath`), producing
// a non-concrete value rather than resolving to the outer
// `#Catalog.metadata`.
//
// Expected: vet FAILS — the public `stamped:` projection forces
// concretization, surfacing the non-concrete value at plain `cue vet`.
// Without the projection (see `direct_hidden/`), vet would pass silently.
package direct

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

// Concrete instance to trigger the pattern.
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

// Public projection. Reading `instance.#transformers[...]` from a public
// field forces concretization of the stamped value, which surfaces the
// incomplete-value error at plain `cue vet` time.
//
// IMPORTANT subtlety for the production failure mode: in `core/catalog.cue`,
// `#Catalog.#transformers` is hidden and nothing public references it. Without
// a public projection like this one, plain `cue vet` passes silently — only
// `cue vet -c` or kernel-time materialize catches the broken stamping. This
// experiment exposes the bug at plain vet by adding a public reader; the
// README's outcome documents the production-mode trap explicitly.
stamped: instance.#transformers["example.com/cat/transformers/foo@1.0.0"].metadata
