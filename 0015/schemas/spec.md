# Specification changes: Catalog Contracts and Transformer Registration

This document pre-drafts the `core/SPEC.md` co-update the core slice will need (the `core-schema-edit` skill gates that co-update via pre-commit hook and CI). One section per NEW or CHANGED construct from [`target.cue`](target.cue), in core SPEC.md's four-part format. Section numbers for CHANGED constructs follow 02-design.md's Integration Points: `#Catalog` §3.6, `#Platform` §3.4.

MIRROR definitions in `target.cue` — `#ModulePath`, `#PackagePath`, `#ContractFQN`, `#ImplFQN`, `#Name`, `#Version`, `#ContractKind`, `#Fulfilment`, `#Subscription` — restate unchanged core types narrowly so the file vets standalone; they change nothing in core and get no section here.

Open Questions gating parts of this delta, cited inline where they bind: OQ8 (platform-package regeneration and registration blast radius; it absorbs OQ6, which is answered — overtaken by 0019 D8), and OQ9/OQ10 (D5's duplicate guard: detection shape and site — until they resolve the guard is stated in prose, not in this delta). The build-incompatibility refusal is resolved-by-D8: refused at acceptance, by 0019 D18's committed-resolution comparison per shared path, exact under GA additive discipline. Provider classes were removed from this delta on 2026-08-20 (D2, as revised): 0010 D37's one-provider rule stands, and the former class shapes live in D2's alternatives for a successor entry.

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
	description?:    string
}
```

### Constraints

- `modulePath` and `catalogVersion` MUST be stamped by the declaring catalog's pattern constraint and MUST NOT be authored at the leaf — the same rule §3.6 already applies to `#transformers` members.
- `fqn` MUST equal the map key the member is published under.
- `fulfilment` MUST default to `"catalog"` (0010 D37's default, unchanged).
- Publishing a contract MUST NOT require an adapter for it to exist anywhere.

### Rationale

- **Why a published member rather than a derivation.** A contract reaches a build only by being demanded by an adapter — every derivation from a catalog walks `#transformers` alone (`materialize/index.go:39-41` in the measured pre-0019 kernel; the composed-map fold after 0019 D5) — so a provider-fulfilled contract — one its declaring catalog deliberately ships no transformer for — is absent entirely, and 0010 D37's zero-provider case is indistinguishable from a key that exists nowhere (D1).
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

The value derivable once contracts are members — under 0019 D5 a pure CUE fold over the platform's embedded catalogs, beside `#composedTransformers`: the cross of "defined by a subscribed catalog" against "required by an adapter on this platform". It is what a `Platform` readiness condition and the `opm platform check` pre-flight both read, and the value `#ContractRouting`'s arity rule is evaluated against. Without D1 the `defined` set is not computable at all.

### Shape

```cue
#ContractInventory: {
	defined: [FQN=#ContractFQNType]: #PublishedContract & {fqn: FQN}
	requiredBy: [#ContractFQNType]: [...#ImplFQNType]
	unfulfilled: [...#ContractFQNType]
	overSubscribed: [...#ContractFQNType]
	ready: bool & (len(unfulfilled) == 0 && len(overSubscribed) == 0)
}
```

### Constraints

- `defined` MUST enumerate every contract every subscribed catalog defines, whether or not any adapter demands it.
- `requiredBy` MUST count required demands only; optional consumption is tolerance, not fulfilment (0010 D32).
- `unfulfilled` MUST list every provider-fulfilled contract that is defined and required by nothing — the zero case that drives `Platform Ready=False, reason=UnfulfilledContracts`, reported at platform assembly with no module in hand.
- `overSubscribed` MUST list every provider-fulfilled contract with more than one implementation — refused per 0010 D37, which D2 (as revised) keeps unamended; the inventory is what lets the refusal name both catalog paths.
- `ready` MUST be true exactly when both reports are empty.

### Rationale

- **Why an assembly-time value.** The pre-D1 failure surfaces later, per-instance, at render, once somebody deploys a module that uses the contract — "no matching transformer", which is true and useless. The inventory moves the answer to where the platform is assembled (D1).
- **Why `overSubscribed` as a named report rather than a bare error.** D37's guard previously counted only adapters it could reach; with the inventory the refusal is computed where the platform is assembled and names both catalog paths, and D3's acceptance gate can refuse the second registration naming the claimant (D2, as revised).

## #ContractRouting (NEW)

### Definition

The relation asserted on the platform value — at 0019 D6's generation step — for one contract: 0010 D37's exactly-one-provider rule, kept unamended by D2 (as revised 2026-08-20). Zero implementations of a provider-fulfilled contract is `unfulfilled`; more than one is `overSubscribed` and refused.

### Shape

```cue
#ContractRouting: {
	contract!:  #ContractFQNType
	fulfilment: *"catalog" | "provider"
	implementations!: [...#ImplFQNType]
	ok: bool // fulfilled ∧ routed
}
```

### Constraints

- Zero implementations of a provider-fulfilled contract MUST be reported at platform assembly (as `unfulfilled`), not deferred to the first render that trips over it.
- A provider-fulfilled contract MUST have at most one implementation (0010 D37); a second MUST be refused, naming the contract and both catalog paths.
- A `"catalog"`-fulfilled contract MUST NOT be arity-constrained by this relation: such a bucket legitimately feeds many outputs (catalog_opm's `#ContainerResource` bucket holds 8 transformers). The duplicate-adapter case within that fulfilment is refused by D5's comparable-predicate guard, whose detection shape (OQ9) and site (OQ10) are unresolved and deliberately not constrained here.

### Rationale

- **Why exactly-one stands.** Provider routing (classes) was adopted 2026-08-05 and rejected 2026-08-20 on cost/benefit ahead of any real two-engine requirement; a successor entry designs routing against a real instance, which is how 0010 D32 said arbitration should be approached (D2, as revised).
- **Why asserted at platform assembly.** The inventory (D1) makes the whole relation computable where the platform is assembled — 0019 D6's generation step — so an over-subscribed or unfulfilled contract names itself before any module deploys (D1, D2).

## #TransformerRegistration (NEW)

### Definition

A cluster-scoped custom resource through which a provider module registers its catalog's transformers, shipped among the module's rendered resources. The CR is a **claim**, not a fact: the Platform reconciler validates it and records acceptance, so there remains exactly one writer to the effective set and one place to reject (D3). It is never authored as a raw object: it is the rendered output of D9's authoring surface — a `transformer-registration` `#Resource` contract in catalog_opm, rendered by a catalog_opm transformer — with every spec field derived or stamped rather than hand-written (D11), and its name instance-derived (D12). The authoring-surface shapes are not core delta and live in `../contracts/contracts.cue`. `target.cue` splits the CR as `#TransformerRegistrationSpec` (the claim) and `#TransformerRegistrationStatus` (the verdict); the Go types land in `opm-operator/api/v1alpha1/`, and this section specifies the CUE-level contract they must satisfy.

### Shape

```cue
#TransformerRegistrationSpec: {
	catalog!: #ModulePathType
	version!: #VersionType // scalar, per 0010 D14 — nothing resolves it
	providerRef!: {name!: string, namespace!: string}
	provides!: [...#ContractFQNType]
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
- `catalog` MUST name a published catalog artifact: acceptance MUST import its root package and require a `#Catalog` value, refusing any other artifact kind by shape (D10). Transformer code MUST NOT ride the CR in any form; the registry is the sole code channel.
- `providerRef` MUST be stamped by the rendering transformer from instance metadata and MUST NOT be an authorable field of the contract's spec (D11).
- The CR's name MUST be instance-derived (dot-joined `namespace.name`, D12), so a duplicate provider is refused at acceptance naming the claimant rather than colliding at apply.
- `provides` MUST be verified against the subscribed catalogs' contract maps (D1) **and** for exact equality against the reconciler's re-derivation of the provider set from the fetched catalog (D11); drift in either direction MUST reject the claim naming both lists. A claim naming a contract no subscribed catalog defines MUST be rejected at acceptance.
- `version` MUST be scalar: the value written is the value used, with nothing to resolve (0010 D14).
- Activation MUST be gated on `providerRef` being Ready, so a transformer never registers ahead of its CRDs; `active` MUST imply `accepted`. The readiness aggregation MUST NOT let the registration CR gate its own package (OQ11).
- Acceptance MUST be centralized in the Platform reconciler; accepted claims MUST be recorded in `Platform.status.registry`, never written into the Platform CR's spec.
- Deletion MUST be refused while `dependentInstances > 0`, naming the count.
- A claim naming a contract already provided by an active subscription or registration MUST be rejected (0010 D37's one-provider rule, kept by D2).
- A claim whose catalog requires a build the platform does not run MUST be refused at this acceptance gate, so the failure names the provider: per shared OPM-namespace path, the provider catalog's committed `cue.mod` requirement MUST be ≤ the platform's resolved version within the same major (0019 D18's comparison; exact under GA additive discipline, best-effort pre-GA — D8). The rejection reason MUST note the conservative case (lower the requirement if unused).

### Rationale

- **Why a CR rather than an event or a convention.** Three properties fall out of it being an object: activation is health-gated (the thing a static subscription structurally cannot express), removal is refusable while consumers depend on it, and the effective set is enumerable (D3).
- **Why cluster-scoped.** The objection to a second registration path was the privilege, not the mechanism — a transformer is arbitrary CUE producing arbitrary Kubernetes objects — and a cluster-scoped CR resolves that against a permission model the operator already enforces instead of inventing one (D3).
- **Why not an annotation on the ModulePackage.** That puts a cluster-scoped privilege on a namespaced object — exactly the escalation the CR prevents — and gives no home for acceptance, health, or a finalizer (D3, alternatives).
- **Why status, not a webhook writing spec.** A mutating webhook would make the Platform CR's spec no longer author-owned, so a GitOps reconciler and the webhook fight over the same field; status is the correct home for a derived set (D3, alternatives).

## #EffectiveRegistry (NEW)

### Definition

The union platform-package generation (0019 D6) consumes and `Platform.status.registry` reports: the subscriptions authored in the Platform CR's spec (the static path) unified with accepted-and-active `TransformerRegistration` claims (the dynamic path), plus the identity the operator stamps on the package it regenerates — a cache key no longer, since 0019 D8 deletes the store it originally served.

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
- The identity MUST cover the Platform CR's generation plus the active-claim set; every accepted or revoked claim moves it, regenerates the platform package (0019 D6), and re-renders every ModuleInstance. Regeneration's trigger, the key's exact serialization, and the blast radius are OQ8-gated.
- A consumer MUST be able to reproduce a cluster's render by pulling the operator-generated platform package (`opm platform pull`, D6): the pull delivers a build-local module carrying the committed resolution and the OQ8 identity, never a published artifact (0019 D6). D3 reintroduces resolution that 0010 D14 deleted; the restated property is "the platform file, plus one attributable fetch per claim-set change".

### Rationale

- **Why a named schema value.** Naming the effective set and its store key in the schema is what stops the invalidation question being answered incidentally in the reconciler (D3).
- **Why conflict rather than merge.** The spec subscription and the claim each name a build; merging would silently pick one, and the registry's whole point is that selection is a stated fact (D3).
- **Why enumerability matters.** The CR makes the effective set fetchable, which is most of 0010 D14's reproducibility value back — the remainder is exactly OQ3 (D3).
