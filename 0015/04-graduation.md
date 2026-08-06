# Graduation Criteria — Catalog Contracts, Provider Classes, and Transformer Registration

This document records the gates that must hold before the enhancement advances along the design lifecycle. Treat these as design acceptance criteria, not implementation milestones — implementation progress lives in `config.yaml.implementation` and the `history` list.

## draft → accepted

- **OQ3 is resolved.** Blocking, and the only one that is. D3 puts part of the effective registry in cluster state, which is in direct tension with 0010 D14's "the platform file is the lockfile". Whether a consumer reproduces a cluster render by exporting `Platform.status.registry`, by a controller writing accepted claims back to git, or by accepting the divergence, changes what `cli` builds and what 0014's export path can promise. Accepting the entry without it accepts a reproducibility regression by omission.
- **OQ2 is resolved** — where the default class is filled in. It determines whether anything in `library/opm/compile` changes, and D2's whole argument is that nothing does.
- **OQ1 is resolved or explicitly deferred to a successor with a written reason.** The duplicate-adapter case is real (measured 2026-08-05: subset containment plus a union match set means two DaemonSets from one component, unguarded), and the three candidate shapes are not equivalent. Deferring is acceptable; leaving it unnamed is not.
- **OQ4 is resolved or deferred.** If transformer-predicate stability gets no rule, the entry must say so, because "additive-only within a major" will otherwise be read as covering a guarantee it does not make.
- **OQ5 and OQ6 may remain open** if each names the entry or slice that inherits it.
- Goals and Non-Goals in `02-design.md` are final and reviewed.
- Every decision D1..DN is locked and carries the four-field format.
- `schemas/target.cue` compiles (`cue vet ./...` from `schemas/` passes) and captures the target shape end-to-end, with every `// OQN:` marker either tightened or pointing at a still-open question.
- `config.yaml.semver` is set. Expected **major**: D1 adds required stamped members to `#Catalog` and D2 adds fields to `#Resource` / `#Trait`, both landing inside 0010's `core@v1` window.
- `related` resolves to `0010` and `0011`.
- **A `plan.yaml` exists.** `affects` spans six areas with a real ordering constraint — `core` before `library` before `opm-operator`, and the catalog listing before any provider catalog — so the `enhancement-slicing` gate applies rather than being optional.
- **The amendment to 0010 D37 is recorded on 0010's side**, not only here. D2 changes an accepted decision in another entry; a reader of 0010 must be able to see that from 0010.
- No `{Capitalised}` placeholder strings remain in any markdown file.
- Cross-References table in `README.md` lists every file path the implementation will touch, and each exists today.

## accepted → implemented

- `core/src/catalog.cue` carries the three contract maps with their stamping constraints; `resource.cue` / `trait.cue` carry `class` and its projection; `platform.cue` carries the class vocabulary. `core/SPEC.md` co-updated per the `core-schema-edit` protocol, §2.1, §2.2, §3.4, §3.6 and §4.1.
- `library/opm/materialize` builds the contract inventory, and the D37 arity guard is rewritten against it — reporting the zero case, which it cannot do today.
- `library/opm/compile/match.go:344-379` is **unchanged**, verified by diff. If it changed, D2's premise failed and the entry needs re-deciding rather than shipping.
- The missed-demand diagnostic distinguishes "defined by a subscribed catalog, unimplemented" from "unknown key", with a test for each arm. 0010 OQ3 closed and marked so in 0010.
- The default-class fill lands wherever OQ2 put it, with a test covering a component that names no class on a platform with two.
- `opm-operator` ships `TransformerRegistration` with claim validation, health-gated activation, the deletion finalizer, and `Platform.status.registry`. RBAC verified from both sides: a tenant ServiceAccount is refused create, a platform-admin one is not — an envtest case, not a manifest review.
- `internal/platform/store.go` keys on the effective-registry digest, with a test that an accepted claim invalidates and an unrelated Platform status write does not.
- `opm platform check` exists and reports unfulfilled contracts and unroutable ones.
- `catalog_opm` lists its resources, traits and blueprints in the new maps, published.
- At least one real provider catalog and its module ship end to end — the k8up path from `01-problem.md`, on a cluster, including the two-class case.
- `config.yaml.implementation.status = complete` with `date`; `history` names each landing; `README.md` carries the implementation-status quote block with a matching date; `## Deviations from Design` lists every divergence or says "None".
