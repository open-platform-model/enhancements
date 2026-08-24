# Graduation Criteria — Export a Deployed Instance as GitOps Manifests

This document records the entry-specific gates that must hold before this design is frozen. These are design acceptance criteria, not implementation milestones — delivery is derived from this entry's `delivery.yaml` log and read back with `task delivery`; the entry's documents store nothing about it.

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
