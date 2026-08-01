// Target schema for enhancement 0010 (Module and Catalog Identity).
//
// These shapes state the identity contract: what an artifact's identity IS
// (D1, D2, D3), what a primitive's match key IS (D4), what a build promises
// across a release (D27), what a subscription selects (D14), and the
// invariant a reader enforces (D11's addressing check).
//
// They are a specification, not an implementation. There is no version
// ORDERING modelled here: under D4 a contract key carries an API version that
// is compared for equality, and a transformer key carries a build that is
// never compared at all. The one place ordering still matters is subscription
// selection (#SubscriptionSelection), where the production implementation is
// Go and library/opm/materialize/filter.go already uses a real semver library.
package schema

import (
	"strings"
	"list"
)

// ─── Types ──────────────────────────────────────────────────────────────────

// #ModulePathType: a complete CUE module path, major suffix mandatory (D1).
//
// Widened from core's current form in two ways. The "@vN" suffix is new, and
// so are underscores in path segments: under D1 a module path ENDS IN the
// module's own snake_case name (D8), and every multi-word name contains one —
// media_server, cert_manager, zot_registry_ttl. Hyphens stay legal because
// CUE accepts them in path segments and OPM must be able to express its own
// organisation (github.com/open-platform-model/...); only the LEAF is
// constrained, and it is constrained by #ModuleIdentity rather than by regex.
#ModulePathType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*@v[0-9]+$"

// #PackagePathType: the path a PRIMITIVE declares (D1). A package path
// inside a module, NOT a module path — no "@vN" suffix.
//
// This is what core types primitive modulePath as today, and D1 keeps it
// that way. D1's widening applies to #Module and #Catalog only. The major
// is inert on a primitive: a "@vN" module publishes vN.* tags, so a
// primitive carrying version "1.2.0" already states its catalog is @v1.
// It is also not a path anyone writes — a consumer imports
// "opmodel.dev/catalogs/opm/resources" with no suffix and CUE resolves the
// major from the deps block.
#PackagePathType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*$"

// #MajorVersionType: the identity-bearing version component, as it appears in
// a module path. Declared in core today and used nowhere; D1 is the design its
// doc comment describes.
#MajorVersionType: string & =~"^v[0-9]+$"

// #APIVersionType: a PRIMITIVE's contract major (D4, D25) — the value an
// author moves when that primitive's shape breaks, independent of the
// catalog's module major and of its release SemVer.
//
// The Kubernetes ladder (resolved-by-D34): vNalphaM -> vNbetaM -> vN. The
// form is not decoration — D34 keys D27's additive-only promise to the level,
// so the string states whether the contract behind it promises anything.
#APIVersionType: string & =~"^v[0-9]+((alpha|beta)[0-9]+)?$"

// #APIVersionGated reports whether D27's additive-only promise binds at a
// given apiVersion (D34). Alpha promises nothing, so 0011 D9's publish gate
// does not run against it and #ContractCompatibility asserts nothing; beta
// and GA are gated in full.
//
// This is the only place the ladder is INTERPRETED rather than matched. There
// is still no ordering here — the level is read off the string, never
// compared against another level.
#APIVersionGated: {
	apiVersion!: #APIVersionType
	gated:       !strings.Contains(apiVersion, "alpha")
}

// #SnakeNameType: a CUE-identifier-safe name. Under D8 this is what an author
// writes and what the module path's leaf must equal.
#SnakeNameType: string & =~"^[a-z0-9]([a-z0-9_]*[a-z0-9])?$"

// #NameType: primitive names stay kebab-case — they are not CUE identifiers
// and never serve as package names.
#NameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"

// #VersionType: bare SemVer, no "v" prefix. Build metadata is permitted
// because core/src/types.cue:35 permits it; nothing in this entry parses a
// version numerically any more, so it costs nothing here.
#VersionType: string & =~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

// #ContractFQNType: what a module DEMANDS — path/name@vN, where vN is the
// primitive's own apiVersion (D4). A catalog release does not move it; only a
// breaking change to that primitive's shape does.
//
// This is the key a #Resource, #Trait or #Blueprint carries, and the key a
// transformer's requiredResources / requiredTraits map is keyed by. It is what
// lets a contract defined in one catalog be fulfilled by a transformer in
// another, on independent release cadences.
#ContractFQNType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@v[0-9]+((alpha|beta)[0-9]+)?$"

