// Target schema for enhancement 0015 — Catalog Contracts, Provider Classes,
// and Transformer Registration.
//
// These shapes describe the target surface across three layers: what a
// #Catalog publishes (D1), how a contract with several implementations is
// routed (D2), and what a registration claim is (D3). They are written
// standalone rather than importing opmodel.dev/core, so the entry vets
// without a registry round-trip; the types they mirror are named in comments.
//
// Unresolved fields carry `// OQN:` markers pointing at ../03-decisions.md.
package schema

import "strings"

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
// entry; restated because D2 amends what "provider" implies about arity.
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

	// D2: a provider-fulfilled contract MAY be routed by class. Absent means
	// the contract has exactly one implementation path and needs no routing.
	classed?: bool

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
	// decomposes it.
	registryPath!:   #PackagePath
	catalogVersion!: #Version

	#resources: [FQN=#ContractFQN]: #PublishedContract & {
		kind:           "resources"
		fqn:            FQN
		modulePath:     "\(registryPath)/resources"
		catalogVersion: catalogVersion
	}
	#traits: [FQN=#ContractFQN]: #PublishedContract & {
		kind:           "traits"
		fqn:            FQN
		modulePath:     "\(registryPath)/traits"
		catalogVersion: catalogVersion
	}
	#blueprints: [FQN=#ContractFQN]: #PublishedContract & {
		kind:           "blueprints"
		fqn:            FQN
		modulePath:     "\(registryPath)/blueprints"
		catalogVersion: catalogVersion
	}
}

// ---------------------------------------------------------------------------
// What materialize computes once contracts are members.
// ---------------------------------------------------------------------------

// The cross of "defined by a subscribed catalog" against "required by an
// adapter on this platform". This is the value a Platform readiness condition
// and `opm platform check` both read, and the value D2's arity rule is
// evaluated against.
//
// Without D1 the `defined` set is not computable: materialize walks
// #transformers only (library/opm/materialize/index.go:39-41), so a contract
// no adapter demands is absent from the world entirely.
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

	// A contract with more implementations than the class vocabulary routes.
	// Replaces 0010 D37's "more than one is an error" (D2).
	unroutable: [...#ContractFQN]

	// The platform is contract-ready when neither report has entries.
	ready: bool & (len(unfulfilled) == 0 && len(unroutable) == 0)
}

// ---------------------------------------------------------------------------
// D2 — provider classes.
// ---------------------------------------------------------------------------

// One entry in the vocabulary a platform publishes for a contract with more
// than one implementation. Modelled on StorageClass / IngressClass /
// GatewayClass / VolumeSnapshotClass: the admin names it, the consumer
// references the name, and one is the default so most consumers say nothing.
#ProviderClass: {
	// The contract being routed.
	contract!: #ContractFQN

	// The class name a module selects by. Platform-published vocabulary — a
	// module NEVER names the catalog below.
	name!: #Name

	// The catalog whose transformer implements this class.
	catalog!: #ModulePath

	// Exactly one class per contract carries this.
	default: bool | *false
}

// The platform-side vocabulary, keyed by contract then class name. Keyed by
// contract rather than flat because a cluster with a default backup class and
// a default ingress class has two independent defaults.
#ClassVocabulary: {
	[Contract=#ContractFQN]: [ClassName=#Name]: #ProviderClass & {
		contract: Contract
		name:     ClassName
	}
}

// The label key a class projects. One key per contract, so two contracts'
// classes cannot collide in a component's unified matchLabels.
#ClassLabelKey: {
	contract!: #ContractFQN
	// "…/traits/backup@v1beta1" → "traits.backup.opmodel.dev/class"
	// OQ2: the exact derivation is settled with the default-fill placement;
	// what is fixed is that it is per-contract and derived, never authored.
	out: string & strings.Replace(contract, "/", ".", -1) + "/class"
}

// The demand side: what a contract carrying a class projects upward. The
// projection IS the whole matcher integration — 0010 D36 unifies
// #Component.matchLabels from its attached primitives' wholesale, and
// #ComponentTransformer.requiredLabels selects on that field.
// compile/match.go:344-360 is unchanged, and that is load-bearing.
#ClassedContract: {
	contract!: #ContractFQN

	// Authored by the module, or filled from the platform default (OQ2).
	class?: #Name

	_key: (#ClassLabelKey & {contract: contract}).out

	// Absent class → no label → the contract is unrouted and the platform's
	// default must have been filled in before match. Present → exactly one
	// transformer's requiredLabels can be satisfied, because class values are
	// mutually exclusive by construction.
	matchLabels: {
		if class != _|_ {
			(_key): class
		}
	}
}

// The arity rule after D2, replacing 0010 D37's exactly-one. Stated as the
// relation materialize asserts for one provider-fulfilled contract.
#ContractRouting: {
	contract!:  #ContractFQN
	fulfilment: #Fulfilment

	// Implementation keys requiring this contract, across subscribed catalogs.
	implementations!: [...#ImplFQN]

	// The classes the platform publishes for it.
	classes!: [Name=#Name]: #ProviderClass & {name: Name}

	// Zero implementations is D1's `unfulfilled` — reportable at materialize
	// rather than deferred to a render (0010 D28).
	_fulfilled: bool & (len(implementations) > 0)

	// One implementation needs no vocabulary; more than one needs one class
	// each, and exactly one default. This is the whole of what replaces
	// "exactly one provider".
	_routed: bool
	if fulfilment == "provider" {
		if len(implementations) <= 1 {
			_routed: true
		}
		if len(implementations) > 1 {
			_routed: len(classes) == len(implementations)
		}
	}
	if fulfilment == "catalog" {
		// OQ1: a "catalog"-fulfilled contract legitimately feeds many
		// different outputs — catalog_opm's #ContainerResource bucket holds 8
		// transformers — so no arity rule binds here. The duplicate-adapter
		// case within this fulfilment is OQ1's, and it is deliberately not
		// constrained by this shape.
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

	// The class this registration serves, for a contract with more than one
	// implementation (D2). Absent means the contract has a single
	// implementation path.
	class?: #Name
}

// What the Platform reconciler decides about a claim. Acceptance is
// centralized so exactly one writer reaches the materialized set.
#TransformerRegistrationStatus: {
	// Passed validation: catalog resolvable, `provides` all defined by a
	// subscribed catalog, class free.
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
// The effective registry, and what the operator's store keys on.
// ---------------------------------------------------------------------------

// A subscription as 0010 D14 leaves it: a scalar version, nothing resolved.
#Subscription: {
	enable:   bool | *true
	version!: #Version
}

// Spec subscriptions unified with active claims. This is what materialize
// consumes and what Platform.status.registry reports.
//
// OQ3: this value existing only in cluster state is the tension with 0010
// D14's "the platform file is the lockfile". Whether it is exported to a
// #Platform file, written back to git, or fetched on demand is unresolved,
// and it blocks draft → accepted.
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

	// What the operator's platform.Store keys on, replacing the Platform CR's
	// .metadata.generation alone (internal/platform/store.go). Every accepted
	// or revoked claim moves this and re-renders every ModuleInstance —
	// blast radius per OQ6.
	key!: {
		generation!: int
		claims: [...string] // sorted "catalog@version" of every active claim
	}
}
