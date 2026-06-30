# Operational Concerns — Operational Primitives: Op, Action, Lifecycle, Workflow

OPM Production Readiness Review (PRR-lite). Several answers firm up as Open Questions resolve; where that is the case it is stated explicitly.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

New error kinds in `library` for the execution half: plan-resolution errors (malformed flow, unknown `#Op` kind, unresolved `dependsOn`), registry errors (no backend for a `protocol` — raised at plan-validation time, before execution), and per-step execution errors carrying the step name, op kind, and backend. These follow the existing `opm/errors` pattern (typed, grouped) so frontends format them. The planner's output (`*flow.Plan`) is itself a diagnostic artifact — inspectable before any side effect, mirroring how `flow-inspect` exposes the render pipeline stages. Step-level progress/result surfacing is a frontend concern (CLI stdout, operator status/events); the kernel stays output-free per Principle I.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

`core`: additive — four new constructs plus additive `#Catalog` maps. No existing definition is removed or tightened, so it is a minor schema change on `opmodel.dev/core@v1` (confirm at accept). `library`: additive Go surface (new `opm/flow/` package, new `Kernel` methods, new opt-in `helper/executor/` packages); existing render-half signatures are untouched. `catalog_opm`: additive (new Op/Action definitions). Shipping order is core → library → catalog_opm → (cli, opm-operator); each downstream re-pins the published core/catalog versions.

## Deprecation

**What gets removed and when? What replaces it?**

Nothing is removed. This enhancement is purely additive — there is no prior operational mechanism in OPM to deprecate. Side scripts / hand-written Jobs that authors used as workarounds are not OPM artifacts and are not managed here; authors migrate them voluntarily as the vocabulary matures.

## Rollback

**If this lands and proves bad, what's the rollback story?**

The execution half is opt-in at two levels: a `#Module` without `#Lifecycle` / `#Workflow` behaves exactly as today, and a frontend that registers no executor backends cannot execute flows. Reverting the library to a pre-`flow/` version leaves rendering fully functional. The additive `core` constructs are inert if unused. Data-plane caveat: any side effects already performed by executors (a migration that ran, a credential rotated) are not undone by a code rollback — this is inherent to operations and is why convergent executors and `#Workflow` run-state (OQ3) matter.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

1. `core` publishes the four constructs + `#Catalog` extension (with `SPEC.md`); emits a new `opmodel.dev/core@v1` version.
2. `library` adopts the new schema paths, implements `opm/flow/` and the backend layer; consumes the new core version.
3. `catalog_opm` publishes the initial Op/Action definitions and artifacts against the new core; emits a new catalog version.
4. `cli` and `opm-operator` re-pin core + catalog, register their backend sets, and wire invocation (CLI workflows + lifecycle; operator lifecycle from reconcile). The operator and CLI may land independently of each other.
