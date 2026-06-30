# Design — Operational Primitives: Op, Action, Lifecycle, Workflow

This document answers: "What is the proposed solution and how does it work?" Trade-off reasoning lives in `03-decisions.md`.

## Design Goals

- A `#Module` can describe operational intent (ordered flows of typed steps) in addition to the resources it renders to, read from the **same** `#Module` the render half consumes.
- OPM owns a small, closed set of operational **primitives** (`#Op` kinds). Authors compose them freely but cannot invent new kinds — composition is open, the vocabulary is closed. This is the structural defence against the Helm "arbitrary script as a hook" failure mode.
- OPM and third parties can publish reusable **compositions** (`#Action`s such as a DB migration) that authors fill in and import.
- Two consumers of those compositions: **`#Lifecycle`** (steps bound to fixed state-transition phases) and **`#Workflow`** (on-demand, explicitly invoked flows).
- The library is a **pure planner + orchestrator**: it resolves flows into an ordered plan and sequences them, but performs no side effects itself (Principle I — kernel neutrality). All side effects live behind injected executor backends.
- The **executable code is not hardcoded in the library**. It is pluggable and catalog-sourced, located by metadata embedded in the CUE definitions, distributed over the same `#Catalog` / `#registry` / `materialize` rails the render half already uses.
- Each frontend (CLI, operator) composes the executor backends it wants; an unsupported operation is rejected cleanly *before* anything runs.

## Non-Goals

- Replacing the render half. The execution half is additive; rendering is unchanged.
- A general-purpose programming language for operations. Composition of a closed primitive set is deliberately less expressive than arbitrary scripting — that is the point.
- Shipping a meta-controller toolkit in this enhancement (see Open Questions — it is an explicit north-star the architecture should *allow*, not a v1 deliverable).
- Defining the full production executor implementations for every backend; v1 defines the contract and a reference set, with artifact form still under decision (OQ1).

## High-Level Approach

The kernel grows a **second half**. Today `opm/compile/` renders `#Module → []*core.Compiled`. This enhancement adds a parallel execution half that consumes the **same `#Module`** and produces ordered flow execution instead of resources. One input, two interpreters.

Four new constructs land in `core` (`opmodel.dev/core@v1`), layered:

- **`#Op`** — the controlled primitive. A slim, inline, dispatchable leaf (no FQN). OPM owns the set of kinds: `exec`, `http` (full CRUD), `wait`, `cue.eval`, k8s get/apply, … Each concrete Op carries a CUE **`@op(...)` attribute** that is invisible to CUE evaluation but readable by the Go SDK.
- **`#Action`** — a composition over Ops and nested Actions, with identity (FQN) so it can be published in a catalog and referenced by name. Steps carry ordering edges.
- **`#Lifecycle`** — binds steps to a fixed nine-phase vocabulary: `pre-install / install / post-install`, `pre-upgrade / upgrade / post-upgrade`, `pre-uninstall / uninstall / post-uninstall`.
- **`#Workflow`** — on-demand flows invoked explicitly (e.g. a container build), more open-ended than `#Lifecycle`.

The library splits cleanly along the neutrality boundary:

```
opm/
  compile/                RENDER HALF  (exists)   #Module → []*core.Compiled

  flow/                   EXECUTION HALF (new, kernel-core, NEUTRAL)
       plan.go        Plan / Step / StepResult  (pure data)
       planner.go     #Lifecycle(phase) | #Workflow(name) → ordered DAG of steps
       executor.go    Executor interface (the PORT) + Registry
       runner.go      walks the Plan in dependency order, dispatches each step
                      to the registered backend, threads results — NO I/O itself

  helper/executor/        EXECUTOR BACKENDS  (opt-in; the I/O lives here)
       wasmexec/      runs wasm op artifacts
       ociexec/       runs container op artifacts (operator variant renders a Job)
       httpexec/      thin HTTP host (full CRUD; returns raw response)
       cueexec/       cue.eval host (pure)
```

**Dispatch is attribute-driven.** The planner reads each step's `@op(protocol=…, ref=…)` attribute. `protocol` selects an executor **backend** from a registry; `ref` is a locator for the pluggable executable artifact. The library ships the generic backend *hosts* (a wasm runtime, an OCI runner, …) — these are runtimes, not operation logic, so neutrality holds and nothing op-specific is compiled in. The actual operation behavior is a catalog-sourced artifact the backend loads at runtime.

