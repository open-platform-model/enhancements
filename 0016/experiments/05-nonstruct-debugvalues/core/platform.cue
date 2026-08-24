package core

// #Subscription declares that a #Platform pulls primitives from a catalog
// published at a given CUE module path, and names the single build it pulls.
// The map key on #Platform.#registry carries the path; #Subscription carries
// the enable flag and the version.
//
// `version` is required and scalar: the value written IS the value
// materialized. No range to resolve, no allow/deny to arbitrate, no
// highest-published default. Catalog selection is therefore a pure function
// of committed source — git-identical inputs materialize identical catalog
// bytes on any day, from any machine, with no lockfile. A prerelease is
// selected by being written down; there is no maturity inference and no flag
// to opt into one (enhancement 0010 D37).
//
// One subscription per catalog path, enforced by CUE map semantics (D13).
// Two builds of one catalog is TWO PLATFORMS — the permanent rule, not a
// staging limitation. Every use of breadth collapses on inspection: union
// coverage across builds describes a catalog that dropped a transformer
// without saying so, which must fail loudly rather than be papered over;
// gradual migration does not structurally exist, because a module demands
// contracts and never a transformer (D4); two API versions of one contract
// already ship side by side in a single build; and testing a new build
// beside the old is two platforms, which names both behaviours and costs
// nothing hidden.
#Subscription: {
	enable:   bool | *true
	version!: #VersionType // Example: "1.2.0", "1.0.0-alpha.2"
}

// #Platform — path-keyed registry of catalog subscriptions plus
// kernel-filled materialization slots.
//
// Authors write #registry. The kernel's Materialize step (library-side)
// pulls the build each subscription NAMES — there is nothing to resolve,
// because the platform file is the resolution — indexes top-level
// #ComponentTransformer values into #composedTransformers, and computes a
// #matchers reverse index. The CUE-level #Platform value is therefore a
// spec; the kernel populates the materialization slots on a separate
// MaterializedPlatform twin (D14 — Materialize is explicit and
// caller-driven; the kernel holds no cache).
//
// Reshaped by enhancement 0001 (supersedes the prior Id-keyed
// #ModuleRegistration model). #knownResources / #knownTraits removed:
// primitives surface transitively via materialized transformers'
// required/optional maps.
#Platform: {
	kind: "Platform"

	metadata: {
		name!:        #NameType
		description?: string
		labels?:      #LabelsAnnotationsType
		annotations?: #LabelsAnnotationsType
	}

	// Informational. Future enhancement may enforce type-vs-transformer
	// compatibility; today it is an authored discriminator the matcher
	// does not consult (014 OQ2).
	type!: string

	// Path-keyed: map key is the catalog's CUE module path
	// (e.g. "opmodel.dev/catalogs/opm"). Exactly one subscription per
	// path — CUE map semantics enforce uniqueness (D13).
	#registry: [Path=#ModulePathType]: #Subscription

	// Kernel-filled after Materialize. Both optional because the
	// CUE-level #Platform value is a spec; the kernel populates these
	// on the materialized twin. Materialize is explicit and caller-driven
	// (D14 — no kernel cache).
	#composedTransformers?: #TransformerMap
	#matchers?: {
		resources: [#ContractFQNType]: [...#ComponentTransformer]
		traits: [#ContractFQNType]: [...#ComponentTransformer]
	}
}
