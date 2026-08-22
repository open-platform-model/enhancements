# Design Decisions — Operational Primitives: Op, Action, Lifecycle, Workflow

This document records every significant design choice with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, …) and recorded as they are made. **Numbers are permanent** — never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes. The *text* under a number states what is true now: a reversal is recorded as its own `DN` while the design is in motion, then woven into the decision it changes at the next compaction pass — the merged decision keeps the lower number, and the vacated number keeps a one-line tombstone. See the `enhancement-compaction` skill.

---

## Decisions

### D1: Add a second kernel half for execution; do not extend the render pipeline

**Kind:** contract

**Decision:** The kernel grows a parallel *execution half* that consumes the same `#Module` as the render half (`opm/compile/`) and produces ordered flow execution rather than resources. One input, two interpreters.

**Alternatives considered:**

- Render operations as resources through the existing transformer pipeline (operations as Jobs emitted by `opm/compile/`) — rejected: it overloads the render half with sequencing/ordering semantics it has no model for, and conflates "what must exist" with "what must happen."
- A separate tool outside the kernel — rejected: the CLI and operator both need it, and the kernel is the shared runtime they embed.

**Rationale:** Mirrors the clean separation already in the codebase. Rendering stays untouched; execution is additive and reuses the same parsed `#Module`.

**Source:** User decision 2026-06-29.

### D2: Four operational constructs in `core`, keep the names

**Kind:** contract

**Decision:** Introduce `#Op`, `#Action`, `#Lifecycle`, `#Workflow` into `opmodel.dev/core@v1`. `#Op` is the controlled primitive (closed set of kinds), `#Action` is a composition with FQN identity, `#Lifecycle` binds steps to state-transition phases, `#Workflow` is on-demand.

**Alternatives considered:**

- A single "operation" construct with a mode flag — rejected: lifecycle (phase-triggered) and workflow (on-demand) have genuinely different trigger and state semantics; collapsing them hides that.
- Define them in a catalog rather than core — rejected: they are schema contracts every consumer types against, like the other primitives; core is their home.

**Rationale:** Parallels the declarative side (Resource/Blueprint/Component) and gives each operational concern its own primitive.

**Source:** User decision 2026-06-29.

### D3: The library is a pure planner + orchestrator; side effects live behind injected executors

**Kind:** contract

**Decision:** The execution half (`opm/flow/`) plans flows into an ordered DAG and sequences them, but performs no side effects itself. Actual execution happens behind an `Executor` interface whose implementations the frontend injects.

**Alternatives considered:**

- An imperative engine in the kernel that runs containers / shells out directly — rejected: violates Principle I (kernel neutrality forbids shell invocation, `os.Exit`, non-determinism) and couples the kernel to a runtime environment.

**Rationale:** Same discipline that keeps the render half clean — it emits `*core.Compiled` and never applies. The execution half emits/sequences a plan and never executes; the frontend executes. Makes lifecycle hooks convergent rather than fire-and-forget.

**Source:** User decision 2026-06-29.

### D4: Executor backends ship in the library's opt-in layer; frontends compose them à la carte

**Kind:** contract

**Decision:** The generic executor backend *hosts* live under `opm/helper/executor/` (opt-in, like `helper/loader/`). Frontends build a `Registry` from only the backends they want. The runner validates the plan against the registry up front; a step whose backend is unregistered fails fast before any execution.

**Alternatives considered:**

- Backends as kernel-core, always present — rejected: forces every frontend to carry every runtime (container, wasm, …) and removes the clean "operator declines workflows" path.
- Backends entirely outside the library — rejected: the user wants the executors to be part of the library (kernel or opt-in layer), just not hardcoded into the planner.

**Rationale:** Matches the existing kernel-vs-helper boundary; gives CLI and operator independent backend sets; same `#Op` runs differently per frontend by swapping the backend.

**Source:** User decision 2026-06-29.

### D5: Dispatch via a CUE `@op(...)` attribute (eval-invisible, SDK-readable)