// #ImplFQNType: what a platform EXECUTES — path/name@1.2.0, the full SemVer of
// the build the transformer shipped in (D4). Unchanged from the form core
// carries today.
//
// Transformers keep the build in their key for two reasons. It is provenance
// an operator needs — which bytes are running — and it is what keeps
// materialize/index.go's invariant true: two builds of one catalog must not
// collide on one composed-map key, which is the failure that made a
// major-keyed transformer unworkable.
#ImplFQNType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

// #FQNType: either form, for the map shapes in core that hold both.
//
// NOTE the deliberate asymmetry with #ModulePathType, which survives D4
// intact: a module path carries "@v1" as an ADDRESS. A contract FQN now also
// ends "@v1" — but it is a KEY, and the two namespaces never meet in one
// field. What must stay visually distinct is a contract key from an
// implementation key, and "@v1" versus "@1.2.0" does that.
#FQNType: #ContractFQNType | #ImplFQNType

// ─── Address decomposition (D1) ─────────────────────────────────────────────

// #ArtifactRef splits a complete module path into the OCI repository its tags
// live under and the major it declares. This single operation REPLACES every
// "compose an address from a prefix and a name" site in cli and library.
//
// A module path carries at most one "@", always terminal, so SplitN(2) is
// exact. CUE has no string slicing, so LastIndex-plus-slice is unavailable.
#ArtifactRef: {
	modulePath!: #ModulePathType

	_p: strings.SplitN(modulePath, "@", 2)

	// registryPath: the OCI repository. Tags hang off this.
	registryPath: _p[0]

	// major: the identity-bearing version component, read rather than parsed.
	major: #MajorVersionType & _p[1]

	// importPath: what an `import` statement and a cue.mod dependency key
	// carry. Under D1 this is modulePath verbatim — nothing is recombined.
	importPath: modulePath
}

// ─── Artifact identity (D1, D2, D3, D8) ─────────────────────────────────────

// #ModuleIdentity is #Module.metadata after this enhancement.
//
// Note what is ABSENT: no version (D2), and no nameSnakeCase (D8) — name is
// already the constrained form, so there is no projection left to make.
#ModuleIdentity: {
	name!:       #SnakeNameType
	modulePath!: #ModulePathType

	_ref: #ArtifactRef & {"modulePath": modulePath}

	// fqn IS the module path (D1). uuid keeps its formula with a version-free,
	// major-bearing input, so it is stable across every release in the major
	// and distinct between majors.
	fqn: #ModulePathType & modulePath

	// leafMatchesName: D8's constraint, expressible over ONE field. Today the
	// same rule spans two independently-authored fields with nowhere to live.
	leafMatchesName: strings.HasSuffix(_ref.registryPath, "/"+name)
	leafMatchesName: true
}

// #CatalogIdentity is #Catalog.metadata after this enhancement.
//
// It keeps a full SemVer (D3) which #ModuleIdentity does not. Under D4 that
// version keys the catalog's TRANSFORMERS and stamps every primitive's
// catalogVersion as provenance; it does NOT key the contracts, which carry
// their own apiVersion and do not move when the catalog releases (D25).
//
// No `name` field: nothing reads one, in Go or in CUE (D16). Catalog
// identity and address are the module path alone.
#CatalogIdentity: {
	modulePath!: #ModulePathType
	version!:    #VersionType

	_ref: #ArtifactRef & {"modulePath": modulePath}

	fqn: #ModulePathType & modulePath
}

// #IdentityPackage is the catalog's committed identity/identity.cue (D5),
// the single source every leaf imports as `id`.
//
// Tooling writes exactly ModulePath and Version, located by THIS schema's
// field names rather than by a marker attribute (D5); RegistryPath and
// Major are DERIVED from ModulePath, so the split happens once here rather
// than at every definition site (D1, D21). `strings` is a CUE builtin, so
// the package keeps its invariant of carrying no INTRA-MODULE import and
// stays at the bottom of the graph with no cycle.
#IdentityPackage: {
	// Written by publish. Byte-identical to cue.mod's `module:`.
	ModulePath!: #ModulePathType

	// Written by `version set` / `publish --version`. The build every FQN
	// interpolates.
	Version!: #VersionType

	_ref: #ArtifactRef & {modulePath: ModulePath}

	RegistryPath: _ref.registryPath // "opmodel.dev/catalogs/opm"
	Major:        _ref.major        // "v1"

	// The prefix every primitive this catalog ships hangs off. Under D1 the
	// major is NOT re-appended — a primitive declares a package path.
	//
	// Enumerated rather than a pattern constraint: `[Kind=string]: …` is
	// unusable at the call site (`id.primitivePrefix.resources` → `undefined
	// field`, because a pattern constrains keys that exist rather than
	// generating them). Measured in experiments/01, finding (b).
	primitivePrefix: {
		resources:    RegistryPath + "/resources"
		traits:       RegistryPath + "/traits"
		blueprints:   RegistryPath + "/blueprints"
		transformers: RegistryPath + "/transformers"
	}
}

