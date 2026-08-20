// Concrete example instances for the 0015 delta — the test.
//
// Every value here unifies against target.cue, so `cue vet ./...` from this
// directory checks the delta's behaviour rather than its syntax. The cast is
// the one from 01-problem.md's Concrete Example: catalog_opm defines the
// provider-fulfilled backup trait, k8up and velero both implement it, and the
// platform routes between them with two classes. Derived values — stamps,
// label keys, readiness, routing verdicts — are pinned with hidden `_assert*`
// fields, so a change in behaviour is a build failure. Must-fail cases are
// commented out with the exact error text observed on 2026-08-20.
package schema

// The contract every example routes: catalog_opm's provider-fulfilled backup
// trait, and the two implementations competing for it.
_backupFQN:  "opmodel.dev/catalogs/opm/traits/backup@v1beta1"
_k8upImpl:   "opmodel.dev/catalogs/k8up/transformers/backup@1.2.0"
_veleroImpl: "opmodel.dev/catalogs/velero/transformers/backup@2.0.1"

// ─── D1: a catalog publishes contracts as members ───────────────────────────

// catalog_opm publishing one member of each kind. The leaves author name,
// apiVersion and fulfilment only — kind, fqn, modulePath and catalogVersion
// all arrive from the map's pattern constraint, which is the unforgeable-
// provenance property D1 extends from #transformers to contracts.
exCatalog: #CatalogContractMaps & {
	registryPath:   "opmodel.dev/catalogs/opm"
	catalogVersion: "1.4.0"

	#traits: (_backupFQN): {
		name:       "backup"
		apiVersion: "v1beta1"
		fulfilment: "provider"
		classed:    true
	}
	#resources: "opmodel.dev/catalogs/opm/resources/volume@v1": {
		name:       "volume"
		apiVersion: "v1"
	}
	#blueprints: "opmodel.dev/catalogs/opm/blueprints/stateless-workload@v1beta1": {
		name:       "stateless-workload"
		apiVersion: "v1beta1"
	}
}

// The stamps, pinned. These four are the observable core of D1: kind and fqn
// from the map, modulePath as registryPath + kind segment (major-free),
// catalogVersion as the catalog's own build.
_assertTraitKind:    exCatalog.#traits[_backupFQN].kind & "traits"
_assertTraitFqn:     exCatalog.#traits[_backupFQN].fqn & _backupFQN
_assertTraitPath:    exCatalog.#traits[_backupFQN].modulePath & "opmodel.dev/catalogs/opm/traits"
_assertTraitVersion: exCatalog.#traits[_backupFQN].catalogVersion & "1.4.0"
_assertResourcePath: exCatalog.#resources["opmodel.dev/catalogs/opm/resources/volume@v1"].modulePath & "opmodel.dev/catalogs/opm/resources"

// fulfilment defaults to "catalog" (0010 D37's default, unchanged here).
_assertResourceFulfilment: exCatalog.#resources["opmodel.dev/catalogs/opm/resources/volume@v1"].fulfilment & "catalog"

// ─── D1: the inventory materialize computes from the maps ───────────────────

// The healthy cross: backup is defined by a subscribed catalog and required
// by two implementations, and the class vocabulary below routes both — so
// neither report has entries and the platform is contract-ready.
exInventoryReady: #ContractInventory & {
	defined: (_backupFQN): {
		name:           "backup"
		kind:           "traits"
		modulePath:     "opmodel.dev/catalogs/opm/traits"
		apiVersion:     "v1beta1"
		catalogVersion: "1.4.0"
		fulfilment:     "provider"
		classed:        true
	}
	requiredBy: (_backupFQN): [_k8upImpl, _veleroImpl]
	unfulfilled: []
	unroutable: []
}
_assertInventoryReady: exInventoryReady.ready & true

// The zero case D1 makes nameable: the contract is defined, nothing requires
// it, and the platform is Ready=False before any module trips over it —
// instead of the pre-D1 state where the key simply exists nowhere.
exInventoryUnfulfilled: #ContractInventory & {
	defined: (_backupFQN): exInventoryReady.defined[_backupFQN]
	requiredBy: {}
	unfulfilled: [_backupFQN]
	unroutable: []
}
_assertInventoryNotReady: exInventoryUnfulfilled.ready & false

