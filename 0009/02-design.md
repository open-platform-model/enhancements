# Design: Operational Primitives: Op, Action, Lifecycle, Workflow

The kernel grows a second half, a pure planner over four new primitives, layered on the same `#Module` the render half already reads. Trade-off reasoning lives in `03-decisions.md`.

## Design Goals

- A `#Module` can describe operational intent (ordered flows of typed steps) in addition to the resources it renders to, read from the **same** `#Module` the render half consumes.
- OPM owns a small, closed set of operational **primitives** (`#Op` kinds). Authors compose them freely but cannot invent new kinds: composition is open, the vocabulary is closed. This is the structural defence against the Helm "arbitrary script as a hook" failure mode.
- OPM and third parties can publish reusable **compositions** (`#Action`s such as a DB migration) that authors fill in and import.
- Two consumers of those compositions: **`#Lifecycle`** (steps bound to fixed state-transition phases) and **`#Workflow`** (on-demand, explicitly invoked flows).
- The library is a **pure planner**: it resolves flows into an ordered plan and decides what comes next, one step per call, but runs no loop and performs no side effects (Principle I, kernel neutrality). The caller drives the loop; all side effects live behind injected executor backends.
- The **executable code is not hardcoded in the library**. It is pluggable and catalog-sourced, located by metadata embedded in the CUE definitions, distributed over the same `#Catalog` and `#Platform.#registry` rails the render half already uses.
- Each frontend (CLI, operator) composes the executor backends it wants; an unsupported operation is rejected cleanly *before* anything runs.

## Non-Goals

- Replacing the render half. The execution half is additive; rendering is unchanged.
- A general-purpose programming language for operations. Composition of a closed primitive set is deliberately less expressive than arbitrary scripting: that is the point.
- Shipping a meta-controller toolkit in this enhancement (see Open Questions: it is an explicit north-star the architecture should *allow*, not a v1 deliverable).
- Defining the full production executor implementations for every backend; v1 defines the contract and a reference set, with artifact form still under decision (OQ1).

## High-Level Approach

The kernel grows a **second half**. Today the render half turns a `#Module` into rendered objects and stops. This enhancement adds a parallel execution half that consumes the **same `#Module`** and produces an ordered plan instead of resources. One input, two interpreters.

Four new constructs land in `core` (`opmodel.dev/core@v1`), layered:

- **`#Op`**: the controlled primitive. A slim, inline, dispatchable leaf (no FQN). OPM owns the set of kinds: `exec`, `http` (full CRUD), `wait`, `cue.eval`, k8s get/apply, … Each concrete Op carries a CUE **`@op(...)` attribute** that is invisible to CUE evaluation but readable by the Go SDK.
- **`#Action`**: a composition over Ops and nested Actions, with identity (FQN) so it can be published in a catalog and referenced by name. Steps carry ordering edges.
- **`#Lifecycle`**: binds steps to a fixed nine-phase vocabulary: `pre-install / install / post-install`, `pre-upgrade / upgrade / post-upgrade`, `pre-uninstall / uninstall / post-uninstall`.
- **`#Workflow`**: on-demand flows invoked explicitly (e.g. a container build), more open-ended than `#Lifecycle`.

The library splits along the neutrality boundary in three parts, and the split is what D3 fixes rather than any particular layout:

- **Plan types and the planner**, in the kernel tier. A phase of a `#Lifecycle` or a named `#Workflow` becomes an ordered graph of steps, as pure data.
- **The advance function**, in the kernel tier. Given a plan and a state value it returns the next state and the one action the caller is to perform. It decides eligibility, order, satisfaction, failure handling and completion; it runs nothing and keeps nothing.
- **Executor backend hosts**, in the opt-in tier where the I/O lives. A wasm host, a container host (whose operator variant renders a Job rather than running locally), a thin HTTP host, and a pure `cue.eval` host.

The caller supplies the loop. A one-shot CLI invocation calls advance until the plan reports completion; a controller calls it once per reconcile and carries the state in the instance it owns.

**Dispatch is attribute-driven.** The planner reads each step's `@op(protocol=…, ref=…)` attribute. `protocol` selects an executor **backend** from a registry; `ref` is a locator for the pluggable executable artifact. The library ships the generic backend *hosts* (a wasm runtime, an OCI runner, …): these are runtimes, not operation logic, so neutrality holds and nothing op-specific is compiled in. The actual operation behavior is a catalog-sourced artifact the backend loads at runtime.

