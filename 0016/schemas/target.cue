// Target schema for enhancement 0016 — Initialize a Module Instance Package
// from a Published Module.
//
// Two surfaces are sketched here:
//
//   1. #ModuleInitSurface — the delta this enhancement adds to core's
//      #Module (one new optional field beside the existing debugValues).
//      Modeled standalone; the real change lands in core/src/module.cue
//      under the core-schema-edit protocol.
//   2. #InstanceInitRequest / #InstanceInitReport / #ScaffoldedPackage —
//      the CLI command's input, its user-facing report, and the exact
//      file set it writes.
//
// Fields gated on an Open Question carry an `// OQN:` marker pointing at
// ../03-decisions.md.
package schema

// #ModuleInitSurface: the slice of core's #Module this enhancement touches.
// Everything else on #Module is unchanged.
#ModuleInitSurface: {
	// #config: existing — the module's value contract (constraints and
	// defaults). Unchanged; shown because both values fields are intended
	// to satisfy it.
	#config: _

	// debugValues: existing — concrete example values for testing and
	// debugging. Contract UNCHANGED by this enhancement; it additionally
	// becomes the documented fallback template source for instance init
	// (D2) when initValues is absent.
	debugValues: _

	// initValues: NEW, optional — the values a freshly initialized
	// instance package starts from. When present, instance init renders
	// this into the generated values.cue and never reads debugValues (D3).
	//
	// OQ1: field name (initValues vs instanceValues vs a structured init:
	// block), whether the schema asserts it satisfies #config, and whether
	// it must be concrete.
	initValues?: _
}

// #InstanceInitRequest: the resolved input of `opm instance init` after
// flag parsing (OQ2 governs the concrete flag/positional surface).
#InstanceInitRequest: {
	// The published module's path including major, resolved to an OCI
	// repository via standard CUE_REGISTRY routing.
	// OQ2: whether an explicit OCI URL form is also accepted.
	moduleRef!: string // e.g. "opmodel.dev/modules/jellyfin@v3"

	// The version (registry tag) to pin in the generated
	// cue.mod/module.cue.
	// OQ2: resolution when omitted (refuse vs highest release of the major).
	version?: string // e.g. "3.0.0"

	// Instance identity, written into instance.cue metadata.
	name!:      string
	namespace!: string

	// Target directory. Defaults to the instance name.
	dir?: string
}

// #ValuesSource: which content populated the generated values.cue —
// reported to the user so a debug-derived scaffold is visibly that (D2).
#ValuesSource: "initValues" | "debugValues" | "empty"

// #ScaffoldedPackage: the exact file set init writes — the same on-disk
// instance-package shape LoadInstancePackage consumes, so init output is
// immediately valid input to `opm instance build` / `apply` and the
// operator's ModulePackage path (D1).
#ScaffoldedPackage: {
	files: {
		// The generated package's own module file: local module path,
		// language version, and deps pinning the module to the resolved
		// version plus core at the module's own major.
		// OQ6: dep-closure strategy (copy vs tidy vs minimal) and the
		// generated package's own module: path.
		"cue.mod/module.cue": #GeneratedFile

		// Imports core and the module, embeds core.#ModuleInstance, states
		// metadata {name, namespace}, wires `#module: <module package>`.
		"instance.cue": #GeneratedFile

		// `values: {...}` rendered from the selected #ValuesSource.
		// OQ3: exact content when the source is "empty" (bare struct vs
		// #config-derived skeleton).
		"values.cue": #GeneratedFile
	}
}

#GeneratedFile: {
	content: string
}

// #InstanceInitReport: what the command tells the user on success.
#InstanceInitReport: {
	moduleRef:       string
	resolvedVersion: string
	valuesSource:    #ValuesSource
	dir:             string

	// OQ5: whether init also runs instance vet on the scaffold before
	// reporting success, and what a template source failing #config does
	// (fail vs warn). A `verified` field lands here once OQ5 resolves.

	// Non-fatal notices — e.g. "values.cue scaffolded from debugValues;
	// review before deploying" when valuesSource is "debugValues".
	warnings: [...string]
}