// ─── D2: the platform-published class vocabulary ────────────────────────────

// Two engines, two classes, one default — the topology 0010 D37 refused.
// contract and name arrive from the map keys; the leaf authors only the
// implementing catalog and the default marker.
exVocabulary: #ClassVocabulary & {
	(_backupFQN): {
		daily: {
			catalog: "opmodel.dev/catalogs/k8up@v1"
			default: true
		}
		archive: {
			catalog: "opmodel.dev/catalogs/velero@v1"
		}
	}
}
_assertClassContract: exVocabulary[_backupFQN].daily.contract & _backupFQN
_assertClassName:     exVocabulary[_backupFQN].archive.name & "archive"
_assertClassDefault:  exVocabulary[_backupFQN].archive.default & false

// The derived label key. OQ2 leaves the exact derivation open; pinning what
// target.cue computes today means settling OQ2 differently breaks this line
// rather than drifting silently.
exLabelKey: #ClassLabelKey & {contract: _backupFQN}
_assertLabelKey: exLabelKey.out & "opmodel.dev.catalogs.opm.traits.backup@v1beta1/class"

// ─── D2: the demand side — class projected as a matchLabel ──────────────────

// A contract carrying a class projects exactly one label, under the
// per-contract key. This projection is the whole matcher integration: it
// lands in #Component.matchLabels via 0010 D36 and is selected on by
// requiredLabels, with compile/match.go unchanged.
exClassedArchive: #ClassedContract & {
	contract: _backupFQN
	class:    "archive"
}
_assertProjectedLabel: exClassedArchive.matchLabels["opmodel.dev.catalogs.opm.traits.backup@v1beta1/class"] & "archive"
_assertOneLabelOnly:   len(exClassedArchive.matchLabels) & 1

// No class → no label. The demand is unrouted until the platform's default
// is filled in (before match — placement per OQ2).
exClassedUnfilled: #ClassedContract & {contract: _backupFQN}
_assertNoLabelYet: len(exClassedUnfilled.matchLabels) & 0

// ─── D2: the arity relation that replaces 0010 D37's exactly-one ────────────

// Two providers, one class each, one default: the motivating topology, and
// under D2 it is routable rather than refused.
exRoutingTwoProviders: #ContractRouting & {
	contract:   _backupFQN
	fulfilment: "provider"
	implementations: [_k8upImpl, _veleroImpl]
	classes: {
		daily: {
			contract: _backupFQN
			catalog:  "opmodel.dev/catalogs/k8up@v1"
			default:  true
		}
		archive: {
			contract: _backupFQN
			catalog:  "opmodel.dev/catalogs/velero@v1"
		}
	}
}
_assertTwoProvidersRouted: exRoutingTwoProviders.ok & true

// One implementation needs no vocabulary at all.
exRoutingSingle: #ContractRouting & {
	contract:   _backupFQN
	fulfilment: "provider"
	implementations: [_k8upImpl]
	classes: {}
}
_assertSingleRouted: exRoutingSingle.ok & true

// More implementations than classes: unroutable, reported at materialize.
exRoutingUnroutable: #ContractRouting & {
	contract:   _backupFQN
	fulfilment: "provider"
	implementations: [_k8upImpl, _veleroImpl]
	classes: daily: {
		contract: _backupFQN
		catalog:  "opmodel.dev/catalogs/k8up@v1"
		default:  true
	}
}
_assertUnroutableRefused: exRoutingUnroutable.ok & false

// Zero implementations: D1's unfulfilled case, reportable at materialize
// rather than deferred to the first render that trips over it.
exRoutingUnfulfilled: #ContractRouting & {
	contract:   _backupFQN
	fulfilment: "provider"
	implementations: []
	classes: {}
}
_assertUnfulfilledNotOk: exRoutingUnfulfilled.ok & false

