// Behaviour contracts for enhancement 0019 (Kernel render path parity with
// pure CUE).
//
// This entry mostly changes kernel BEHAVIOUR rather than schema shapes, so
// most of its target is stated as a contract over that behaviour: which
// inputs the runtime owes a #transform, what may and may not be removed from
// a value in transit, what the render build owes its own cue.mod, what a
// transformer author may read, and what the parity oracle compares. Writing
// it in CUE rather than prose makes the obligations enumerable: a fill site
// can be checked against #FillObligation, a generated cue.mod against
// #DependencyPromotion, and the harness's comparison scope against
// #ParityCase.
//
// Nothing here proposes an opmodel.dev/core definition. The three decisions
// that DO change core live in ../schemas/ (the core-schema delta, gated by
// config.yaml core_schema: true), where they are exercised by examples.cue
// and pre-drafted for SPEC.md:
//
//   D5  the registry entry that carries its catalog     -> ../schemas/target.cue
//   D12 #TransformerContext as a projection (the shape) -> ../schemas/target.cue
//   D16 the instance-qualified resourceName default     -> ../schemas/target.cue
//
// Where a contract here has a counterpart there, its comment says so rather
// than restating the shape: two copies of one derivation is the drift this
// entry exists to remove, and it would be a poor look to introduce it in the
// entry's own files.
//
// Self-contained: no imports, no module dependencies. Two core type names are
// mirrored below as plain strings because a field's TYPE is part of what the
// contract says; nothing here validates a value against them.
package contracts

// ---------------------------------------------------------------------------
// Mirrors of core type names
// ---------------------------------------------------------------------------
//
// core is the source of truth; these carry no constraints because no contract
// in this file validates a value. The real constrained forms are in
// core/src/types.cue, and ../schemas/target.cue mirrors them faithfully where
// the delta needs them to bite.

// core's #ModulePathType — "opmodel.dev/catalogs/opm@v2".
#ModulePathType: string

// core's #VersionType — SemVer 2.0.
#VersionType: string

// ---------------------------------------------------------------------------
// The parity contract (D1)
// ---------------------------------------------------------------------------

// The reference semantics of the render path. `kernel` is what
// library/opm/compile produces; `cue` is what plain unification of the same
// three inputs produces in a single CUE build. D1 fixes `cue` as the oracle:
// where they differ, the kernel is defective and the fix removes kernel
// behaviour rather than adding emulation.
#Renderer: "kernel" | "cue"

// D1 as three fields rather than a sentence. `closesBy` is the load-bearing
// one: it fixes the DIRECTION of every parity fix, so a proposal that closes a
// divergence by teaching the kernel to emulate CUE more faithfully is refused
// by the contract rather than by review taste.
#ParityContract: {
	oracle:     #Renderer & "cue"
	closesBy:   "kernel-removal"
	enforcedBy: "differential-harness"
}

// One comparison the parity harness performs. A case names the inputs, and
// asserts the two renderers agree.
//
// `equality` is deliberately a field rather than an assumption: structural
// equality of the exported value is the intended meaning, but #context is
// projected differently on the two sides today, so the harness may legitimately
// need a narrower comparison until D12's projection slice lands. Naming it here
// forces the choice to be stated rather than buried in the assertion helper.
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

	// D14: field order is part of what the harness compares, because the
	// output ordering contract is CUE's natural one. Fixed rather than
	// per-case: a harness that compares modulo order cannot observe a
	// re-sorting pass being reintroduced, which is the regression D14's
	// alternatives call out.
	orderSensitive: true

	// Whether this case is expected to diverge today. The harness lands
	// before the fixes (D4), so its first run legitimately reports failures;
	// they are the evidence for D1, not a broken harness. Every entry here
	// must be emptied by the time the entry reaches `implemented`.
	expectedDivergence?: string
}

// ---------------------------------------------------------------------------
// What the runtime owes #transform (D3, D12)
// ---------------------------------------------------------------------------

