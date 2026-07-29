// Target schema for enhancement 0014 — Export a Deployed Instance as GitOps
// Manifests.
//
// This file is the canonical home for the shapes the enhancement introduces.
// It is CUE rather than markdown so reviewers can check it with
// `cue vet ./...` from this directory, and so the design's structural claims
// (which fields may be completed, which documents make up an export, what a
// successful adoption means) are values rather than prose.
//
// Unresolved surfaces carry `// OQN:` markers pointing at the corresponding
// Open Question in ../03-decisions.md.
package schema

// ---------------------------------------------------------------------------
// Request
// ---------------------------------------------------------------------------

// #ExportRequest is one invocation of `opm instance export`. Exactly two
// shapes exist: one named instance, or every exportable instance in a scope.
// There is no third mode that takes a local file — the live CR is the sole
// input (D4).
#ExportRequest: #ExportOne | #ExportAll

#ExportOne: {
	mode:      "one"
	name:      string & !=""
	namespace: string & !=""
	outDir:    string | *"./gitops"

	// force bypasses the verification-digest comparison only, exactly as it
	// does for handoff. It does not relax provenance or resolvability (D2).
	force: bool | *false
}

#ExportAll: {
	mode: "all"

	// An empty namespace means every namespace the caller can list.
	namespace: string | *""
	outDir:    string | *"./gitops"
	force:     bool | *false
}

// ---------------------------------------------------------------------------
// Gate chain
// ---------------------------------------------------------------------------

#GateClass: "cluster" | "existence" | "provenance" | "resolvability" | "verification"

// #Gate is one precondition. The chain is ordered cheapest-first: a metadata
// read never runs after a registry render.
#Gate: {
	id:    string & !=""
	order: int & >0
	class: #GateClass

	// Whether --force bypasses this gate. Only the verification digest is
	// forceable (D2).
	forceable: bool | *false

	// Whether handoff runs the same gate. Everything except the ownership
	// gate is shared; export has no ownership gate of its own until OQ3
	// resolves.
	sharedWithHandoff: bool | *true

	// The refusal this gate produces, in the user's terms.
	refusal: string & !=""
}

#GateChain: [...#Gate]

// The concrete chain. Mirrors cli/internal/workflow/handoff/handoff.go's
// runPreconditions, minus gate 2's ownership arm (OQ3).
gateChain: #GateChain & [
	{
		id: "cluster", order: 1, class: "cluster"
		refusal: "the ModuleInstance CRD is absent or the cluster is outside the supported version skew"
	},
	{
		id: "exists", order: 2, class: "existence"
		refusal: "no ModuleInstance of that name in that namespace"
	},
	{
		id: "provenance", order: 3, class: "provenance"
		refusal: "the instance was last applied from local module bytes; the operator resolves modules from the registry only, so this instance has no GitOps form"
	},
	{
		id: "resolvable", order: 4, class: "resolvability"
		refusal: "spec.module carries no complete path and version"
	},
	{
		id: "hasDigest", order: 5, class: "verification"
		refusal: "the instance records no status.lastAppliedRenderDigest to verify against"
	},
	{
		id: "reproduces", order: 6, class: "verification", forceable: true
		refusal: "the published module does not reproduce the deployed state; the cluster is running something the registry no longer describes"
	},
]

// ---------------------------------------------------------------------------
// Field classification
// ---------------------------------------------------------------------------

// #FieldClass is the partition that makes completion safe.
//
//   render-bearing — decides what the operator produces. Verified by the
//                    digest gate; the export copies it and must never alter it.
//   apply-bearing  — decides who applies the instance and what happens on
//                    delete. Absent from a CLI-written CR, absent from the
//                    render digest, therefore completable without weakening
//                    D2's guarantee — but every completion is reported.
//   cluster-side   — assigned by the API server or written by a controller.
//                    Never committed.
#FieldClass: "render-bearing" | "apply-bearing" | "cluster-side"

#FieldAction: "copy" | "complete" | "set" | "drop"

// The structural claim, enforced rather than asserted: a render-bearing field
// is only ever copied, and a cluster-side field is only ever dropped. A policy
// entry that broke the partition would fail `cue vet` on the list below.
#FieldPolicy: {
	field:  string & !=""
	class:  #FieldClass
	action: #FieldAction
	if class == "render-bearing" {
		action: "copy"
	}
	if class == "cluster-side" {
		action: "drop"
	}
	reported: bool | *false
	note?:    string
}

#Policies: [...#FieldPolicy]

