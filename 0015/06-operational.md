# Operational Concerns — Catalog Contracts, Provider Classes, and Transformer Registration

This document is the OPM Production Readiness Review (PRR-lite). Five fixed prompts — answer every one, even briefly.

## Observability

Three new surfaces, and the first is the point of the entry.

**Platform-level contract readiness.** `Platform.status` gains the contract inventory's two reports — `unfulfilled` (a provider-fulfilled contract defined by a subscribed catalog that no adapter implements) and `unroutable` (a contract with more implementations than the class vocabulary routes) — surfaced as a `Ready=False` reason. Both are computable at materialize with no module in hand, which is the whole of what D1 buys operationally: the answer moves from "the first team to deploy finds out" to "the platform says so".

**A sharper missed-demand diagnostic.** `library/opm/compile/match.go:130` today emits `no matching transformer` for every miss. With the inventory it separates two cases that need different actions: *defined by a subscribed catalog and unimplemented* (the platform is missing a provider) versus *unknown key* (the module demands something no subscribed catalog defines). This closes 0010 OQ3, which was left open there because the derivation it needed was unreliable.

**Registration status.** `TransformerRegistration.status` carries `accepted`, `active`, `reason` and `dependentInstances`. The four together answer the questions an operator actually asks — why was my claim refused, why is it accepted but not live, and what breaks if I delete it. A refused claim names the failing check (catalog unresolvable, contract not defined by any subscribed catalog, class already taken); an inactive one names the ModulePackage it is waiting on.

New error kinds: a `MaterializeError` variant for an unroutable contract (replacing 0010 D37's two-provider refusal), and a registration-rejection reason enum on the CR.

## Semver Impact

**Breaking, `major`, and it must land inside 0010's `core@v1` window.**

- **core** — `#Catalog` gains three member maps whose pattern constraints stamp `modulePath` and `catalogVersion`; `#Resource` and `#Trait` gain `class`; `#Platform` gains the class vocabulary. The maps are additive in the sense that no existing value changes meaning, but a catalog that does not populate them produces an empty inventory and therefore an unhelpful readiness answer — so in practice every catalog must be republished, which is a break in effect if not in schema.
- **library** — `MaterializedPlatform` gains fields; `indexCatalogs` changes signature. Go-major for embedders.
- **opm-operator** — a new CRD and a `PlatformStatus` addition. Additive to the API, but the store key change means the first reconcile after upgrade re-materializes and re-renders everything.
- **cli** — additive (`opm platform check`), plus whatever OQ3 requires for effective-registry retrieval.

The ordering constraint that matters: **D2 depends on 0010 D36 having landed.** Classes are carried by `matchLabels`, and without D36 there is no field to carry them. This entry cannot ship ahead of 0010's `core-platform-and-match` slice.

## Deprecation

- **0010 D37's exactly-one-provider rule** is replaced by at-most-one-per-class (D2). Since 0010 is `accepted` and `not-started`, nothing is deprecated in code — the rule is amended before it ships. The amendment must be recorded on 0010's side as well as here.
- **The stub-transformer workaround** — publishing a no-op adapter so a contract reaches the index — is retired by D1. No shipped catalog uses it today; it is named so the pattern does not reappear.
- **`platform.Store`'s generation-only key** (`opm-operator/internal/platform/store.go`) is replaced by the effective-registry digest. Same release.

Nothing is removed from `core` by this entry.

## Rollback

**Schema-side: not rollback-safe within a release, by construction.** Once `catalog_opm` is republished with populated contract maps, a kernel that predates D1 ignores them — which is harmless, since a build that skips unknown fields degrades to today's behaviour. The reverse is not true: a kernel expecting the inventory against a catalog published without one computes an empty `defined` set and reports every provider-fulfilled contract as unfulfilled. So the safe rollback direction is **kernel first, catalogs second on the way forward; catalogs stay put on the way back**.

**Registration-side: rollback is clean, because the CR is additive.** Reverting the operator leaves `TransformerRegistration` objects orphaned but inert — a Platform without the reconciler simply materializes from `spec.registry` alone, which is today's behaviour. Any catalog that was reachable only via a claim becomes unreachable, and modules depending on it fail to render; that is loud, not silent. The finalizer is the one hazard: a reverted operator cannot clear finalizers it no longer understands, so the rollback runbook must include removing them.

**Data-plane state survives a code rollback.** Resources rendered by a provider's transformer stay applied and stay owned — the owner label derives from instance identity (0010 D41), not from which transformer produced the resource. Rolling back does not orphan them; it makes the next reconcile of their instance fail until the provider is reachable again.

## Cross-Repo Coordination

Six areas, with a genuine ordering constraint rather than a convention, which is why `04-graduation.md` makes a `plan.yaml` a gate for acceptance rather than a suggestion.

```
  0010 core-platform-and-match      (matchLabels — D2 has nothing to ride without it)
            │
            ▼
  core      contract maps + class + vocabulary + SPEC.md
            │
            ▼
  library   inventory · rewritten arity guard · sharper diagnostic · default-class fill
            │
            ├──────────────▶ catalog   catalog_opm lists its contracts, republished
            │                              │
            ▼                              ▼
  opm-operator  CRD · acceptance · store re-key      catalog_k8up + module (the proof)
            │
            ▼
  cli       opm platform check · effective-registry retrieval (shape per OQ3)
```

Each hand-off produces something concrete the next consumes: `core` publishes a `@v1` build carrying the new shapes; `library` publishes a Go module whose `MaterializedPlatform` exposes the inventory; `catalog_opm` publishes a build whose contract maps are populated, which is what makes `library`'s readiness answer non-trivial; `opm-operator` consumes both and adds the CRD. The `cli` slice depends on OQ3's resolution rather than on code, so it can be planned but not written until that question closes.

The two catalog slices are `migration` phase, not `implementation` — they push bytes rather than define a system, and under the slicing rules that ordering is enforced as an edge rule. The provider-catalog slice is deliberately last: it is the end-to-end proof that the k8up path from `01-problem.md` works on a cluster, including the two-class case, and it is worth nothing if it runs before the pieces it exercises exist.
