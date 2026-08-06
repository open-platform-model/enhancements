# Design — Catalog Contracts, Provider Classes, and Transformer Registration

This document answers the question: "What is the proposed solution and how does it work?" Design Goals and Non-Goals together define the boundary; the High-Level Approach should be understandable without deep implementation knowledge. All trade-off reasoning lives in `03-decisions.md`, not here.

## Design Goals

- **A catalog states what it promises, separately from what it implements.** A contract is a member of the catalog artifact whether or not an adapter for it ships in the same artifact.
- **A missing provider is a platform-level answer, available with no module in hand.** "This platform subscribes to a contract nothing implements" is knowable at materialize, not discovered at render by whoever deploys first.
- **Two providers of one contract coexist, and routing is a platform decision expressed as source.** Which engine backs up which workload is reviewable in the platform's own files, not inferred from arithmetic or from subscription arity.
- **A module never names a provider.** It declares a contract and, at most, selects from a vocabulary the platform publishes. The moment a module can say "k8up" it has stopped consuming a contract.
- **A provider's runtime installation and its transformer registration are one act, gated by the permission that already governs the cluster.** Registering an adapter is a platform-team privilege, enforced by RBAC rather than by convention.
- **A registration that is not backed by a healthy provider is not active**, so no render targets CRDs that do not exist yet.
- **Removing a provider is refused while consumers depend on it**, rather than silently breaking their next render.
- **Nothing here adds ordering or arbitration to the matcher.** Whatever routing ships must reduce to the predicate `compile/match.go` already evaluates.

## Non-Goals

- **Splitting contracts and adapters into separate CUE modules.** Decided against in D4, deliberately and now rather than by default, because riding 0010's FQN break is nearly free and a standalone break later is not.
- **Refinement / override semantics in the matcher** — "the most specific transformer in a bucket wins". This is what OQ1 is about, and it is a substantially larger change than classes: it puts ordering into a matcher that has deliberately had none since 0001.
- **Capability-based routing** — a module declaring RPO, retention or "must support hooks" and the platform routing to whichever provider satisfies it. Strictly more expressive than classes and the right long-term shape; classes degenerate to it cleanly, so it is a successor rather than a competitor.
- **Contract promotion between catalogs** (experimental → stable). A real and recurring cost under 0010's keying, carried here as OQ5 and likely its own entry.
- **What identity is, and how artifacts are published.** 0010 and 0011 respectively. This entry adds members to `#Catalog` and reads keys those entries define.
- **Re-litigating 0010 D4's key split.** Contract keys carry `apiVersion`, implementation keys carry the build. That is the substrate this entry builds on.

## High-Level Approach

Four changes, in dependency order. The first is a schema gap; the second and third are the two halves of "a provider is a thing that exists"; the fourth is a decision not to build something.

**1. `#Catalog` gains three contract member maps** (D1). `#resources`, `#traits` and `#blueprints` sit beside `#transformers`, each with the same pattern constraint that already makes transformer provenance unforgeable — the catalog stamps `metadata.modulePath` onto every member. A contract becomes a *published member* of the artifact rather than a value reachable only by walking adapters.

That converts three things from derivations into lookups. Materialize can enumerate every contract every subscribed catalog **defines** and cross it against what transformers **require**, which is D37's missing zero case and a `Platform` readiness condition. A missed demand can distinguish "defined by a subscribed catalog, unimplemented" from "unknown key" — 0010's OQ3, left open there because the derivation it needed was unreliable. And because the stamp is structural, a primitive's owning catalog stops being underivable from its FQN, which is what 0010 D17 records as explicitly not delivered.

**2. Provider classes replace the one-provider rule** (D2, amending 0010 D37). Kubernetes solved this exact shape — many implementations, one abstract demand — with a named class the admin defines, referenced by name, with a default so most consumers say nothing: StorageClass, IngressClass, GatewayClass, VolumeSnapshotClass.

The mechanism is already in 0010. D36 adds `matchLabels` to `#Resource` / `#Trait` / `#Blueprint`, unifies them wholesale onto `#Component.matchLabels`, and repoints `#ComponentTransformer.requiredLabels` at that field:

```
  #Backup trait      class: "archive"
                     matchLabels: {"backup.opmodel.dev/class": "archive"}
                              │
                              │  D36: unifies upward, wholesale
                              ▼
  #Component.matchLabels   { "backup.opmodel.dev/class": "archive", … }
                              │
                              │  candidateSatisfied() — match.go:350, UNCHANGED
                              ▼
  k8up transformer     requiredLabels: {"backup.opmodel.dev/class": "daily"}    ✗
  velero transformer   requiredLabels: {"backup.opmodel.dev/class": "archive"}  ✓
```