// ─── Primitive identity (D4, D25) ──────────────────────────────────────────

// #PrimitiveIdentity is shared by #Resource, #Trait, #Blueprint and
// #ComponentTransformer.
//
// TWO versions, and the split is the whole of D4. `apiVersion` is the
// CONTRACT major — what this primitive promises, moved only when its shape
// breaks. `catalogVersion` is the BUILD it shipped in — provenance, which no
// contract key interpolates and which D26 excludes from the match comparison
// entirely.
//
// `apiVersion` is the one identity value on a primitive that is NOT derivable
// from identity/identity.cue. It is a judgement its author makes, which is why
// it is a field rather than an interpolation, and it is what a compatibility
// gate keys its comparison on: "compare this against the last published build
// shipping this name at this apiVersion" (D27).
//
// `catalogVersion` is the D21 field under its D25 name. It stays REQUIRED for
// the reason D21 recorded — it is a key's source component for transformers
// and the provenance both ends of a match read — and it keeps its two supply
// routes: `id.Version` at the leaf, and #Catalog's pattern constraint stamping
// every #transformers entry structurally.
//
// `fqn` is AUTHORED, not derived (D21), and which type it takes depends on the
// kind:
//
//	resource / trait / blueprint  fqn: "\(id.RegistryPath)/resources/\(name)@\(apiVersion)"
//	transformer                   fqn: "\(id.RegistryPath)/transformers/\(name)@\(id.Version)"
//
// Enforcement MOVES rather than disappearing: core's unification made a wrong
// value inexpressible; 0011's publish gate (#PrimitiveFQNGate) catches it
// before it ships, which is where D17 already put the primitive-path rule.
//
// `modulePath` is a PACKAGE path under D1 — no "@vN".
#PrimitiveIdentity: {
	name!:           #NameType
	modulePath!:     #PackagePathType
	apiVersion!:     #APIVersionType
	catalogVersion!: #VersionType
	fqn!:            #FQNType
}

// #Fulfilment (D37) is how a CONTRACT declares where its implementation comes
// from. It exists because the answer is not derivable: D17 records that
// "which catalog ships FQN X?" cannot be answered from the FQN alone, since
// the kind-segment count is not fixed (…/opm/resources vs
// …/opm/blueprints/workload). So the contract author states it.
//
//	catalog   the declaring catalog implements this itself. Today's behaviour
//	          and the default, so every existing primitive is unchanged.
//	provider  fulfilment comes from a transformer in ANOTHER catalog, and the
//	          platform admits exactly one such provider.
//
// It is carried by #Resource and #Trait only. A #Blueprint composes resources
// and traits and is never demanded by a transformer — core/src/transformer.cue
// has requiredResources and requiredTraits and no blueprint equivalent — so
// the field would be unreachable there.
#Fulfilment: *"catalog" | "provider"

// #ContractSupply is D37's guard, stated as a shape that fails to unify when
// the rule is broken. For a provider-fulfilled contract the platform must
// carry EXACTLY ONE transformer requiring it: zero is D28's unresolved demand,
// two is two providers competing.
//
// `providers` counts transformers that REQUIRE the contract. Optional
// consumption is tolerance, not fulfilment — which is also why bucket arity
// could never be the test (D37's correction to D32): materialize/index.go
// indexes required ∪ optional, so catalog_opm's own #ContainerResource bucket
// holds 8 transformers from one catalog.
#ContractSupply: {
	contract!:   #ContractFQNType
	fulfilment!: #Fulfilment

	// Catalog paths of the transformers REQUIRING this contract.
	providers!: [...#PackagePathType]

	_n: len(providers)

	// A catalog-fulfilled contract is unconstrained here: many transformers may
	// consume one contract and produce different outputs.
	_ok: {
		if fulfilment == "catalog" {true}
		if fulfilment == "provider" {_n == 1}
	}
	_ok: true
}

