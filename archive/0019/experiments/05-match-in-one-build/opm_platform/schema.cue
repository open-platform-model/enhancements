// The PROPOSED #Platform shape, defined here rather than imported.
//
// Copied from core/src/platform.cue @ v2.0.0-alpha.4 and modified. Only the
// #registry entry changes; everything else is verbatim so the diff is legible.
// It is redefined locally (rather than unified onto core's #Platform) because
// core's #Subscription is closed around `enable` + `version!`, so the proposal
// cannot be expressed as an extension of it, which is itself the point: this
// is a core schema change, not an authoring convention.
//
//	core today                          this experiment
//	---------------------------------   ---------------------------------
//	#registry: [Path]: #Subscription    #registry: [Path]: #CatalogEntry
//	  enable:   bool | *true              enable:        bool | *true
//	  version!: #VersionType              #transformers: #TransformerMap
//
// The `version!` scalar is GONE, not optional. Under the proposal a catalog
// build is named the way every other CUE dependency is named, by the
// platform module's own cue.mod, and the transformer set arrives by import.
// Keeping a version field beside an import would create two answers to one
// question and no way to tell which is load-bearing.
package platform

import (
	c "opmodel.dev/core@v2"
)

// A registry entry: the catalog a platform admits, carried as its VALUE
// rather than named as a coordinate.
//
// #transformers is embedded WHOLE. Per-transformer selection is deliberately
// not expressible here; that is enhancement 0015's job (provider classes and
// TransformerRegistration), and putting a second selection mechanism in the
// platform file would compete with it.
#CatalogEntry: {
	enable: bool | *true

	// The imported catalog's transformer map, verbatim.
	#transformers: c.#TransformerMap
}

#PlatformV2: {
	kind: "Platform"

	metadata: {
		name!:        c.#NameType
		description?: string
		labels?:      c.#LabelsAnnotationsType
		annotations?: c.#LabelsAnnotationsType
	}

	type!: string

	#registry: [Path=c.#ModulePathType]: #CatalogEntry

	// DERIVED, not kernel-filled. With the transformers present in the
	// registry, the composed map is a fold over enabled entries rather than
	// a slot the Go kernel populates from an OCI pull
	// (library/opm/materialize/index.go). Written here to show the derivation
	// works; a real core change would also derive #matchers the same way.
	#composedTransformers: {
		for _, entry in #registry if entry.enable {
			entry.#transformers
		}
	}
}