**Opt-in by registry.** A frontend builds a `Registry` from only the backends it wants, then drives the plan. The whole plan is checked against that registry before the first action: a step whose `protocol` has no registered backend fails fast with a clear error *before* execution begins. This is how the operator cleanly declines, say, ad-hoc container builds: it simply never registers that backend. The same `#Op` and the same plan run differently per frontend: `exec` runs a local container on the CLI and renders-a-Job-and-watches on the operator, just by swapping the backend.

**Catalog-sourced, over existing rails.** Op definitions and their artifacts are distributed through the `#Catalog` manifest the render half already uses. `core`'s `#Catalog` gains additive sibling maps (`#ops`, `#actions`) alongside `#transformers`; the comment in `core/src/catalog.cue` already anticipates exactly this extension. A platform's `#registry` resolves them the way it already resolves transformers: no parallel distribution pipeline.

## Schema / API Surface

Headline shapes only; the full surface is in [`schemas/target.cue`](schemas/target.cue).

- `#Op`: `opKind` discriminator + hidden `#out` + the `@op(protocol=…, ref=…)` attribute.
- `#Action`: `metadata{modulePath, version, name, fqn}` + a `steps` map; each step is `(#Op | #Action) & {dependsOn?: […]}`.
- `#Lifecycle`: `phases: [#Phase]: [...#Step]` over the fixed nine-phase enum.
- `#Workflow`: `metadata{name}` + a `steps` map.
- Library: a plan verb per trigger (a `#Lifecycle` phase, a named `#Workflow`), both pure; and one advance verb taking a plan, a state value and the previous action's result, returning the next state plus the action to perform. The caller loops over advance; the library ships no loop (D3).

The `@op(...)` attribute is the load-bearing new convention. It is hof.io-inspired (their `@task(os.Exec)` names a registered implementation); here the attribute instead carries a *protocol + locator* so the implementation is pluggable and catalog-sourced rather than compiled in.

## Integration Points

**`core/` (`opmodel.dev/core@v1`)**: new `src/op.cue`, `src/action.cue`, `src/lifecycle.cue`, `src/workflow.cue` defining the four constructs; additive `#ops` / `#actions` maps on `#Catalog` in `src/catalog.cue`; attachment of `#Lifecycle` / `#Workflow` onto `#Module` (OQ4). SPEC.md co-update required (`core-schema-edit` skill).

**`library/`**: the plan types, the planner, the advance verb, the executor port and its registry in the kernel tier; the backend hosts in the opt-in tier; attribute reading in the planner via `cue.Value.Attribute`. The shape is fixed by D3 and by library ADR-008: the library decides and never acts, and the caller owns the loop and the run state. This half also owns what is left of the kernel's cancellation path (D9). The kernel's former logger, tracer and clock slots were removed as write-only surface (revised D9); this half introduces the injection surface the planner needs together with its first reader.

**`catalog_opm/`**: publish the initial Op definitions and their artifacts; register them in the catalog manifest's new `#ops` / `#actions` maps. (No `#Area` token exists for `catalog_opm`; tracked in prose.)

**`cli/`**: register the backend set (incl. workflow execution); surface `opm workflow run <name>` and lifecycle invocation.

**`opm-operator/`**: register the operator's backend set (k8s-flavored `exec` → Job; likely no ad-hoc workflow backend); drive `#Lifecycle` phases from the reconcile loop.

## Before / After

**Before**: the migration scenario from `01-problem.md` lives outside OPM: a hand-written `migrate-job.yaml` pinned to one cluster, a `kubectl exec` seed step documented in prose, ordering left to the operator.

**After**: it is typed and composed from controlled primitives, carried on the same `#Module` that renders the app:

```cue
lifecycle: phases: "pre-upgrade": [
    ops.#WaitOp & {condition: "db.ready", timeout: "120s"},
    actions.#DBMigration & {steps: migrate: {image: "flyway/flyway:10", command: ["flyway", "migrate"]}},
]
workflows: "seed-demo": steps: run: ops.#ExecOp & {image: "myorg/seeder:1", command: ["seed"]}
```

The kernel plans the `pre-upgrade` phase into an ordered DAG and the operator orchestrates it through its registered backends; `seed-demo` runs only when an operator invokes it. Nothing is pinned to a cluster shape, and the platform team controls which Op kinds and backends exist.
