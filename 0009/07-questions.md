# Open Questions — Operational Primitives: Op, Action, Lifecycle, Workflow

## Open Questions

Each entry carries a `Status:` line; close with `resolved-by-D##`, `deferred-to-NNNN`, or `answered`.

- **OQ1: What form do cataloged op artifacts take — WASM, OCI image, or both?** Status: open. This decides the executor backend set and the `@op(...)` attribute's `protocol`/`ref` schema. Recommendation on the table: support both, selected per-op by `protocol` — WASM as the default for pure-logic ops (http, cue.eval, wait-evaluation), OCI/container for inherently side-effecting ops (exec, build, k8s apply), with the operator's container backend rendering a Job rather than running locally. Resolving it requires choosing the wasm host and the OCI execution contract. Note: OPM's wasm backend would run op artifacts at **runtime** through the library orchestrator (side effects) — this is distinct from CUE's own **evaluation-time** WASM `@extern` functions (pure, and currently flagged experimental); do not conflate the two (see `research/cue-attribute-longevity.md`).

- **OQ2: Do steps pass typed data to each other, or is `dependsOn` ordering the only inter-step relation?** Status: open (needs further digging). A pure in-process orchestrator makes holding step outputs in memory natural, so typed `out → in` wiring (hof.io's data-DAG elegance) is feasible — but it is heavier to build and specify than ordering-only. `schemas/target.cue` currently reserves a hidden `#out` and an explicit `dependsOn` without committing to data references.

- **OQ3: What is the run-state / idempotency model for `#Workflow` (and how does it differ from `#Lifecycle`)?** Status: open (needs more design). `#Lifecycle` is tractable inside the operator reconcile loop — re-plan each reconcile, lean on convergent executors (k8s apply) plus completion records for run-once steps. On-demand `#Workflow` invocation is harder: it may be non-idempotent, may need run history, re-entrancy guarantees, and a place to store invocation state. This needs its own design pass.

- **OQ4: Where do `#Lifecycle` and `#Workflow` attach on `#Module` — module root, per-component, or both?** Status: open. The execution half reads them off the same `#Module` the render half consumes; the exact field placement and whether workflows can be component-scoped is undecided. `schemas/target.cue` sketches a module-root attachment only.

- **OQ5: Is the meta-controller toolkit in scope, and when?** Status: open (likely deferred). The same primitives + execution half could let authors stand up Kubernetes meta-controllers quickly (PoC operators) — an operator becomes "a reconcile loop + an executor registry." Treated as a north-star the architecture should not preclude, not a v1 deliverable; may split to a follow-up enhancement.
