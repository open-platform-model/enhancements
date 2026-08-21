# Graduation Criteria — Catalog Contracts and Transformer Registration

This document records the gates that must hold before the enhancement advances along the design lifecycle. Treat these as design acceptance criteria, not implementation milestones — implementation progress lives in `config.yaml.implementation` and the `history` list.

## draft → accepted

- **OQ3 is resolved.** Blocking, and the only one that is. D3 puts part of the effective registry in cluster state, which is in direct tension with 0010 D14's "the platform file is the lockfile". Whether a consumer reproduces a cluster render by exporting `Platform.status.registry`, by a controller writing accepted claims back to git, or by accepting the divergence, changes what `cli` builds and what 0014's export path can promise. Accepting the entry without it accepts a reproducibility regression by omission.
- **OQ9's deferral stands as written.** The guard's site is decided (platform-package generation, D5 resolving OQ10); OQ9 is deferred to the implementation slice with the measured candidate definition attached, and the slice must re-validate its adopted definition against the shipped 8-transformer bucket. (OQ1 is resolved-by-D5; OQ2 dissolved with the class rejection, resolved-by-D2.)
- **OQ4 is resolved or deferred.** If transformer-predicate stability gets no rule, the entry must say so, because "additive-only within a major" will otherwise be read as covering a guarantee it does not make.
- **OQ5 may remain open** if it names the entry that inherits it. OQ6 is answered — overtaken by 0019 D8; its blast-radius residue lives in OQ8.
- **OQ7 and OQ8 are resolved or explicitly deferred with a written reason.** Both were filed from 0019's OQ walk (its OQ10's refusal half and its OQ9). OQ7 in particular was deferred here because it needs experiments rather than argument, so resolving it likely means a concluded experiment under `experiments/`; OQ8 decides what the operator slice actually builds, so deferring it past acceptance would leave the D3 integration surface unspecified.
- Goals and Non-Goals in `02-design.md` are final and reviewed.
- Every decision D1..DN is locked and carries the four-field format.
- `schemas/target.cue` compiles (`cue vet ./...` from `schemas/` passes) and captures the target shape end-to-end, with every `// OQN:` marker either tightened or pointing at a still-open question.
- `config.yaml.semver` is set. Expected **major**: D1 adds required stamped members to `#Catalog`, landing inside 0010's core major window.
- `related` resolves to `0010`, `0011` and `0019`.
- **A delivery plan exists.** `affects` spans six areas with a real ordering constraint — `core` before `library` before `opm-operator`, and the catalog listing before any provider catalog — so a structured delivery plan (see `plans/`) is required rather than optional.
- No `{Capitalised}` placeholder strings remain in any markdown file.
- Cross-References table in `README.md` lists every file path the implementation will touch, and each exists today.

## accepted → implemented

- `core/src/catalog.cue` carries the three contract maps with their stamping constraints; `platform.cue` carries the inventory fold and the `#ContractRouting` assertion. `core/SPEC.md` co-updated per the `core-schema-edit` protocol, §3.4, §3.6 and §4.1.
- The contract inventory is derived on the platform value (the fold 0019 D5 makes possible), and the D37 arity guard is rewritten as the `#ContractRouting` assertion against it — refusing at platform-package generation and reporting the zero case, which the pre-0019 guard could not.
- The render build's match glue is **unchanged** by this entry — no new rung, no reordering; D5's guard asserts at platform assembly. Verified by diff against the glue as 0019's `library-match-in-build` slice landed it.
- The missed-demand diagnostic distinguishes "defined by a subscribed catalog, unimplemented" from "unknown key" — a verdict-data split in the render build's diagnostics under 0019 D10 — with a test for each arm. 0010 OQ3 closed and marked so in 0010.
- D5's duplicate guard lands wherever OQ9/OQ10 put it, with a test that comparable predicates refuse naming both FQNs and that the shipped 8-transformer `#ContainerResource` bucket still composes.
- `opm-operator` ships `TransformerRegistration` with claim validation, health-gated activation (latching, per D3), the deletion finalizer, and `Platform.status.registry`. RBAC verified from both sides: a tenant ServiceAccount is refused create, a platform-admin one is not — an envtest case, not a manifest review.
- D16's shrink guard lands at the site the slice picks, with a test that a provider upgrade whose re-derived `provides` drops a contract with dependent instances is refused while the previously accepted claim stays effective, naming the dropped contracts and the count — and that an upgrade with an unchanged `provides` passes.
- The slice decides D11's deferred `providerRef` verification (candidate: 0010 D41 owner-label match) and covers the hand-applied-stray arm in the same envtest family as the RBAC checks.
- Platform-package regeneration lands wherever OQ8 put it, with a test that an accepted claim regenerates the package (and re-renders) and an unrelated Platform status write does not.
- `opm platform check` exists and reports unfulfilled contracts and over-subscribed ones.
- `catalog_opm` lists its resources, traits and blueprints in the new maps, published.
- At least one real provider catalog and its module ship end to end — the k8up path from `01-problem.md`, on a cluster, including a second registration for the same contract being refused at acceptance.
- `config.yaml.implementation.status = complete` with `date`; `history` names each landing; `README.md` carries the implementation-status quote block with a matching date; `## Deviations from Design` lists every divergence or says "None".
