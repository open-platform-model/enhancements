// Contracts for enhancement 0017 — Layered Defaults.
//
// This file governs the non-core side of the layering design: the who-writes-
// what layer contract (core SPEC.md §6 rules L1–L6, as citable rule data for
// CLI gates — D1/D4/D6) and the catalog-side blueprint idiom it constrains
// (D2/D3: bounds-only primitives, subtractive narrowing plus one field-level
// default). None of this is proposed opmodel.dev/core surface — the core
// delta lives in ../schemas/. Source of truth: core SPEC.md §6 for the rule
// text; catalog_opm blueprints for the idiom (issue 40 tracks the exhaustive
// per-kind audit). Marker comments reference Open Questions in
// ../03-decisions.md.
package contracts

/////////////////////////////////////////////////////////////////
// D3 — the blueprint idiom: subtractive narrowing + one field-level
// default. Illustrated for the stateless workload (Deployment).
/////////////////////////////////////////////////////////////////

// What the trait publishes: bounds only, union across kinds (D2/L1).
#UpdateStrategyBounds: {
	type: "RollingUpdate" | "Recreate" | "OnDelete"
	rollingUpdate?: {
		maxUnavailable?: uint | string
		maxSurge?:       uint | string
		partition?:      uint
	}
}

// What the stateless blueprint conjoins: the Deployment submenu plus the
// blueprint's default. Field-level `*` only (L3) — a whole-struct marked
// disjunct is forbidden. OQ1: whether first-party blueprints keep this
// default once D5 lands, or go silent and delegate to the transformer.
#StatelessUpdateStrategyNarrowing: {
	type: ("RollingUpdate" | "Recreate") & (*"RollingUpdate" | string)
	rollingUpdate?: {
		maxUnavailable?: uint | string
		maxSurge?:       uint | string
		// no partition — Deployment has none (catalog_opm issue 40 tracks
		// the exhaustive per-kind audit).
	}
}

// Narrowing to a single legal value needs no default at all — the field is
// concrete by narrowing alone (Deployment/STS/DS pods accept only Always).
#StatelessRestartPolicyNarrowing: "Always"

/////////////////////////////////////////////////////////////////
// D1/D4 — the precedence chain as a checkable statement. The kernel
// finalize step (D4) is Go behavior, not schema; what CUE can state is
// the contract each layer's contribution satisfies.
/////////////////////////////////////////////////////////////////

#LayerRule: {
	id:          =~"^L[1-9][0-9]*$"
	layer:       "primitive" | "blueprint" | "module-config" | "module-components" | "kernel" | "transformer"
	rule:        string
	enforcement: "catalog-publish-gate" | "module-vet-gate" | "kernel-behavior" | "review"
}

// The six rules of core SPEC.md §6, as data for CLI gates to cite.
// OQ2: L4's gate mechanics need a feasibility spike.
#LayerContract: [...#LayerRule] & [
	{id: "L1", layer: "primitive", rule: "spec schemas publish bounds; never mark a default", enforcement: "catalog-publish-gate"},
	{id: "L2", layer: "blueprint", rule: "narrowing is subtractive; every admitted value is admitted by the primitive", enforcement: "catalog-publish-gate"},
	{id: "L3", layer: "blueprint", rule: "at most one default per field, field-level, never whole-struct", enforcement: "catalog-publish-gate"},
	{id: "L4", layer: "module-config", rule: "authors mark defaults only inside #config; #components carries data and references", enforcement: "module-vet-gate"},
	{id: "L5", layer: "kernel", rule: "validated #config is finalized to concrete data before composition; the two-default collision is unrepresentable", enforcement: "kernel-behavior"},
	{id: "L6", layer: "transformer", rule: "fallbacks are keyed on field absence; transformers never unify values into component spec", enforcement: "review"},
]