// The three inputs core/src/transformer.cue declares on #transform. Its own
// comment states the contract this file makes enumerable: "The runtime
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
		input:  "#moduleInstance"
		source: "instance-derived"
		preserves: ["regular", "definition", "hidden", "optional-unset"]
	},
	{
		input:  "#component"
		source: "instance-derived"
		preserves: ["regular", "definition", "hidden", "optional-unset"]
	},
	{
		// resolved-by-D12: core computes every field except #runtimeName as a
		// projection of the two inputs above (../schemas/target.cue writes the
		// projection), so the kernel's obligation narrows to filling
		// #runtimeName alone.
		input:  "#context"
		source: "runtime-owned"
		preserves: ["regular", "definition", "hidden", "optional-unset"]
	},
]

// D12 from the RUNTIME's side: which fields stop being the kernel's job, and
// what has to be true before the Go fills are deleted. The core-side shape of
// the projection is ../schemas/target.cue's #TransformerContext; this is the
// migration contract around it.
//
// Enumerating the split is the point: `runtimeOwned` is the whole of what the
// kernel may still fill, so a future context field is projected by default and
// a second runtime-owned slot has to argue for itself here.
#ContextProjection: {
	// Computed by core from #moduleInstance and #component.
	projected!: [...string]

	// Supplied by the runtime, because nothing in the two inputs carries it.
	runtimeOwned!: [...string]

	// The hand-maintained Go decode/re-encode mirror the projection replaces.
	goMirrorDeleted: "opm/schema/context.go"

	// Staged migration: for one release the kernel keeps filling values
	// identical to what the projection computes and unification agrees. The
	// harness confirming agreement is what unblocks removing the Go fills, and
	// #ParityCase.equality collapses to "structural" at that point.
	staged:            true
	removeGoFillsWhen: "parity harness reports agreement on every case"
}

// The field split as core declares it today (core/src/transformer.cue).
#targetContextProjection: #ContextProjection & {
	projected: [
		"#moduleInstanceMetadata",
		"#componentMetadata",
		"moduleLabels",
		"moduleAnnotations",
		"componentLabels",
		"componentAnnotations",
		"controllerLabels",
		"labels",
		"annotations",
	]
	runtimeOwned: ["#runtimeName"]
}

// ---------------------------------------------------------------------------
// The execution unit (D2, D11)
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

	// What a transformer forfeits by reading a sibling anyway. Written down
	// because "discouraged" with no stated cost is a rule nobody can weigh.
	forfeitsOnSiblingRead: [
		"per-pair error attributability",
		"per-pair reordering",
		"per-pair caching",
	]
}

// ---------------------------------------------------------------------------
// Authoring obligations on transformer authors (D11, D15)
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

// D15: a transformer's relationship to component identity is read-only, and
// the rule is scoped to the component's PRIMARY object. The object name comes
// from #component.#names.resourceName and the DNS variants from
// #component.#names.dns.*. Generation stays upstream on #Component (the
// cascade whose default D16 changes; see ../schemas/target.cue). Like sibling
// access (D11), this is an authoring contract enforced by catalog review and
// by the harness's fixtures, never structurally prevented: CUE cannot forbid
// string interpolation.
#NamesAccess: {
	scope!:      "primary-object"
	source!:     "#component.#names"
	derivation!: "forbidden"

	// The two spellings the sweep replaces, kept as data because both are
	// equal in value today and therefore invisible to any test. #context is
	// itself a projection of #component under D12, and metadata.resourceName
	// is the INPUT to the cascade rather than its finalized projection.
	forbiddenSources: ["#context", "#component.metadata.resourceName"]

	enforcedBy: "catalog review + parity harness fixtures"
}

// A class of name the D15 sweep does NOT rewrite, and the rule that governs it
// instead. Enumerated because the unscoped version of D15 was wrong against
// the shipped catalog: 50 transformers, of which these three classes are not
// primary-object names at all.
#NameCarveOut: {
	class!: "exact-name" | "secondary" | "cross-reference"
	rule!:  string
	examples!: [...string]
}

