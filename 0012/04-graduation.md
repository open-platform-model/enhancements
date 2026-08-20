# Graduation Criteria — Kubernetes as a First-Class Kernel Platform

These are design acceptance criteria, not implementation milestones. Implementation progress lives in `config.yaml.implementation` and the `history` list.

## draft → accepted

- OQ1 (how far past the render line the kernel goes) and OQ2 (whether the kernel takes a cluster client) are resolved by decisions. Every slice's shape depends on them, so neither may be deferred.
- OQ3 (delete or retain the neutral `core.Resource` / `Identity` contract) is resolved, because it determines `config.yaml.semver`.
- OQ4 (`ownerReferences`) is resolved. It is half this entry's stated scope; deferring it means the entry did not answer what it was opened for.
- OQ5 (`spec.prune` default), OQ6 (holds on CLI-owned instances), OQ7 (stale-set base relation), and OQ8 (apply-time collision guard) are each resolved or explicitly deferred with a named destination. "Deferred" is acceptable here in a way it is not for OQ1–OQ4, but an unowned deferral is what produced 0006's OQ15 and OQ16 and is not acceptable again.
- OQ9 (relationship to 0008) and OQ10 (relationship to 0009) carry an agreed position recorded in both entries, not only in this one. A unilateral answer here is not a resolution.
- OQ11 (label stamping) is resolved or deferred to 0010 with 0010 updated to say so.
- `03-decisions.md` records every resolution in the four-field format, with `Source` naming a dated user decision, an experiment outcome, or a file path.
- `contracts/contracts.cue` compiles (`cue vet ./...` from `schemas/`) and captures the deletion policy, the verdict enums, the inventory wire shape, the label vocabulary, and the ownerRef eligibility predicate end-to-end, with every `// OQN:` marker either removed or pointing at a still-open question that graduation explicitly allows.
- `config.yaml.semver` is set. It will be `major` if OQ3 lands as a deletion of the neutral contract.
- `config.yaml.affects` is final and lists every repo shipping code.
- The Cross-References table in `README.md` lists every file path implementation will touch, and each exists today.
- `05-risks.md` and `06-operational.md` carry concrete content, in particular a stated position on the `apimachinery` MVS floor and on the rollback story for a kernel that both frontends pin at the same version.

## accepted → implemented

- Every duplicated artefact named in `02-design.md ## Integration Points` is **deleted** from `cli` and `opm-operator`, not aliased or wrapped: `pkg/core/{labels,resource,convert}.go`, `pkg/resourceorder/`, the operator's `internal/inventory/`, the CLI's `pkg/inventory/`, and the CLI's `ComputeRenderDigest` with its hand-maintained parity comment.
- The three divergences from `01-problem.md` are closed and each has a regression test in the kernel: the CLI no longer deletes `CustomResourceDefinition`s, the CLI applies the delete-time ownership guard, and the operator applies an apply-time collision guard (subject to OQ8's resolution).
- A conformance test in `library` asserts that a frontend cannot execute a delete that the kernel's plan marked `Skip`. This is the graduation criterion that distinguishes this entry from 0006's OQ15/OQ16 — without it, the design goal "divergence becomes a compile error, not a review comment" has not been met and the entry should not be marked implemented.
- The deletion protocol is kernel-owned end to end: `handleDeletion`'s branching is `MayReleaseHold` calls, and the operator retains only the patch and the impersonation setup.
- OQ4's resolution is realised — either ownerReferences are stamped where the resolution says they are, with the `spec.prune` interaction handled explicitly, or the entry records that none are stamped and why.
- `library/CONSTITUTION.md` is amended for Principle III's package list and Principle IV's runtime-concerns clause, with an ADR under `library/adr/` recording the amendment and its bounds (`apimachinery` only; no `client-go`, `controller-runtime`, or Flux).
- `library/MIGRATIONS.md` carries an entry per breaking change, satisfying the repo's `migration-guard` contract.
- Both frontends build against one published `library` version, and `cli/go.mod` still carries no `opm-operator` edge (0006 D13's surviving clause).
- `config.yaml.implementation.status = complete` with `date` set to the final landing date; `history` names each slice; `README.md` carries the implementation-status quote block with a matching date and a filled `## Deviations from Design`.