Two providers, both subscribed, exactly one match, and `compile/match.go` does not change a line. Class values are mutually exclusive by construction, which is what makes this different from Gap 3's failed workaround — the discriminating label has one value, so at most one predicate holds. What is genuinely new is small: the platform publishes the class vocabulary and marks a default, and the kernel fills that default into demands that name no class. The fill is platform-dependent, so it cannot live in the module; where exactly it happens is OQ2.

**3. Registration is a cluster-scoped CR, gated by the RBAC the operator already has** (D3). `opm-operator` already impersonates a per-tenant ServiceAccount during apply (`docs/TENANCY.md`, `--default-service-account` lockdown). A cluster-scoped `TransformerRegistration` that a tenant ServiceAccount cannot create is therefore a gate that exists today rather than a new permission model: a provider module ships the CR among its rendered resources, and only a module applied under a platform-team identity can create it.

The CR is a **claim**, not a fact:

```
  k8up ModulePackage
        │ renders (needs cluster-admin SA to apply)
        ▼
  TransformerRegistration/k8up            ── cluster-scoped, RBAC-gated
    spec.catalog:     opmodel.dev/catalogs/k8up@v1
    spec.version:     1.2.0
    spec.providerRef: ModulePackage/k8up             ── health gate
    spec.provides:    [".../traits/backup@v1beta1"]  ── declared, then verified
        │
        │  PlatformReconciler validates: catalog resolvable, declared contracts
        │  exist, class does not collide, providerRef is Ready
        ▼
  Platform.status.registry   ── the EFFECTIVE set: spec subscriptions + accepted claims
        │
        ▼
  materialize ──▶ platform.Store   (key: generation + accepted-claim digest)
```

Three properties fall out of it being an object rather than an event. Activation is gated on `providerRef` being Ready, so a transformer never registers ahead of its CRDs — the thing a static subscription structurally cannot express. Acceptance is centralized in the Platform reconciler, so there remains exactly one writer to the materialized set and one place to reject. And a finalizer can refuse deletion while instances still demand the contracts it provides, naming the count, which turns the removal hazard into a blocked delete.

**4. Contracts and adapters stay in one CUE module** (D4). The split's only mechanical benefit was a thin dependency for provider catalogs, and CUE evaluates per imported package while fetching per module — so the cost of depending on a whole catalog is a fetch, not the evaluation of 23 adapters. Cadence decoupling, the thing that would have justified it, is already delivered by 0010 D4's key split: a contract key does not move on a catalog release. With D1's contract maps in place a single catalog can already say "I define these and implement only some of them", which is the capability the split was wanted for.

## Schema / API Surface

Full shapes in [`schemas/target.cue`](schemas/target.cue).

- **`#CatalogContractMaps`** — the three member maps and their stamping pattern constraint, modelled on `core/src/catalog.cue`'s existing `#transformers` constraint. The stamp is the whole point: it is what makes owning-catalog structural rather than parsed back out of an FQN.
- **`#ContractInventory`** — what materialize computes once the maps exist: defined contracts per subscribed catalog, required-by sets from adapters, and the derived `unfulfilled` / `overSubscribed` reports. This is the value a `Platform` readiness condition and a CLI pre-flight both read.
- **`#ProviderClass`** — a class as a platform-published vocabulary entry: a name, the contract it routes, the catalog that implements it, and whether it is the default for that contract. Deliberately keyed by contract FQN, because a cluster with a default backup class and a default ingress class has two independent defaults.
- **`#ClassedContract`** — the demand side: the optional `class` field on a provider-fulfilled contract and the `matchLabels` projection it produces. The projection is the entire matcher integration.
- **`#TransformerRegistration`** — the CR's spec and status, expressed as a CUE shape so the claim/accept split and the activation preconditions are checkable before they are Go types.
- **`#EffectiveRegistry`** — spec subscriptions unified with accepted claims, and the digest the operator's `platform.Store` keys on. Naming the digest in the schema is what stops the invalidation question being answered incidentally in the reconciler.

## Integration Points

**core** — load the `core-schema-edit` skill before touching any of these; the SPEC.md co-update is gated by a pre-commit hook and CI.

- `core/src/catalog.cue:70-76` — `#resources`, `#traits`, `#blueprints` added beside `#transformers`, each with a `modulePath` stamping pattern constraint. The existing `#transformers` constraint is the template; the doc comment reserving these maps as "an additive extension if introspection demand surfaces later" is the line being cashed in.
- `core/src/resource.cue`, `core/src/trait.cue` — the optional `class?: #NameType` field on provider-fulfilled contracts, and the `matchLabels` projection that carries it. Depends on 0010 D36 having landed `matchLabels` on both kinds.
- `core/src/platform.cue` — the class vocabulary: a path-keyed map of contract FQN → class name → implementing catalog, with a default marker. Sits beside `#registry`, which keeps its 0010 D14 shape.
- `core/SPEC.md` — §3.6 (`#Catalog` shape and constraints) gains the three maps and their stamps; §3.4 (`#Platform`) gains the class vocabulary; §2.1/§2.2 gain `class`. §4.1's "Why match is FQN-keyed and always unifies" needs a paragraph on why classes require no matcher change.

