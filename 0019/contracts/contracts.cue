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
package contracts

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
// need a narrower comparison until D12's projection slice lands. Naming it here forces the
// choice to be stated rather than buried in the assertion helper.
#ParityCase: {
	name!: string

	// The three inputs, named by fixture rather than inlined. The harness
	// resolves them identically for both renderers; a case where the two
	// sides construct their inputs differently proves nothing.
	instance!:    string
	component!:   string
	transformer!: string

	// resolved-by-D12: core computes #context from the two inputs, so once
	// the projection slice lands both sides derive it identically and this
	// collapses to "structural" permanently; "output-fields-only" exists
	// only for the interim harness.
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
		// resolved-by-D12: core computes every field except #runtimeName as a
		// projection of the two inputs above; the kernel's obligation narrows
		// to filling #runtimeName alone.
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

	// resolved-by-D11: reaching a sibling through #moduleInstance.components
	// stays possible (D1/D3 forbid narrowing the filled value) and is
	// discouraged by authoring contract, never structurally prevented.
	siblingAccess!: "discouraged"
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

// D15: a transformer's relationship to component identity is read-only. The
// object name comes from #component.#names.resourceName and the DNS variants
// from #component.#names.dns.* — never interpolated from #context fields, and
// never read from #component.metadata.resourceName, which is the input to the
// cascade rather than the finalized projection. Generation stays upstream on
// #Component. Like sibling access (D11), this is an authoring contract
// enforced by catalog review, never structurally prevented.
#NamesAccess: {
	source!:     "#component.#names"
	derivation!: "forbidden"
}

// D16: the resourceName cascade's default is the instance-qualified name,
// spelled *("\(#instance.name)-\(name)" & #NameType) | #NameType — the
// default branch is unified with #NameType so an overlong concatenation
// refuses the render, and an explicit resourceName still wins. #names.dns
// inherits the qualification by construction.
#ResourceNameDefault: {
	form!:      "<instance>-<component>"
	validated!: "#NameType"
	override!:  "metadata.resourceName"
}

// ---------------------------------------------------------------------------
// The render build (D9) and the registry shape that makes it resolvable (D5)
// ---------------------------------------------------------------------------

// D9: the render step is one CUE build per render. The kernel generates the
// render module, and what that module's cue.mod owes is the D13 invariant:
// the complete tidied dependency set, or no render at all. Experiment 02
// measured that authority fails by OMISSION, never by override — a path the
// render module does not list is answered by the module graph's maximum
// instead of by the platform.
#RenderBuild: {
	// One build, one cue.Context, per render; the context does not outlive
	// the render (D8). No built value is shared between renders.
	buildsPerRender:   1
	sharesBuiltValues: false

	// resolved-by-D13, stated as obligations on the generated cue.mod.
	// The list is DERIVED by promotion — the platform module's list whole,
	// the instance module's unioned in for module-only paths, the platform
	// winning every shared path — never computed by a render-time tidy.
	// `refusesOnIncomplete` is fixed: no caller may configure it away —
	// a render module missing a path is a kernel defect, not a policy.
	dependencyList!:     "complete-tidied-set"
	derivedBy:           "promotion"
	refusesOnIncomplete: true

	// The check that no OPM-namespace path resolved from the module graph
	// rather than from the roots (the default-major trap has the same
	// shape: a default is honoured only for a root dependency).
	opmPathsFromRoots: true
}

// D5 (revised 2026-08-20): a registry entry carries the catalog by import,
// embedded WHOLE, and derives everything else from it. Inexpressible as an
// extension of core's #Subscription (closed around `enable` + `version!`),
// so this is the replacement shape. The catalog build is named where every
// other CUE dependency is named: the platform module's own cue.mod. In core
// the pattern constraint binds the map key to the embedded catalog, so key
// and import cannot drift:
//   #registry: [Path=#ModulePathType]: #CatalogEntry & {#catalog: metadata: modulePath: Path}
#CatalogEntry: {
	enable: bool | *true

	// The imported catalog, whole. Free to carry: unevaluated definition
	// payloads cost nothing (measured by experiment 07). core's #Catalog;
	// named by reference here.
	#catalog: _

	// Derived, never authored: a readout of the release-stamped identity
	// (#catalog.metadata.version). The operator MAY stamp the expected
	// version at platform-generation time; it unifies with the readout, so
	// wrong bytes are a build conflict naming this entry (D13's tripwire).
	version: string

	// The catalog's transformer map, derived: core's #TransformerMap &
	// #catalog.#transformers. Per-transformer selection is deliberately
	// inexpressible here — that concern belongs to enhancement 0015
	// (provider classes, TransformerRegistration).
	#transformers: _
}

// What replaces the kernel-filled #composedTransformers: a fold over enabled
// entries, computable in the schema itself once the maps are present. Folds
// COPY (comprehension), never unify into one catalog's member map — the D25
// provenance stamp refuses foreign members (measured by experiment 05).
#ComposedTransformers: {
	#registry: [string]: #CatalogEntry
	out: {
		for _, entry in #registry if entry.enable {
			for tfqn, tf in entry.#transformers {(tfqn): tf}
		}
	}
}

// D10: matching inside the build reports verdicts as DATA. The shape below is
// the contract experiment 05's glue measured: a caller (the kernel, via
// LookupPath) reads these beside a failing fail-closed gate. Two boundaries
// are part of the contract: an unstated trait posture refuses as a build
// error rather than a diagnostics row, and an incomplete pair output is
// caught by per-pair concreteness validation, not by these fields.
#MatchDiagnostics: {
	pairs: [...{component!: string, transformer!: string}]
	missing: [...{component!: string, kind!: "resource" | "trait", fqn!: string}]
	unifyFailures: [...{component!: string, transformer!: string, conflicts!: [...string]}]
	unresolved: [...{component!: string, kind!: "resource" | "trait", fqn!: string, disqualified!: [...string]}]
	warnings: [...{component!: string, fqn!: string}]
	unmatchedComponents: [...string]

	// The fail-closed gate (0010 D28): unified against `true` inside the
	// build; the build refuses while every field above stays readable
	// through the Go API.
	resolved!: bool
}
