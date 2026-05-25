// Alias variant — `metadata: M={...}` value-alias form.
//
// CUE has two alias forms; they behave differently across pattern-constraint
// boundaries:
//   - VALUE alias: `field: M={...}` binds `M` to the value of `field`.
//   - LABEL alias: `M=field: {...}` binds `M` to the field/path itself.
//
// This variant uses the value-alias form. Expected: vet FAILS with
// "reference M not found". Value aliases do NOT carry across the nested
// pattern-constraint boundary into the transformer literal's body.
// D19's history entry recorded this as the original attempt that failed
// and motivated the `_md` mirror workaround. The label-alias form
// (`M=metadata: {...}`), which DOES carry across, is demonstrated in
// `label_alias/` — see that variant for the sound alternative.
package alias

import "enhancements.opmodel.dev/0001/experiments/09-catalog-mirror-pattern/schema"

#Catalog: {
	kind: "Catalog"
	metadata: M={
		modulePath!: schema.#ModulePathType
		version!:    schema.#VersionType
	}
	#transformers: [schema.#FQNType]: schema.#ComponentTransformer & {
		metadata: {
			modulePath: "\(M.modulePath)/transformers"
			version:    M.version
		}
	}
}

// Concrete instance to trigger the pattern. If the alias propagated as
// hoped, this would evaluate identically to mirror/. We expect "reference
// M not found" instead.
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
