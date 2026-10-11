# Graduation Criteria: Manifest Passthrough: Side-Channel Raw and Kustomize Manifests

These are design acceptance criteria, not implementation milestones: delivery is derived from this entry's `delivery.yaml` log and read back with `task delivery`. The entry's documents store nothing about delivery progress.

## draft → accepted

Eight gates must all hold before promoting this design from draft to accepted:

- Design Goals and Non-Goals in `02-design.md` are final and reviewed.
- Every Open Question in `03-decisions.md` is resolved, in particular: OQ1 (kustomize-build vs raw-only scope for v1), OQ2 (relationship to 0005), OQ3 (`ModuleInstance` path root), OQ6 (Kustomize security posture), and OQ7 (collision semantics). OQ4 and OQ5 may close as `deferred-to-NNNN` / `answered`.
- Every decision recorded in `03-decisions.md` (D1..DN) is locked. No open trade-offs in the design.
- `contracts/contracts.cue` compiles (`cue vet ./...` from `schemas/` passes) and captures the `extraManifests` spec surface plus the provenance marker, tightened to match the resolved OQs.
- `depends_on`, `supersedes`, `superseded_by` in `config.yaml` are final and resolve; every `depends_on` id is carried by a `**Depends:**` line in a live decision.
- `semver` in `config.yaml` is set: expected `none` for `opmodel.dev/core` (D1: core untouched); the operator CRD addition is an additive, optional field.
- No `{Capitalised}` placeholder strings remain in any markdown file.
- The Cross-References table in `README.md` lists every file path the implementation will touch, and each path exists today.
