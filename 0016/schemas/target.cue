// Core-schema delta for enhancement 0016 — Initialize a Module Instance
// Package from a Published Module.
//
// Delta manifest (vs opmodel.dev/core@v2):
//
//   - #Module — CHANGED: gains one new optional field, initValues (working
//     name, OQ1), beside the existing debugValues. Modeled standalone here
//     as #ModuleInitSurface — the slice of #Module this enhancement
//     touches, with `_` placeholders for the untouched rest; the real
//     change lands in core/src/module.cue under the core-schema-edit
//     protocol.
//
// The CLI command contracts (#InstanceInitRequest, #InstanceInitReport,
// #ScaffoldedPackage, #ValuesSource) live in ../contracts/contracts.cue —
// they propose no core surface.
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
