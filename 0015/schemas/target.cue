// Target schema for enhancement 0015 — Catalog Contracts and Transformer
// Registration.
//
// These shapes describe the target surface across three layers: what a
// #Catalog publishes (D1), how a contract with several implementations is
// routed (D2), and what a registration claim is (D3). They are written
// standalone rather than importing opmodel.dev/core, so the entry vets
// without a registry round-trip; the types they mirror are named in comments.
//
// Delta manifest — every top-level definition, classified against
// opmodel.dev/core@v2 (core/src/*.cue). MIRROR = an unchanged core type
// restated narrowly for this file's self-containment; mirrors are NOT part
// of the proposed delta and get no section in spec.md.
//
//   #ModulePath                     MIRROR   core #ModulePathType (types.cue) — regex kept, rune bounds dropped
//   #PackagePath                    MIRROR   core #PackagePathType (types.cue) — regex kept, rune bounds dropped
//   #ContractFQN                    MIRROR   core #ContractFQNType (types.cue) — collapsed to one segment class
//   #ImplFQN                        MIRROR   core #ImplFQNType (types.cue) — build-metadata (+…) tail dropped
//   #Name                           MIRROR   core #NameType (types.cue) — regex kept, rune bounds dropped
//   #Version                        MIRROR   core #VersionType (types.cue) — simplified pre-release tail
//   #ContractKind                   MIRROR   the kind-segment vocabulary of core's kindPrefix (identity_package.cue, 0010 D21), contract kinds only
//   #Fulfilment                     MIRROR   the fulfilment disjunction on core #Resource/#Trait (0010 D37) — values unchanged; D37's arity rule is asserted by #ContractRouting
//   #PublishedContract              NEW      (D1) the member value a catalog publishes per contract; provenance stamped, never authored at the leaf
//   #CatalogContractMaps            CHANGED  vs core@v2 #Catalog (catalog.cue) — #resources/#traits/#blueprints added beside #transformers, same stamping pattern constraint; stated standalone here
//   #ContractInventory              NEW      (D1) the defined × required cross — under 0019 D5 a fold over the platform's embedded catalogs; Platform readiness and `opm platform check` read it
//   #ContractRouting                NEW      (D2/D5) the arity relation: 0010 D37's exactly-one-provider rule stands (D2, as revised); catalog buckets unconstrained here — D5's comparable-predicate guard is OQ9/OQ10-gated
//   #TransformerRegistrationSpec    NEW      (D3) the claim a provider module ships
//   #TransformerRegistrationStatus  NEW      (D3) what the Platform reconciler decides about a claim
//   #TransformerRegistration        NEW      (D3) the cluster-scoped CR: spec + status
//   #Subscription                   MIRROR   the Platform CR's subscription coordinate (opm-operator platform_types.go) — core's own registry entry becomes #CatalogEntry {enable, #catalog} under 0019 D5; the scalar shape survives only CR-side, as what 0019 D6's generator consumes
//   #EffectiveRegistry              NEW      (D3) spec subscriptions unified with active claims, and the regenerated platform package's identity (OQ3, OQ8)
//
// Unresolved fields carry `// OQN:` markers pointing at ../03-decisions.md.
package schema

// ---------------------------------------------------------------------------
// Shared vocabulary — mirrors of core types, narrowed to what this entry needs.
// ---------------------------------------------------------------------------

// A CUE module path carrying a major suffix (core #ModulePathType after
// enhancement 0010 D1). Example: "opmodel.dev/catalogs/opm@v1".
#ModulePath: =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*@v[0-9]+$"

// A package path with no major suffix — what a primitive declares
// (core #PackagePathType, 0010 D1). Example: "opmodel.dev/catalogs/opm/traits".
#PackagePath: =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*$"

// A contract key: package path, kind segment, name, and the contract's own
// API version (0010 D4). Example:
//   "opmodel.dev/catalogs/opm/traits/backup@v1beta1"
#ContractFQN: =~"^[a-z0-9._/-]+@v[0-9]+((alpha|beta)[0-9]+)?$"

// An implementation key: the same shape ending in a build SemVer (0010 D4).
// Example: "opmodel.dev/catalogs/k8up/transformers/backup@1.2.0"
#ImplFQN: =~"^[a-z0-9._/-]+@[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$"

#Name:    =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"
#Version: =~"^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$"

#ContractKind: "resources" | "traits" | "blueprints"

// Where a contract's fulfilment comes from (0010 D37). Unchanged by this
// entry; restated because #ContractRouting asserts D37's arity rule on it.
#Fulfilment: *"catalog" | "provider"

