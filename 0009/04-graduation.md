# Graduation Criteria — Operational Primitives: Op, Action, Lifecycle, Workflow

This document records the entry-specific gates that must hold before this design is frozen. Treat these as design acceptance criteria, not implementation milestones — delivery is derived from this entry's `delivery.yaml` log and read back with `task delivery`; the entry's documents store nothing about it.

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
