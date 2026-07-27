// Target schema for enhancement 0010 (Module and Catalog Identity).
//
// These shapes state the identity contract: what an artifact's identity IS
// (D1, D2, D3), what a primitive's match key IS (D13), what a subscription
// selects (D14, D15), and the invariant a reader enforces (D11's addressing
// check).
//
// They are a specification, not an implementation. D13 removed the SemVer
// COMPARISON that earlier revisions modelled here — under full-SemVer keys a
// demand either finds its exact build or does not, so there is no ordering to
// evaluate and no prerelease-ordering simplification left to paper over. The
// one place ordering still matters is subscription selection (#Subscription-
// Selection), where the production implementation is Go and
// library/opm/materialize/filter.go already uses a real semver library.
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

// #MajorVersionType: the identity-bearing version component, as it appears in
// a module path. Declared in core today and used nowhere; D1 is the design its
// doc comment describes.
#MajorVersionType: string & =~"^v[0-9]+$"

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

// #FQNType: a primitive's fully-qualified name — the full SemVer of the
// catalog build the definition came from (D13).
//
// NOTE the deliberate asymmetry with #ModulePathType. A module path carries
// "@v1" — CUE's own spelling, and an ADDRESS. An FQN carries "@1.2.0" — bare
// SemVer, and a KEY. The two are never the same string and must not look
// alike.
#FQNType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

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
// It keeps a full SemVer (D3) which #ModuleIdentity does not. Under D13 that
// version is load-bearing in a way D3 did not intend: it is interpolated into
// every FQN the catalog ships, so it is a KEY COMPONENT rather than a
// compatibility signal sitting beside the keys.
//
// OQ1: whether a `name` field joins this shape is unresolved.
#CatalogIdentity: {
	modulePath!: #ModulePathType
	version!:    #VersionType

	_ref: #ArtifactRef & {"modulePath": modulePath}

	fqn: #ModulePathType & modulePath

	// The prefix every primitive this catalog ships hangs off. The major must
	// be split OUT and re-appended, because under D1 "@v1" sits mid-string and
	// plain concatenation would yield ".../opm@v1/resources".
	//
	// Enumerated rather than a pattern constraint: `[Kind=string]: …` is
	// unusable at the call site (`id.Prefix.resources` → `undefined field`,
	// because a pattern constrains keys that exist rather than generating
	// them). Measured in experiments/01, finding (b).
	primitivePrefix: {
		resources:    _ref.registryPath + "/resources@" + _ref.major
		traits:       _ref.registryPath + "/traits@" + _ref.major
		blueprints:   _ref.registryPath + "/blueprints@" + _ref.major
		transformers: _ref.registryPath + "/transformers@" + _ref.major
	}
}

// ─── Primitive identity (D13) ───────────────────────────────────────────────

// #PrimitiveIdentity is shared by #Resource, #Trait, #Blueprint and
// #ComponentTransformer.
//
// Under D13 the FQN carries the FULL SemVer of the catalog build this
// definition came from, so the key names its own bytes: a module demanding
// this key gets exactly the definition it was authored against, permanently,
// and a catalog release cannot alter what an installed module renders.
//
// `version` is the value the FQN interpolates. Whether it also survives as a
// separate required field is OQ6 — D12 gave it a reader (the matcher's catalog
// lookup) and D13 deleted that reader, leaving it derivable from `fqn`.
#PrimitiveIdentity: {
	name!:       #NameType
	modulePath!: #ModulePathType
	version!:    #VersionType

	_ref: #ArtifactRef & {"modulePath": modulePath}

	fqn: #FQNType & (_ref.registryPath + "/" + name + "@" + version)
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

// ─── Subscription selection (D14, D15) ──────────────────────────────────────

// #SubscriptionSelection is what a #Platform's subscription resolves to under
// D13. It replaces "the highest published stable version" (filter.go:43-47)
// with EVERY published build in the subscribed major, because a single build
// supplies a single key space and every module authored against any other
// build would miss (D14).
//
// The subscription key already names the major under D1, so "every build in
// this major" is the literal reading of a key that says @v1 rather than a new
// concept an author must know to ask for.
//
// includePrereleases is D15's explicit opt-in. It exists because prereleases
// are the live regime — catalogs/opm publishes only v1.0.0-alpha* — and
// because a default of "everything in the major" and a rule of "prereleases
// need opt-in" cannot both hold without a field to reconcile them.
#SubscriptionSelection: {
	// The subscription's own key, which carries the major.
	catalogPath!: #ModulePathType

	// Bare SemVers published under catalogPath's registry path, any major.
	published!: [...#VersionType]

	includePrereleases!: bool | *false

	_ref: #ArtifactRef & {modulePath: catalogPath}

	// "v1" → "1". Majors are compared as strings; nothing here needs a
	// numeric ordering.
	_wantMajor: strings.TrimPrefix(_ref.major, "v")

	selected: [for v in published
		if strings.SplitN(v, ".", 2)[0] == _wantMajor
		if includePrereleases || !strings.Contains(v, "-") {v}]
}