// ---------------------------------------------------------------------------
// D1 — #Catalog publishes its contracts as members.
// ---------------------------------------------------------------------------

// One published contract, as a catalog member. `modulePath` and
// `catalogVersion` are STAMPED by the catalog rather than authored at the
// leaf — the same mechanism core/src/catalog.cue already applies to
// #transformers, and the reason a transformer's provenance is unforgeable
// today. Extending the stamp to contracts is what makes a primitive's owning
// catalog structural, closing what 0010 D17 records as not delivered.
#PublishedContract: {
	name!:           #Name
	kind!:           #ContractKind
	modulePath!:     #PackagePath // stamped
	apiVersion!:     =~"^v[0-9]+((alpha|beta)[0-9]+)?$"
	catalogVersion!: #Version // stamped
	fqn!:            #ContractFQN
	fulfilment:      #Fulfilment

	description?: string
}

// The three member maps added to #Catalog beside #transformers, each keyed by
// the member's own contract FQN and each stamping provenance onto its values.
//
// Expressed here as one struct so the stamping rule is stated once; in
// core/src/catalog.cue it lands as three sibling pattern constraints
// alongside the existing #transformers one.
#CatalogContractMaps: {
	// The catalog's identity, as core/src/catalog.cue's `M._ref` already
	// decomposes it. Label aliases (0001 D25, the same device catalog.cue's
	// `M=metadata` uses) carry the values across the pattern-constraint
	// boundary — a bare `catalogVersion: catalogVersion` inside the member
	// struct would self-reference and stamp nothing.
	RP=registryPath!:   #PackagePath
	CV=catalogVersion!: #Version

	#resources: [FQN=#ContractFQN]: #PublishedContract & {
		kind:           "resources"
		fqn:            FQN
		modulePath:     "\(RP)/resources"
		catalogVersion: CV
	}
	#traits: [FQN=#ContractFQN]: #PublishedContract & {
		kind:           "traits"
		fqn:            FQN
		modulePath:     "\(RP)/traits"
		catalogVersion: CV
	}
	#blueprints: [FQN=#ContractFQN]: #PublishedContract & {
		kind:           "blueprints"
		fqn:            FQN
		modulePath:     "\(RP)/blueprints"
		catalogVersion: CV
	}
}

// ---------------------------------------------------------------------------
// The defined × required cross, computable once contracts are members — under
// 0019 D5 a pure fold over the platform's embedded catalogs, derivable in core
// beside #composedTransformers.
// ---------------------------------------------------------------------------

