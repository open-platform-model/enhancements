# Design — Catalog Contracts and Transformer Registration

This document answers the question: "What is the proposed solution and how does it work?" Design Goals and Non-Goals together define the boundary; the High-Level Approach should be understandable without deep implementation knowledge. All trade-off reasoning lives in `03-decisions.md`, not here.

## Design Goals

- **A catalog states what it promises, separately from what it implements.** A contract is a member of the catalog artifact whether or not an adapter for it ships in the same artifact.
- **A missing provider is a platform-level answer, available with no module in hand.** "This platform subscribes to a contract nothing implements" is knowable when the platform is assembled, not discovered at render by whoever deploys first.
- **A second provider of one contract is refused loudly, where the failure can be named.** One provider per contract per cluster is the supported state (0010 D37, kept unamended); the refusal names both catalog paths at platform assembly and names the claimant at registration acceptance. Routing between providers is a successor entry.
- **A module never names a provider.** It declares a contract. The moment a module can say "k8up" it has stopped consuming a contract.
- **A provider's runtime installation and its transformer registration are one act, gated by the permission that already governs the cluster.** Registering an adapter is a platform-team privilege, enforced by RBAC rather than by convention.
- **The claim carries no author-trusted data.** Every field of the shipped CR is derived from the provider catalog's identity package or stamped from instance identity at render; the only authored fact in the flow is the module's catalog dependency version, and acceptance's only free variable is which identity applied the claim.
- **A registration is not activated before its provider is Ready**, so no render targets CRDs that do not exist yet. Activation latches: once active, a claim deactivates only by deletion, so provider health noise never moves the effective registry.
- **Removing a provider is refused while consumers depend on it**, rather than silently breaking their next render.
- **Nothing here adds ordering or arbitration to the matcher.** Whatever routing ships must reduce to the predicate the matcher already evaluates — in Go at `compile/match.go` when this entry was drafted, in the render build's CUE match glue since 0019 D10, with the same rungs either way.

## Non-Goals

- **Splitting contracts and adapters into separate CUE modules.** Decided against in D4, deliberately and now rather than by default, because riding 0010's FQN break is nearly free and a standalone break later is not.
- **Transformers shipped inside module artifacts, or riding the CR.** Decided against in D10: a registration names a published catalog artifact only, refused structurally otherwise, and the CR is pure data. The generalization (an optional `package` field selecting a `#Catalog` subpackage, plus publish-gate coverage for module artifacts) is preserved in D10's alternatives and reachable additively if a real need arrives.
- **Provider routing of any kind — classes included.** Adopted 2026-08-05, rejected 2026-08-20 (D2, as revised): 0010 D37's one-provider rule stands, and the class design is preserved in D2's alternatives for the successor entry that picks routing up against a real two-engine instance.
- **Refinement / override semantics in the matcher** — "the most specific transformer in a bucket wins". OQ1 resolved by D5's guard instead: comparable predicates are refused, not ordered. Refinement is the only shape that expresses "override" and the only one that puts ordering into a matcher that has deliberately had none since 0001; successor material.
- **Capability-based routing** — a module declaring RPO, retention or "must support hooks" and the platform routing to whichever provider satisfies it. The likely shape of the successor routing entry; nothing here forecloses it.
- **Contract promotion between catalogs** (experimental → stable). A real and recurring cost under 0010's keying, carried here as OQ5 and likely its own entry.
- **What identity is, and how artifacts are published.** 0010 and 0011 respectively. This entry adds members to `#Catalog` and reads keys those entries define.
- **Re-litigating 0010 D4's key split.** Contract keys carry `apiVersion`, implementation keys carry the build. That is the substrate this entry builds on.

## High-Level Approach

Four changes, in dependency order. The first is a schema gap; the second is a decision not to route; the third makes a provider's installation and registration one act; the fourth is a decision not to split packaging.

**1. `#Catalog` gains three contract member maps** (D1). `#resources`, `#traits` and `#blueprints` sit beside `#transformers`, each with the same pattern constraint that already makes transformer provenance unforgeable — the catalog stamps `metadata.modulePath` onto every member. A contract becomes a *published member* of the artifact rather than a value reachable only by walking adapters.