**Opt-in by registry.** A frontend builds a `Registry` from only the backends it wants, then runs. The runner validates the whole plan against the registry up front: a step whose `protocol` has no registered backend fails fast with a clear error *before* execution begins. This is how the operator cleanly declines, say, ad-hoc container builds — it simply never registers that backend. The same `#Op` and the same plan run differently per frontend: `exec` runs a local container on the CLI and renders-a-Job-and-watches on the operator, just by swapping the backend.

**Catalog-sourced, over existing rails.** Op definitions and their artifacts are distributed through the `#Catalog` manifest the render half already uses. `core`'s `#Catalog` gains additive sibling maps (`#ops`, `#actions`) alongside `#transformers`; the comment in `core/src/catalog.cue` already anticipates exactly this extension. `#Platform.#registry` + `materialize` resolve them — no parallel distribution pipeline.

## Schema / API Surface

Headline shapes only; the full surface is in [`schemas/target.cue`](schemas/target.cue).

- `#Op` — `opKind` discriminator + hidden `#out` + the `@op(protocol=…, ref=…)` attribute.
- `#Action` — `metadata{modulePath, version, name, fqn}` + a `steps` map; each step is `(#Op | #Action) & {dependsOn?: […]}`.
- `#Lifecycle` — `phases: [#Phase]: [...#Step]` over the fixed nine-phase enum.
- `#Workflow` — `metadata{name}` + a `steps` map.
- Library: `Kernel.PlanLifecycle(inst, phase) → *flow.Plan`, `Kernel.PlanWorkflow(inst, name) → *flow.Plan` (pure); `flow.Run(ctx, plan, registry) → *flow.Result` (drives injected backends).

The `@op(...)` attribute is the load-bearing new convention. It is hof.io-inspired (their `@task(os.Exec)` names a registered implementation); here the attribute instead carries a *protocol + locator* so the implementation is pluggable and catalog-sourced rather than compiled in.

## Integration Points

**`core/` (`opmodel.dev/core@v1`)** — new `src/op.cue`, `src/action.cue`, `src/lifecycle.cue`, `src/workflow.cue` defining the four constructs; additive `#ops` / `#actions` maps on `#Catalog` in `src/catalog.cue`; attachment of `#Lifecycle` / `#Workflow` onto `#Module` (OQ4). SPEC.md co-update required (`core-schema-edit` skill).

**`library/`** — new `opm/flow/` package (planner, runner, `Executor` interface, `Registry`, plan types); `Kernel.PlanLifecycle` / `Kernel.PlanWorkflow` / run entry points; opt-in `opm/helper/executor/*` backend hosts; attribute reading in the planner via `cue.Value.Attribute`.

**`catalog_opm/`** — publish the initial Op definitions and their artifacts; register them in the catalog manifest's new `#ops` / `#actions` maps. (No `#Area` token exists for `catalog_opm`; tracked in prose.)

**`cli/`** — register the backend set (incl. workflow execution); surface `opm workflow run <name>` and lifecycle invocation.

**`opm-operator/`** — register the operator's backend set (k8s-flavored `exec` → Job; likely no ad-hoc workflow backend); drive `#Lifecycle` phases from the reconcile loop.

## Before / After

**Before** — the migration scenario from `01-problem.md` lives outside OPM: a hand-written `migrate-job.yaml` pinned to one cluster, a `kubectl exec` seed step documented in prose, ordering left to the operator.

**After** — it is typed and composed from controlled primitives, carried on the same `#Module` that renders the app:

```cue
lifecycle: phases: "pre-upgrade": [
    ops.#WaitOp & {condition: "db.ready", timeout: "120s"},
    actions.#DBMigration & {steps: migrate: {image: "flyway/flyway:10", command: ["flyway", "migrate"]}},
]
workflows: "seed-demo": steps: run: ops.#ExecOp & {image: "myorg/seeder:1", command: ["seed"]}
```

The kernel plans the `pre-upgrade` phase into an ordered DAG and the operator orchestrates it through its registered backends; `seed-demo` runs only when an operator invokes it. Nothing is pinned to a cluster shape, and the platform team controls which Op kinds and backends exist.
