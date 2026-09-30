package core

import (
	"list"
	"strings"
)

// WHY an import instead of a version string: a version string is inert data
// nothing in a CUE build resolves, so the kernel pulled the build out of band
// and handed the result back on a materialized twin. The entry carries the
// catalog itself, resolved through the platform module's cue.mod like every
// other dependency, which is what lets one render build evaluate the
// instance, the platform and the catalog together (0019:D5, D9).
// Catalog selection stays a pure function of committed source (0010:D14):
// cue.mod is committed source, and a prerelease is still selected by naming
// it there. SPEC.md § 3.4 Rationale, "Why an import instead of a version
// string", "Why the version is derived and not authored" and "Why the whole
// transformer map".

// WHY #CatalogEntry: 0019:D13.

// #CatalogEntry declares that a #Platform admits a catalog, by carrying the
// imported catalog value whole on #catalog. `version` and `#transformers` are
// derived readouts, never authored; an expected `version` stamped at
// platform-generation time unifies with the readout, so wrong bytes are a
// build conflict naming the entry. One entry per catalog path; two builds of
// one catalog is two platforms. See SPEC.md § 3.4.
#CatalogEntry: {
	enable: bool | *true

	// The imported catalog, embedded whole.
	#catalog: #Catalog

	// WHY the readouts: 0019:D13.

	// Derived readouts of the catalog's release-stamped identity. Neither
	// is authored; #Catalog.metadata.version! has no development default,
	// so an unstamped catalog refuses as incomplete rather than rendering
	// wrong. A generation-time expected `version` stamp unifies with the
	// readout, which is the tripwire.
	version:       #catalog.metadata.version
	#transformers: #TransformerMap & #catalog.#transformers
}

// WHY no per-contract routing relation: 0015's pre-draft named a
// `ContractRouting` a caller unifies per contract; `overSubscribed` and
// `routable` state the arity rule for every contract at once and
// `requiredBy` is the list the relation took as input, so the relation
// would be a second statement of the same two facts with no consumer
// (Principle V). SPEC.md § 3.4 Rationale, "Why no per-contract routing
// relation".

// WHY #ContractInventory: 0015:D1/D2/D5/D18.