**Kind:** contract

**Decision:** Each concrete `#Op` carries a CUE attribute, hof.io-style, as a **field attribute** (placed after the field value, e.g. `opKind: "exec" @op(...)`) or a declaration/file-level attribute. It is invisible to CUE evaluation and read by the Go SDK (`cue.Value.Attribute`). It carries `protocol` (which backend) and `ref` (locator for the pluggable artifact). Note: CUE does **not** support attributes placed *before* a field/identifier (the "before the field" hof.io form is not portable CUE — see `research/cue-attribute-longevity.md`), so 0009 uses the on-field placement.

**Alternatives considered:**

- A regular CUE field (e.g. `executor: "..."`) — rejected: this is runtime dispatch metadata, not user configuration; attributes are CUE's designed mechanism for exactly this and keep the evaluated value clean.
- Hardcoding op-kind → implementation in the planner (hof.io's compiled-in `@task` registry) — rejected: the implementation must be pluggable, not compiled into the library (see D6).

**Rationale:** Attributes cross the hermetic boundary only when the SDK chooses to read them; CUE evaluation stays pure. The attribute is the bridge from declarative schema to pluggable runtime dispatch.

**Source:** User decision 2026-06-29. Inspired by hofstadter.io's task/flow attribute model (`@task(os.Exec)`). Longevity of the attribute mechanism assessed in `research/cue-attribute-longevity.md` (2026-06-29) — no removal planned; CUE's own custom-function feature is itself attribute-based (`@extern`).

### D6: Executable op code is catalog-sourced, not hardcoded in the library

**Kind:** policy

**Decision:** The actual code an Op runs is not compiled into the library. It is a pluggable artifact located by the `@op(...)` attribute's `ref`, distributed through the existing `#Catalog` / `#Platform.#registry` / `materialize` machinery. `core`'s `#Catalog` gains additive `#ops` / `#actions` maps alongside `#transformers`.

**Alternatives considered:**

- Compile op implementations into the library (hof.io model) — rejected: every new op would need a library release; the user wants the system pluggable.
- A new, separate distribution pipeline for op artifacts — rejected: the render half already solved catalog distribution; reuse it. The `#Catalog` schema comment already anticipates additive sibling maps.

**Rationale:** Operations become as pluggable as transformers already are. The library owns the *mechanism* (planner + generic backend hosts); the catalog owns the *behavior*.

**Source:** User decision 2026-06-29.

### D7: `#Lifecycle` exposes a fixed nine-phase vocabulary

**Kind:** contract

**Decision:** `#Lifecycle` phases are the fixed set: `pre-install`, `install`, `post-install`, `pre-upgrade`, `upgrade`, `post-upgrade`, `pre-uninstall`, `uninstall`, `post-uninstall`. Each phase is an ordered list of steps; absent phases are no-ops.

**Alternatives considered:**

- Author-defined arbitrary phase names — rejected: a closed vocabulary is what lets the operator reason about and drive transitions from its reconcile loop.

**Rationale:** A small, well-known phase set keyed to the install/upgrade/uninstall lifecycle is tractable for the operator and familiar to authors, without re-importing Helm's hook sprawl.

**Source:** User decision 2026-06-29.

### D8: The HTTP Op exposes full CRUD and returns the raw response; parsing is done in CUE

**Kind:** contract

**Decision:** The `http` Op exposes the full verb set (GET/POST/PUT/PATCH/DELETE) and returns the raw status, headers, and body. Response parsing/shaping is done in CUE downstream, not inside the executor.

**Alternatives considered:**

- A typed/parsed HTTP op that decodes JSON in the executor — rejected (for the initial version): keeps the executor dumb and pushes shaping into CUE, where OPM already does data work.

**Rationale:** Keeps the backend a thin transport and leverages CUE for data handling; a richer typed op can layer on later as a composition.

**Source:** User decision 2026-06-29.

Open Questions live in [`07-questions.md`](07-questions.md) — the entry's question register.
