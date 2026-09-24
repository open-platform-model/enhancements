# Design Decisions: Operational Primitives: Op, Action, Lifecycle, Workflow

This document records every design choice, with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, …) and recorded as they are made. **Numbers are permanent**: never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes. The *text* under a number states what is true now: a reversal is recorded as its own `DN` while the design is in motion, then woven into the decision it changes at the next compaction pass. The merged decision keeps the lower number, and the vacated number keeps a one-line tombstone. See the `enhancement-compaction` skill.

---

## Decisions

### D1: Add a second kernel half for execution; do not extend the render pipeline

**Kind:** contract

**Decision:** The kernel grows a parallel *execution half* that consumes the same `#Module` as the render half and produces an ordered plan rather than resources. One input, two interpreters.

**Requirements:**

- R1: A `#Module` renders identically with and without operational declarations; the render output carries no resource derived from a lifecycle or workflow.
- R2: From the same `#Module` the render half reads, a caller obtains an ordered plan of steps for a lifecycle phase or a named workflow, never a rendered resource.

**Alternatives considered:**

- Render operations as resources through the existing transformer pipeline (operations as Jobs emitted by the render half): rejected: it overloads the render half with sequencing/ordering semantics it has no model for, and conflates "what must exist" with "what must happen."
- A separate tool outside the kernel: rejected: the CLI and operator both need it, and the kernel is the shared runtime they embed.

**Rationale:** Mirrors the clean separation already in the codebase. Rendering stays untouched; execution is additive and reuses the same parsed `#Module`.

**Source:** User decision 2026-06-29.

### D2: Four operational constructs in `core`, keep the names

**Kind:** contract

**Decision:** Introduce `#Op`, `#Action`, `#Lifecycle`, `#Workflow` into `opmodel.dev/core@v1`. `#Op` is the controlled primitive (closed set of kinds), `#Action` is a composition with FQN identity, `#Lifecycle` binds steps to state-transition phases, `#Workflow` is on-demand.

**Requirements:**

- R1: A module or catalog author declares operational intent with `#Op`, `#Action`, `#Lifecycle` and `#Workflow` from the published core module, not from a catalog.
- R2: An author composes existing Op kinds and cannot declare a new one; an `opKind` outside the OPM-owned vocabulary is rejected.
- R3: An `#Action` carries an FQN derived from its module path, name and version, and an FQN authored independently of them is rejected.
- R4: A `#Workflow` runs only when explicitly invoked by name; no state transition triggers it.
- R5: A step's ordering edges name sibling steps in the same map; an edge naming anything else is rejected.

**Alternatives considered:**

- A single "operation" construct with a mode flag: rejected: lifecycle (phase-triggered) and workflow (on-demand) have genuinely different trigger and state semantics; collapsing them hides that.
- Define them in a catalog rather than core: rejected: they are schema contracts every consumer types against, like the other primitives; core is their home.

**Rationale:** Parallels the declarative side (Resource/Blueprint/Component) and gives each operational concern its own primitive.

**Source:** User decision 2026-06-29.

### D3: The library plans and advances one step per call; the caller runs the loop and performs every action

**Kind:** contract

**Decision:** The execution half plans a flow into an ordered graph and advances it one step per call: given a plan and a state value it returns the next state and the action the caller is to perform. It runs no loop, holds no run state between calls, and performs no side effects. The caller drives the loop, performs each action through an executor backend it registered, and owns the state, which MUST survive serialisation so a controller can carry it across reconciles. Every decision about what happens next stays in the library: which steps are eligible, in what order, what counts as a step being satisfied, what a failure does, and when a phase and a plan are complete.

**Requirements:**

- R1: Given a plan and a state value, one advance returns the next state and at most one action for the caller to perform, and performs no side effect itself.
- R2: A run state written out and read back advances identically to one held in memory.
- R3: Which steps are eligible, in what order, what satisfies a step, what a failure does and when a phase or plan is complete are decided by the library; two callers with the same plan, state and result receive the same next action.
- R4: The library holds no run state between calls; a caller that stops calling advance owes nothing further.