// #ContractInventory: what a #Platform derives about the contracts its
// enabled catalogs define and its enabled transformers require: the members
// and their defining catalogs, the required demands per contract, the three
// reports and the three booleans they imply. Lives on #Platform.#contracts,
// derived and never authored; it reports and never refuses.
// See SPEC.md § 3.4.
#ContractInventory: {
	// Every contract every enabled entry's catalog lists, keyed by contract
	// FQN and carrying the member value as the catalog lists it (the
	// primitive itself, provenance stamped).
	defined: [#ContractFQNType]: #Resource | #Trait | #Blueprint

	// Contract FQN to the registry key (module path) of the catalog listing
	// it: the value every diagnostic prints beside the contract.
	definedBy: [#ContractFQNType]: #ModulePathType

	// WHY requiredBy counts required demands only: 0010:D32.

	// Contract FQN to the implementation FQNs of every enabled transformer
	// whose requiredResources or requiredTraits name it. Required demands
	// only, because optional consumption is tolerance, not fulfilment;
	// a defined contract nothing requires maps to an empty list.
	requiredBy: [#ContractFQNType]: [...#ImplFQNType]

	// WHY unfulfilled: 0015:D18.

	// Defined provider-fulfilled resources and traits with no providedBy
	// key. A report the operator surfaces as a non-gating condition; never
	// a refusal. Blueprints never appear, nor does a contract no enabled
	// catalog defines.
	unfulfilled: [...#ContractFQNType]

	// WHY providedBy: 0010:D37, 0015:D2/D18. It is the one provider count:
	// the render build reads it instead of keeping its own, so the refusal
	// and the generation gate cannot disagree. Keyed by registry key, major
	// included, because the stamped transformer modulePath is major-free.

	// Provider-fulfilled contract FQN to the sorted registry keys (path@vN)
	// of the enabled entries whose transformers require it, whether or not
	// an enabled entry defines it. Present exactly when some entry provides
	// it. See SPEC.md § 3.4.
	providedBy: [#ContractFQNType]: [...#ModulePathType]

	// WHY overSubscribed: 0010:D37.

	// Keys of providedBy with more than one registry entry, including a
	// contract no enabled entry defines. Two majors of one catalog are two
	// providers; two adapters in one entry are one. What the generation
	// step and the render build refuse on.
	overSubscribed: [...#ContractFQNType]

	// Pairs of enabled transformers whose match predicates are comparable
	// over at least one shared catalog-fulfilled contract: `broader`
	// matches every component `narrower` matches. Provider-fulfilled
	// contracts are `overSubscribed`'s business, not this list's.
	comparable: [...{
		broader:  #ImplFQNType
		narrower: #ImplFQNType
		contracts: [...#ContractFQNType]
	}]

	// True exactly when nothing is unfulfilled. A report, never a gate.
	fulfilled: bool & (len(unfulfilled) == 0)

	// True exactly when nothing is over-subscribed. The gate the generation
	// step (operator, CLI) reads; `core` itself refuses nothing on it.
	routable: bool & (len(overSubscribed) == 0)

	// True exactly when nothing is comparable. The second gate the
	// generation step (operator, CLI) reads; `core` itself refuses
	// nothing on it.
	discriminated: bool & (len(comparable) == 0)
}

// WHY the fold copies per entry rather than unifying entry maps: the
// catalog's provenance stamp (0010:D25) refuses a foreign transformer
// unified into another catalog's member map, so map-level unification fails
// on healthy multi-catalog input (measured,
// enhancements/0019/experiments/05-match-in-one-build). Two entries writing
// one composed FQN still unify at that key: agreement collapses, divergent
// bodies conflict loudly. #matchers is removed (0019:D17): its only reader
// was the Go matcher the render-path collapse deletes, and the in-build
// matching glue folds its own buckets from #composedTransformers in a shape
// core's list-valued buckets never matched. SPEC.md § 3.4 Rationale, "Why
// the key binding is structural rather than a check", "Why the fold copies
// rather than unifies" and "Why #matchers is removed rather than derived".

// A #Platform is a path-keyed registry of catalog entries, each carrying its
// imported catalog, plus the derived #composedTransformers fold over the
// enabled entries and the derived #contracts inventory. A platform value is
// complete on its own: no Materialize step, no materialized twin, no reverse
// index. See SPEC.md § 3.4.
#Platform: {
	kind: "Platform"

	metadata: {
		name!:        #NameType
		description?: string
		labels?:      #LabelsAnnotationsType
		annotations?: #LabelsAnnotationsType
	}

	// WHY type: 0014:OQ2.

	// Informational. Future enhancement may enforce type-vs-transformer
	// compatibility; today it is an authored discriminator the matcher does not
	// consult.
	type!: string

	// WHY #registry: 0019:D5; 0001:D13.

	// Path-keyed: the map key is the catalog's CUE module path, bound into the
	// embedded catalog's metadata.modulePath, so key-versus-import drift is a
	// build conflict naming the entry. Exactly one entry per path; CUE map
	// semantics enforce uniqueness.
	#registry: [Path=#ModulePathType]: #CatalogEntry & {#catalog: metadata: modulePath: Path}

	// Derived, never runtime-filled: the fold of every enabled entry's
	// #transformers, copied per entry by comprehension (see the WHY block
	// above). Empty when the registry is empty or fully disabled.
	#composedTransformers: {
		for _, entry in #registry if entry.enable {
			for fqn, tf in entry.#transformers {(fqn): tf}
		}
	}

	// WHY the inventory reports rather than asserts (0015:D18): an
	// assertion inside #Platform is a bottom on the first over-subscribed
	// contract, so the value cannot name it and every diagnostic reads a
	// failed value. `routable: false` is the value the generation step
	// (operator, CLI) refuses on, naming `overSubscribed` and `definedBy`;
	// `fulfilled: false` is surfaced as a non-gating condition and gates
	// nothing, which an in-schema assertion could not express.
	//
	// WHY over-subscription counts registry entries, not transformers: one
	// provider catalog may carry two adapters over one contract (k8up's
	// Schedule and PreBackupPod), so counting transformers refuses its own
	// shape. The key is the registry key, major included: the stamped
	// transformer metadata.modulePath is major-free, so it cannot tell
	// k8up@v2 from k8up@v3, and the render build counts them as two.
	// Fulfilment is read off each transformer's own requirement, so
	// providers of a contract no enabled entry defines are counted too.
	//
	// WHY comparability folds all three required demand kinds: what keeps a
	// shared catalog-fulfilled bucket legal is a differing required LABEL
	// VALUE *or* a distinct required TRAIT, not labels alone. Measured
	// against catalog_opm `opm` 4.4.0: in the ContainerResource bucket
	// `hpa` declares no requiredLabels while `deployment` declares
	// `workload-type: stateless`, so on labels alone `hpa`'s predicate is a
	// subset of `deployment`'s and the report would falsely name a pair that
	// is supposed to fire together; their requiredTraits (the catalog's
	// ScalingTrait against none) is what separates them. SPEC.md § 3.4
	// Rationale, "Why the inventory reports and does not refuse", "Why
	// over-subscription counts registry entries" and "Why the predicate is
	// every required demand, not only labels".

	// Derived, never authored or runtime-filled: the contract inventory,
	// folded from every enabled entry's #resources, #traits and #blueprints,
	// crossed with the required demands of the enabled entries' transformers.
	// Empty, fulfilled and routable on an empty or fully disabled registry.
	// An over-subscribed platform still evaluates; refusing it is the
	// generation step's act. See SPEC.md § 3.4.
	#contracts: #ContractInventory & {
		defined: {
			for _, entry in #registry if entry.enable {
				for fqn, r in entry.#catalog.#resources {(fqn): r}
				for fqn, t in entry.#catalog.#traits {(fqn): t}
				for fqn, b in entry.#catalog.#blueprints {(fqn): b}
			}
		}
		definedBy: {
			for path, entry in #registry if entry.enable {
				for fqn, _ in entry.#catalog.#resources {(fqn): path}
				for fqn, _ in entry.#catalog.#traits {(fqn): path}
				for fqn, _ in entry.#catalog.#blueprints {(fqn): path}
			}
		}

		// The demand maps are optional on #ComponentTransformer, and an
		// unguarded `for` over an absent one fails the whole platform; the
		// presence guards are sound because a present map is concrete.
		requiredBy: {
			for fqn, _ in defined {
				(fqn): [
					for k, tf in #composedTransformers if tf.requiredResources != _|_ for req, _ in tf.requiredResources if req == fqn {k},
					for k, tf in #composedTransformers if tf.requiredTraits != _|_ for req, _ in tf.requiredTraits if req == fqn {k},
				]
			}
		}

		// Per provider-fulfilled contract some enabled transformer requires,
		// the set of registry keys whose transformers require it. Iterated
		// per entry, not over #composedTransformers, so the key stays
		// visible; the demand maps are presence-guarded as for requiredBy.
		_providerSet: {
			for rkey, entry in #registry if entry.enable
			for _, tf in entry.#transformers {
				if tf.requiredResources != _|_ {
					for fqn, req in tf.requiredResources if req.fulfilment == "provider" {(fqn): (rkey): true}
				}
				if tf.requiredTraits != _|_ {
					for fqn, req in tf.requiredTraits if req.fulfilment == "provider" {(fqn): (rkey): true}
				}
			}
		}
		providedBy: {for fqn, ps in _providerSet {(fqn): list.Sort([for k, _ in ps {k}], list.Ascending)}}
		unfulfilled: [for fqn, c in defined if c.kind != "Blueprint" if c.fulfilment == "provider" if providedBy[fqn] == _|_ {fqn}]
		overSubscribed: [for fqn, ps in providedBy if len(ps) > 1 {fqn}]

		// WHY _predicates: 0010:D32.

		// Each enabled transformer's match predicate as a canonical token set:
		// resource:, trait: and label:<key>=<value> tokens from the three REQUIRED
		// demand maps, each presence-guarded because all three are optional.
		// Optional demands never contribute.
		_predicates: {
			for fqn, tf in #composedTransformers {
				(fqn): {
					if tf.requiredResources != _|_ {for r, _ in tf.requiredResources {"resource:\(r)": true}}
					if tf.requiredTraits != _|_ {for t, _ in tf.requiredTraits {"trait:\(t)": true}}
					if tf.requiredLabels != _|_ {for k, v in tf.requiredLabels {"label:\(k)=\(v)": true}}
				}
			}
		}

		// Keyed by the SORTED pair, so a pair found in two buckets collapses
		// to one row carrying both contracts whatever order each bucket
		// lists it in (measured: position-derived keys double-report a
		// reversed bucket). Subset is tested by union cardinality, which
		// needs no probing for absent fields and yields both directions.
		_comparablePairs: {
			for cfqn, c in defined if c.kind != "Blueprint" if c.fulfilment == "catalog" {
				let _bucket = requiredBy[cfqn]
				for i, a in _bucket for j, b in _bucket if i < j {
					let _pa = _predicates[a]
					let _pb = _predicates[b]
					let _union = {for k, v in _pa {(k): v}, for k, v in _pb {(k): v}}
					let _aSubB = len(_union) == len(_pb)
					let _bSubA = len(_union) == len(_pa)
					if _aSubB || _bSubA {
						let _pair = list.Sort([a, b], list.Ascending)
						(strings.Join(_pair, "|")): {
							broader: [if _aSubB && _bSubA {_pair[0]}, if _aSubB {a}, b][0]
							narrower: [if _aSubB && _bSubA {_pair[1]}, if _aSubB {b}, a][0]
							contracts: (cfqn): true
						}
					}
				}
			}
		}
		comparable: [for _, r in _comparablePairs {{
			broader:  r.broader
			narrower: r.narrower
			contracts: [for c, _ in r.contracts {c}]
		}}]
	}
}
