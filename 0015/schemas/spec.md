# Specification changes: Catalog Contracts, Provider Classes, and Transformer Registration

This document pre-drafts the `core/SPEC.md` co-update the core slice will need (the `core-schema-edit` skill gates that co-update via pre-commit hook and CI). One section per NEW or CHANGED construct from [`target.cue`](target.cue), in core SPEC.md's four-part format. Section numbers for CHANGED constructs follow 02-design.md's Integration Points: `#Catalog` §3.6, `#Platform` §3.4, `#Resource`/`#Trait` §2.1/§2.2.

MIRROR definitions in `target.cue` — `#ModulePath`, `#PackagePath`, `#ContractFQN`, `#ImplFQN`, `#Name`, `#Version`, `#ContractKind`, `#Fulfilment`, `#Subscription` — restate unchanged core types narrowly so the file vets standalone; they change nothing in core and get no section here.

Three Open Questions gate parts of this delta and are cited inline where they bind: OQ2 (default-class fill placement and the exact label-key derivation), OQ3 (reproducibility of the effective registry — blocking for `draft → accepted`), and OQ6 (store-key shape and registration blast radius). OQ1 (duplicate transformers inside a `"catalog"`-fulfilled bucket) and OQ7 (where a build-incompatible registration is refused) bound what this delta deliberately does not constrain.

## #PublishedContract (NEW)

### Definition

The member value a catalog publishes for one contract: the contract's identity (name, kind, API version, FQN), its provenance (the declaring catalog's package path and build), and its fulfilment. It makes "this catalog **defines** contract X" a stated fact of the artifact, separate from "this catalog **implements** contract X" — the two facts today's `#Catalog` collapses, and the provider-fulfilled case is exactly where they diverge (D1).

### Shape

```cue
#PublishedContract: {
	name!:           #NameType
	kind!:           "resources" | "traits" | "blueprints"
	modulePath!:     #PackagePathType // stamped by the owning catalog
	apiVersion!:     #APIVersionType
	catalogVersion!: #VersionType // stamped by the owning catalog
	fqn!:            #ContractFQNType
	fulfilment:      *"catalog" | "provider"
	classed?:        bool
	description?:    string
}
```

### Constraints

