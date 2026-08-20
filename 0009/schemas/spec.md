# Specification changes: Operational Primitives: Op, Action, Lifecycle, Workflow

<!--
Pre-draft of the core/SPEC.md co-update the core slice will need (core-schema-edit skill). Derived from 01-problem.md, 02-design.md, 03-decisions.md, and schemas/target.cue only. Aspects still gated by an Open Question are flagged with the OQ number; nothing here resolves an open OQ.
-->

## `#Op` (NEW)

### Definition

`#Op` is the controlled operational primitive: the smallest, inline, dispatchable leaf of a flow. Where `#Resource` states "what must exist", an Op is the unit of "what must happen". It is a slim schema base rather than a full primitive — it carries no FQN and no metadata block — and OPM owns the closed set of Op *kinds*: authors compose Ops but cannot invent new kinds. Each concrete Op kind (the initial vocabulary: `exec`, `http`, `wait`, `cue.eval`) pairs the visible `opKind` discriminator with a CUE `@op(...)` field attribute that is invisible to CUE evaluation and read by the Go SDK to dispatch the step to an executor backend. The concrete Op definitions themselves are catalog-sourced, not compiled into the library (D6); `target.cue` restates them only to illustrate the attribute placement.

### Shape

From `target.cue` (supporting type `#OpKind` included):

```cue
#OpKind: =~"^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$"

#Op: {
	opKind!: #OpKind         // visible discriminator the runtime dispatches on
	#out?: {...}             // runtime-produced outputs, hidden from export (OQ2)
	...
}

// Illustrative concrete kind, showing the on-field @op(...) placement:
#ExecOp: #Op & {
	opKind: "exec" @op(protocol="oci", ref="ghcr.io/open-platform-model/ops/exec:v1")
	image!:   string
	command!: [...string]
	...
}
```

### Constraints

- Every concrete Op MUST set `opKind`, and the value MUST satisfy the `#OpKind` grammar (lowercase alphanumeric with interior dots and hyphens, e.g. `http`, `cue.eval`).
- The set of Op kinds is closed and OPM-owned: authors MUST NOT introduce new kinds; they compose existing ones (D2).
- Each concrete Op kind MUST carry an `@op(...)` attribute naming a `protocol` (which executor backend runs the step) and a `ref` (locator for the pluggable executable artifact). The attribute MUST be placed as a field attribute after the field value — CUE does not support attributes placed before a field (D5).
- The `@op(...)` attribute MUST NOT affect CUE evaluation; it is readable only through the SDK (`cue.Value.Attribute`) (D5).
- The executable artifact an Op dispatches to MUST be catalog-sourced, never hardcoded in the library (D6). The concrete form of `ref` (WASM, OCI image, or both) is OQ1-gated and not fixed by this specification.
- Runtime outputs MUST live under the hidden `#out` field so they do not appear in `cue export` of the declaration. Whether one step's `#out` may be referenced as another step's input is OQ2-gated.
- The `http` Op MUST expose the full verb set (GET/POST/PUT/PATCH/DELETE) and MUST return the raw status, headers, and body; executors MUST NOT parse or shape the response — that is done downstream in CUE (D8).

### Rationale

- Why a closed kind set. The Helm failure mode is an arbitrary template running an arbitrary script — maximally flexible and unmaintainable at scale. A closed, OPM-owned vocabulary is the structural defence: composition is open, the vocabulary is not (D2, 01-problem.md).
- Why attribute dispatch instead of a regular field. Dispatch metadata is runtime concern, not user configuration; an attribute keeps the evaluated value clean and crosses the hermetic boundary only when the SDK chooses to read it (D5).
- Why catalog-sourced artifacts. Compiling op implementations into the library (the hof.io model) would require a library release for every new op; riding the existing `#Catalog` rails makes operations as pluggable as transformers already are (D6).
- Why a raw HTTP response. Keeping the executor a thin transport pushes data shaping into CUE, where OPM already does data work; a typed op can layer on later as a composition (D8).

