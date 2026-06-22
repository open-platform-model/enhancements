// Target schema for enhancement 0005 — Kubernetes-Native Refocus.
//
// Sketch of the new shapes this enhancement introduces. These are the
// catalog-/tooling-level constructs; nothing here changes opmodel.dev/core@v0
// (see D3). Fields still under debate carry an OQ# marker pointing at the
// matching Open Question in ../03-decisions.md. Tighten as decisions land.
package schema

// ----------------------------------------------------------------------------
// Generation manifest — declarative input to the generator. Makes the catalog
// source a reproducible generation artifact rather than hand-written CUE.
// Home/language of the generator itself is OQ2.
// ----------------------------------------------------------------------------

#GenerationManifest: {
	// One k8s minor's OpenAPI, or a CRD bundle. Exactly one input kind.
	source: #OpenAPISource | #CRDSource

	// Strict (closed types) feeds catalog_opm construction; open (`...` leaves)
	// feeds catalog_kubernetes pass-through. The generator may emit both. OQ1.
	projection: "strict" | "open" | "both"

	// Targeted Kubernetes minor, e.g. "1.33". Drives catalog SemVer alignment. OQ3.
	kubernetesMinor?: =~"^[0-9]+\\.[0-9]+$"
}

#OpenAPISource: {
	kind: "openapi"
	// Endpoint or vendored path to the cluster's aggregated OpenAPI v3.
	ref!: string
}

#CRDSource: {
	kind: "crd"
	// One or more CRD documents (openAPIV3Schema is read per version).
	refs!: [...string]
}

// ----------------------------------------------------------------------------
// Lifecycle metadata — stamped onto every generated resource's metadata so the
// library/operator reconcile loop can act without re-deriving from the GVK.
// ----------------------------------------------------------------------------

#LifecycleMetadata: {
	// From discovery: cluster-scoped kinds get no namespace injection.
	scope: "Namespaced" | "Cluster"

	// Apply-order phase; generalizes library/pkg/resourceorder into per-kind
	// data. Lower applies first.
	applyPhase: int & >=0

	// Readiness is curated per kind (not in the OpenAPI), with a generic
	// fallback. Curated source + ownership is OQ4.
	readiness: #ReadinessRule

	// Prune/ownership for resources dropped between releases. K8s-only lets us
	// commit to ownerReferences + server-side apply.
	prune: {
		strategy:        *"ownerReference" | "label"
		serverSideApply: bool | *true
	}
}

#ReadinessRule: {
	// A CUE/CEL-style expression over the live object's status, or the generic
	// Ready-condition fallback. Exact expression language is OQ4.
	expr:     string | *"status.conditions[?type=='Ready'].status == 'True'"
	fallback: bool | *true
}

// ----------------------------------------------------------------------------
// Trapdoor convention — how a catalog_opm abstraction exposes the full strict
// type for author overrides. Defaults from sugar; overrides win. Mechanism
// (defaulted projection vs explicit overrides field) is OQ5.
// ----------------------------------------------------------------------------

#Trapdoor: {
	// The strict generated type for the resource this abstraction produces.
	// `_` here stands in for the imported strict GVK type at use sites.
	overrides?: {...}
}
