// Target schema for enhancement 0019 (Kernel render path parity with pure CUE).
//
// This entry changes kernel BEHAVIOUR, not primarily schema shapes, so the
// target is stated as a contract over that behaviour: which inputs the runtime
// owes a #transform, what may and may not be removed from a value in transit,
// and what the parity oracle compares. Writing it in CUE rather than prose
// makes the obligations enumerable: a fill site can be checked against
// #FillObligation, and the harness's comparison scope against #ParityCase.
//
// Self-contained by design: it does not import opmodel.dev/core, so it
// compiles with no module dependencies. Shapes it mirrors from core are
// named as references rather than redeclared.
//
// Unresolved fields carry an OQ# comment pointing at ../03-decisions.md.
package schema

// ---------------------------------------------------------------------------
// The parity contract
// ---------------------------------------------------------------------------

// The reference semantics of the render path. `kernel` is what
// library/opm/compile produces; `cue` is what plain unification of the same
// three inputs produces in a single CUE build. D1 fixes `cue` as the oracle:
// where they differ, the kernel is defective and the fix removes kernel
// behaviour rather than adding emulation.
#Renderer: "kernel" | "cue"

// One comparison the parity harness performs. A case names the inputs, and
// asserts the two renderers agree.
//
// `equality` is deliberately a field rather than an assumption: structural
// equality of the exported value is the intended meaning, but #context is
// projected differently on the two sides today, so the harness may legitimately
// need a narrower comparison until OQ5 resolves. Naming it here forces the
// choice to be stated rather than buried in the assertion helper.
#ParityCase: {
	name!: string

	// The three inputs, named by fixture rather than inlined. The harness
	// resolves them identically for both renderers; a case where the two
	// sides construct their inputs differently proves nothing.
	instance!:    string
	component!:   string
	transformer!: string

	// OQ5: while #TransformerContext is filled by the kernel and projected by
	// hand on the CUE side, "structural" may over-report. If OQ5 resolves
	// toward projection, both sides derive #context from the same two inputs
	// and this collapses to "structural" permanently.
	equality!: "structural" | "output-fields-only"

	// Whether this case is expected to diverge today. The harness lands
	// before the fixes (D4), so its first run legitimately reports failures;
	// they are the evidence for D1, not a broken harness. Every entry here
	// must be emptied by the time the entry reaches `implemented`.
	expectedDivergence?: string
}

// ---------------------------------------------------------------------------
// What the runtime owes #transform
// ---------------------------------------------------------------------------

// The three inputs core/src/transformer.cue declares on #transform. Its own
// comment states the contract this schema makes enumerable: "The runtime
// supplies all three inputs concretely."
#TransformInput: "#moduleInstance" | "#component" | "#context"

// One fill the kernel performs, and the shape of the value it supplies.
//
// `preserves` is the field this entry exists for. A fill that removes any
// field class from the value in transit diverges from unification, which
// removes nothing.
#FillObligation: {
	input!: #TransformInput

	// Where the filled value comes from. `instance-derived` means it is read
	// off the evaluated #ModuleInstance without a Go-side round trip;
	// `runtime-owned` means the runtime is its only possible source.
	source!: "instance-derived" | "runtime-owned"

	// Which field classes survive the fill. Parity requires all of them for
	// any instance-derived value: unification narrows nothing, so neither may
	// the kernel. Stated as a set rather than a boolean so a future divergence
	// has to name exactly what it drops.
	preserves!: [...#FieldClass]

	if source == "instance-derived" {
		preserves: [...#FieldClass] & [_, _, _, _]
	}
}

// The field classes cue.Final() distinguishes. Three of the four switches it
// flips were wanted when FinalizeValue was written; `definition` was
// collateral, and dropping it is the divergence this entry closes.
#FieldClass: "regular" | "definition" | "hidden" | "optional-unset"

// The target fill set. #component and #moduleInstance are both read off the
// evaluated instance and both preserve every field class. #context is the only
// input with a runtime-owned component (#runtimeName), which is why it is the
// only one that cannot be a pure projection.
#targetFills: [...#FillObligation] & [
	{
		input:     "#moduleInstance"
		source:    "instance-derived"
		preserves: ["regular", "definition", "hidden", "optional-unset"]
	},
	{
		input:     "#component"
		source:    "instance-derived"
		preserves: ["regular", "definition", "hidden", "optional-unset"]
	},
	{
		// OQ5: every field except #runtimeName is derivable from the two
		// inputs above. If OQ5 resolves toward projection, this obligation
		// narrows to filling #runtimeName alone and core computes the rest.
		input:     "#context"
		source:    "runtime-owned"
		preserves: ["regular", "definition", "hidden", "optional-unset"]
	},
]

// ---------------------------------------------------------------------------
// The execution unit
// ---------------------------------------------------------------------------

// D2: #transform evaluates once per (component, transformer) pair, and
// #component carries exactly one component. Stated here because D3 fills
// #moduleInstance, which contains every sibling component, so the invariant
// is no longer implied by what is reachable.
#ExecutionUnit: {
	componentsPerEvaluation: 1

	// OQ4: whether reaching a sibling through #moduleInstance.components is
	// permitted, discouraged, or structurally prevented. `reachable` is the
	// state D3 produces; the other two are the candidate resolutions.
	siblingAccess!: "reachable" | "discouraged" | "prevented"
}

// ---------------------------------------------------------------------------
// Authoring obligation
// ---------------------------------------------------------------------------

// CUE resolves references lexically, against the source where the reference is
// written, not against the unified result. A slot that arrives only by
// unification with core.#ComponentTransformer is therefore NOT in scope in a
// transformer's own body: referencing it fails the catalog build with
// `reference "#moduleInstance" not found`.
//
// Every transformer that reads an input must re-declare it. This is already
// why shipped transformers write `#component: _` despite core declaring it,
// and it becomes author-visible the moment #moduleInstance is fillable.
#TransformerDeclaration: {
	reads!: [...#TransformInput]

	// Must equal `reads`. Modelled as a separate field rather than derived,
	// because the failure this encodes is precisely an author reading
	// something they did not declare.
	declares!: [...#TransformInput]
	declares: reads
}
