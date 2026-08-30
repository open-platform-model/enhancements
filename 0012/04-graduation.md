# Graduation Criteria: Kubernetes as a First-Class Kernel Platform

These are design acceptance criteria, not implementation milestones. Delivery is logged in this entry's `delivery.yaml` and read back with `task delivery`; the entry's documents store nothing about it.

## draft → accepted

Eleven open questions and six documentation checks gate promotion; every `Blocking: acceptance` question below must resolve, and every `Blocking: deferrable` question must close by decision, not by silent omission.

**Open Questions**

- OQ1 (how far past the render line the kernel goes) and OQ2 (whether the kernel takes a cluster client) are resolved by decisions. Every slice's shape depends on them, so neither may be deferred.
- OQ3 (delete or retain the neutral `core.Resource` / `Identity` contract) is resolved, because it determines `config.yaml.semver`.
- OQ4 (`ownerReferences`) is resolved. It is half this entry's stated scope; deferring it means the entry did not answer what it was opened for.
- OQ5 (`spec.prune` default), OQ6 (holds on CLI-owned instances), OQ7 (stale-set base relation), and OQ8 (apply-time collision guard) are each resolved or explicitly deferred with a named destination. "Deferred" is acceptable here in a way it is not for OQ1–OQ4, but an unowned deferral is what produced 0006's OQ15 and OQ16 and is not acceptable again.
- OQ9 (relationship to 0008) and OQ10 (relationship to 0009) carry an agreed position recorded in both entries, not only in this one. A unilateral answer here is not a resolution.
- OQ11 (label stamping) is resolved or deferred to 0010 with 0010 updated to say so.

**Documentation and schema checks**

Schema and metadata:

- `contracts/contracts.cue` compiles (`cue vet ./...` from `schemas/`) and captures the deletion policy, the verdict enums, the inventory wire shape, the label vocabulary, and the ownerRef eligibility predicate end-to-end, with every `// OQN:` marker either removed or pointing at a still-open question that graduation explicitly allows.
- `config.yaml.semver` is set. It will be `major` if OQ3 lands as a deletion of the neutral contract.
- `config.yaml.affects` is final and lists every repo shipping code.

Prose completeness:

- `03-decisions.md` records every resolution in the four-field format, with `Source` naming a dated user decision, an experiment outcome, or a file path.
- The Cross-References table in `README.md` lists every file path implementation will touch, and each exists today.
- `05-risks.md` and `06-operational.md` carry concrete content, in particular a stated position on the `apimachinery` MVS floor and on the rollback story for a kernel that both frontends pin at the same version.