// The cross of "defined by a subscribed catalog" against "required by an
// adapter on this platform". This is the value a Platform readiness condition
// and `opm platform check` both read, and the value #ContractRouting's arity
// rule is evaluated against.
//
// Without D1 the `defined` set is not computable: every derivation from a
// catalog walks #transformers only (measured pre-0019 at
// materialize/index.go:39-41; equally true of 0019's composed-map fold), so a
// contract no adapter demands is absent from the world entirely.
#ContractInventory: {
	// Every contract every subscribed catalog DEFINES.
	defined: [FQN=#ContractFQN]: #PublishedContract & {fqn: FQN}

	// Every contract at least one subscribed adapter REQUIRES, mapped to the
	// implementation keys that require it. Required demands only — optional
	// consumption is tolerance, not fulfilment (0010 D32).
	requiredBy: [#ContractFQN]: [...#ImplFQN]

	// A provider-fulfilled contract that is defined and required by nothing.
	// Under D1 this is nameable; before it, indistinguishable from a key that
	// exists nowhere. Drives Platform Ready=False/UnfulfilledContracts.
	unfulfilled: [...#ContractFQN]

	// A provider-fulfilled contract with more than one implementation —
	// refused per 0010 D37, which D2 (as revised) keeps unamended. The
	// inventory is what lets the refusal name both catalog paths.
	overSubscribed: [...#ContractFQN]

	// The platform is contract-ready when neither report has entries.
	ready: bool & (len(unfulfilled) == 0 && len(overSubscribed) == 0)
}

// ---------------------------------------------------------------------------
// D2/D5 — the arity relation.
// ---------------------------------------------------------------------------

// The arity rule: 0010 D37's exactly-one-provider, kept unamended by D2 (as
// revised 2026-08-20). Stated as the relation asserted on the platform value,
// at 0019 D6's generation step, for one contract.
#ContractRouting: {
	contract!:  #ContractFQN
	fulfilment: #Fulfilment

	// Implementation keys requiring this contract, across subscribed catalogs.
	implementations!: [...#ImplFQN]

	// Zero implementations is D1's `unfulfilled` — reportable at platform assembly
	// rather than deferred to a render (0010 D28).
	_fulfilled: bool & (len(implementations) > 0)

	// Exactly one provider (0010 D37). A second is `overSubscribed` in the
	// inventory and refused, naming both catalog paths; routing between
	// providers is a successor entry (D2).
	_routed: bool
	if fulfilment == "provider" {
		_routed: len(implementations) <= 1
	}
	if fulfilment == "catalog" {
		// A "catalog"-fulfilled contract legitimately feeds many different
		// outputs — catalog_opm's #ContainerResource bucket holds 8
		// transformers — so no arity rule binds here. The duplicate-adapter
		// case is refused by D5's comparable-predicate guard, whose detection
		// shape is OQ9 and detection site OQ10; until OQ9 resolves the guard
		// is not expressible in this file.
		_routed: true
	}

	ok: bool & (_fulfilled && _routed)
}

// ---------------------------------------------------------------------------
// D3 — transformer registration.
// ---------------------------------------------------------------------------

// The claim a provider module ships. Cluster-scoped, so a tenant
// ServiceAccount cannot create one — which is the RBAC gate, using the
// impersonation opm-operator already performs during apply.
#TransformerRegistrationSpec: {
	// The catalog whose transformers this registers.
	catalog!: #ModulePath

	// The build. Scalar, per 0010 D14 — nothing resolves it.
	version!: #Version

	// The provider's own ModulePackage. Activation is gated on this being
	// Ready, so a transformer never registers ahead of its CRDs.
	providerRef!: {
		name!:      string
		namespace!: string
	}

	// What the registration claims to provide. VERIFIED against the
	// subscribed catalogs' contract maps (D1) rather than trusted — a claim
	// naming a contract no catalog defines is rejected at acceptance.
	provides!: [...#ContractFQN]

}

// What the Platform reconciler decides about a claim. Acceptance is
// centralized so exactly one writer reaches the effective set.
#TransformerRegistrationStatus: {
	// Passed validation: catalog resolvable, `provides` all defined by a
	// subscribed catalog, none already provided (0010 D37, kept by D2).
	accepted: bool | *false

	// Accepted AND providerRef is Ready. Only active registrations reach the
	// effective registry.
	active: bool | *false

	// Why a claim was refused, or why an accepted claim is inactive.
	reason?: string

	// Instances demanding a contract in `provides`. The finalizer refuses
	// deletion while this is non-zero, naming the count.
	dependentInstances: int & >=0 | *0

	// A claim cannot be live without having passed validation.
	_activeImpliesAccepted: true & (!active || accepted)
}

#TransformerRegistration: {
	spec!:   #TransformerRegistrationSpec
	status!: #TransformerRegistrationStatus
}

// ---------------------------------------------------------------------------
// The effective registry, and the regenerated platform package's identity.
// ---------------------------------------------------------------------------

// The Platform CR's subscription coordinate: a scalar version, nothing
// resolved. Under 0019 D6 the CR names coordinates and the operator generates
// the platform package; the generated module's registry entry embeds the
// catalog itself (0019 D5's #CatalogEntry), so this scalar shape is CR-side
// input to generation, not core's registry shape.
#Subscription: {
	enable:   bool | *true
	version!: #Version
}

// Spec subscriptions unified with active claims. This is what platform-package
// generation (0019 D6) consumes and what Platform.status.registry reports.
//
// resolved-by-D6: this value existing only in cluster state was the tension
// with 0010 D14's "the platform file is the lockfile"; the answer is fetch —
// `opm platform pull` retrieves the operator-generated platform package
// (the authoritative bytes, identity per OQ8), and a local build against it
// reproduces the cluster's render.
#EffectiveRegistry: {
	// Authored in Platform.spec.registry — the static path.
	subscriptions: [#ModulePath]: #Subscription

	// Accepted and active TransformerRegistrations — the dynamic path.
	claims: [#ModulePath]: #TransformerRegistration & {
		status: active: true
	}

	// A claim naming a path the spec already subscribes to is a conflict, not
	// a merge: two sources would then disagree about the build.
	_conflicts: [for p, _ in claims for q, _ in subscriptions if p == q {p}]
	_noConflict: true & (len(_conflicts) == 0)

	// The identity of the platform package the operator regenerates from this
	// set (0019 D6; the store this originally keyed is deleted by 0019 D8).
	// Every accepted or revoked claim moves it, regenerates the package, and
	// re-renders every ModuleInstance — trigger, identity and blast radius
	// per OQ8.
	key!: {
		generation!: int
		claims: [...string] // sorted "catalog@version" of every active claim
	}
}
