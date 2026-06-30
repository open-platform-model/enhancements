# Graduation Criteria — Operational Primitives: Op, Action, Lifecycle, Workflow

This document records the gates that must hold before the enhancement advances along the design lifecycle. Treat these as design acceptance criteria, not implementation milestones — implementation progress lives in `config.yaml.implementation` and the `history` list.

## draft → accepted

The enhancement is ready to be implemented when:

- Design Goals and Non-Goals in `02-design.md` are reviewed and stable.
- The five Open Questions are resolved, in particular **OQ1 (artifact form)** — it gates the executor backend set and the `@op(...)` attribute schema, so the design cannot freeze without it. OQ2/OQ3/OQ4 are either resolved or explicitly deferred to a named follow-up.
- Every decision (D1..DN) carries the four-field shape with a concrete `Source:`.
- `schemas/target.cue` compiles (`cue vet ./...` from the schemas directory) and captures the four constructs plus the catalog/attachment surface end-to-end, with `// OQn` markers removed as their questions close.
- `semver` in `config.yaml` is set. Adding new constructs to `core` is additive (minor) for the schema; confirm no existing definition is tightened.
- `affects` lists every repo shipping changes; `area` ∈ `affects`.
- `README.md ## Scope` (In/Out) and the Cross-References table are final; every listed path exists today.
- `05-risks.md` and `06-operational.md` carry concrete content, not scaffolds.

## accepted → implemented

The enhancement is shipped when:

- The four constructs and the `#Catalog` `#ops` / `#actions` extension are added to `core/src/*.cue`, with `SPEC.md` co-updated (`core-schema-edit` protocol) and `core` published.
- `library/opm/flow/` (planner, runner, `Executor` interface, `Registry`, plan types) and the `Kernel.PlanLifecycle` / `Kernel.PlanWorkflow` / run entry points are implemented with test coverage on the planner and the fail-fast registry path.
- At least the reference executor backends for the chosen artifact form(s) (OQ1) exist under `opm/helper/executor/`, with the operator's k8s-flavored variant where it differs.
- The initial Op/Action definitions and artifacts are published from `catalog_opm` and registered in its catalog manifest.
- CLI and operator each register their backend set; the operator drives `#Lifecycle` phases from the reconcile loop; an end-to-end flow (e.g. the migration scenario) runs in at least one frontend.
- `config.yaml.implementation.status = complete` with `date`; `history` names the landing milestones; `README.md` carries the implementation-status quote block and a `## Deviations from Design` section.