That converts three things from derivations into lookups. The platform can enumerate every contract every subscribed catalog **defines** and cross it against what transformers **require** — under 0019 D5, which embeds each subscribed catalog whole in its registry entry, that cross is a pure CUE fold over the platform value, the same shape as 0019's derived `#composedTransformers` — which is D37's missing zero case and a `Platform` readiness condition. A missed demand can distinguish "defined by a subscribed catalog, unimplemented" from "unknown key" — 0010's OQ3, left open there because the derivation it needed was unreliable. And because the stamp is structural, a primitive's owning catalog stops being underivable from its FQN, which is what 0010 D17 records as explicitly not delivered.

**2. One provider per contract, refused loudly** (D2, as revised 2026-08-20; 0010 D37 stands unamended). The entry originally adopted provider classes here — StorageClass's shape, carried to matching by 0010 D36's `matchLabels` — and rejected them: the vocabulary is an operator-facing concept to design and operate, the invisible default re-route is StorageClass's known failure mode, and the default fill needed its own unresolved design, all ahead of any real two-engine requirement. What replaces them is nothing but better diagnostics: with D1's inventory the second provider is *over-subscription*, reported at platform assembly naming both catalog paths, and with D3 a second registration is refused at acceptance naming the claimant. Routing between providers — classes or capabilities — is a successor entry, designed against a real instance when one arrives, which is what 0010 D32 prescribed for arbitration all along. The full class design survives in D2's *Alternatives considered*.

**3. Registration is a cluster-scoped CR, gated by the RBAC the operator already has** (D3), **and authored as a contract-and-transformer pair** (D9). `opm-operator` already impersonates a per-tenant ServiceAccount during apply (`docs/TENANCY.md`, `--default-service-account` lockdown). A cluster-scoped `TransformerRegistration` that a tenant ServiceAccount cannot create is therefore a gate that exists today rather than a new permission model: a provider module ships the CR among its rendered resources, and only a module applied under a platform-team identity can create it.

How the CR gets *into* the rendered resources is D9's authoring surface, and it is the platform's own machinery eating its own dog food: catalog_opm publishes a `transformer-registration` `#Resource` contract (`fulfilment: "catalog"`) and the transformer that renders it. A provider module attaches the resource to a component; the transformer selects on the contract's FQN alone (no `matchLabels`, its own bucket, D5's guard untouched) and emits the CR. `#Module` is unchanged — no authored field, no second emission path, and core stays runtime-neutral: a non-Kubernetes runtime ships a different transformer for the same contract. The RBAC gate depends on this shape — the CR must be *rendered output applied under the tenant impersonation*, or the gate would have to be reimplemented inside the reconciler.

The spec is derived, the stamps structural (D10/D11/D12): the provider catalog exports a pre-bound value whose `catalog`/`version` interpolate from its identity package and whose `provides` folds over its own transformers' provider-fulfilled demands; the rendering transformer stamps `providerRef` and the dot-joined `namespace.name` CR name from instance identity. `spec.catalog` may name a published **catalog** artifact only — acceptance imports its root package and requires a `#Catalog` value, so a module artifact fails by shape — and transformer code never rides the CR; the registry stays the sole code channel. A provider wanting one repository publishes catalog and module in lockstep (`06-operational.md`).

The CR is a **claim**, not a fact:

```
  k8up module: component carries the transformer-registration #Resource
        │ rendered by catalog_opm's transformer (D9); spec derived from the
        │ k8up catalog's identity package, providerRef + name stamped (D11/D12)
        ▼
  TransformerRegistration/backup-system.k8up   ── cluster-scoped, RBAC-gated
    spec.catalog:     opmodel.dev/catalogs/k8up@v1      ── derived (D11)
    spec.version:     1.2.0                             ── derived (D11)
    spec.providerRef: ModulePackage/k8up                ── stamped; health gate
    spec.provides:    [".../traits/backup@v1beta1"]     ── derived, then verified
        │
        │  PlatformReconciler validates: artifact is a #Catalog (D10), provides
        │  equals the re-derived provider set (D11), contracts exist and are
        │  not already provided, providerRef is Ready
        ▼
  Platform.status.registry   ── the EFFECTIVE set: spec subscriptions + accepted claims
        │
        ▼
  platform-package regeneration (0019 D6)   ── trigger + package identity: OQ8
```