// #ContractIdentity / #ImplIdentity narrow `fqn` by kind. A resource, trait or
// blueprint carries a contract key; a transformer carries an implementation
// key. Both keep both versions.
#ContractIdentity: #PrimitiveIdentity & {fqn!: #ContractFQNType}
#ImplIdentity:     #PrimitiveIdentity & {fqn!: #ImplFQNType}

// #PrimitiveFQNGate states what 0011's publish gate asserts for one
// primitive. It is deliberately NOT part of #PrimitiveIdentity: expressing it
// there would re-derive the value and undo D21. Unifying it is the check.
//
// The kind segment is retained (D21) — a flat FQN would make primitive names
// globally unique across all four kinds within a catalog, and catalog_opm
// already ships a resource named `secrets`.
#PrimitiveFQNGate: {
	identity!: #IdentityPackage
	kind!:     "resources" | "traits" | "blueprints" | "transformers"
	name!:     #NameType

	// What the catalog actually authored.
	declaredFQN!:            #FQNType
	declaredModulePath!:     #PackagePathType
	declaredAPIVersion!:     #APIVersionType
	declaredCatalogVersion!: #VersionType

	// What identity/identity.cue implies. The provenance must name THIS build;
	// the path must sit under THIS catalog (D17).
	declaredModulePath:     identity.primitivePrefix[kind]
	declaredCatalogVersion: identity.Version

	// The key is interpolated from the contract for the three demand-side
	// kinds and from the build for a transformer (D4). apiVersion is NOT
	// checked against identity — nothing implies it, which is the point of it.
	_keyVersion: [
		if kind == "transformers" {identity.Version},
		declaredAPIVersion,
	][0]

	declaredFQN: identity.primitivePrefix[kind] + "/" + name + "@" + _keyVersion
}

// ─── The compatibility promise (D27) ────────────────────────────────────────

// #ContractCompatibility states the relation a publish gate asserts between
// the build being published and the last build that shipped this primitive at
// this apiVersion. It is a SPECIFICATION of the check, not the check: the
// comparison is structural and belongs in Go, where cue.Value.Subsume is the
// candidate primitive (0011 D9; still to be measured).
//
// The three clauses are separate because they fail differently. Subsumption
// covers added fields and widened options. `newRequiredFields` is called out
// on its own because adding a REQUIRED field passes a naive "nothing was
// removed" reading and breaks every component authored earlier. Default
// stability is called out because it is invisible to subsumption AND to the
// match rung: measured in experiments/02, two builds disagreeing on a
// default unify to a NON-CONCRETE value, so the match passes and the render
// fails later on an incomplete value, naming a field rather than a build.
// D34 keys the relation to the API version's level. At alpha the promise does
// not bind, so every clause below is left unasserted and the gate does not run
// — which is what "no promise" MEANS, rather than a hole in the check.
#ContractCompatibility: {
	apiVersion!:  #APIVersionType
	fromVersion!: #VersionType // the previously published build
	toVersion!:   #VersionType // the build being published

	// Whether D27's rule binds here at all (D34).
	gated: (#APIVersionGated & {"apiVersion": apiVersion}).gated

	// Every value valid under `from` is valid under `to`.
	subsumes!: bool

	// No field required by `to` that was absent or optional in `from`.
	newRequiredFields!: [...#NameType]

	// No field present in both whose default value changed.
	changedDefaults!: [...#NameType]

	if gated {
		subsumes:          true
		newRequiredFields: []
		changedDefaults:   []
	}
}

// MUST FAIL — a beta contract that removed a field. The promise binds at beta,
// so the gate refuses.
//   _betaBreak.subsumes: conflicting values true and false
//
//  _betaBreak: #ContractCompatibility & {
//   apiVersion:        "v1beta1"
//   fromVersion:       "1.0.0"
//   toVersion:         "1.1.0"
//   subsumes:          false
//   newRequiredFields: []
//   changedDefaults:   []
//  }

// PASSES, and must — the same break at alpha. D34 carves alpha out of D27, so
// nothing here asserts and the publish gate does not run.
_alphaBreak: #ContractCompatibility & {
	apiVersion:        "v1alpha1"
	fromVersion:       "1.2.0"
	toVersion:         "1.3.0"
	subsumes:          false
	newRequiredFields: ["retention"]
	changedDefaults: ["mode"]
}

// ─── Read-side invariant (D11) ──────────────────────────────────────────────

// #FetchedArtifact binds an artifact's declared identity to the coordinates it
// was actually fetched by. Unifying it is the check; a violation is a conflict
// naming both values.
//
// Only the ADDRESS is checked. artifactVersion is RECORDED — it is what the
// kernel stamps into the D9 label and writes to spec.module.version — and is
// not compared against anything, because under D2 nothing inside a module
// claims a version for it to be checked against.
//
// The `self=` alias is required: embedded fields are unified into the value
// but are not in lexical scope, so the constraint reaches them through it.
#FetchedArtifact: self={
	#ArtifactRef

	// The coordinates in hand — what was passed to the registry loader, or
	// what a publish is about to write.
	artifactPath!:    #ModulePathType
	artifactVersion!: string

	// The invariant: the artifact lives where its metadata says it lives.
	artifactPath: self.importPath
}

