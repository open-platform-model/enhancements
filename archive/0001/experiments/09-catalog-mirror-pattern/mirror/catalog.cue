// Mirror variant — `_md: metadata` hidden top-level field reference.
//
// Expected: vet clean. The `_md` mirror is a separate field on `#Catalog`
// whose value equals `metadata`. From inside the pattern's nested
// `metadata: { ... }` block, a `_md.modulePath` reference walks up to the
// closest parent field named `_md` — which is the outer `#Catalog._md` (no
// inner field named `_md` exists to self-collide with). The mirror reads
// the outer metadata cleanly. This is one of two sound forms: see
// `label_alias/` for the `M=metadata: {...}` field-label alias form.
package mirror

import "enhancements.opmodel.dev/0001/experiments/09-catalog-mirror-pattern/schema"

#Catalog: {
	kind: "Catalog"
	metadata: {
		modulePath!: schema.#ModulePathType
		version!:    schema.#VersionType
	}
	_md: metadata
	#transformers: [schema.#FQNType]: schema.#ComponentTransformer & {
		metadata: {
			modulePath: "\(_md.modulePath)/transformers"
			version:    _md.version
		}
	}
}

// Concrete instance — should evaluate to fully-concrete values with the
// transformer's modulePath = "example.com/cat/transformers" and version = "1.0.0".
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

// Public projection so `cue export` exposes the stamped values for inspection.
// The map key "example.com/cat/transformers/foo@1.0.0" must equal the
// computed fqn `<modulePath>/<name>@<version>` of the transformer; if the
// pattern didn't stamp modulePath + version correctly the fqn would not match
// the key and unification would have failed at vet time.
stamped: instance.#transformers["example.com/cat/transformers/foo@1.0.0"].metadata