// ─── The matcher's lookup (D13) ─────────────────────────────────────────────
//
// #PrimitiveDemand is the whole check the matcher performs for one demanded
// primitive, and under D13 it is exact-key containment: the composed
// transformer map either carries the demanded key or it does not. There is no
// floor, no owning-catalog derivation, and no longest-prefix match — a key
// from a build the platform did not materialize is simply absent.
//
// The diagnostic that replaces `no matching transformer` is computed WITHOUT a
// catalog lookup, which is why this does not depend on OQ3: strip the version
// off the demanded FQN and collect every supplied key sharing that
// path-and-name. That set is exactly "which builds of this primitive the
// platform has", so the message names the subscription gap directly:
//
//   demanded .../config-maps@1.2.0
//   platform carries 1.1.0, 1.3.0 for .../config-maps
#PrimitiveDemand: {
	demanded!: #FQNType

	// The composed transformer map's key set (materialize's indexCatalogs
	// output), flattened to the keys themselves.
	supplied!: [...#FQNType]

	_d: strings.SplitN(demanded, "@", 2)

	// The version-free identity of the primitive: path + name.
	primitivePath:   _d[0]
	demandedVersion: _d[1]

	// Every build of THIS primitive the platform materialized.
	availableVersions: [for k in supplied
		let _k = strings.SplitN(k, "@", 2)
		if _k[0] == primitivePath {_k[1]}]

	matched: list.Contains(availableVersions, demandedVersion)
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

// A catalog's identity: full path, full version, and a primitive prefix with
// the major re-appended after the kind segment.
_catalogExample: #CatalogIdentity & {
	modulePath: "opmodel.dev/catalogs/opm@v1"
	version:    "1.2.0"
	fqn:        "opmodel.dev/catalogs/opm@v1"

	primitivePrefix: resources: "opmodel.dev/catalogs/opm/resources@v1"
}

// A primitive: the key carries the build it came from (D13).
_primitiveExample: #PrimitiveIdentity & {
	name:       "config-maps"
	modulePath: "opmodel.dev/catalogs/opm/resources@v1"
	version:    "1.2.0"
	fqn:        "opmodel.dev/catalogs/opm/resources/config-maps@1.2.0"
}

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

// D14: the whole major is selected, and only that major. 2.0.0 and the
// prerelease are both excluded — the first by major, the second by D15's
// default.
_selectionDefault: #SubscriptionSelection & {
	catalogPath: "opmodel.dev/catalogs/opm@v1"
	published: ["0.9.0", "1.0.0", "1.1.0", "1.2.0-rc.1", "1.2.0", "2.0.0"]
	includePrereleases: false

	selected: ["1.0.0", "1.1.0", "1.2.0"]
}

// D15: the same subscription with prereleases opted in.
_selectionPrerelease: #SubscriptionSelection & {
	catalogPath: "opmodel.dev/catalogs/opm@v1"
	published: ["0.9.0", "1.0.0", "1.1.0", "1.2.0-rc.1", "1.2.0", "2.0.0"]
	includePrereleases: true

	selected: ["1.0.0", "1.1.0", "1.2.0-rc.1", "1.2.0"]
}

// The live regime: catalogs/opm publishes only prereleases (measured
// 2026-07-27). Without D15's flag the default selects NOTHING, which is the
// concrete reason the flag exists.
_selectionLiveRegime: #SubscriptionSelection & {
	catalogPath: "opmodel.dev/catalogs/opm@v1"
	published: ["1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.2"]
	includePrereleases: false

	selected: []
}

// THE PAYOFF (D13). Two modules built against different minors of one catalog,
// on a platform that materialized the whole v1 major. Each demands the exact
// build it was authored against, and each finds it — cross-minor installs
// without collapsing the key space, and without either module's render moving
// when 1.2.0 was published.
_supply: [
	"opmodel.dev/catalogs/opm/resources/config-maps@1.0.0",
	"opmodel.dev/catalogs/opm/resources/config-maps@1.1.0",
	"opmodel.dev/catalogs/opm/resources/config-maps@1.2.0",
]

_demandOldModule: #PrimitiveDemand & {
	demanded: "opmodel.dev/catalogs/opm/resources/config-maps@1.0.0"
	supplied: _supply

	availableVersions: ["1.0.0", "1.1.0", "1.2.0"]
	matched: true
}

_demandNewModule: #PrimitiveDemand & {
	demanded: "opmodel.dev/catalogs/opm/resources/config-maps@1.2.0"
	supplied: _supply
	matched:  true
}

// MUST FAIL — the platform's subscription does not cover the build this module
// was authored against. Uncommenting yields, and ONLY yields:
//   matched: conflicting values false and true
//
// availableVersions is still computed, so the error message can name what the
// platform DOES carry: "demanded ...@1.3.0; platform carries 1.0.0, 1.1.0,
// 1.2.0". That is the subscription gap named directly.
//
//  _demandUncovered: #PrimitiveDemand & {
//   demanded: "opmodel.dev/catalogs/opm/resources/config-maps@1.3.0"
//   supplied: _supply
//  }
//
// MUST FAIL — the primitive is absent entirely (a catalog that never shipped
// it, or a typo). availableVersions is empty, so the message distinguishes
// "wrong build" from "no such primitive" without a catalog lookup.
//
//  _demandAbsent: #PrimitiveDemand & {
//   demanded: "opmodel.dev/catalogs/opm/resources/nonexistent@1.2.0"
//   supplied: _supply
//  }