#nameCarveOuts: [...#NameCarveOut] & [
	{
		// Names that are contracts with something outside the module render,
		// so the API server (not the module) decides them.
		class: "exact-name"
		rule:  "authored verbatim; #names is not consulted"
		examples: [
			"APIService (<version>.<group>)",
			"CRD (<plural>.<group>)",
			"webhook configurations (patched by name at runtime)",
			"Namespace",
			"Role / RoleBinding / ServiceAccount",
			"k8s_object user-supplied segment",
		]
	},
	{
		// Objects a component emits beside its primary one. They stay derived,
		// with #names.resourceName as the prefix wherever one applies.
		class: "secondary"
		rule:  "derived, prefixed by #component.#names.resourceName where a prefix applies"
		examples: [
			"per-item ConfigMap / Secret names (hash-suffixed immutable forms included)",
			"per-volume PVCs",
			"policy-plus-binding pairs",
			"#ExposeSchema.name (Service exact-name knob)",
			"headless and governing service names",
		]
	},
	{
		// The silent-failure class: a wrong name here vets clean and breaks at
		// runtime, because nothing unifies the two sides.
		class: "cross-reference"
		rule:  "follows the REFERENCED object's naming rule; never an independent formula"
		examples: [
			"HPA scaleTargetRef",
			"PDB selector target",
			"route backendRefs",
			"StatefulSet serviceName",
		]
	},
]

// D15's other half: the catalog's own competing name-override authority is
// deleted rather than reconciled, because core's metadata.resourceName
// subsumes it and (after D16) carries the DNS variants the trait never did.
// Alpha stance: removed outright, no deprecation cycle.
//
// This is a catalogs/opm change, which is why it is here and not in the core
// delta: nothing in core moves for it.
#DeletedNameAuthority: {
	definition:       "#ResourceNameTrait"
	file:             "traits/v1beta1/resource_name.cue"
	helper:           "#WorkloadName"
	replacedBy:       "#Component.metadata.resourceName"
	deprecationCycle: false
	fixturesMigrated: ["istio-cni-node", "istiod", "database"]

	// The sweep is byte-identity gated, and the gate only holds if the core
	// default flips first: D16 makes the value #names computes equal to what
	// every hand-rolled formula already renders.
	gatedOn: ["library-component-fill", "core-resourcename-default"]
}

// ---------------------------------------------------------------------------
// The render build (D8, D9, D13, D14)
// ---------------------------------------------------------------------------

// D9: the render step is one CUE build per render. The kernel generates the
// render module, and what that module's cue.mod owes is the D13 invariant:
// the complete tidied dependency set, or no render at all. Experiment 02
// measured that authority fails by OMISSION, never by override: a path the
// render module does not list is answered by the module graph's maximum
// instead of by the platform.
#RenderBuild: {
	// One build, one cue.Context, per render; the context does not outlive
	// the render (D8). No built value is shared between renders.
	buildsPerRender:   1
	sharesBuiltValues: false

	// D8 stated as the fields that make it checkable rather than as a
	// principle. `contextOutlivesRender: false` is the rule ADR-002 lost:
	// holding a cue.Context is what retains 348 MB per render, and filling a
	// shared built value is a write to its evaluation state, which is the race
	// experiment 06 reproduced. Concurrency is across renders only, so a pool
	// is sized by memory rather than by core count (CUE evaluates one build
	// single-threaded).
	contextOutlivesRender: false
	concurrency:           "across-renders"
	poolSizedBy:           "memory"

	// How the two unpublished inputs enter the build (D9). Named because the
	// mechanism is the reason nothing crosses a build boundary and therefore
	// the reason nothing can be stripped in transit.
	staging: {
		instanceEntersVia: "generated render module (synth in-tree staging)"
		overridesVia:      "cue.mod/local-module.cue directory replacements"
	}

	// What the kernel reads off the built value. Two values, both by
	// LookupPath, both readable beside a failing fail-closed gate (D10).
	reads: ["rendered", "diagnostics"]

	// resolved-by-D13, stated as obligations on the generated cue.mod.
	// The list is DERIVED by promotion (see #DependencyPromotion), never
	// computed by a render-time tidy. `refusesOnIncomplete` is fixed: no
	// caller may configure it away, because a render module missing a path is
	// a kernel defect rather than a policy.
	dependencyList!:     "complete-tidied-set"
	derivedBy:           "promotion"
	refusesOnIncomplete: true

	// The check that no OPM-namespace path resolved from the module graph
	// rather than from the roots (the default-major trap has the same
	// shape: a default is honoured only for a root dependency).
	opmPathsFromRoots: true

	dependencies: #DependencyPromotion
	ordering:     #OutputOrdering
}

