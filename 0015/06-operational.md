# Operational Concerns — Catalog Contracts and Transformer Registration

This document is the OPM Production Readiness Review (PRR-lite). Five fixed prompts — answer every one, even briefly.

## Observability

Three new surfaces, and the first is the point of the entry.

**Platform-level contract readiness.** `Platform.status` gains the contract inventory's two reports — `unfulfilled` (a provider-fulfilled contract defined by a subscribed catalog that no adapter implements) and `overSubscribed` (a provider-fulfilled contract with more than one implementation, refused per 0010 D37, kept by D2) — surfaced as a `Ready=False` reason. Both are computable on the platform value with no module in hand — under 0019 D5 as a fold over the embedded catalogs, evaluated at platform-package generation (0019 D6) — which is the whole of what D1 buys operationally: the answer moves from "the first team to deploy finds out" to "the platform says so".

**A sharper missed-demand diagnostic.** The pre-0019 matcher emitted `no matching transformer` for every miss (`compile/match.go:130`, measured 2026-08-05); under 0019 D10 an unresolved demand is already a verdict row in the render build's diagnostics data. With the inventory that row separates two cases that need different actions: *defined by a subscribed catalog and unimplemented* (the platform is missing a provider) versus *unknown key* (the module demands something no subscribed catalog defines). This closes 0010 OQ3, which was left open there because the derivation it needed was unreliable.

**Registration status.** `TransformerRegistration.status` carries `accepted`, `active`, `reason` and `dependentInstances`. The four together answer the questions an operator actually asks — why was my claim refused, why is it accepted but not live, and what breaks if I delete it. A refused claim names the failing check (catalog unresolvable, contract not defined by any subscribed catalog, contract already provided); an inactive one names the ModulePackage it is waiting on.

New diagnostics: the `unfulfilled` and `overSubscribed` reports at platform-package generation (0010 D37's two-provider refusal, now able to name both catalog paths), D5's comparable-predicate refusal (site per OQ10), and a registration-rejection reason enum on the CR.

## Semver Impact

**Breaking, `major`, and it must land inside 0010's `core@v1` window.**

- **core** — `#Catalog` gains three member maps whose pattern constraints stamp `modulePath` and `catalogVersion`; `#Platform` gains the inventory fold and the `#ContractRouting` assertion. The maps are additive in the sense that no existing value changes meaning, but a catalog that does not populate them produces an empty inventory and therefore an unhelpful readiness answer — so in practice every catalog must be republished, which is a break in effect if not in schema.
- **library** — re-baselined: the surfaces this entry originally extended (`MaterializedPlatform`, `indexCatalogs`) are deleted by 0019, so the library delta shrinks to reading the inventory and routing verdicts off built values, the OQ2 default fill, and OQ8's regeneration hooks. Go-major only if a public kernel surface moves; which surfaces exist to move depends on where 0019's slices leave the kernel.
- **opm-operator** — a new CRD and a `PlatformStatus` addition. Additive to the API, but the first reconcile after upgrade regenerates the platform package and re-renders everything — and every claim change does the same (OQ8).
- **cli** — additive (`opm platform check`), plus whatever OQ3 requires for effective-registry retrieval.

The ordering constraint that matters: **the whole entry extends 0019's pipeline:** the inventory fold needs D5's embedded catalogs (`core-registry-import`), the routing rungs need the match glue (`library-match-in-build`), and D3's acceptance flow needs the generation step (`opm-operator-platform-generation`), so this entry cannot ship ahead of those slices either.

## Deprecation

- **Nothing is deprecated in 0010.** D37's exactly-one-provider rule stands unamended (D2, as revised 2026-08-20); what changes is where its refusal is computed and how much it can name.
- **The stub-transformer workaround** — publishing a no-op adapter so a contract reaches the index — is retired by D1. No shipped catalog uses it today; it is named so the pattern does not reappear.
- **`platform.Store` itself** is deleted by 0019 D8 (`opm-operator-store-removal`), not by this entry — so nothing here re-keys it. The effective-registry digest this entry once aimed at the store survives as the regenerated platform package's identity (OQ8).

Nothing is removed from `core` by this entry.

## Rollback

**Schema-side: not rollback-safe within a release, by construction.** Once `catalog_opm` is republished with populated contract maps, a kernel that predates D1 ignores them — which is harmless, since a build that skips unknown fields degrades to today's behaviour. The reverse is not true: a kernel expecting the inventory against a catalog published without one computes an empty `defined` set and reports every provider-fulfilled contract as unfulfilled. So the safe rollback direction is **kernel first, catalogs second on the way forward; catalogs stay put on the way back**.

**Registration-side: rollback is clean, because the CR is additive.** Reverting the operator leaves `TransformerRegistration` objects orphaned but inert — a Platform without the reconciler simply generates its platform package from `spec.registry` alone, which is the 0019-baseline behaviour. Any catalog that was reachable only via a claim becomes unreachable, and modules depending on it fail to render; that is loud, not silent. The finalizer is the one hazard: a reverted operator cannot clear finalizers it no longer understands, so the rollback runbook must include removing them.

**Data-plane state survives a code rollback.** Resources rendered by a provider's transformer stay applied and stay owned — the owner label derives from instance identity (0010 D41), not from which transformer produced the resource. Rolling back does not orphan them; it makes the next reconcile of their instance fail until the provider is reachable again.

## Cross-Repo Coordination

Six areas, with a genuine ordering constraint rather than a convention, which is why `04-graduation.md` makes a `plan.yaml` a gate for acceptance rather than a suggestion.

```
  0019 core-registry-import ·      (embedded catalogs, match glue, generated platform
       library-match-in-build ·     package — the pipeline this entry extends)
       opm-operator-platform-generation
            │
            ▼
  core      contract maps + inventory fold + routing assertion + SPEC.md
            │
            ▼
  library   read inventory/verdicts off built values · sharper diagnostic · duplicate guard (OQ9/OQ10)
            │
            ├──────────────▶ catalog   catalog_opm lists its contracts, republished
            │                              │
            ▼                              ▼
  opm-operator  CRD · acceptance · package regeneration (OQ8)      catalog_k8up + module (the proof)
            │
            ▼
  cli       opm platform check · effective-registry retrieval (shape per OQ3)
```

Each hand-off produces something concrete the next consumes: `core` publishes a build carrying the new shapes, the inventory fold and the routing assertion; `library` publishes a kernel that surfaces them through the render build's diagnostics and the generation step; `catalog_opm` publishes a build whose contract maps are populated, which is what makes the readiness answer non-trivial; `opm-operator` consumes both and adds the CRD. The `cli` slice depends on OQ3's resolution rather than on code, so it can be planned but not written until that question closes.

The two catalog slices are `migration` phase, not `implementation` — they push bytes rather than define a system, and under the slicing rules that ordering is enforced as an edge rule. The provider-catalog slice is deliberately last: it is the end-to-end proof that the k8up path from `01-problem.md` works on a cluster, including a second registration being refused at acceptance, and it is worth nothing if it runs before the pieces it exercises exist.