- `modulePath` and `catalogVersion` MUST be stamped by the declaring catalog's pattern constraint and MUST NOT be authored at the leaf — the same rule §3.6 already applies to `#transformers` members.
- `fqn` MUST equal the map key the member is published under.
- `fulfilment` MUST default to `"catalog"` (0010 D37's default, unchanged).
- `classed` MAY be set on a provider-fulfilled contract to declare that routing by class (D2) applies; absent means the contract has exactly one implementation path and needs no routing.
- Publishing a contract MUST NOT require an adapter for it to exist anywhere.

### Rationale

- **Why a published member rather than a derivation.** Today a contract reaches the materialized world only by being demanded by an adapter (`materialize/index.go:39-41` walks `#transformers` only), so a provider-fulfilled contract — one its declaring catalog deliberately ships no transformer for — is absent entirely, and 0010 D37's zero-provider case is indistinguishable from a key that exists nowhere (D1).
- **Why stamped provenance.** The stamp is what makes a primitive's owning catalog structural instead of parsed back out of an FQN — closing what 0010 D17 records as explicitly not delivered — and it is the same mechanism that already makes transformer provenance unforgeable (D1).
- **Why not a stub transformer.** The only publication mechanism available today inverts the artifact's meaning (an adapter that emits nothing is indistinguishable from a broken one) and is self-defeating: the stub is a provider, so the first real provider becomes the second and gets refused (D1, alternatives).

## #CatalogContractMaps (CHANGED vs SPEC.md §3.6)

### Definition

`#Catalog` gains three contract member maps — `#resources`, `#traits`, `#blueprints` — beside the existing `#transformers`, each keyed by the member's contract FQN and each stamping provenance onto its values. This cashes in the additive extension §3.6's own doc comment reserves ("Adding sibling maps (#resources, #traits, #blueprints) is an additive extension if introspection demand surfaces later"); the demand is 0010 D37. `target.cue` states the three maps as one standalone struct so the stamping rule is written once; in `core/src/catalog.cue` they land as three sibling pattern constraints alongside the `#transformers` one.

### Shape

```cue
// Inside #Catalog, beside #transformers. RP/CV are label aliases carrying
// the catalog's registryPath and version across the pattern-constraint
// boundary, as catalog.cue's M=metadata already does.
#resources: [FQN=#ContractFQNType]: #PublishedContract & {
	kind:           "resources"
	fqn:            FQN
	modulePath:     "\(RP)/resources"
	catalogVersion: CV
}
// #traits and #blueprints identical, with their own kind segment.
```

### Constraints

- Added: each map MUST key members by the member's own contract FQN.
- Added: the catalog MUST stamp each member's `modulePath` as its registry path plus the kind segment — the major-free package path, exactly as the `#transformers` stamp does.
- Added: the catalog MUST stamp each member's `catalogVersion` with the catalog's own `version`.
- Added: the stamp MUST NOT cover `fqn` — an FQN is authored at the definition site (0010 D21), and the map key already carries it.
- The change MUST be additive: no existing `#Catalog` value changes meaning, and a catalog publishing no contracts remains valid.

### Rationale

- **Why members beside `#transformers`.** Four derivations become lookups: D37's zero case becomes reportable, a platform readiness condition becomes computable with no module in hand, "unimplemented" separates from "unknown" in the missed-demand diagnostic (0010 OQ3), and a primitive's owning catalog becomes structural (D1).
- **Why three maps rather than one `#contracts` map keyed by kind.** Symmetry with `#transformers` and with `kindPrefix` (0010 D21), which already admits exactly one path per kind — three maps mirror three kind prefixes (D1, alternatives).
- **Why the inventory lives in the catalog and not the platform.** The platform would restate what the catalog already knows, and the restatement can drift from the artifact it describes (D1, alternatives).

## #ContractInventory (NEW)

### Definition

The value materialize computes once contracts are members: the cross of "defined by a subscribed catalog" against "required by an adapter on this platform". It is what a `Platform` readiness condition and the `opm platform check` pre-flight both read, and the value D2's arity rule (`#ContractRouting`) is evaluated against. Without D1 the `defined` set is not computable at all.

### Shape

```cue
#ContractInventory: {
	defined: [FQN=#ContractFQNType]: #PublishedContract & {fqn: FQN}
	requiredBy: [#ContractFQNType]: [...#ImplFQNType]
	unfulfilled: [...#ContractFQNType]
	unroutable: [...#ContractFQNType]
	ready: bool & (len(unfulfilled) == 0 && len(unroutable) == 0)
}
```

### Constraints

- `defined` MUST enumerate every contract every subscribed catalog defines, whether or not any adapter demands it.
- `requiredBy` MUST count required demands only; optional consumption is tolerance, not fulfilment (0010 D32).
- `unfulfilled` MUST list every provider-fulfilled contract that is defined and required by nothing — the zero case that drives `Platform Ready=False, reason=UnfulfilledContracts`, reported at materialize with no module in hand.
- `unroutable` MUST list every contract with more implementations than the class vocabulary routes (D2's replacement for 0010 D37's "more than one is an error").
- `ready` MUST be true exactly when both reports are empty.

### Rationale

- **Why a materialize-time value.** The pre-D1 failure surfaces later, per-instance, at render, once somebody deploys a module that uses the contract — "no matching transformer", which is true and useless. The inventory moves the answer to where the platform is assembled (D1).
- **Why `unroutable` instead of refusal.** D2 amends 0010 D37: two providers stop being an error and become a routing obligation, so the failure mode shifts from "refused at materialize" to "reported as unroutable until the vocabulary covers the bucket" (D2).

## #ProviderClass (NEW)

### Definition

One entry in the vocabulary a platform publishes for a contract with more than one implementation: a name the admin defines, the contract it routes, the catalog whose transformer implements it, and whether it is the default for that contract. Modelled on StorageClass / IngressClass / GatewayClass / VolumeSnapshotClass: the admin names it, the consumer references the name, and one is the default so most consumers say nothing (D2).

### Shape

```cue
#ProviderClass: {
	contract!: #ContractFQNType
	name!:     #NameType
	catalog!:  #ModulePathType
	default:   bool | *false
}
```

### Constraints

- `name` MUST be platform-published vocabulary; a module MUST NOT name the implementing catalog — the moment a module can say "k8up" it has stopped consuming a contract.
- Exactly one class per contract MUST carry `default: true`.
- `catalog` MUST name the implementing catalog's CUE module path (major suffix included).

### Rationale

- **Why classes.** Kubernetes solved this exact shape — many implementations, one abstract demand, admin-defined selection, reference by name, a default — four separate times; adopting the pattern buys a decade of production validation (D2).
- **Why a default.** Most consumers say nothing; migration then becomes one field on one component rather than a cluster-wide subscription swap (D2).
- **Why not weights, newest-wins, or predicate-equality detection.** All rejected in 0010 D32 with measurements, and nothing here revives them (D2, alternatives).

## #ClassVocabulary (CHANGED vs SPEC.md §3.4)

### Definition

The platform-side routing vocabulary `#Platform` gains beside `#registry`: a map keyed by contract FQN, then by class name, of `#ProviderClass` entries. `#registry` itself keeps its 0010 D14 shape untouched. `target.cue` states it standalone; in core it lands in `core/src/platform.cue`.

### Shape

```cue
#ClassVocabulary: {
	[Contract=#ContractFQNType]: [ClassName=#NameType]: #ProviderClass & {
		contract: Contract
		name:     ClassName
	}
}
```

### Constraints

- The vocabulary MUST be keyed by contract FQN and then by class name; `contract` and `name` MUST be stamped from the map keys.
- Defaults MUST be independent per contract — a cluster with a default backup class and a default ingress class has two independent defaults.
- Adding the vocabulary MUST NOT change `#registry` (0010 D14's shape stays).

### Rationale

- **Why keyed by contract rather than flat.** Per-contract keying is what makes defaults independent and keeps two contracts' vocabularies from colliding (D2).
- **Why the platform publishes it.** Routing is a platform decision expressed as source — reviewable in the platform's own files, not inferred from subscription arity (D2).

## #ClassLabelKey (NEW)

### Definition

The label key a class projects for one contract, derived from the contract FQN and never authored. One key per contract, so two contracts' classes cannot collide in a component's unified `matchLabels`.

### Shape

```cue
#ClassLabelKey: {
	contract!: #ContractFQNType
	out:       string & strings.Replace(contract, "/", ".", -1) + "/class"
}
```

### Constraints

- The key MUST be derived from the contract FQN and MUST NOT be authorable.
- The key MUST be per-contract, so class labels of distinct contracts unify without collision.
- The exact derivation is OQ2-gated: it is settled together with the default-fill placement. What is fixed now is only that it is per-contract and derived; `target.cue`'s current expression (and the pinned assertion in `examples.cue`) is a placeholder that MUST be revisited when OQ2 resolves.

### Rationale

- **Why one key per contract.** A component may carry several classed contracts at once; per-contract keys are what let their projections coexist in one unified `matchLabels` struct (D2).
- **Why derived.** An authorable key would reopen the collision the derivation exists to close, and would let a module and a platform disagree about which label routes a contract (D2).

## #ClassedContract (CHANGED vs SPEC.md §2.1/§2.2)

### Definition

`#Resource` and `#Trait` gain an optional `class` field, and a provider-fulfilled contract carrying one projects exactly one entry into the `matchLabels` field 0010 D36 already defined. The projection is the entire matcher integration: D36 unifies a component's primitives' `matchLabels` wholesale onto `#Component.matchLabels`, and `#ComponentTransformer.requiredLabels` selects on that field. `target.cue` states the change standalone as `#ClassedContract`; in core it lands in `core/src/resource.cue` and `core/src/trait.cue`.

### Shape

```cue
#ClassedContract: {
	C=contract!: #ContractFQNType
	class?:      #NameType // authored by the module, or filled from the platform default (OQ2)
	_key: (#ClassLabelKey & {contract: C}).out
	matchLabels: {
		if class != _|_ {
			(_key): class
		}
	}
}
```

### Constraints

- `class` MAY be authored by the module; a demand naming no class MUST have the platform's default filled in before match (fill placement is OQ2-gated).
- When `class` is present, `matchLabels` MUST carry exactly the one class label under the contract's derived key; when absent, it MUST carry none.
- Class values within one contract MUST be mutually exclusive by construction: at most one transformer's `requiredLabels` can be satisfied.
- `compile/match.go:344-360` MUST NOT change. This is load-bearing: classes ride `requiredLabels`, and if any part of the design needs that function to change, the design is wrong (D2).

### Rationale

- **Why a label projection.** 0010 D36's `matchLabels` is exactly the substrate a class needs — a label that unifies upward from a primitive to its component and is selected on by `requiredLabels` — so routing costs no matcher change (D2).
- **Why mutual exclusion succeeds where predicate-narrowing fails.** `fqnSubset` is subset containment and predicates are monotone: adding a required trait to one transformer never excludes the *other* transformer from components that have it. A discriminating label with one value means at most one predicate holds (D2).
- **Why the fill cannot live in the module.** The default is platform-published, so a module cannot know it; the fill must run after materialize and before match (OQ2).

## #ContractRouting (NEW)

### Definition

The relation materialize asserts for one provider-fulfilled contract, replacing 0010 D37's exactly-one-provider rule (D2 amends D37): zero implementations is `unfulfilled`, one needs no vocabulary, more than one needs one class per implementation and exactly one default.

### Shape

```cue
#ContractRouting: {
	contract!:  #ContractFQNType
	fulfilment: *"catalog" | "provider"
	implementations!: [...#ImplFQNType]
	classes!: [Name=#NameType]: #ProviderClass & {name: Name}
	ok: bool // fulfilled ∧ routed
}
```

### Constraints

- Zero implementations of a provider-fulfilled contract MUST be reported at materialize (as `unfulfilled`), not deferred to the first render that trips over it.
- A provider-fulfilled contract with one implementation MUST require no class vocabulary.
- A provider-fulfilled contract with more than one implementation MUST have one class per implementation, with exactly one default — this is the whole of what replaces "exactly one provider".
- A `"catalog"`-fulfilled contract MUST NOT be arity-constrained by this relation: such a bucket legitimately feeds many outputs (catalog_opm's `#ContainerResource` bucket holds 8 transformers). The duplicate-adapter case within that fulfilment is OQ1's and is deliberately unconstrained here.

### Rationale

- **Why at-most-one-per-class.** The motivating topology — restic-for-PVCs and namespace-snapshot backup on one cluster — is a legitimate state D37 made unexpressible; D37 itself recorded its rule as provisional pending a real instance, and this is that instance (D2).
- **Why asserted at materialize.** The inventory (D1) makes the whole relation computable where the platform is assembled, so an unroutable or unfulfilled contract names itself before any module deploys (D1, D2).

## #TransformerRegistration (NEW)

### Definition

A cluster-scoped custom resource through which a provider module registers its catalog's transformers, shipped among the module's rendered resources. The CR is a **claim**, not a fact: the Platform reconciler validates it and records acceptance, so there remains exactly one writer to the materialized set and one place to reject (D3). `target.cue` splits it as `#TransformerRegistrationSpec` (the claim) and `#TransformerRegistrationStatus` (the verdict); the Go types land in `opm-operator/api/v1alpha1/`, and this section specifies the CUE-level contract they must satisfy.

### Shape

```cue
#TransformerRegistrationSpec: {
	catalog!: #ModulePathType
	version!: #VersionType // scalar, per 0010 D14 — nothing resolves it
	providerRef!: {name!: string, namespace!: string}
	provides!: [...#ContractFQNType]
	class?: #NameType
}

#TransformerRegistrationStatus: {
	accepted: bool | *false
	active:   bool | *false
	reason?:  string
	dependentInstances: int & >=0 | *0
	// invariant: active ⇒ accepted
}

#TransformerRegistration: {
	spec!:   #TransformerRegistrationSpec
	status!: #TransformerRegistrationStatus
}
```

### Constraints

- The CR MUST be cluster-scoped, and tenant roles MUST NOT carry create on it — the RBAC gate rides the per-tenant ServiceAccount impersonation the operator already performs during apply (D3).
- `provides` MUST be verified against the subscribed catalogs' contract maps (D1); a claim naming a contract no subscribed catalog defines MUST be rejected at acceptance.
- `version` MUST be scalar: the value written is the value used, with nothing to resolve (0010 D14).
- Activation MUST be gated on `providerRef` being Ready, so a transformer never registers ahead of its CRDs; `active` MUST imply `accepted`.
- Acceptance MUST be centralized in the Platform reconciler; accepted claims MUST be recorded in `Platform.status.registry`, never written into the Platform CR's spec.
- Deletion MUST be refused while `dependentInstances > 0`, naming the count.
- `class` MAY name the class this registration serves (D2); a claim whose class is already taken for the contract MUST be rejected.
- Where a registration is refused when the provider requires a build the platform does not run is OQ7-gated; the natural refusal site is this acceptance gate, so the failure names the provider.

### Rationale

- **Why a CR rather than an event or a convention.** Three properties fall out of it being an object: activation is health-gated (the thing a static subscription structurally cannot express), removal is refusable while consumers depend on it, and the effective set is enumerable (D3).
- **Why cluster-scoped.** The objection to a second registration path was the privilege, not the mechanism — a transformer is arbitrary CUE producing arbitrary Kubernetes objects — and a cluster-scoped CR resolves that against a permission model the operator already enforces instead of inventing one (D3).
- **Why not an annotation on the ModulePackage.** That puts a cluster-scoped privilege on a namespaced object — exactly the escalation the CR prevents — and gives no home for acceptance, health, or a finalizer (D3, alternatives).
- **Why status, not a webhook writing spec.** A mutating webhook would make the Platform CR's spec no longer author-owned, so a GitOps reconciler and the webhook fight over the same field; status is the correct home for a derived set (D3, alternatives).

## #EffectiveRegistry (NEW)

### Definition

The union materialize consumes and `Platform.status.registry` reports: the subscriptions authored in the Platform CR's spec (the static path) unified with accepted-and-active `TransformerRegistration` claims (the dynamic path), plus the key the operator's `platform.Store` derives its cache identity from.

### Shape

```cue
#EffectiveRegistry: {
	subscriptions: [#ModulePathType]: #Subscription
	claims: [#ModulePathType]: #TransformerRegistration & {status: active: true}
	// invariant: no path appears in both maps
	key!: {
		generation!: int
		claims: [...string]
	}
}
```

### Constraints

- `claims` MUST include only registrations that are accepted AND active.
- A claim naming a path the spec already subscribes to MUST be a conflict, not a merge — two sources would then disagree about the build.
- The store key MUST cover the Platform CR's generation plus the active-claim set, replacing generation alone; every accepted or revoked claim moves the key and re-renders every ModuleInstance. Whether that blast radius is acceptable as-is, needs rate limiting, or needs a diffable materialized platform is OQ6-gated, as is the exact serialization of the key's claim list.
- How a consumer reproduces a cluster's render when part of the registry lives in cluster state is OQ3-gated and blocking for `draft → accepted`: D3 reintroduces resolution that 0010 D14 deleted, and "the platform file plus a cluster query" is a weaker property than "the platform file".

### Rationale

- **Why a named schema value.** Naming the effective set and its store key in the schema is what stops the invalidation question being answered incidentally in the reconciler (D3).
- **Why conflict rather than merge.** The spec subscription and the claim each name a build; merging would silently pick one, and the registry's whole point is that selection is a stated fact (D3).
- **Why enumerability matters.** The CR makes the effective set fetchable, which is most of 0010 D14's reproducibility value back — the remainder is exactly OQ3 (D3).
