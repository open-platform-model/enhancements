# Graduation Criteria: CUE-Native CRD Schemas as Single Source of Truth

These are design acceptance criteria, not implementation milestones:
delivery is logged in this entry's `delivery.yaml` and read back with
`task delivery`. The entry's documents store nothing about delivery
progress.

Repo-wide checks (semver set, placeholders gone, CUE compiles, cross-refs
resolve) live in `gates.cue` and `task vet`, not here. What belongs here
is what is true of THIS design and no other.

## draft → accepted

Seven gates must all hold before promoting this design from draft to accepted:

- Design Goals and Non-Goals in `02-design.md` are final and reviewed.
- Every decision recorded in `03-decisions.md` (D1..D8) is locked, and every Open Question is resolved (`resolved-by-D##`, `deferred-to-NNNN`, or `answered`). In particular, OQ2 (status ownership), OQ4 (`ModulePackage` domain anchor), and OQ5 (`core` semver impact) gate whether the first slice is well-formed.
- `schemas/` compiles (`cue vet ./...` from the directory passes): `target.cue` captures the `#CRD` / `#CRDVersion` / `#PrinterColumn` / `#CELValidation` surface, and `examples.cue` carries at least one worked instance (`ModuleInstance` and `Platform`) end-to-end.
- A throwaway spike has demonstrated, against the real `opmodel.dev/core` and CUE v0.17, that `encoding/openapi` with `ExpandReferences` produces a structural schema the API server accepts for at least one of the three kinds, i.e. the central feasibility claim (D3) is validated, ideally captured as an `experiments/` entry.
- `depends_on`, `supersedes`, `superseded_by` in `config.yaml` are final and resolve; every `depends_on` id is carried by a `**Depends:**` line in a live decision.
- `semver` in `config.yaml` is set (major / minor / none), informed by OQ5.
- No `{Capitalised}` placeholder strings remain in any markdown file.
- The Cross-References table in `README.md` lists every file path the implementation will touch, and each path exists today (or is explicitly marked *(new)*).
