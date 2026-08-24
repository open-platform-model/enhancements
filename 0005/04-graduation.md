# Graduation Criteria — Kubernetes-Native Refocus: Generated Mirror and Composed Abstractions

This document records the entry-specific gates that must hold before this design is frozen. Treat these as design acceptance criteria, not implementation milestones — delivery is derived from this entry's `delivery.yaml` log and read back with `task delivery`; the entry's documents store nothing about it.

## draft → accepted

The design is ready to be sliced for implementation when:

- Design Goals and Non-Goals in `02-design.md` are final and reviewed.
- Every Open Question in `03-decisions.md` is resolved (`resolved-by-D##`, `deferred-to-NNNN`, or `answered`) — in particular OQ1 (projection shape), OQ2 (generator home/language), OQ3 (version axis), and OQ5 (trapdoor semantics), which gate the construction roadmap.
- `contracts/contracts.cue` compiles (`cue vet ./...`) and captures the generation manifest, lifecycle metadata, and trapdoor shapes end-to-end.
- `config.yaml.semver` is set; the cross-cutting impact on each entry in `affects` is understood.
- `config.yaml` cross-refs (`related`, `supersedes`, `superseded_by`) are final and resolve.
- No `{Capitalised}` placeholder strings remain in any markdown file.
- The Cross-References table in `README.md` lists every file path the implementation will touch, and each exists today.
