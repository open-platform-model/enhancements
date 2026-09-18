# Enhancement 0009: Operational Primitives: Op, Action, Lifecycle, Workflow

The OPM kernel, the engine that turns a Module into Kubernetes objects, only renders. A Module cannot say what should happen around a deployment: an upgrade hook, a data migration, an on-demand job. Those end up in side scripts nobody governs. This entry adds a second half to the kernel that produces an ordered plan of steps instead of resources.

All entries: [INDEX.md](../INDEX.md). How this one relates to others: [GRAPH.md](../GRAPH.md). Metadata: [config.yaml](config.yaml).

## Summary

**The kernel gains a second half over the same Module (D1).** The render half is untouched. Four constructs land in core (D2): an `#Op` is one step from a closed set, an `#Action` groups Ops under a name a catalog can publish, a `#Lifecycle` binds steps to fixed phases, and a `#Workflow` runs on demand.

**The library plans, then advances one step per call (D3).** Given a plan and a state it returns the next state and the one thing the caller should do. It runs no loop and causes no side effect; the caller owns the state, which must survive serialization so a controller can carry it across reconciles.

**Backends are opt-in (D4).** A frontend registers only the ones it wants, and the plan is checked against that registry before the first step. That is how the operator declines ad-hoc container builds.

**Dispatch is by CUE attribute (D5).** It is inert metadata that evaluation ignores and the Go SDK reads. It names a protocol, which picks a backend, and where to fetch the executable, which comes from a catalog rather than being compiled in and travels the same rails transformers do (D6).

**Nine fixed lifecycle phases (D7), and cancellation belongs here (D9).** Before, during and after for install, upgrade and uninstall; an absent phase does nothing. One step per call means a caller cancels by not calling again. The HTTP Op returns the raw response (D8).

## How it works

```mermaid
flowchart TD
    mod["Module"] --> render["Render half: components become resources"]
    mod --> lifecycle["Lifecycle: steps bound to fixed phases, such as pre-upgrade"]
    mod --> workflow["Workflow: an on-demand named flow"]
    lifecycle --> action
    workflow --> action
    action["Action: a reusable composition, publishable in a catalog"] --> prim["Op: one of a closed set of primitives, carrying a protocol and an artifact locator"]
    prim --> planner["Planner: pure, builds an ordered plan"]
    planner --> advance["Advance: given the plan and the state, names the next action"]
    advance --> caller["Caller loop: CLI one-shot, or operator once per reconcile"]
    caller --> registry["Backend registry: only the backends this frontend chose, checked before the first step"]
    registry --> backend["Executor backend: wasm, container or Job, http, cue eval"]
    backend --> caller
    catalog["Catalog supplies the op artifacts"] -.-> backend
```

Read the top as authoring and the bottom as execution. One plan behaves differently per frontend without changing the module: a step that runs a local container on the CLI renders a Job and watches it under the operator, purely by swapping the backend.

## Documents

1. [01-problem.md](01-problem.md): OPM renders but cannot execute, and why side scripts are the anti-pattern
1. [02-design.md](02-design.md): the second kernel half, the four constructs, dispatch and the backend tier
1. [03-decisions.md](03-decisions.md): the decision log, D1 to D9
1. [04-graduation.md](04-graduation.md): what must hold before `draft` becomes `accepted`
1. [05-risks.md](05-risks.md): risks, drawbacks, alternatives not taken
1. [06-operational.md](06-operational.md): rollout, versioning, rollback, cross-repo ordering
1. [07-questions.md](07-questions.md): the open-questions register, OQ1 to OQ6

The core-schema delta lives under [`schemas/`](schemas/) as compilable CUE with worked examples and a specification delta; [`research/`](research/) holds a dated note on how durable the CUE attribute mechanism is.

## Scope

### In scope

- The four constructs in core, plus the dispatch-attribute convention and additive op and action maps on the catalog.
- The execution half of the kernel: a pure planner and a one-step-per-call advance (D3), with the opt-in backend layer, its registry and its fail-fast behaviour.
- The initial Op vocabulary, `exec`, full-CRUD `http`, `wait`, `cue.eval` and Kubernetes get and apply, as catalog definitions.
- Frontend wiring: the CLI and operator each composing their own backend set, the operator driving lifecycle phases from its reconcile loop.
- The kernel's cancellation path, designed and wired here and untouched by any other change until it lands (D9). It also introduces the injection point surface the planner needs, with its first reader, now that the kernel's write-only logger, tracer and clock slots are gone (revised D9).

### Out of scope

- Any change to the render half. Execution is purely additive.
- A general-purpose scripting language for operations. Composing a closed primitive set is the point.
- The meta-controller toolkit (OQ5): a north star the architecture must allow, not a first deliverable.
- Final production implementations of every executor backend, since the artifact form is still open (OQ1).

## Deviations from Design

None at this stage. Update this section when implementation lands and any deliberate divergences from the design need to be documented.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `core/CLAUDE.md`, `core/SPEC.md`, `core/.claude/skills/core-schema-edit/SKILL.md` | The schema home for the four constructs and the co-update protocol the core slice follows |
| `core/src/catalog.cue` | The catalog shape the additive op and action maps extend |
| `core/src/transformer.cue` | The transformer and matcher pattern the execution half parallels |
| `library/CLAUDE.md`, `library/CONSTITUTION.md` | Kernel neutrality and the boundary the planner and backend split honours |
| `library/opm/kernel/` | The render half this one parallels |
| `library/opm/helper/` | The opt-in tier the backends would join, and the fence a frontend may skip |
| `library/opm/platform/` | The platform registry that resolves catalogs, the rails op artifacts ride on |
| `library/adr/008-kernel-plans-caller-runs.md` | The library rule D3 records: the kernel decides, the caller loops and acts |
| `catalog_opm/CLAUDE.md`, `catalog_opm/src/catalog.cue` | Where the initial Op and Action definitions are published |
| https://hofstadter.io/getting-started/task-engine/ | Prior art for the attribute-dispatch model adapted here |