// A "catalog"-fulfilled bucket carries no arity rule here — catalog_opm's
// #ContainerResource bucket legitimately feeds 8 transformers. The duplicate-
// adapter case inside this fulfilment is OQ1's, deliberately unconstrained.
exRoutingCatalogBucket: #ContractRouting & {
	contract:   "opmodel.dev/catalogs/opm/resources/container@v1"
	fulfilment: "catalog"
	implementations: [
		"opmodel.dev/catalogs/opm/transformers/deployment@1.4.0",
		"opmodel.dev/catalogs/opm/transformers/daemonset@1.4.0",
	]
	classes: {}
}
_assertCatalogBucketOk: exRoutingCatalogBucket.ok & true

// ─── D3: the registration claim and its lifecycle ───────────────────────────

// The claim the k8up module ships, accepted and activated: catalog resolvable,
// provides all defined by a subscribed catalog (exCatalog), class "daily" free
// in the vocabulary, and ModulePackage/k8up Ready.
exRegistrationActive: #TransformerRegistration & {
	spec: {
		catalog: "opmodel.dev/catalogs/k8up@v1"
		version: "1.2.0"
		providerRef: {
			name:      "k8up"
			namespace: "backup-system"
		}
		provides: [_backupFQN]
		class: "daily"
	}
	status: {
		accepted:           true
		active:             true
		dependentInstances: 7
	}
}

// Accepted but held inactive: the health gate a static subscription cannot
// express — the claim waits for the provider's CRDs.
exRegistrationPending: #TransformerRegistration & {
	spec: exRegistrationActive.spec
	status: {
		accepted: true
		reason:   "providerRef ModulePackage/k8up is not Ready"
	}
}
_assertPendingInactive: exRegistrationPending.status.active & false

// A rejected claim: defaults leave it neither accepted nor active.
exRegistrationRejected: #TransformerRegistration & {
	spec: {
		catalog: "opmodel.dev/catalogs/velero@v1"
		version: "2.0.1"
		providerRef: {
			name:      "velero"
			namespace: "backup-system"
		}
		provides: ["opmodel.dev/catalogs/opm/traits/snapshot@v1"]
	}
	status: reason: "provides names a contract no subscribed catalog defines"
}
_assertRejectedInert: exRegistrationRejected.status.accepted & false

// Must fail — a claim cannot be live without having passed validation:
//
//	exRegistrationEscaped: #TransformerRegistration & {
//		spec: exRegistrationActive.spec
//		status: {
//			accepted: false
//			active:   true
//		}
//	}
//
// cue vet ./... reports:
//	exRegistrationEscaped.status._activeImpliesAccepted: conflicting values
//	false and true

// ─── D3: the effective registry ─────────────────────────────────────────────

// Spec subscriptions (the static path) unified with active claims (the
// dynamic path), and the store key covering both. The claims list inside the
// key is illustrative "catalog@version" strings; its exact serialization is
// part of OQ6's store-key question, and whether this whole value is
// exportable back to a #Platform file is OQ3 — blocking for accepted.
exEffectiveRegistry: #EffectiveRegistry & {
	subscriptions: "opmodel.dev/catalogs/opm@v1": {
		version: "1.4.0"
	}
	claims: "opmodel.dev/catalogs/k8up@v1": exRegistrationActive
	key: {
		generation: 4
		claims: ["opmodel.dev/catalogs/k8up@v1#1.2.0"]
	}
}
_assertNoConflicts: len(exEffectiveRegistry._conflicts) & 0

// The default of the static path, pinned: a subscription is enabled unless
// disabled (0010 D14 shape, mirrored unchanged).
_assertSubscriptionEnabled: exEffectiveRegistry.subscriptions["opmodel.dev/catalogs/opm@v1"].enable & true

// Must fail — a claim naming a path the spec already subscribes to is a
// conflict, not a merge:
//
//	exEffectiveConflict: #EffectiveRegistry & {
//		subscriptions: "opmodel.dev/catalogs/k8up@v1": {
//			version: "1.1.0"
//		}
//		claims: "opmodel.dev/catalogs/k8up@v1": exRegistrationActive
//		key: {
//			generation: 5
//			claims: ["opmodel.dev/catalogs/k8up@v1#1.2.0"]
//		}
//	}
//
// cue vet ./... reports:
//	exEffectiveConflict._noConflict: conflicting values false and true