Three properties fall out of it being an object rather than an event. Activation is gated on `providerRef` being Ready, so a transformer never registers ahead of its CRDs — the thing a static subscription structurally cannot express; the gate latches, so once active a claim rides out provider restarts and deactivates only by deletion (D3). Acceptance is centralized in the Platform reconciler, so there remains exactly one writer to the materialized set and one place to reject. And a finalizer can refuse deletion while instances still demand the contracts it provides, naming the count, which turns the removal hazard into a blocked delete — with the same refusal covering the update door, where a provider upgrade whose re-derived `provides` drops a still-demanded contract is blocked before the new spec replaces the accepted claim (D16). Downstream of acceptance, 0019 D6 supplies the mechanism this entry used to lack a name for: the operator regenerates the platform package the render build consumes, folding the accepted catalog's import into the registry — 0019 D8 deleted the held materialized platform, so the regenerated package IS the effective set's materialization, and what triggers and keys the regeneration is OQ8.

**4. Contracts and adapters stay in one CUE module** (D4). The split's only mechanical benefit was a thin dependency for provider catalogs, and CUE evaluates per imported package while fetching per module — so the cost of depending on a whole catalog is a fetch, not the evaluation of 23 adapters. Cadence decoupling, the thing that would have justified it, is already delivered by 0010 D4's key split: a contract key does not move on a catalog release. With D1's contract maps in place a single catalog can already say "I define these and implement only some of them", which is the capability the split was wanted for.

## Schema / API Surface

Full shapes in [`schemas/target.cue`](schemas/target.cue).

- **`#CatalogContractMaps`** — the three member maps and their stamping pattern constraint, modelled on `core/src/catalog.cue`'s existing `#transformers` constraint. The stamp is the whole point: it is what makes owning-catalog structural rather than parsed back out of an FQN.
- **`#ContractInventory`** — the fold the platform value computes once the maps exist (0019 D5 embeds the catalogs, so it is derivable in core beside `#composedTransformers`): defined contracts per subscribed catalog, required-by sets from adapters, and the derived `unfulfilled` / `overSubscribed` reports. This is the value a `Platform` readiness condition and a CLI pre-flight both read.
- **`#ContractRouting`** — the arity relation asserted on the platform value: 0010 D37's exactly-one for provider-fulfilled contracts, `overSubscribed` refusal naming both paths, and catalog buckets deliberately unconstrained (D5's guard is OQ9/OQ10-gated).
- **`#TransformerRegistration`** — the CR's spec and status, expressed as a CUE shape so the claim/accept split and the activation preconditions are checkable before they are Go types.
- **The authoring surface** (D9–D12) — not core delta; compilable in [`contracts/contracts.cue`](../0015/contracts/contracts.cue): `#TransformerRegistrationContract` (the catalog_opm resource member), `#PreBoundRegistration` (the identity-package derivation of `catalog`/`version`/`provides`), `#RenderedRegistration` (the `providerRef` and CR-name stamps), `#ClaimedArtifactGate` (D10's catalog-only shape refusal) and `#ProvidesVerification` (D11's exact-equality acceptance check), each with pinned k8up-cast examples.
- **`#EffectiveRegistry`** — spec subscriptions unified with accepted claims, and the identity the operator stamps on the platform package it regenerates from the set (0019 D6; the store this digest originally keyed is deleted by 0019 D8). Naming the identity in the schema is what stops OQ8's regeneration question being answered incidentally in the reconciler.

## Integration Points

**core** — load the `core-schema-edit` skill before touching any of these; the SPEC.md co-update is gated by a pre-commit hook and CI.