// D13: the promotion rule, spelled out as the facts a reviewer has to check
// the implementation against. `renderTimeTidy: false` is the negative half and
// the one most likely to be reintroduced by accident: tidy WRITES a
// resolution, and the render build's job is to inherit one that was already
// written at platform-package generation (D6, cold path).
#DependencyPromotion: {
	platformList:     "promoted whole into the render module's roots"
	instanceList:     "unioned in for paths only the module carries"
	sharedPathWinner: "platform"
	renderTimeTidy:   false
	tidiedAt:         "platform-package generation (D6)"

	// A shared path where the two lists disagree is not silently resolved: the
	// disagreement IS the skew surface, reported through D7's diagnostics.
	sharedPathDisagreement: "reported as #SkewDiagnostic"

	// Defense in depth, not the mechanism: D5's derived fields turn wrong
	// bytes into a build conflict naming the registry entry even if promotion
	// is ever defective. Both live in ../schemas/target.cue as core shape;
	// named here because the render path is what they protect. Rejected as
	// the SOLE mechanism, because they detect rather than prevent and cover
	// only stamped OPM artifacts.
	tripwires: [
		"#CatalogEntry.version: stamped expectation unified with the derived readout",
		"#Platform.#registry: key bound into #catalog.metadata.modulePath",
	]
}

// D14: the byte ordering the collapse emits is the contract. Today's ordering
// is an artifact of the strip (finalize.go re-emits through Syntax(cue.Final()),
// which hoists comprehension-produced fields ahead of declared ones), carrying
// no compatibility promise. Re-sorting to preserve it would be kernel
// behaviour added to emulate an artifact, which is D1's wrong direction.
#OutputOrdering: {
	ordering:         "cue-natural"
	finalizationPass: false
	reSortsOutput:    false

	// The whole migration cost, measured: 12 of 28 comparison points differ
	// modulo list order, all of them fixtures whose container environment is
	// assembled from several guarded sources.
	migration: "one server-side-apply diff on the first reconcile after upgrade"
	shipsWith: "library-finalize-removal"
}

// ---------------------------------------------------------------------------
// Where the platform package comes from (D6)
// ---------------------------------------------------------------------------

// D6: the Platform CR keeps naming a catalog coordinate in typed Kubernetes
// fields, and the operator encodes those into a #Platform CUE package on the
// backend. D5 moved resolution into a cue.mod, which a CR cannot express, so
// generation is what gives the build a real module. It is also the step where
// a runtime-discovered transformer set is folded in (enhancement 0015 D3's
// TransformerRegistration).
//
// No core shape moves for this: what the generator EMITS is the core delta in
// ../schemas/target.cue; this is the contract on the generator.
#PlatformPackage: {
	crCarries:   "catalog coordinate (typed fields), not CUE text"
	generatedBy: "opm-operator, on the backend"

	// Revised 2026-08-20: publishing is disallowed outright rather than
	// permitted-but-unused. A published module cannot carry a build-local
	// override (mod/modfile/schema.cue's #Strict refuses replaceWith), so a
	// published platform would express intent without enforcement outside the
	// kernel's own promotion path (D13).
	publishable:     false
	namespaceStatus: "reserved-unpublished"
	reservedPath:    "opmodel.dev/platforms"

	// The generated module is where tidy runs (D13's cold path).
	tidiedHere: true
}

// ---------------------------------------------------------------------------
// Catalog version skew (D7)
// ---------------------------------------------------------------------------

// The caller's choice. Supplied per compile, so cli and opm-operator can each
// expose it on their own surface without reimplementing the comparison.
#SkewPolicy: "warn" | "refuse"