**Alternatives considered:**

- The library sequences the flow itself, walking the graph to completion behind an injected executor port (previously adopted, 2026-06-29). Reversed on revision: a loop that blocks on a wait step is a process model, which Principle I forbids the library to assume, and a controller reconcile is level-triggered and must return promptly, so it could never call that loop. The operator would have kept the plan, ignored the sequencer and written its own resumable walk, reproducing below the plan the duplication this entry exists to prevent above it.
- An imperative engine in the kernel that runs containers / shells out directly: rejected: violates Principle I (kernel neutrality forbids shell invocation, `os.Exit`, non-determinism) and couples the kernel to a runtime environment.
- A plan the library emits once, leaving each frontend to write its own walk: rejected: it puts the sequencing rules in two places, and a rule with two homes drifts silently. The render half already shows the pattern, where apply ordering was lost in one frontend and nothing failed.

**Rationale:** Same discipline that keeps the render half clean: it emits compiled output and never applies. The execution half decides and never acts. Advancing one step at a time is what makes one set of decisions usable by both frontends: a one-shot CLI invocation calls it in a loop, and a controller calls it once per reconcile with the state carried in the instance it owns. It also makes cancellation free, which matters because OQ6 measures that cancellation can never reach a running CUE evaluation anyway.

**Source:** User decision 2026-06-29; narrowed by user decision 2026-09-14, recorded as library ADR-008.

**Revised:** 2026-09-14, the sequencing loop moves from the library to the caller and the caller owns the run state; what the library decides is unchanged.

### D4: Executor backends ship in the library's opt-in layer; frontends compose them à la carte

**Kind:** contract

**Decision:** The generic executor backend *hosts* ship in the library's opt-in tier, the boundary a frontend may skip. Frontends build a `Registry` from only the backends they want, and the whole plan is checked against that registry before the first action: a step whose backend is unregistered fails fast, before anything runs.

**Requirements:**

- R1: A frontend runs a plan through only the backends it registered; the same plan runs through different backends on different frontends.
- R2: A plan containing a step whose protocol has no registered backend is refused before any step runs, naming the step and the protocol.

**Alternatives considered:**

- Backends as kernel-core, always present: rejected: forces every frontend to carry every runtime (container, wasm, …) and removes the clean "operator declines workflows" path.
- Backends entirely outside the library: rejected: the user wants the executors to be part of the library (kernel or opt-in layer), just not hardcoded into the planner.

**Rationale:** Matches the existing kernel-vs-helper boundary; gives CLI and operator independent backend sets; same `#Op` runs differently per frontend by swapping the backend.

**Source:** User decision 2026-06-29.

### D5: Dispatch via a CUE `@op(...)` attribute (eval-invisible, SDK-readable)

**Kind:** contract

**Decision:** Each concrete `#Op` carries a CUE attribute, hof.io-style, as a **field attribute** (placed after the field value, e.g. `opKind: "exec" @op(...)`) or a declaration/file-level attribute. It is invisible to CUE evaluation and read by the Go SDK (`cue.Value.Attribute`). It carries `protocol` (which backend) and `ref` (locator for the pluggable artifact). Note: CUE does **not** support attributes placed *before* a field/identifier (the "before the field" hof.io form is not portable CUE; see `research/cue-attribute-longevity.md`), so 0009 uses the on-field placement.

**Requirements:**

- R1: Every concrete Op kind carries an `@op(...)` attribute naming the backend protocol and the artifact locator, placed on the field after its value.
- R2: The attribute does not change the evaluated value: exporting an Op with and without its attribute yields identical data.

**Alternatives considered:**