- `core/src/catalog.cue:70-76` — `#resources`, `#traits`, `#blueprints` added beside `#transformers`, each with a `modulePath` stamping pattern constraint. The existing `#transformers` constraint is the template; the doc comment reserving these maps as "an additive extension if introspection demand surfaces later" is the line being cashed in.
- `core/src/platform.cue` — the contract-inventory fold and the `#ContractRouting` assertion, derived beside `#composedTransformers` on `#Platform`, whose registry entries 0019 D5 reshapes to `{enable, #catalog}` with the catalog embedded whole — the embedding is what makes both derivable here rather than computed in Go.
- `core/SPEC.md` — §3.6 (`#Catalog` shape and constraints) gains the three maps and their stamps; §3.4 (`#Platform`) gains the inventory and routing derivations. §4.1's "Why match is FQN-keyed and always unifies" needs a paragraph on why D5's duplicate guard is asserted at platform assembly and is not a matcher change.
- `core/src/module.cue` — **deliberately untouched** (D9). Registration ships as a contract attachment inside `#components`, so `#Module` needs no authored field; the derived `#provides` introspection fold is deferred until a consumer (an 0011-family gate, `opm module inspect`) exists.

**library** — re-baselined 2026-08-20 on 0019's acceptance. The surfaces this entry originally extended — `opm/materialize/index.go`, `opm/compile/match.go`, `opm/materialize/types.go` — are deleted by 0019 D5/D10/D17; the dated measurements against them stay in `01-problem.md` and `03-decisions.md`. The post-0019 surfaces:

- The contract inventory — no longer a Go index. With catalogs embedded whole in the platform value (0019 D5), the `#ContractInventory` cross is a core-derived fold beside `#composedTransformers` (it is already in this entry's core delta, `schemas/target.cue`); `library`'s obligation shrinks to reading it off a built value.
- The D37 arity guard — rewritten as the `#ContractRouting` relation asserted on the platform value: exactly one provider per contract (0010 D37, kept by D2), with the zero case reportable as `unfulfilled` and the two-provider case as `overSubscribed` naming both paths. It refuses at platform-package generation (0019 D6's cold path), which is where "a platform-level answer with no module in hand" naturally lives.
- The missed-demand diagnostic — under 0019 D10 an unresolved demand is already a verdict row in the render build's diagnostics data; the inventory lets that row (or the caller reading it) distinguish "defined by a subscribed catalog, unimplemented" from "unknown key", using membership rather than a prefix derivation. This is 0010 OQ3.
- The match glue — **unchanged.** Stated as an integration point because it is load-bearing that it is unchanged: D5's duplicate guard is asserted at platform assembly (site per OQ10), never as a rung change in the glue (`enhancements/0019/experiments/05-match-in-one-build/matchdef/match.cue`), and if any part of this design needs a rung to change, the design is wrong.

**opm-operator**

- `api/v1alpha1/` (new) — `TransformerRegistration`, cluster-scoped. `spec.{catalog,version,providerRef,provides}`, `status.{accepted,active,conditions}`.
- `api/v1alpha1/platform_types.go:74-94` — `PlatformStatus` gains `registry`: the effective set (spec subscriptions + accepted claims) and a readiness condition covering unfulfilled contracts.
- `internal/controller/platform_controller.go` — claim validation and acceptance; watches `TransformerRegistration` and the referenced `ModulePackage`s. Acceptance gains D10's artifact-kind check (the fetched artifact's root package must be a `#Catalog` value) and D11's provides-equality check (re-derive the provider set from the fetched catalog, refuse on drift naming both lists); the ModulePackage readiness aggregation excludes the registration CR by kind, and pure-registration modules are legal (D14).
- Platform-package regeneration — 0019 D8 deletes `internal/platform/store.go`'s held slot, so there is no cache to re-key; instead an accepted or revoked claim regenerates the platform package the operator builds renders from (0019 D6). What triggers regeneration, what identity the package carries, and the fleet-wide re-render blast radius are OQ8.
- The registration finalizer — refuses deletion while instances demand contracts the registration provides, which needs a reverse index from contract FQN to ModuleInstance.
- `config/rbac/` — the tenant role must **not** carry create on `transformerregistrations`; the platform-admin role must.

**cli**

- `opm platform check` (new) — the pre-flight the inventory makes possible: unfulfilled contracts, over-subscribed ones (a second provider, named and refused), and D5's comparable-predicate duplicates once OQ9/OQ10 resolve.
- Effective-registry retrieval — the CLI must be able to reproduce a cluster's render offline, which under D3 means fetching the effective set rather than reading the platform file alone. Shape per OQ3.

**catalog repos**

- `catalog_opm` — `src/catalog.cue` lists its resources, traits and blueprints in the new maps (mechanical; the values already exist and are already imported by the transformers that demand them), **and gains the registration pair** (D9): the `transformer-registration` resource contract plus the transformer rendering the CR with D11's stamps and D12's naming.
- A provider catalog (`catalog_k8up` as the first) — contract import, adapter, and the exported pre-bound registration value (D11: `catalog`/`version` interpolated from its identity package, `provides` folded from its own transformers). The corresponding module attaches that value to a component; the two artifacts publish in lockstep, catalog before module (D10, `06-operational.md`). Note the dependency structure this creates deliberately, on both sides. The provider *module* depends on catalog_opm for the registration contract (it already does in practice for the primitives deploying the provider). The provider *catalog* depends on catalog_opm too: a required map carries the contract's **value**, not just its FQN key (the shipped catalog's own shape — `daemonset_transformer.cue` writes `(res.#ContainerResource.metadata.fqn): res.#ContainerResource` — and what D11's fold reads `fulfilment` off), so requiring `catalogs/opm/traits/backup` means importing catalog_opm. Independence holds between *providers*: provider catalogs do not depend on each other. The base-catalog dependency is covered, not hazardous: D8's comparison runs per shared OPM-namespace path, catalog_opm included, and inside the render build 0019 D13's promotion resolves the provider catalog's catalog_opm import to the platform's own version — which is exactly what keeps the transformer's required copy and the platform's embedded copy on the same bytes (the property that let 0019's experiment 05 delete the D30 provenance carve-out).

