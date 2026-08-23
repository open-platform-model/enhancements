# Graduation Criteria — Manifest Passthrough: Side-Channel Raw and Kustomize Manifests

This document records the entry-specific gates that must hold before this design is frozen. Treat these as design acceptance criteria, not implementation milestones — delivery is derived from the plans side and read back with `task delivery`; this entry stores nothing about it.

## draft → accepted

The enhancement is ready to be implemented when:

- Design Goals and Non-Goals in `02-design.md` are final and reviewed.
- Every Open Question in `03-decisions.md` is resolved — in particular: OQ1 (kustomize-build vs raw-only scope for v1), OQ2 (relationship to 0005), OQ3 (`ModuleInstance` path root), OQ6 (Kustomize security posture), and OQ7 (collision semantics). OQ4 and OQ5 may close as `deferred-to-NNNN` / `answered`.
- Every decision recorded in `03-decisions.md` (D1..DN) is locked — no open trade-offs in the design.
- `contracts/contracts.cue` compiles (`cue vet ./...` from `schemas/` passes) and captures the `extraManifests` spec surface plus the provenance marker, tightened to match the resolved OQs.
- `related` (`0005`) in `config.yaml` is final and resolves to an existing enhancement.
- `semver` in `config.yaml` is set — expected `none` for `opmodel.dev/core` (D1: core untouched); the operator CRD addition is an additive, optional field.
- No `{Capitalised}` placeholder strings remain in any markdown file.
- The Cross-References table in `README.md` lists every file path the implementation will touch, and each path exists today.
