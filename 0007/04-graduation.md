# Graduation Criteria — Manifest Passthrough: Side-Channel Raw and Kustomize Manifests

This document records the gates that must hold before the enhancement advances along the design lifecycle. Treat these as design acceptance criteria, not implementation milestones — implementation progress lives in `config.yaml.implementation` and the `history` list.

## draft → accepted

The enhancement is ready to be implemented when:

- Design Goals and Non-Goals in `02-design.md` are final and reviewed.
- Every Open Question in `03-decisions.md` is resolved — in particular: OQ1 (kustomize-build vs raw-only scope for v1), OQ2 (relationship to 0005), OQ3 (`ModuleRelease` path root), OQ6 (Kustomize security posture), and OQ7 (collision semantics). OQ4 and OQ5 may close as `deferred-to-NNNN` / `answered`.
- Every decision recorded in `03-decisions.md` (D1..DN) is locked — no open trade-offs in the design.
- `schemas/target.cue` compiles (`cue vet ./...` from `schemas/` passes) and captures the `extraManifests` spec surface plus the provenance marker, tightened to match the resolved OQs.
- `related` (`0005`) in `config.yaml` is final and resolves to an existing enhancement.
- `semver` in `config.yaml` is set — expected `none` for `opmodel.dev/core` (D1: core untouched); the operator CRD addition is an additive, optional field.
- No `{Capitalised}` placeholder strings remain in any markdown file.
- The Cross-References table in `README.md` lists every file path the implementation will touch, and each path exists today.

## accepted → implemented

The enhancement is shipped when:

- The operator's `ModuleRelease` and `Release` CRD specs carry the optional `extraManifests` field; CRDs are regenerated under `opm-operator/config/crd`.
- The shared passthrough renderer (embedding `sigs.k8s.io/kustomize/api/krusty`) exists at the location chosen by OQ5, with hardened options per OQ6, and unit tests covering raw decode and a kustomize build.
- The operator render path folds passthrough output into the resource list before labeling/inventory/apply/prune, with tests proving side objects are stamped with the release UUID, recorded in `status.inventory`, and pruned on release deletion (the `01-problem.md` jellyfin scenario, end to end).
- The CLI `release build`/`apply` honor the same declaration and serialize/apply passthrough objects alongside rendered output, with test coverage.
- Collision behavior (OQ7) is enforced and tested.
- `core/` and `library/` carry **no** changes (verified — the non-goal held).
- `config.yaml.implementation.status = complete` with `date` set to the landing date.
- `history` carries events naming each landing milestone (operator slice, CLI slice), with `slice` refs where the target repo used OpenSpec.
- `README.md` carries an `> **Implementation status (YYYY-MM-DD).**` quote block whose date matches `implementation.date`.
- `## Deviations from Design` in `README.md` lists every deliberate divergence (or says "None").