// ─── Subscription selection (D14) ───────────────────────────────────────────

// #SubscriptionSelection is what a #Platform's subscription resolves to under
// D14: the ONE build the platform named, and nothing else.
//
// `version` is REQUIRED and SCALAR. There is no range to solve, no deny to
// subtract, no highest-stable default to fall through to, no maturity
// inference, and no list to arbitrate over — a prerelease is selected by
// being written down. Every one of those was tried and retired; D4 records
// which, and why each stopped being needed.
// Resolution is therefore total and offline: the field IS the answer rather
// than a query whose result depends on what the registry holds today. That is
// what makes a render reproducible from a commit without a lockfile, and it is
// the whole of OQ11's answer.
//
// D4's contract keys are what make one build sufficient: a contract key does
// not name a build, so a single build serves every module in the major, and
// the residual breadth a list would preserve has no surviving use case — a
// module cannot demand
// a transformer, so there is no per-module migration to stage, and the one
// scenario breadth uniquely served (a build that DROPPED a transformer) is a
// catalog bug that D28 now fails loudly on. Two builds of one catalog is two
// platforms.
//
// Note there is no `selected` field. While the shape carried a list it was
// the projection of that list; with a scalar the projection is the value
// itself.
//
// `published` is retained as a diagnostic input only. Selection never reads
// it; a read-side gate uses it to report a named build that does not exist.
#SubscriptionSelection: {
	// The subscription's own key, which carries the major.
	catalogPath!: #ModulePathType

	// D14: the single build this subscription materializes.
	version!: #VersionType

	// Bare SemVers published under catalogPath's registry path, any major.
	// Diagnostic surface; not an input to selection.
	published!: [...#VersionType]

	_ref: #ArtifactRef & {modulePath: catalogPath}

	// "v1" → "1". Majors are compared as strings; nothing here needs a
	// numeric ordering.
	_wantMajor: strings.TrimPrefix(_ref.major, "v")

	// The named build must sit in the subscription key's major. This is the
	// only rule left in the shape, and it is a consistency check on what the
	// author wrote rather than a selection step.
	_majorAgrees: strings.SplitN(version, ".", 2)[0] & _wantMajor
}

// ─── The matcher's lookup (D4, D26, D27) ───────────────────────────────────
//
// #PrimitiveDemand is the whole check the matcher performs for one demanded
// contract, and under D4 it is exact-key containment on a CONTRACT key: the
// #matchers reverse index either carries the demanded key or it does not.
// There is no floor, no ordering, no range and no owning-catalog derivation.
//
// What D4 changes is what a hit MEANS. Under SemVer keys a hit guaranteed
// byte-identical definitions, so nothing further was checked. Under a contract
// key the two sides may come from different builds, so the hit is followed by
// the always-unify rung (match.go:243-278) comparing their bodies — which is
// where D27's promise is enforced and D26's exclusion applies.
//
// The diagnostic on a miss needs no catalog lookup and is sharper than the
// SemVer-keyed one, because the version noise is gone:
//
//	availableApiVersions empty     nothing on this platform implements this
//	                               contract — the PLATFORM lacks a provider
//	availableApiVersions ["v2"]    implemented, at an apiVersion this module
//	                               does not speak
//
// Under D28 either outcome fails the render rather than being collected.
#PrimitiveDemand: {
	demanded!: #ContractFQNType

	// The #matchers reverse index key set: every contract FQN some transformer
	// on this platform requires or optionally consumes.
	supplied!: [...#ContractFQNType]

	_d: strings.SplitN(demanded, "@", 2)

	// The version-free identity of the contract: path + name.
	primitivePath:      _d[0]
	demandedAPIVersion: _d[1]

	// Every apiVersion of THIS contract the platform implements.
	availableApiVersions: [for k in supplied
		let _k = strings.SplitN(k, "@", 2)
		if _k[0] == primitivePath {_k[1]}]

	matched: list.Contains(availableApiVersions, demandedAPIVersion)
	matched: true
}