**library**

- `opm/materialize/index.go:35-96` — `indexCatalogs` additionally reads the three contract maps and builds the `#ContractInventory`. The `if !txs.Exists() { continue }` at `:39-41` stops being the whole of a catalog's contribution.
- `opm/materialize/index.go` (new) — the D37 arity guard rewritten against the inventory: it can now enumerate provider-fulfilled contracts directly rather than inferring them from adapters, so the zero case becomes reportable. Under D2 the arity rule itself changes from "exactly one" to "at most one per class, and every class in the vocabulary is implemented".
- `opm/compile/match.go:130` — the missed-demand diagnostic distinguishes "defined by a subscribed catalog, unimplemented" from "unknown key", using the inventory rather than a prefix derivation. This is 0010 OQ3.
- `opm/compile/match.go:344-360` — **unchanged.** Stated as an integration point because it is load-bearing that it is unchanged: classes ride `requiredLabels`, and if any part of the design needs this function to change, the design is wrong.
- The default-class fill — new, placement per OQ2. It must run after the platform is materialized and before match, on demands carrying no explicit class.
- `opm/materialize/types.go` — `MaterializedPlatform` gains the inventory and the class vocabulary.

**opm-operator**

- `api/v1alpha1/` (new) — `TransformerRegistration`, cluster-scoped. `spec.{catalog,version,providerRef,provides,class}`, `status.{accepted,active,conditions}`.
- `api/v1alpha1/platform_types.go:74-94` — `PlatformStatus` gains `registry`: the effective set (spec subscriptions + accepted claims) and a readiness condition covering unfulfilled contracts.
- `internal/controller/platform_controller.go` — claim validation and acceptance; watches `TransformerRegistration` and the referenced `ModulePackage`s.
- `internal/platform/store.go` — the store key moves from the Platform CR's `.metadata.generation` to a digest over generation plus the accepted-claim set. Every accepted or revoked claim is a cluster-wide re-render; that blast radius is OQ6.
- The registration finalizer — refuses deletion while instances demand contracts the registration provides, which needs a reverse index from contract FQN to ModuleInstance.
- `config/rbac/` — the tenant role must **not** carry create on `transformerregistrations`; the platform-admin role must.

**cli**

- `opm platform check` (new) — the pre-flight the inventory makes possible: unfulfilled contracts, classes with no implementation, contracts with more implementations than classes.
- Effective-registry retrieval — the CLI must be able to reproduce a cluster's render offline, which under D3 means fetching the effective set rather than reading the platform file alone. Shape per OQ3.

**catalog repos**

- `catalog_opm` — `src/catalog.cue` lists its resources, traits and blueprints in the new maps. Mechanical; the values already exist and are already imported by the transformers that demand them.
- A provider catalog (`catalog_k8up` as the first) — contract import, adapter, and the `TransformerRegistration` shipped by the corresponding module.

## Before / After

**A contract with no adapter.** Before: `catalog_opm` declares `traits/backup@v1beta1` with `fulfilment: "provider"`. `materialize/index.go:39-41` walks `#transformers`; no transformer requires it; the contract is not in `#matchers`. A platform subscribed to `catalog_opm` alone reports Ready. The first module to declare `backup` fails to render with `no matching transformer`, which is true and useless.

After: the contract is a member of `#catalog.#traits`, materialize inventories it, and the platform reports `Ready=False, reason=UnfulfilledContracts` naming `traits/backup@v1beta1` and the catalog that defines it — before any module exists.

**Two backup engines.** Before: subscribe to `catalog_k8up` and `catalog_velero` and materialize refuses under 0010 D37, naming both catalog paths. The platform team's actual topology is unexpressible; the only path is to run one engine outside OPM.

After: the platform publishes two classes for `traits/backup@v1beta1` — `daily` → k8up (default), `archive` → velero. A module that says nothing gets `daily`. A module that says `class: "archive"` projects `backup.opmodel.dev/class: "archive"` up to its component's `matchLabels`, and only Velero's `requiredLabels` is satisfied. Migrating the database tier is one field on one component, not a subscription swap.

**Installing a provider.** Before: `kubectl apply` the k8up ModulePackage, then edit the cluster Platform CR to add the subscription, and hope the CRDs are established before the first consumer renders.

After: the k8up module ships a `TransformerRegistration` among its resources. Applying it requires the platform-admin ServiceAccount, so a tenant cannot register an adapter. The Platform reconciler accepts the claim and holds it inactive until `ModulePackage/k8up` is Ready. `kubectl get transformerregistrations` enumerates what the cluster can render. Deleting it while seven instances demand `backup` is refused, naming the seven.
