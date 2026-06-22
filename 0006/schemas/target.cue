// Target shapes for enhancement 0006.
//
// These mirror the Go types in opm-operator/api/v1alpha1 (the source of truth,
// Kubebuilder-generated). They are expressed here as compilable CUE so the
// new/changed surface — spec.owner (D3) and the CLI-written status subset (D2)
// — can be reviewed and vetted (`cue vet ./...` from this directory) without a
// Go toolchain. This enhancement adds NO core schema; it only adds a field to
// the operator CRD and constrains which status fields the CLI writes.
package schema

// Ownership marker added to ModuleRelease.spec (D3). Default "operator" keeps
// existing CRs reconciled by the controller; "cli" makes the operator skip.
#Owner: "cli" | "operator"

#ModuleReference: {
	path!:    string
	version?: string // best-effort when applying from a local path (D6)
}

// ModuleRelease.spec — only the fields 0006 reads or adds are modelled here.
#ModuleReleaseSpec: {
	owner:  #Owner | *"operator" // NEW (D3); the CLI may edit spec when owner=="operator" but defers execution to the operator (D18)
	module: #ModuleReference
	values?: {...} // sole authoritative render input — the CLI unifies ALL value inputs into this blob and renders its own apply from it (D19, resolves OQ10)
	suspend?:      bool // unchanged; orthogonal to owner (D3 rejected suspend-as-marker)
	prune?:        bool
	...
}

#InventoryEntry: {
	group?:     string
	kind!:      string
	namespace?: string
	name!:      string
	version?:   string // informative; excluded from identity equality
	component?: string
}

#Inventory: {
	revision: int & >=0
	digest:   string
	count:    int & >=0
	entries: [...#InventoryEntry]
}

#Condition: {
	type!:    string
	status!:  "True" | "False" | "Unknown"
	reason!:  string
	message?: string
}

// Full ModuleReleaseStatus is operator-owned. The CLI writes only the subset
// below (D2, amended by D25); every other field stays unset by the CLI and
// owned by the controller's reconcile loop. Notably the CLI writes NO
// status.conditions — conditions are operator-exclusive (D25), so this subset
// carries no Ready entry; in a solo cluster status.conditions is simply absent.
#CLIStatusSubset: {
	inventory:               #Inventory
	releaseUUID:             string
	lastAppliedRenderDigest: string
	lastAppliedSourceDigest: string
	lastAppliedConfigDigest: string
	lastAppliedAt:           string // RFC3339
}

// status.conditions is operator-exclusive (D25). The operator's skip-state
// condition for a CLI-owned CR (D3): the operator sets
// Ready=Unknown/ManagedExternally and touches no CLI-written status field.
#OperatorSkipCondition: #Condition & {
	type:   "Ready"
	status: "Unknown"
	reason: "ManagedExternally"
}

// A concrete example CLI-written status, for vet coverage.
_exampleCLIStatus: #CLIStatusSubset & {
	inventory: {
		revision: 1
		digest:   "sha256:deadbeef"
		count:    1
		entries: [{kind: "Deployment", namespace: "media", name: "jellyfin", component: "server"}]
	}
	releaseUUID:             "a3b8f2e1-1234-5678-9abc-def012345678"
	lastAppliedRenderDigest: "sha256:1111"
	lastAppliedSourceDigest: "sha256:2222"
	lastAppliedConfigDigest: "sha256:3333"
	lastAppliedAt:           "2026-06-22T00:00:00Z"
}

// Platform source (D11/D12). The CLI resolves a platform spec by precedence
// (--platform flag > cluster Platform CR > local/embedded default), then calls
// the same kernel path the operator uses (SynthesizePlatform -> Materialize ->
// Compile). This is Go/kernel wiring, not a CRD field, so it has no CUE shape
// here. The one CRD-shaped fact worth recording: unlike ModuleRelease, the
// Platform CR gets NO owner marker — the operator always owns/materializes the
// singleton; the CLI only reads it (and writes it write-if-absent in solo
// clusters). The sketch below is the Platform spec the CLI reads/writes; note
// the deliberate ABSENCE of an `owner` field (contrast #ModuleReleaseSpec).
#Subscription: {
	enable?: bool
	filter?: {
		range?: string
		allow?: [...string]
		deny?: [...string]
	}
}

#PlatformSpec: {
	type!: string
	registry?: [string]: #Subscription
	// no `owner` field, by design (D12)
}