// ─── Pinned behaviour ───────────────────────────────────────────────────────

// The address decomposition, on a real path.
_refExample: #ArtifactRef & {
	modulePath:   "opmodel.dev/m/acme/media_server@v2"
	registryPath: "opmodel.dev/m/acme/media_server"
	major:        "v2"
	importPath:   "opmodel.dev/m/acme/media_server@v2"
}

// A module's identity. No version anywhere; fqn is the path.
_moduleExample: #ModuleIdentity & {
	name:       "media_server"
	modulePath: "opmodel.dev/m/acme/media_server@v2"
	fqn:        "opmodel.dev/m/acme/media_server@v2"
}

// MUST FAIL — a path leaf that disagrees with the name. Uncommenting yields
//   leafMatchesName: conflicting values false and true
//
//  _moduleBadLeaf: #ModuleIdentity & {
//   name:       "media_server"
//   modulePath: "opmodel.dev/m/acme/something_else@v2"
//  }

// A catalog's identity: the full module path, major included.
_catalogExample: #CatalogIdentity & {
	modulePath: "opmodel.dev/catalogs/opm@v1"
	version:    "1.2.0"
	fqn:        "opmodel.dev/catalogs/opm@v1"
}

// The identity package every leaf imports as `id`. Two authored fields; the
// rest derived, so no leaf splits a major (D1, D21).
_identityExample: #IdentityPackage & {
	ModulePath:   "opmodel.dev/catalogs/opm@v1"
	Version:      "1.2.0"
	RegistryPath: "opmodel.dev/catalogs/opm"
	Major:        "v1"

	primitivePrefix: {
		resources:    "opmodel.dev/catalogs/opm/resources"
		traits:       "opmodel.dev/catalogs/opm/traits"
		blueprints:   "opmodel.dev/catalogs/opm/blueprints"
		transformers: "opmodel.dev/catalogs/opm/transformers"
	}
}

// One primitive of each kind, exactly as a catalog leaf authors them (D21).
// modulePath carries no major (D1). Note the two contracts and the
// transformer come from the SAME build and key differently (D4): the
// contracts on what they promise, the transformer on the bytes that run.
_resourceExample: #ContractIdentity & {
	name:           "config-maps"
	modulePath:     "opmodel.dev/catalogs/opm/resources"
	apiVersion:     "v1"
	catalogVersion: "1.2.0"
	fqn:            "opmodel.dev/catalogs/opm/resources/config-maps@v1"
}

_traitExample: #ContractIdentity & {
	name:           "scaling"
	modulePath:     "opmodel.dev/catalogs/opm/traits"
	apiVersion:     "v1"
	catalogVersion: "1.2.0"
	fqn:            "opmodel.dev/catalogs/opm/traits/scaling@v1"
}

_transformerExample: #ImplIdentity & {
	name:           "configmap-transformer"
	modulePath:     "opmodel.dev/catalogs/opm/transformers"
	apiVersion:     "v1"
	catalogVersion: "1.2.0"
	fqn:            "opmodel.dev/catalogs/opm/transformers/configmap-transformer@1.2.0"
}

// The publish gate accepting all three.
_gateResource: #PrimitiveFQNGate & {
	identity:           _identityExample
	kind:               "resources"
	name:               "config-maps"
	declaredFQN:            _resourceExample.fqn
	declaredModulePath:     _resourceExample.modulePath
	declaredAPIVersion:     _resourceExample.apiVersion
	declaredCatalogVersion: _resourceExample.catalogVersion
}

_gateTrait: #PrimitiveFQNGate & {
	identity:           _identityExample
	kind:               "traits"
	name:               "scaling"
	declaredFQN:            _traitExample.fqn
	declaredModulePath:     _traitExample.modulePath
	declaredAPIVersion:     _traitExample.apiVersion
	declaredCatalogVersion: _traitExample.catalogVersion
}

_gateTransformer: #PrimitiveFQNGate & {
	identity:           _identityExample
	kind:               "transformers"
	name:               "configmap-transformer"
	declaredFQN:            _transformerExample.fqn
	declaredModulePath:     _transformerExample.modulePath
	declaredAPIVersion:     _transformerExample.apiVersion
	declaredCatalogVersion: _transformerExample.catalogVersion
}

