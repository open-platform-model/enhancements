# Graduation Criteria — Export a Deployed Instance as GitOps Manifests

This document records the gates that must hold before the enhancement advances along the design lifecycle. These are design acceptance criteria, not implementation milestones — implementation progress lives in `config.yaml.implementation` and the `history` list.

## draft → accepted

- Goals and Non-Goals in `02-design.md` are final and reviewed.
- OQ1 (completion policy for `spec.serviceAccountName` and `spec.prune`) is resolved by a decision — the export's field-completion behaviour is the single largest difference between the exported document and the live object, and it cannot be left to implementation.
- OQ2 (RBAC content) is resolved. Emitting a `cluster-admin` binding from a tool is a security posture decision, not a formatting one.
- OQ3 (whether a CLI-owned instance may be exported) is resolved, because it decides whether export and handoff are sequential operations or overlapping ones.
- OQ4 (field-manager collision on the first GitOps apply) is answered by a **runnable experiment**, not by reasoning. The experiment applies an exported tree over a live CLI-applied-then-handed-off instance in a kind cluster and records: whether kustomize-controller's apply conflicts, whether the resulting field ownership is stable across reconciles, whether Flux's `Kustomization.spec.prune` interacts with the operator's finalizer, and whether the instance's inventory entry set is unchanged. Until this runs, D2's adoption guarantee is a claim rather than a result.
- OQ5 (whether the CR's own OPM labels are exported) is resolved, most likely by the same experiment.
- OQ6 (whether the CLI warns when applying to a git-managed instance) is either resolved or explicitly deferred to a named follow-on.
- `contracts/contracts.cue` compiles (`cue vet ./...` from that directory) and captures the full target shape: request, gate chain, field classes, exported set, report, and the adoption property.
- `related`, `supersedes`, `superseded_by` in `config.yaml` are final and resolve to existing entries.
- `semver` in `config.yaml` is set.
- No placeholder strings remain in any markdown file.
- The Cross-References table in `README.md` lists every file path the implementation will touch, and each path exists today.

## accepted → implemented

- `opm instance export` exists in `cli/internal/cmd/instance/export.go` and is registered on the `instance` command group.
- The gate chain in `cli/internal/workflow/export/` runs the same verification primitive as handoff, with exactly one implementation of `VerificationDigest` in the tree.
- Every field class named in `02-design.md` is implemented as specified: render-bearing fields copied verbatim, apply-bearing fields completed per OQ1's resolution and reported, cluster-side fields dropped.
- Unit coverage for completion and composition (table-driven over `Record` fixtures; no cluster required), including the byte-stability property — exporting the same record twice yields identical bytes.
- An e2e case in `cli/tests/e2e/` covering the full arc: CLI apply, handoff, export, apply the exported tree, assert the inventory entry set is unchanged and no workload was replaced. This is the executable form of `#AdoptionProperty` and is the gate that proves the enhancement's headline claim.
- A refusal test per gate: local-provenance instance, missing module version, absent `lastAppliedRenderDigest`, digest mismatch without `--force`. Each asserts nothing was written to the out-dir.
- `cli/README.md` documents the command; the generated CLI reference on `opmodel.dev` is regenerated.
- `config.yaml.implementation.status = complete` with `date` set to the landing date.
- `history` carries one or more events naming the landing milestone(s).
- `README.md` carries an implementation-status quote block whose date matches `implementation.date`.
- `## Deviations from Design` in `README.md` lists every deliberate divergence (or says "None").
