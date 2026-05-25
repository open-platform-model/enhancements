// Label-alias variant — `M=metadata: {...}` field-label alias form.
//
// Distinct from the value-alias form in `alias/` (`metadata: M={...}`):
//   - value-alias: `metadata: M={...}` binds `M` to the value; CUE's value
//     aliases do NOT carry across the nested pattern-constraint boundary.
//   - label-alias: `M=metadata: {...}` binds `M` to the field/path itself;
//     this alias DOES carry across the boundary and resolves to the outer
//     catalog's metadata field.
//
// Expected: vet clean; stamping works identically to mirror/. This is a
// second sound form for reading outer catalog metadata from inside the
// pattern constraint. Discovered while debugging direct/ — see the README.
package label_alias

import "enhancements.opmodel.dev/0001/experiments/09-catalog-mirror-pattern/schema"

#Catalog: {
	kind: "Catalog"
	M=metadata: {
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

// Public projection so `cue export` exposes the stamped values.
stamped: instance.#transformers["example.com/cat/transformers/foo@1.0.0"].metadata
