# Enhancement 0015 — Catalog Contracts and Transformer Registration

Enhancement 0010 made a contract declared in one catalog fulfillable by a transformer in another (D4) and named that the supported shape (D37). This entry supplies two things that shape needs and does not have: somewhere for a contract to live when nobody implements it, and a way for a provider's installation and its transformer registration to be one act. A third — a way for two providers to coexist — was in scope until 2026-08-20 and is deferred to a successor entry (D2, as revised).

See [`config.yaml`](config.yaml) for the metadata contract — it is the sole source of metadata; no parallel metadata table lives in this README.

## Summary

**A catalog publishes its contracts as members** (D1). `#Catalog` gains `#resources`, `#traits` and `#blueprints` beside `#transformers`, each stamping provenance onto its values the way the transformer map already does. A contract reaches a build only by being demanded by an adapter — measured 2026-08-05 at `materialize/index.go:39-41`, and just as true after 0019 deletes that walk: the platform now embeds each subscribed catalog whole (0019 D5), but every derived value (the composed transformer map, the match glue's buckets) folds over `#transformers` alone — so a contract deliberately left unimplemented, which is exactly what 0010 D37's `fulfilment: "provider"` creates, is invisible. Making it a member turns four derivations into lookups: D37's own zero-provider case, a platform readiness answer available with no module in hand, 0010 OQ3's "unimplemented versus unknown" diagnostic, and 0010 D17's underivable owning catalog. Under 0019 D5 the inventory itself is a pure CUE fold over the platform's embedded catalogs, the same shape as the derived `#composedTransformers`.

**A second provider of one contract stays refused; provider classes are rejected here** (D2, as revised 2026-08-20). 0010 D37's exactly-one-provider rule stands unamended. The class design — StorageClass's shape, carried to matching by 0010 D36's `matchLabels` — was adopted 2026-08-05 and rejected on cost/benefit ahead of any real two-engine requirement: an operator-facing vocabulary, an invisible default re-route, and a default-fill design of its own. It is preserved in D2's alternatives for the successor entry that picks routing up. What this entry keeps is the loud refusal: over-subscription reported at platform assembly by D1's inventory naming both catalog paths, and a second registration refused at acceptance by D3 naming the claimant. A module never names a provider — it declares a contract and nothing else. D5 adds the sibling rule for catalog-fulfilled buckets: comparable predicates in one bucket are refused, not arbitrated (detection per OQ9/OQ10).

**A registration is a cluster-scoped CR, gated by RBAC the operator already enforces** (D3). A provider module ships a `TransformerRegistration` among its rendered resources; only a module applied under a platform-team identity can create one, because `opm-operator` already impersonates a per-tenant ServiceAccount. The CR is a claim the Platform reconciler accepts or rejects, so there stays exactly one writer to the effective set — and because it is an object rather than an event, activation can be gated on the provider being Ready, and deletion refused while consumers depend on it. Acceptance's downstream is 0019 D6's generation step: the operator regenerates the platform package the render build consumes (there is no held materialized platform to invalidate — 0019 D8 deleted it); what triggers and keys that regeneration is OQ8, filed from 0019's OQ9.

**Contracts and adapters stay in one CUE module** (D4). Recorded as a decision rather than left undecided, because a contract FQN embeds its declaring catalog's path: splitting rides 0010's break nearly free and costs a second flag day later. With D1 in place a single catalog can already say "I define these and implement only some of them", which is what the split was wanted for.

**The registration is authored as a `#Resource` contract and every field of the claim is derived or stamped** (D9–D12, 2026-08-21). catalog_opm publishes a `transformer-registration` resource contract and the transformer that renders D3's CR, so registration is self-hosting on the platform's own machinery and `#Module` is unchanged — no authored field, no second emission path, and the RBAC gate keeps its footing (the CR must be rendered output applied under the tenant impersonation). The claim names a published **catalog** artifact only, refused structurally otherwise, and carries no code and no author-trusted data: `catalog`/`version`/`provides` derive from the provider catalog's identity package via the module's own dependency, `providerRef` and the dot-joined instance name are stamped at render, and acceptance verifies `provides` for exact equality against its own re-derivation. The one human decision in the flow is the catalog version in the module's `cue.mod`. Providers wanting one repository publish catalog and module in lockstep; module-hosted transformers wait in D10's alternatives as an additive generalization.

## Documents

1. [01-problem.md](01-problem.md) — the three gaps, measured 2026-08-05 against `core/src/catalog.cue`, `materialize/index.go` and `compile/match.go` (pre-0019 anchors, kept dated) and restated against 0019's single-build pipeline
2. [02-design.md](02-design.md) — contract member maps, the one-provider rule and its refusal sites, the registration CR, and the packaging decision
3. [03-decisions.md](03-decisions.md) — D1..D15 + Open Questions OQ1..OQ12
4. [04-graduation.md](04-graduation.md) — per-status gates (draft → accepted → implemented)
5. [05-risks.md](05-risks.md) — risks, drawbacks, high-level alternatives
6. [06-operational.md](06-operational.md) — operational concerns (PRR-lite)

Pure-CUE schema definitions live in [`schemas/`](schemas/) (the core delta) and [`contracts/`](contracts/) (the D9–D12 authoring surface: catalog-side contract, derivation, stamps, acceptance checks) as compilable files, never as fenced blocks inside markdown.

## Scope

### In scope

- `#Catalog` gains `#resources`, `#traits`, `#blueprints` with provenance-stamping pattern constraints (D1).
- The contract inventory derived from them — under 0019 D5 a pure fold over the platform's embedded catalogs — and the platform readiness answer it enables.
- The missed-demand diagnostic distinguishing "defined but unimplemented" from "unknown key" — 0010 OQ3, closable once the inventory exists.
- Keeping 0010 D37's exactly-one-provider rule, with better refusal sites: over-subscription reported by the inventory at platform assembly naming both paths, and refused at registration acceptance naming the claimant (D2, as revised).
- D5's hard guard on comparable predicates within one catalog-fulfilled bucket (detection shape OQ9, site OQ10).
- A cluster-scoped `TransformerRegistration` CR with claim/accept, health-gated activation, and a deletion finalizer (D3).
- The registration's authoring surface (D9): the `transformer-registration` `#Resource` contract and rendering transformer in catalog_opm; `#Module` unchanged.
- Catalog-only claim coordinates with structural refusal of other artifact kinds, and the no-code-on-the-CR rule (D10); the lockstep two-artifact provider release flow.
- Full derivation and stamping of the claim (D11) — identity-package interpolation, `provides` fold, `providerRef` and instance-derived CR naming (D12) — with exact-equality verification at acceptance.
- `Platform.status.registry` as the effective set, and the identity of the platform package the operator regenerates from it (OQ8 — the store key this bullet used to name was deleted with the store by 0019 D8).
- `opm platform check` — the pre-flight the inventory makes possible.

### Out of scope

- **Splitting contracts and adapters into separate CUE modules** — decided against in D4, deliberately and now.
- **Transformers shipped inside module artifacts, or riding the CR** — decided against in D10; the additive generalization (an optional `package` coordinate plus publish-gate coverage) waits in D10's alternatives.
- **Provider routing of any kind — classes included.** Adopted 2026-08-05, rejected 2026-08-20 (D2, as revised); the class design waits in D2's alternatives for a successor entry with a real two-engine instance.
- **Refinement / override semantics in the matcher** ("most specific predicate wins"). OQ1 resolved by D5's guard instead: comparable predicates refuse, never order. Successor material.
- **Capability-based routing** — a module declaring RPO or retention and the platform routing on it. The likely shape of the successor routing entry.
- **Contract promotion between catalogs** (experimental → stable) and the FQN flag day it implies. Carried as OQ5, likely its own entry.
- **What identity is** (0010) and **how artifacts are published** (0011). This entry adds members to `#Catalog` and reads keys those entries define.
- **Namespace-scoped registration.** Rejected in D3's alternatives; revisit only if a genuinely tenant-scoped adapter appears.

## Deviations from Design

None at this stage. Update when implementation lands.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `enhancements/0010/` | Defines the contract/implementation key split (D4), `fulfilment` and the one-provider rule this entry keeps (D37), scalar subscriptions (D14), and the underivable-owning-catalog limitation (D17) |
| `enhancements/0011/` | The publish-side gates; D9's compatibility gate is the shape OQ4 would extend to transformer predicates |
| `enhancements/0019/` | The single-build render pipeline this entry is baselined on (accepted 2026-08-20): D5 embedded catalogs, D6 the operator-generated platform package (OQ8's surface), D8 no held platform, D10 the in-build match glue, D17 `#matchers` removed; its OQ9 and OQ10's refusal half are filed here as OQ8 and OQ7 |
| `enhancements/0019/experiments/05-match-in-one-build/matchdef/match.cue` | The match glue's measured shape — the rungs D5's guard must not change |
| `core/src/catalog.cue` | `#Catalog`'s single `#transformers` map and the pattern constraint D1 replicates for contracts |
| `core/src/platform.cue` | Where the inventory fold and `#ContractRouting` assertion land, beside `#registry` |
| `core/SPEC.md` | Normative co-update — §3.4, §3.6, §4.1 |
| `library/opm/materialize/index.go` | The measured pre-0019 skip (`:39-41`) that made a contract-only catalog a no-op; deleted by 0019 D5 — the platform's own imports replace pull-plus-index |
| `library/opm/compile/match.go` | The measured pre-0019 matcher (`:138-157` candidate loop, `:344-379` predicate); 0019 D10 moves it into the render build's glue with the same pair set — D2 rides its rungs unchanged either way |
| `library/opm/materialize/types.go` | Where the inventory would have landed pre-0019; deleted with materialize — the inventory becomes a core-derived fold instead |
| `opm-operator/api/v1alpha1/platform_types.go` | `PlatformStatus` gains the effective registry and the readiness condition |
| `opm-operator/internal/platform/store.go` | The held slot 0019 D8 deletes; its re-key question became OQ8's platform-package regeneration identity |
| `opm-operator/internal/controller/platform_controller.go` | Claim validation and acceptance |
| `opm-operator/openspec/changes/archive/2026-04-20-default-sa-and-tenancy-guide/design.md` | The per-tenant ServiceAccount model D3's RBAC gate rests on (the shipped tenancy design; `docs/TENANCY.md` no longer exists) |
| `catalog_opm/src/catalog.cue` | First catalog to list its contracts in the new maps; also gains D9's registration pair (`src/resources/` contract + `src/transformers/` renderer) |
| `CONSTITUTION.md` (per target repo) | Core design principles governing changes in each touched repo |
