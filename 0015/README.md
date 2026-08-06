# Enhancement 0015 — Catalog Contracts, Provider Classes, and Transformer Registration

Enhancement 0010 made a contract declared in one catalog fulfillable by a transformer in another (D4) and named that the supported shape (D37). This entry supplies the three things that shape needs and does not have: somewhere for a contract to live when nobody implements it, a way for two providers to coexist, and a way for a provider's installation and its transformer registration to be one act.

See [`config.yaml`](config.yaml) for the metadata contract — it is the sole source of metadata; no parallel metadata table lives in this README.

## Summary

**A catalog publishes its contracts as members** (D1). `#Catalog` gains `#resources`, `#traits` and `#blueprints` beside `#transformers`, each stamping provenance onto its values the way the transformer map already does. Today a contract reaches the kernel only by being demanded by an adapter — `materialize/index.go:39-41` walks `#transformers` and skips a build that has none — so a contract deliberately left unimplemented, which is exactly what 0010 D37's `fulfilment: "provider"` creates, is invisible. Making it a member turns four derivations into lookups: D37's own zero-provider case, a platform readiness answer available with no module in hand, 0010 OQ3's "unimplemented versus unknown" diagnostic, and 0010 D17's underivable owning catalog.

**Two providers of one contract are routed by class, not refused** (D2, amending 0010 D37). A class is a platform-published vocabulary with one default per contract — StorageClass's shape, four times validated in Kubernetes. The mechanism costs no matcher change: 0010 D36 already unifies `matchLabels` upward from a primitive to its component and points `requiredLabels` at that field, so `class: "archive"` becomes a label that exactly one transformer's predicate can satisfy. `compile/match.go:344-360` is untouched, and that is load-bearing. A module never names a provider — it names a class or it names nothing.

**A registration is a cluster-scoped CR, gated by RBAC the operator already enforces** (D3). A provider module ships a `TransformerRegistration` among its rendered resources; only a module applied under a platform-team identity can create one, because `opm-operator` already impersonates a per-tenant ServiceAccount. The CR is a claim the Platform reconciler accepts or rejects, so there stays exactly one writer to the materialized set — and because it is an object rather than an event, activation can be gated on the provider being Ready, and deletion refused while consumers depend on it.

**Contracts and adapters stay in one CUE module** (D4). Recorded as a decision rather than left undecided, because a contract FQN embeds its declaring catalog's path: splitting rides 0010's break nearly free and costs a second flag day later. With D1 in place a single catalog can already say "I define these and implement only some of them", which is what the split was wanted for.

## Documents

1. [01-problem.md](01-problem.md) — the three gaps, measured against `core/src/catalog.cue`, `materialize/index.go` and `compile/match.go`
2. [02-design.md](02-design.md) — contract member maps, class routing, the registration CR, and the packaging decision
3. [03-decisions.md](03-decisions.md) — D1..D4 + Open Questions OQ1..OQ6
4. [04-graduation.md](04-graduation.md) — per-status gates (draft → accepted → implemented)
5. [05-risks.md](05-risks.md) — risks, drawbacks, high-level alternatives
6. [06-operational.md](06-operational.md) — operational concerns (PRR-lite)

Pure-CUE schema definitions live in [`schemas/`](schemas/) as compilable files, never as fenced blocks inside markdown.

## Scope

### In scope

- `#Catalog` gains `#resources`, `#traits`, `#blueprints` with provenance-stamping pattern constraints (D1).
- The contract inventory materialize computes from them, and the platform readiness answer it enables.
- The missed-demand diagnostic distinguishing "defined but unimplemented" from "unknown key" — 0010 OQ3, closable once the inventory exists.
- Provider classes: the platform-side vocabulary, the optional `class` on a provider-fulfilled contract, and the `matchLabels` projection that carries it (D2).
- Amending 0010 D37's exactly-one-provider rule to at-most-one-per-class.
- A cluster-scoped `TransformerRegistration` CR with claim/accept, health-gated activation, and a deletion finalizer (D3).
- `Platform.status.registry` as the effective set, and the store key that replaces `.metadata.generation` alone.
- `opm platform check` — the pre-flight the inventory makes possible.

### Out of scope

- **Splitting contracts and adapters into separate CUE modules** — decided against in D4, deliberately and now.
- **Refinement / override semantics in the matcher** ("most specific predicate wins"). Carried as OQ1; it puts ordering into a matcher that has deliberately had none since 0001.
- **Capability-based routing** — a module declaring RPO or retention and the platform routing on it. Classes degenerate to it cleanly; it is a successor entry.
- **Contract promotion between catalogs** (experimental → stable) and the FQN flag day it implies. Carried as OQ5, likely its own entry.
- **What identity is** (0010) and **how artifacts are published** (0011). This entry adds members to `#Catalog` and reads keys those entries define.
- **Namespace-scoped registration.** Rejected in D3's alternatives; revisit only if a genuinely tenant-scoped adapter appears.

## Deviations from Design

None at this stage. Update when implementation lands.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `enhancements/0010/` | Defines the contract/implementation key split (D4), `fulfilment` and the one-provider rule this entry amends (D37), `matchLabels` (D36), scalar subscriptions (D14), and the underivable-owning-catalog limitation (D17) |
| `enhancements/0011/` | The publish-side gates; D9's compatibility gate is the shape OQ4 would extend to transformer predicates |
| `core/src/catalog.cue` | `#Catalog`'s single `#transformers` map and the pattern constraint D1 replicates for contracts |
| `core/src/resource.cue`, `core/src/trait.cue` | Where `class` and its `matchLabels` projection land |
| `core/src/platform.cue` | Where the class vocabulary sits, beside `#registry` |
| `core/SPEC.md` | Normative co-update — §2.1, §2.2, §3.4, §3.6, §4.1 |
| `library/opm/materialize/index.go` | `indexCatalogs`; `:39-41` is the skip that makes a contract-only catalog a no-op today |
| `library/opm/compile/match.go` | `:138-157` candidate loop, `:344-379` `candidateSatisfied`/`fqnSubset` — unchanged by D2, and load-bearing that it is |
| `library/opm/materialize/types.go` | `MaterializedPlatform` gains the inventory and the vocabulary |
| `opm-operator/api/v1alpha1/platform_types.go` | `PlatformStatus` gains the effective registry and the readiness condition |
| `opm-operator/internal/platform/store.go` | The single slot keyed on `.metadata.generation`, which D3 must re-key |
| `opm-operator/internal/controller/platform_controller.go` | Claim validation and acceptance |
| `opm-operator/docs/TENANCY.md` | The per-tenant ServiceAccount model D3's RBAC gate rests on |
| `catalog_opm/src/catalog.cue` | First catalog to list its contracts in the new maps |
| `CONSTITUTION.md` (per target repo) | Core design principles governing changes in each touched repo |