## `#Action` (NEW)

### Definition

`#Action` is a composition over Ops and nested Actions, with FQN identity so it can be published in a catalog and referenced by name. It is the reuse unit of the operational side: OPM and third parties ship ready-made Actions (e.g. a DB migration) that authors fill in and import. Steps live in a name-keyed map and carry explicit ordering edges.

### Shape

From `target.cue` (supporting types `#Step`, `#StepMap`, `#ActionMap` included):

```cue
#Step: (#Op | #Action) & {
	dependsOn?: [...#Name]   // explicit ordering edges only (OQ2)
}

#StepMap: [#Name]: #Step

#Action: {
	kind: "Action"
	metadata: {
		modulePath!:  string
		version!:     string
		name!:        #Name
		fqn:          #FQN & "\(modulePath)/\(name)@\(version)"
		description?: string
	}
	steps: #StepMap
}

#ActionMap: [#FQN]: #Action
```

### Constraints

- An Action MUST carry `metadata.modulePath`, `metadata.version`, and `metadata.name`; `metadata.fqn` MUST be the interpolation `"<modulePath>/<name>@<version>"` and MUST NOT be authored independently of those fields.
- Step map keys MUST satisfy the `#Name` grammar (in core: `#NameType`).
- A step MUST be either an Op or a nested Action; `dependsOn` entries MUST name sibling steps in the same map.
- `dependsOn` is the only inter-step relation this specification defines. Typed data-flow edges (one step's `#out` referenced as another step's input) are OQ2-gated and MUST NOT be assumed by consumers.

### Rationale

- Why identity on the composition but not the primitive. Actions are the publishable, importable unit — the catalog needs a stable name to distribute them by — while Ops stay inline leaves; this parallels the declarative side's split between catalog-published members and inline composition (D2, D6).
- Why explicit ordering edges. A pure in-process planner can turn `dependsOn` into an ordered DAG without committing to the heavier data-DAG model before OQ2 resolves (02-design.md, OQ2).
- Why compositions in core rather than only in catalogs. `#Action` is a schema contract every consumer types against, like the other primitives; core is where such contracts live (D2).

## `#Lifecycle` (NEW)

### Definition

`#Lifecycle` binds steps to a fixed vocabulary of state-transition phases. It is the state-transition-triggered consumer of Ops and Actions: the kernel's execution half plans a phase into an ordered DAG, and the frontend (operator reconcile loop, CLI) drives it at the matching transition. Absent phases are no-ops.

### Shape

From `target.cue` (supporting type `#Phase` included):

```cue
#Phase: "pre-install" | "install" | "post-install" |
	"pre-upgrade" | "upgrade" | "post-upgrade" |
	"pre-uninstall" | "uninstall" | "post-uninstall"

#Lifecycle: {
	kind: "Lifecycle"
	phases: [P=#Phase]: [...#Step]
}
```

### Constraints

- Phase keys MUST be drawn from the fixed nine-phase set; authors MUST NOT define arbitrary phase names (D7).
- Each phase's value MUST be a list of `#Step`; list order is the authored order within the phase.
- Absent or empty phases MUST be treated as no-ops (D7).

### Rationale

- Why a fixed vocabulary. A closed, well-known phase set keyed to install/upgrade/uninstall is what lets the operator reason about and drive transitions from its reconcile loop; author-defined phases would re-import Helm's hook sprawl (D7).
- Why a separate construct from `#Workflow`. Phase-triggered and on-demand flows have genuinely different trigger and state semantics; collapsing them into one construct with a mode flag hides that (D2).

## `#Workflow` (NEW)

### Definition

`#Workflow` is an on-demand flow, invoked explicitly by name (e.g. `opm workflow run seed-demo`, a container build) rather than triggered by a state transition. It is more open-ended than `#Lifecycle`: the same step model, but no phase binding.

### Shape

From `target.cue` (supporting type `#WorkflowMap` included):