- A regular CUE field (e.g. `executor: "..."`): rejected: this is runtime dispatch metadata, not user configuration; attributes are CUE's designed mechanism for exactly this and keep the evaluated value clean.
- Hardcoding op-kind → implementation in the planner (hof.io's compiled-in `@task` registry): rejected: the implementation must be pluggable, not compiled into the library (see D6).

**Rationale:** Attributes cross the hermetic boundary only when the SDK chooses to read them; CUE evaluation stays pure. The attribute is the bridge from declarative schema to pluggable runtime dispatch.

**Source:** User decision 2026-06-29. Inspired by hofstadter.io's task/flow attribute model (`@task(os.Exec)`). Longevity of the attribute mechanism assessed in `research/cue-attribute-longevity.md` (2026-06-29): no removal planned; CUE's own custom-function feature is itself attribute-based (`@extern`).

### D6: Executable op code is catalog-sourced, not hardcoded in the library

**Kind:** contract

**Decision:** The actual code an Op runs is not compiled into the library. It is a pluggable artifact located by the `@op(...)` attribute's `ref`, distributed through the existing `#Catalog` and `#Platform.#registry` machinery. `core`'s `#Catalog` gains additive `#ops` / `#actions` maps alongside `#transformers`.

**Requirements:**

- R1: `#Catalog` carries `#ops` and `#actions` maps beside `#transformers`, keyed by FQN, and a catalog that omits them is unchanged in meaning.
- R2: An `#actions` entry is keyed by the contained Action's FQN.
- R3: A platform gains a new Op by subscribing a catalog that publishes it, with no library release involved.

**Alternatives considered:**

- Compile op implementations into the library (hof.io model): rejected: every new op would need a library release; the user wants the system pluggable.
- A new, separate distribution pipeline for op artifacts: rejected: the render half already solved catalog distribution; reuse it. The `#Catalog` schema comment already anticipates additive sibling maps.

**Rationale:** Operations become as pluggable as transformers already are. The library owns the *mechanism* (planner + generic backend hosts); the catalog owns the *behavior*.

**Source:** User decision 2026-06-29.

### D7: `#Lifecycle` exposes a fixed nine-phase vocabulary

**Kind:** contract

**Decision:** `#Lifecycle` phases are the fixed set: `pre-install`, `install`, `post-install`, `pre-upgrade`, `upgrade`, `post-upgrade`, `pre-uninstall`, `uninstall`, `post-uninstall`. Each phase is an ordered list of steps; absent phases are no-ops.

**Requirements:**

- R1: A `#Lifecycle` accepts exactly the phases `pre-install`, `install`, `post-install`, `pre-upgrade`, `upgrade`, `post-upgrade`, `pre-uninstall`, `uninstall` and `post-uninstall`, and rejects any other phase key at module validation.
- R2: Steps within a phase run in the order authored.
- R3: A phase that is absent or empty is a no-op; the transition proceeds with nothing to run.

**Alternatives considered:**

- Author-defined arbitrary phase names: rejected: a closed vocabulary is what lets the operator reason about and drive transitions from its reconcile loop.

**Rationale:** A small, well-known phase set keyed to the install/upgrade/uninstall lifecycle is tractable for the operator and familiar to authors, without re-importing Helm's hook sprawl.

**Source:** User decision 2026-06-29.

### D8: The HTTP Op exposes full CRUD and returns the raw response; parsing is done in CUE

**Kind:** contract

**Decision:** The `http` Op exposes the full verb set (GET/POST/PUT/PATCH/DELETE) and returns the raw status, headers, and body. Response parsing/shaping is done in CUE downstream, not inside the executor.

**Requirements:**

- R1: The `http` Op accepts GET, POST, PUT, PATCH and DELETE and rejects any other method at validation.
- R2: The `http` Op's output is the raw status, headers and body; the executor performs no parsing or shaping of the body.

**Alternatives considered:**

- A typed/parsed HTTP op that decodes JSON in the executor: rejected (for the initial version): keeps the executor dumb and pushes shaping into CUE, where OPM already does data work.

**Rationale:** Keeps the backend a thin transport and leverages CUE for data handling; a richer typed op can layer on later as a composition.

**Source:** User decision 2026-06-29.

### D9: The execution half owns the kernel's cancellation path and introduces its own injection surface

**Kind:** scope

**Decision:** The cancellation path (a caller's context reaching phase boundaries and registry I/O) is this entry's to design and deliver; until this entry lands it stays as it is, and no other change threads or wires it. Under the one-step-per-call shape (D3) a caller cancels between steps by not calling again, so what remains to design is cancellation inside a single advance, which reaches a registry fetch and nothing else. The three dependency-injection slots the kernel accepted (logger, tracer, clock) are removed now as write-only surface, in a library change this entry does not carry. This entry introduces the injection surface the planner actually needs together with its first reader, in whatever shape that reader dictates, not as a restoration of the removed symbols.

**Requirements:** none (bounds ownership of cancellation and of the planner's injection surface to this entry; what cancellation inside one advance observably does is OQ6 and lands under D3 and D4)

**Alternatives considered:**

- Keep the three slots reserved for this entry, accepted and unread, until the execution half lands (previously adopted, 2026-08-30). Reversed on revision: the kernel carried a write-only option surface whose only effect was to suggest an observability story that did not exist, and the tracer slot alone kept an external tracing dependency direct; the churn argument undervalued the cost of a misleading public surface with one workspace-internal consumer to migrate.
- Thread cancellation through the kernel as a standalone library change ahead of this entry. Rejected: a cancellation path needs a consumer with a cancellation story, and the execution half is the first one; designing it beside the executor port keeps one model across both halves.

**Rationale:** Measured in the library kernel review: the kernel discards the caller's context on most entry points, and the context never reaches a registry fetch because CUE's loader substitutes its own before loading; the logger, tracer and clock slots had no reader since they were added. The planner is the first kernel surface that needs cancellation, logs and spans. A lifecycle phase waits on conditions and registry pulls, and step-level spans are where an operator reads progress, so the execution half is where an injection surface first earns its existence, shaped by its first reader rather than reserved ahead of it. A clock is no longer among them: under D3 the caller holds the loop and therefore the waiting. See OQ6 for the measured limit on how far cancellation can reach.

**Source:** User decision 2026-08-30, from the library kernel review.

**Revised:** 2026-09-01, reserved-slots half reversed by user decision: slots removed now, re-introduced by this entry with their first reader; cancellation half unchanged.

**Revised:** 2026-09-14, cancellation between steps becomes a property of D3's shape rather than a mechanism to design; what is left to design is cancellation inside one advance.

### D10: `#Lifecycle` and `#Workflow` attach at module root as module traits on an aspect

**Kind:** contract

**Depends:** 0025:D11, 0025:D12

**Decision:** Lifecycle and workflow declarations attach to a `#Module` through its `#aspects` map (0025 D11): a catalog publishes them as module traits (0025 D12), a module attaches them on a named aspect and fills the spec. There is no per-component attachment and no dedicated field on `#Module`. The execution half reads them off the same aspect the render half sees; no render-side transformer handles them, so their fulfilment is stated under 0025's answer to OQ13.

**Requirements:**

- R1: A module attaches lifecycle and workflow declarations as module traits on a named aspect and nowhere else; a lifecycle or workflow declared on a component or as a dedicated `#Module` field is rejected.
- R2: A module carrying lifecycle or workflow traits renders with no resource emitted for them and no missing-transformer failure.

**Alternatives considered:**

- **Per-component attachment.** Rejected: a workflow spans components by construction (drain one, migrate another, verify a third); scoping it to one component would need a cross-component reference vocabulary the render half does not have either.
- **Both module root and per-component.** Rejected: two attachment points is the two-interpreter problem entry 0027 names for served kinds, transposed to placement; every consumer would merge the two.
- **A dedicated `lifecycle` and `workflows` field on `#Module`** (the sketch this entry carried until 2026-09-19). Rejected once 0025 gave the module one named extension point: a field per feature is what the aspect map exists to stop.

**Rationale:** The execution half consumes the same `#Module` the render half does; an aspect is exactly the module-scoped, catalog-published, versioned slot it needs, and 0025 D13 already reserves non-resource output for this interpreter rather than for a render-side transformer.

**Source:** User decision 2026-09-19.

Open Questions live in [`07-questions.md`](07-questions.md): the entry's question register.