// MUST FAIL — the failure D21 accepts and delegates to the publish gate: an
// author left a stale build in the FQN while the catalog moved to 1.2.0.
// core no longer derives fqn, so nothing catches this at the catalog's own
// cue vet (measured: exit 0). The gate does. Uncommenting yields:
//   declaredFQN: conflicting values ".../secrets@1.1.0" and ".../secrets@1.2.0"
//
//  _gateStale: #PrimitiveFQNGate & {
//   identity:           _identityExample
//   kind:               "resources"
//   name:               "secrets"
//   declaredFQN:        "opmodel.dev/catalogs/opm/resources/secrets@1.1.0"
//   declaredModulePath: "opmodel.dev/catalogs/opm/resources"
//   declaredVersion:    "1.2.0"
//  }
//
// MUST FAIL — a primitive sitting outside its own catalog's path (D17's rule,
// enforced at publish). Uncommenting yields a declaredModulePath conflict.
//
//  _gateForeignPath: #PrimitiveFQNGate & {
//   identity:           _identityExample
//   kind:               "resources"
//   name:               "config-maps"
//   declaredFQN:        "opmodel.dev/elsewhere/resources/config-maps@1.2.0"
//   declaredModulePath: "opmodel.dev/elsewhere/resources"
//   declaredVersion:    "1.2.0"
//  }

// The read-side check passing.
_fetchedExample: #FetchedArtifact & {
	modulePath:      "opmodel.dev/m/acme/media_server@v2"
	artifactPath:    "opmodel.dev/m/acme/media_server@v2"
	artifactVersion: "v2.1.0"
}

// MUST FAIL — an artifact fetched from a path its metadata does not claim.
//   artifactPath: conflicting values "...other/media_server@v2" and "...acme/media_server@v2"
//
//  _fetchedMismatch: #FetchedArtifact & {
//   modulePath:      "opmodel.dev/m/acme/media_server@v2"
//   artifactPath:    "opmodel.dev/m/other/media_server@v2"
//   artifactVersion: "v2.1.0"
//  }

// D14: the platform names one build, and under D4 that is not a compromise —
// a contract key does not name a build, so one build serves the whole fleet.
// Note what is NOT consulted: 1.2.0 is published and newer, and is not
// selected, because nothing here resolves anything.
_selectionSingle: #SubscriptionSelection & {
	catalogPath: "opmodel.dev/catalogs/opm@v1"
	published: ["0.9.0", "1.0.0", "1.1.0", "1.2.0-rc.1", "1.2.0", "2.0.0"]
	version: "1.1.0"
}

// The live regime: catalogs/opm publishes only prereleases (measured
// 2026-07-27). Under the whole-major default and its prerelease flag this
// selected NOTHING without an opt-in; a prerelease is now selected by being
// written down (D14).
_selectionLiveRegime: #SubscriptionSelection & {
	catalogPath: "opmodel.dev/catalogs/opm@v1"
	published: ["1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.2"]
	version: "1.0.0-alpha.2"
}

// MUST FAIL — a named build outside the subscription key's major. The only
// rule D14 leaves in the shape, and it catches an author, not a registry.
//
//	_selectionWrongMajor: #SubscriptionSelection & {
//	 catalogPath: "opmodel.dev/catalogs/opm@v1"
//	 published: ["1.1.0", "2.0.0"]
//	 version: "2.0.0"
//	}
//
// → _majorAgrees: conflicting values "1" and "2"

// MUST FAIL — two builds of one catalog. Earlier revisions of D14 made this
// the implied default, then legal-but-unresolved (OQ15); the field is now
// scalar, so the shape itself refuses it. There is no subscription that
// materializes two builds — that is two platforms.
//
//	_selectionMulti: #SubscriptionSelection & {
//	 catalogPath: "opmodel.dev/catalogs/opm@v1"
//	 published: ["1.0.0", "1.1.0"]
//	 version: ["1.0.0", "1.1.0"]
//	}
//
// → version: conflicting values ["1.0.0","1.1.0"] and string (mismatched types list and string)