// D7: what is configurable, and what is not. The three fixed fields are the
// decision's substance: each names a case that LOOKS like it belongs under the
// policy and does not.
#SkewContract: {
	detectedBy: "kernel"
	response!:  #SkewPolicy

	// library/CONSTITUTION.md forbids the kernel writing to stdout or stderr,
	// so "warn" means a structured diagnostic returned to the caller through
	// the channel compile already has. Rendering it is the caller's job.
	emitsOutput: false
	warnChannel: "compile warnings"

	// A module requiring an OLDER build than the platform imports is the
	// ordinary forward-compatible case, not skew. Its lower-severity signal is
	// OQ7's residue, deliberately not folded in here.
	olderIsSkew: false

	// A render module omitting a path is a kernel defect (D13), caught by an
	// internal invariant. No caller may configure it away, which is why it is
	// not reachable through #SkewPolicy at all.
	missingPathIsSkew: false
}

// One detected skew, as the caller receives it. `relation` is what the kernel
// computes; only "newer" reaches the policy. The two versions are read off the
// two committed resolutions D13 promotes from, and `entry` names the registry
// entry whose path they disagree on.
#SkewDiagnostic: {
	entry!:           #ModulePathType
	moduleRequires!:  #VersionType
	platformImports!: #VersionType
	relation!:        "newer" | "older" | "equal"
}

// ---------------------------------------------------------------------------
// Matching inside the render build (D10)
// ---------------------------------------------------------------------------

// D10: matching is expressed in CUE inside the render build, per experiment
// 05's measured glue shape. Semantics are unchanged; the slice's gate is
// reproducing the kernel's exact pair set against a vendored kernel record.
//
// The glue OWNS the reverse index (D17): #Platform.#matchers is removed rather
// than derived, so the buckets are built here from the composed transformer
// map, keyed contract FQN to a set of transformer FQNs. Experiment 05's #Match
// takes exactly two inputs, the composed map and the components, which is what
// makes the removal free: nothing in the render path was reading the slot.
#MatchingInBuild: {
	location: "render-build"
	rungs: ["reverse-index (required ∪ optional)", "always-unify", "predicate"]

	// D17: where the first rung's index comes from, and its shape. Stated
	// because core no longer carries one, so this is the only reverse index
	// in the system.
	bucketsBuiltBy:       "render glue, from #composedTransformers"
	bucketShape:          "contract FQN -> set of transformer FQNs"
	platformCarriesIndex: false

	// In one build both embedded copies resolve to the same catalog bytes, so
	// the always-unify rung runs as plain `&` and 0010 D30's provenance
	// carve-out (excludeProvenance plus its denylist) is DELETED rather than
	// ported, together with the parity harness's one stated exemption.
	// Porting it is impossible as stated anyway: CUE cannot express "unify but
	// ignore conflicts at these paths".
	alwaysUnify:        "plain &"
	provenanceCarveOut: "deleted"
	parityExemption:    "deleted"

	// 0010 D28's fail-closed gate is one unification inside the build. The
	// diagnostics value stays fully readable and concrete beside the failing
	// gate, which is why verdicts are data rather than bottoms.
	failClosedGate:    "resolved & true"
	diagnosticsReadBy: "LookupPath"
	semanticsChange:   false

	// Two measured boundaries, part of the contract rather than surprises for
	// the implementer.
	//
	// An unhandled trait with an UNSTATED optional posture refuses as an
	// incomplete-value error naming core/trait.cue's own `optional` field:
	// fail-closed survives, but as a build error, because posture-statedness
	// is default-detection, which CUE exposes only through evaluation. Making
	// it a diagnostics row needs a publish-side gate enforcing 0010 D46, which
	// belongs to the 0011 publish-gate family.
	unstatedTraitPosture: "build error, not a diagnostics row"

	// An INCOMPLETE (non-error) pair output is invisible to `== _|_`: it lands
	// non-concrete in `rendered`, where the per-pair concreteness validation
	// the kernel already owns catches it at a path naming the pair key. So
	// failure isolation as data covers error-class failures only.
	incompletePairOutput: "caught by per-pair concreteness validation"

	// The one recoverability loss, recorded so the fallback (keep matching in
	// Go) stays a legible option during the slice.
	losesOnMove: "oerrors.UnifyError's verbatim CUE cause, not recoverable in-build without a second diagnostic evaluation"
}

// The verdict shape experiment 05's glue measured: a caller (the kernel, via
// LookupPath) reads these beside a failing fail-closed gate.
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
