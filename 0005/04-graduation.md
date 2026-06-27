# Graduation Criteria — Kubernetes-Native Refocus: Generated Mirror and Composed Abstractions

This document records the gates that must hold before the enhancement advances along the design lifecycle. Treat these as design acceptance criteria, not implementation milestones — implementation progress lives in `config.yaml.implementation` and the `history` list.

## draft → accepted

The design is ready to be sliced for implementation when:

- Design Goals and Non-Goals in `02-design.md` are final and reviewed.
- Every Open Question in `03-decisions.md` is resolved (`resolved-by-D##`, `deferred-to-NNNN`, or `answered`) — in particular OQ1 (projection shape), OQ2 (generator home/language), OQ3 (version axis), and OQ5 (trapdoor semantics), which gate the construction roadmap.
- `schemas/target.cue` compiles (`cue vet ./...`) and captures the generation manifest, lifecycle metadata, and trapdoor shapes end-to-end.
- `config.yaml.semver` is set; the cross-cutting impact on each entry in `affects` is understood.
- `config.yaml` cross-refs (`related`, `supersedes`, `superseded_by`) are final and resolve.
- No `{Capitalised}` placeholder strings remain in any markdown file.
- The Cross-References table in `README.md` lists every file path the implementation will touch, and each exists today.

## accepted → implemented

The enhancement is shipped when:

- The generator exists and reproducibly emits both projections from a pinned Kubernetes minor's OpenAPI and from at least one CRD bundle.
- `catalog_kubernetes` is regenerated output (open projection), with the `#Objects` hatch retained, and its publish flow runs the generator.
- `catalog_opm` consumes the shared strict types (independently-vendored types dropped) and exposes the trapdoor/override field on its blueprints.
- Each generated resource carries lifecycle metadata; `library` reads `applyPhase` (replacing the hardcoded `resourceorder` list) and exposes readiness/prune metadata.
- `opm-operator` reconciles using the lifecycle metadata (ordering, readiness reporting, pruning via ownerReferences + SSA), with test coverage on the new paths.
- At least one provider golden-path composition example exists and validates end-to-end.
- `opmodel.dev` documents the generation workflow and the composition pattern.
- `config.yaml.implementation.status = complete` with `date` set; `history` names each landing milestone; `README.md` carries the implementation-status quote block and a `## Deviations from Design` section.
