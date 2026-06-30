// Target schema for enhancement 0009 — Operational Primitives.
//
// Sketch of the four operational constructs the enhancement introduces into
// the core schema (opmodel.dev/core@v1): #Op, #Action, #Lifecycle, #Workflow,
// plus the @op(...) dispatch-attribute convention the library planner reads.
//
// This file is intentionally self-contained — it does NOT import
// opmodel.dev/core so it vets offline. In core, the placeholder types below
// (#Name, #FQN, #Phase keys) reuse the existing #NameType / #FQNType /
// #ModulePathType / #VersionType machinery. Field shapes marked `// OQn`
// track an Open Question in ../03-decisions.md and are deliberately loose
// until that question resolves.
package schema

// ---------------------------------------------------------------------------
// Placeholder primitives (reuse core's real types when this lands in core/).
// ---------------------------------------------------------------------------

#Name: =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"
#FQN:  string

// Op kinds may be dotted-namespaced (e.g. "http", "cue.eval").
#OpKind: =~"^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$"

// ---------------------------------------------------------------------------
// #Op — the controlled primitive (smallest common denominator).
//
// OPM owns the set of Op *kinds*; authors compose Ops, they do not invent new
// kinds. An Op is a slim schema base, not a full primitive: no FQN, no
// metadata — it is the inline, dispatchable leaf of a flow.
//
// Dispatch is carried by a CUE attribute, hof.io-style. The @op(...) attribute
// is invisible to CUE evaluation but readable by the Go SDK
// (cue.Value.Attribute). It tells the library planner/orchestrator which
// executor *backend* runs the step (`protocol`) and where the pluggable
// executable artifact lives (`ref`). The artifact itself is catalog-sourced —
// never hardcoded in the library. (D5, D6.)
//
// Attribute grammar (illustrative):
//   @op(protocol="wasm", ref="opmodel.dev/catalogs/opm/ops/http@v1")
//   @op(protocol="oci",  ref="ghcr.io/open-platform-model/ops/exec:v1")
//
// `protocol`  — selects a library executor backend (wasm | oci | http | cue …).
//               The backend set is itself a registry; frontends add/override.
// `ref`       — locator for the pluggable artifact (OQ1 decides its form).
// ---------------------------------------------------------------------------

#Op: {
	// Visible discriminator the runtime dispatches on. Each concrete Op sets
	// this; the companion @op(...) attribute carries backend + locator.
	opKind!: #OpKind

	// Runtime-produced outputs. Hidden so they don't appear in `cue export`
	// of the declaration; the backend populates the shape after execution.
	// OQ2: whether one step's #out can be referenced as another step's input
	// (typed data DAG) or whether ordering is the only inter-step relation.
	#out?: {...}
	...
}

// ---------------------------------------------------------------------------
// Well-known Ops (the initial vocabulary — D2 scope, OQ1 picks artifact form).
// Definitions illustrate the @op(...) placement on the discriminator field.
// ---------------------------------------------------------------------------

// Run a command in a container image. Side-effecting → oci backend.
#ExecOp: #Op & {
	opKind: "exec" @op(protocol="oci", ref="ghcr.io/open-platform-model/ops/exec:v1")
	image!:    string
	command!:  [...string]
	env?: [string]: string
	workdir?:  string
	#out: {exitCode: int, stdout: bytes, stderr: bytes}
}

// HTTP request — full CRUD. Returns the RAW response; parsing is done in CUE,
// not in the executor (D8). Pure-logic → wasm backend.
#HttpOp: #Op & {
	opKind: "http" @op(protocol="wasm", ref="opmodel.dev/catalogs/opm/ops/http@v1")
	method!: "GET" | "POST" | "PUT" | "PATCH" | "DELETE"
	url!:    string
	headers?: [string]: string
	body?:   bytes
	#out: {status: int, headers: [string]: string, body: bytes}
}

// Poll until a condition holds. Pure-logic evaluation → wasm backend; the
// thing being polled is supplied by the frontend's environment.
#WaitOp: #Op & {
	opKind: "wait" @op(protocol="wasm", ref="opmodel.dev/catalogs/opm/ops/wait@v1")
	condition!: string
	timeout!:   string
	interval:   *"5s" | string
	#out: {satisfied: bool, elapsed: string}
}

// Evaluate a CUE expression. Pure and deterministic → cue backend.
#CueOp: #Op & {
	opKind: "cue.eval" @op(protocol="cue", ref="builtin")
	expression!: string
	scope?: {...}
	#out: {value: _}
}

// ---------------------------------------------------------------------------
// #Action — composition over Ops (and nested Actions). A full unit with
// identity (FQN) so it can be published in catalogs and referenced by name.
// OPM ships ready-made Actions (e.g. a DB migration); authors write their own.
// ---------------------------------------------------------------------------

// A step is an Op or a nested Action, plus its ordering edges.
// OQ2: `dependsOn` is explicit ordering only for now; typed data-flow edges
// (step.out → step.in) are an open question.
#Step: (#Op | #Action) & {
	dependsOn?: [...#Name]
}

#StepMap: [#Name]: #Step

#Action: {
	kind: "Action"
	metadata: {
		modulePath!: string
		version!:    string
		name!:       #Name
		fqn:         #FQN & "\(modulePath)/\(name)@\(version)"
		description?: string
	}
	steps: #StepMap
}

#ActionMap: [#FQN]: #Action

// ---------------------------------------------------------------------------
// #Lifecycle — binds Actions/Ops to fixed state-transition phases (D7).
// State-transition-triggered; tractable inside the operator reconcile loop.
// ---------------------------------------------------------------------------

#Phase: "pre-install" | "install" | "post-install" |
	"pre-upgrade" | "upgrade" | "post-upgrade" |
	"pre-uninstall" | "uninstall" | "post-uninstall"

#Lifecycle: {
	kind: "Lifecycle"
	// Each phase is an ordered list of steps; empty/absent phases are no-ops.
	phases: [P=#Phase]: [...#Step]
}

// ---------------------------------------------------------------------------
// #Workflow — on-demand, explicitly invoked flows (e.g. a container build).
// More open-ended than Lifecycle. OQ3: run-state / idempotency model for
// on-demand invocation (history, re-entrancy) needs further design.
// ---------------------------------------------------------------------------

#Workflow: {
	kind: "Workflow"
	metadata: {
		name!:        #Name
		description?: string
	}
	steps: #StepMap
}

#WorkflowMap: [#Name]: #Workflow

// ---------------------------------------------------------------------------
// Attachment on #Module (OQ4 — exact shape/field names not yet decided).
// The execution half of the kernel reads these off the SAME #Module the
// render half consumes. Sketch only:
// ---------------------------------------------------------------------------

#ModuleOperationalSketch: {
	// OQ4: do lifecycle/workflows live at module root, per-component, or both?
	lifecycle?: #Lifecycle
	workflows?: #WorkflowMap
}

// ---------------------------------------------------------------------------
// Catalog distribution (rides the existing #Catalog rails — D6).
// Additive sibling maps on core's #Catalog, alongside #transformers:
//   #ops:     [#FQN]: #Op-definition provenance
//   #actions: [#FQN]: #Action
// Sketched here as plain maps; the real constraint mirrors #transformers'
// modulePath/version stamping in core/src/catalog.cue.
// ---------------------------------------------------------------------------

#CatalogOperationalSketch: {
	#ops:     [#FQN]: #Op
	#actions: #ActionMap
}