fieldPolicies: #Policies & [
	{field: "spec.module.path", class:    "render-bearing", action: "copy"},
	{field: "spec.module.version", class: "render-bearing", action: "copy"},
	{field: "spec.values", class:         "render-bearing", action: "copy", reported: true, note: "written verbatim; the report warns that OPM cannot yet identify secret values (D3)"},

	// OQ3: whether a CLI-owned instance may be exported at all decides
	// whether this is a `set` or a refusal.
	{field: "spec.owner", class: "apply-bearing", action: "set", reported: true, note: "OQ3"},

	// OQ1: `complete` is the design's current assumption, not a decision.
	{field: "spec.serviceAccountName", class: "apply-bearing", action: "complete", reported: true, note: "OQ1 — absent on every CLI-written CR"},
	{field: "spec.prune", class:              "apply-bearing", action: "complete", reported: true, note: "OQ1 — absent on every CLI-written CR; completing it changes deletion from orphan to prune"},

	// OQ5: keeping the CLI's own CR labels hands their ownership to Flux;
	// dropping them mutates a live object during a nominal no-op adoption.
	{field: "metadata.labels", class: "apply-bearing", action: "copy", reported: true, note: "OQ5"},

	{field: "status", class:                     "cluster-side", action: "drop"},
	{field: "metadata.managedFields", class:     "cluster-side", action: "drop"},
	{field: "metadata.uid", class:               "cluster-side", action: "drop"},
	{field: "metadata.resourceVersion", class:   "cluster-side", action: "drop"},
	{field: "metadata.generation", class:        "cluster-side", action: "drop"},
	{field: "metadata.creationTimestamp", class: "cluster-side", action: "drop"},
]

// ---------------------------------------------------------------------------
// Exported document set
// ---------------------------------------------------------------------------

#DocumentName: "namespace.yaml" | "serviceaccount.yaml" | "rbac.yaml" |
	"moduleinstance.yaml" | "kustomization.yaml"

// The emitted ModuleInstance. `version` carries its `v` prefix: 0006's live
// verification found that a bare version made a CLI-written CR unresolvable
// by the operator, and an exported document has no second actor to catch it.
#ExportedModuleInstance: {
	apiVersion: "opmodel.dev/v1alpha1"
	kind:       "ModuleInstance"
	metadata: {
		name:      string & !=""
		namespace: string & !=""
		labels?: [string]: string // OQ5
	}
	spec: {
		owner: "operator" // OQ3
		module: {
			path:    string & !=""
			version: string & =~"^v"
		}
		serviceAccountName: string & !="" // OQ1
		prune:              bool          // OQ1
		values?: {...}
	}
}

// The applier identity the CR references, plus its authorization. OQ2 owns
// what `rbac.yaml` actually grants; the shape below is the invariant that
// holds whichever way it resolves.
#ExportedEnvelope: {
	namespace: {
		apiVersion: "v1"
		kind:       "Namespace"
		metadata: name: string & !=""
	}
	serviceAccount: {
		apiVersion: "v1"
		kind:       "ServiceAccount"
		metadata: {
			name:      string & !=""
			namespace: string & !=""
		}
	}
	// OQ2: cluster-admin binding (the demo's shape), an unfilled skeleton, or
	// a least-privilege Role derived from status.inventory's GVK list.
	rbac: {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRoleBinding" | "RoleBinding"
		metadata: name: string & !=""
	}
}

#ExportedKustomization: {
	apiVersion: "kustomize.config.k8s.io/v1beta1"
	kind:       "Kustomization"
	// Lists exactly the other four documents, in apply-safe order.
	resources: [
		"namespace.yaml",
		"serviceaccount.yaml",
		"rbac.yaml",
		"moduleinstance.yaml",
	]
}

// One directory per instance. Nothing is shared or merged between the
// directories a single `--all` invocation writes.
#ExportedSet: {
	dir:            string & !=""
	moduleInstance: #ExportedModuleInstance
	envelope:       #ExportedEnvelope
	kustomization:  #ExportedKustomization

	files: [...#DocumentName] & [
		"namespace.yaml",
		"serviceaccount.yaml",
		"rbac.yaml",
		"moduleinstance.yaml",
		"kustomization.yaml",
	]

	// Byte-stability: the set is a pure function of the record, so nothing
	// derived from wall-clock time or map iteration order may appear in it.
	containsNonDeterministicContent: false
}

// ---------------------------------------------------------------------------
// Report
// ---------------------------------------------------------------------------

#Completion: {
	field: string & !=""
	// What the live CR held (absent, in every case the CLI wrote).
	was: string | *"absent"
	// What the export wrote.
	now: string & !=""
	// The behavioural consequence, in the user's terms — not the field name
	// restated. `spec.prune` reports orphan-versus-delete.
	consequence?: string
}

#ExportReport: {
	instance: {
		name:      string & !=""
		namespace: string & !=""
	}
	module: {
		path:    string & !=""
		version: string & =~"^v"
	}
	verification: {
		deployedDigest: string & !=""
		renderedDigest: string & !=""
		matched:        bool
		forced:         bool | *false
	}
	completions: [...#Completion]
	warnings: [...string]
	written: {
		dir:   string & !=""
		files: [...#DocumentName]
	}
}

// ---------------------------------------------------------------------------
// Conformance
// ---------------------------------------------------------------------------

// #AdoptionProperty is the claim the e2e case in 04-graduation.md asserts.
// It restates 0006 D40's inventory-stable criterion for a GitOps applier
// rather than for the operator's first post-handoff reconcile.
//
// OQ4 is exactly the question of whether `then` holds under a real Flux
// apply, given that the exported CR's fields are owned by other field
// managers. Until the experiment runs, this is the design's claim, not a
// result.
#AdoptionProperty: {
	given: {
		gatesPassed:      true
		operatorManaged:  true
		sameNameAndSpace: true
	}
	then: {
		// The instance's resource set is unchanged as a set.
		entrySetDrift: ""
		// The operator records a new inventory revision.
		revisionIncremented: true
		// No workload is replaced, recreated, or deleted.
		workloadsUntouched: true
	}
}