## Before / After

**A contract with no adapter.** Before: `catalog_opm` declares `traits/backup@v1beta1` with `fulfilment: "provider"`. No transformer requires it, so it reaches no match bucket — absent from `#matchers` in the measured pre-0019 kernel, absent from the glue's derived buckets after 0019, for the same reason. A platform subscribed to `catalog_opm` alone reports Ready. The first module to declare `backup` fails to render with `no matching transformer`, which is true and useless.

After: the contract is a member of `#catalog.#traits`, the platform's embedded copy of the catalog carries it, the inventory fold reports it, and the platform reports `Ready=False, reason=UnfulfilledContracts` naming `traits/backup@v1beta1` and the catalog that defines it — before any module exists.

**A second backup engine.** Before: the exactly-one-provider rule is enforced by a guard that can only count adapters it reaches, so its refusal arrives with whatever context the adapter walk happened to have. After: the rule is unchanged — exactly one provider, deliberately (D2, as revised) — but the refusal is well-placed: the inventory reports `traits/backup@v1beta1` as over-subscribed at platform assembly naming both catalog paths, and a second `TransformerRegistration` is refused at acceptance naming the claimant. Running two engines stays out of scope; a successor entry designs routing when the need is real.

**Installing a provider.** Before: `kubectl apply` the k8up ModulePackage, then edit the cluster Platform CR to add the subscription, and hope the CRDs are established before the first consumer renders.

After: the k8up module attaches the k8up catalog's pre-bound `transformer-registration` resource to a component — one line, nothing authored (D9/D11) — and catalog_opm's transformer renders the `TransformerRegistration` among its resources, spec derived from the k8up catalog's identity package, `providerRef` and name stamped from the instance. Applying it requires the platform-admin ServiceAccount, so a tenant cannot register an adapter. The Platform reconciler verifies the artifact is a catalog and the claim equals the derived provider set (D10/D11), accepts, and holds the claim inactive until `ModulePackage/k8up` is Ready. `kubectl get transformerregistrations` enumerates what the cluster can render. Deleting it while seven instances demand `backup` is refused, naming the seven.