// MUST FAIL — an empty subscription. An earlier revision of D14 made this the
// ergonomic default; there is nothing left for it to mean, and no list to be
// empty — the field is simply absent.
//
//	_selectionEmpty: #SubscriptionSelection & {
//	 catalogPath: "opmodel.dev/catalogs/opm@v1"
//	 published: ["1.1.0"]
//	}
//
// → version: field is required but not present
//
// NOTE the detection strength changed here, and it is worth knowing which flag
// catches it. The earlier empty list failed under plain `cue vet` as a length
// conflict ("versions: incompatible list lengths (0 and 1)"). An ABSENT
// required field is an incompleteness, not a conflict, so it needs
// `cue vet -c` — plain `cue vet` reports "some instances are incomplete" for a
// visible field and says nothing at all for a hidden one. The publish-side
// identity gate (0011 D4) already rests on exactly this distinction: it exists
// because `cue vet` without -c exits 0 on a tree with unfilled identity.

// THE PAYOFF (D4). A contract defined in one catalog, fulfilled by a
// transformer in another, with the two compiled against different builds of
// the defining catalog. Both arrive at one key.
//
// This is the case build-keyed contracts could not express: catalog_opm defines
// `backup` and ships no transformer for it, a k8up provider catalog ships the
// transformer, and neither release cadence is coupled to the other.
_supply: [
	"opmodel.dev/catalogs/opm/resources/backup@v1",
	"opmodel.dev/catalogs/opm/resources/config-maps@v1",
	"opmodel.dev/catalogs/opm/traits/scaling@v1",
]

// The module compiled against catalog_opm 1.3.0; the provider against 1.0.0.
// Neither version appears in either key, so the demand lands.
_demandFulfilledContract: #PrimitiveDemand & {
	demanded: "opmodel.dev/catalogs/opm/resources/backup@v1"
	supplied: _supply

	availableApiVersions: ["v1"]
	matched:              true
}

// Whether the two BODIES agree is the always-unify rung's job, not this
// shape's — see #ContractCompatibility and experiments/02.
_demandOrdinary: #PrimitiveDemand & {
	demanded: "opmodel.dev/catalogs/opm/resources/config-maps@v1"
	supplied: _supply
	matched:  true
}

// MUST FAIL — nothing on this platform implements the contract at any API
// version. availableApiVersions is EMPTY, which is what distinguishes "you
// have no provider for this" from "your provider speaks a different version".
// Uncommenting yields, and ONLY yields:
//   matched: conflicting values false and true
//
//  _demandNoProvider: #PrimitiveDemand & {
//   demanded: "opmodel.dev/catalogs/opm/resources/nonexistent@v1"
//   supplied: _supply
//  }
//
// MUST FAIL — implemented, but at an apiVersion this module does not speak.
// availableApiVersions is ["v1"], so the message names the gap: "this module
// demands backup@v2; this platform implements backup@v1".
//
//  _demandWrongAPIVersion: #PrimitiveDemand & {
//   demanded: "opmodel.dev/catalogs/opm/resources/backup@v2"
//   supplied: _supply
//  }

// D37's guard passing: one provider fulfils a provider-declared contract.
_supplyProviderOK: #ContractSupply & {
	contract:   "opmodel.dev/catalogs/opm/resources/backup@v1"
	fulfilment: "provider"
	providers: ["opmodel.dev/catalogs/k8up/transformers"]
}

// A catalog-fulfilled contract with many consumers is fine, and this is the
// case D32's bucket-arity invariant would have refused: measured 2026-08-01,
// catalog_opm's own #ContainerResource is consumed by 8 of its transformers.
_supplyCatalogMany: #ContractSupply & {
	contract:   "opmodel.dev/catalogs/opm/resources/container@v1"
	fulfilment: "catalog"
	providers: [
		"opmodel.dev/catalogs/opm/transformers",
		"opmodel.dev/catalogs/opm/transformers",
	]
}

// MUST FAIL — two providers for one provider-declared contract. This is the
// rule D37 states: k8up or velero, never both. Uncommenting yields
//   _ok: conflicting values false and true
//
//	_supplyTwoProviders: #ContractSupply & {
//	 contract:   "opmodel.dev/catalogs/opm/resources/backup@v1"
//	 fulfilment: "provider"
//	 providers: [
//	  "opmodel.dev/catalogs/k8up/transformers",
//	  "opmodel.dev/catalogs/velero/transformers",
//	 ]
//	}

// MUST FAIL — a provider-declared contract nothing supplies. D28 already makes
// an unresolved demand an error; this states the other end of "exactly one".
// Uncommenting yields
//   _ok: conflicting values false and true
//
//	_supplyNoProvider: #ContractSupply & {
//	 contract:   "opmodel.dev/catalogs/opm/resources/backup@v1"
//	 fulfilment: "provider"
//	 providers: []
//	}