```cue
#Workflow: {
	kind: "Workflow"
	metadata: {
		name!:        #Name
		description?: string
	}
	steps: #StepMap
}

#WorkflowMap: [#Name]: #Workflow
```

### Constraints

- A Workflow MUST carry `metadata.name` satisfying the `#Name` grammar; `#WorkflowMap` keys MUST satisfy it as well.
- A Workflow MUST run only when explicitly invoked; nothing in the schema triggers it from a state transition.
- The run-state and idempotency model for on-demand invocation (run history, re-entrancy, where invocation state is stored) is OQ3-gated; this specification deliberately models none of it, and consumers MUST NOT assume any particular run-state semantics yet.

### Rationale

- Why name identity but no FQN. A Workflow is addressed within its module by the invoker ("run seed-demo"), not published and imported across modules the way an Action is (02-design.md).
- Why the run-state model is deferred. `#Lifecycle` is tractable inside the operator reconcile loop (re-plan each reconcile, convergent executors); on-demand invocation may be non-idempotent and needs its own design pass before it is specified (OQ3).

## `#Module` (CHANGED vs SPEC.md §3.2)

### Definition

The execution half of the kernel reads operational intent off the same `#Module` the render half consumes — one input, two interpreters (D1). `#Module` therefore gains an attachment for `#Lifecycle` and `#Workflow`. Where exactly they attach — module root, per-component, or both — is OQ4-gated; `target.cue` carries only a module-root sketch (`#ModuleOperationalSketch`).

### Shape

Sketch only (`#ModuleOperationalSketch` in `target.cue`; field names and placement not final, OQ4):

```cue
{
	lifecycle?: #Lifecycle
	workflows?: #WorkflowMap
}
```

### Constraints

- The attachment MUST be additive: rendering behavior of a `#Module` without operational fields MUST be unchanged (02-design.md, Non-Goals).
- Both fields MUST be optional; a module with no operational intent remains valid.
- The exact field placement (module root vs per-component vs both) is OQ4-gated and MUST be resolved before this section can be lifted into core/SPEC.md.

### Rationale

- Why the same `#Module`. Operations ship and version with the app instead of living in side scripts; the kernel grows a second interpreter over the same parsed input rather than a second input format (D1, 01-problem.md).
- Why additive. Replacing or extending the render pipeline is an explicit non-goal; execution is a parallel half, and overloading the render half with sequencing semantics was rejected (D1).

## `#Catalog` (CHANGED vs SPEC.md §3.6)

### Definition

`#Catalog` gains additive sibling maps for operational members, alongside the existing `#transformers`: `#ops` for Op definitions and `#actions` for published Actions. Distribution rides the existing `#Catalog` / `#Platform.#registry` / `materialize` rails — no parallel pipeline (D6). `target.cue` carries this as the `#CatalogOperationalSketch`; the real constraint mirrors `#transformers`' modulePath/version stamping in `core/src/catalog.cue`.

### Shape

Sketch only (`#CatalogOperationalSketch` in `target.cue`):

```cue
{
	#ops:     [#FQN]: #Op
	#actions: #ActionMap
}
```

### Constraints

- The new maps MUST be additive: existing `#Catalog` consumers that ignore them MUST be unaffected.
- `#actions` keys MUST be the contained Action's `metadata.fqn`.
- The maps SHOULD mirror `#transformers`' modulePath/version stamping discipline; the sketch's plain maps are not the final constraint.
- The form of the executable artifact an `#ops` entry locates (WASM, OCI, or both) is OQ1-gated.

### Rationale

- Why extend `#Catalog` instead of a new distribution pipeline. The render half already solved catalog distribution, and the `#Catalog` schema comment anticipates additive sibling maps; reuse beats a parallel mechanism (D6).
- Why the catalog owns the behavior. The library owns the mechanism (planner + generic backend hosts); the catalog owns what an op actually does, so new operations ship without a library release (D6).
