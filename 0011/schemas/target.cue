// Target schema for enhancement 0011 (Module and Catalog Publishing).
//
// These shapes describe a publish DECISION rather than a type an artifact
// carries: what the command resolves before it pushes, and the conditions
// under which it refuses. They are written as CUE so the rules can be checked
// and so a rule that does not hold is a failing build rather than a paragraph
// nobody re-read.
//
// A #PublishPlan that does not unify is a push that does not happen.
package schema

import "strings"

// ─── Namespace (D5) ─────────────────────────────────────────────────────────

// #RegistryPath describes the two spaces OPM OPERATES. It deliberately does
// NOT describe every publishable path: under D13 a vanity domain or a
// self-hosted registry may use any valid CUE module path, and OPM constrains
// neither — path ownership is domain ownership. What is modelled here is the
// namespace OPM itself shapes, because that is the only part it can.
//
//   first-party  opmodel.dev/modules/<name>
//                opmodel.dev/catalogs/<name>
//                opmodel.dev/platforms/<name>    (reserved, nothing published yet — D14)
//                opmodel.dev/core                (fixed path, outside the pattern)
//   community    community.opmodel.dev/m/<owner>/<name>
//                community.opmodel.dev/catalogs/<owner>/<name>
//                community.opmodel.dev/p/<owner>/<name>
//   elsewhere    any valid CUE module path, unconstrained
//
// INSTANCES ARE ABSENT ON PURPOSE (D14). opmodel.dev/releases/* holds Flux OCI
// artifacts pushed by `flux push artifact` and consumed by the operator through
// a Flux source — never resolved by CUE's module resolver, never imported,
// never in a deps block. They are not in this namespace, so they get no segment
// and need no collision guard: `kind` below is a closed disjunction, so nothing
// first-party can land under `opmodel.dev/releases/*` to begin with.
//
// The kind segment is a FIRST-PARTY LAYOUT CONVENTION rather than a global
// property. D5 claimed it made the namespace partitionable — tooling telling
// a module from a catalog by path alone — and free-form third-party paths
// remove that, so tooling must handle arbitrary shapes regardless.
#RegistryPath: #FirstPartyPath | #CommunityPath

// #FirstPartyPath: one publisher, so no owner segment — owner-scoping would
// have nothing to disambiguate.
//
// `modules` is a GRANDFATHERED spelling, not a second canonical one. D5
// proposed renaming it to `m`; D13 declined, because the rename rewrites every
// published module coordinate and every deployment-side pin for a spelling
// change D5 itself calls cosmetic.
#FirstPartyPath: {
	space:  "first-party"
	domain: "opmodel.dev"
	kind!:  "modules" | "catalogs" | "platforms"
	name!:  string
	out:    domain + "/" + kind + "/" + name
}

// #CommunityPath: publishers using OPM's central registry without a domain of
// their own. The owner segment is REQUIRED and assigned at registration — it
// is what makes two publishers' "postgres" distinct without OPM arbitrating a
// name it does not own.
#CommunityPath: {
	space:  "community"
	domain: "community.opmodel.dev"
	kind!:  "m" | "catalogs" | "p"
	owner!: string
	name!:  string
	out:    domain + "/" + kind + "/" + owner + "/" + name
}

_firstPartyModule: (#FirstPartyPath & {
	kind: "modules"
	name: "postgres"
}).out & "opmodel.dev/modules/postgres"

_firstPartyCatalog: (#FirstPartyPath & {
	kind: "catalogs"
	name: "opm"
}).out & "opmodel.dev/catalogs/opm"

_communityModule: (#CommunityPath & {
	kind:  "m"
	owner: "acme"
	name:  "media_server"
}).out & "community.opmodel.dev/m/acme/media_server"

_communityCatalog: (#CommunityPath & {
	kind:  "catalogs"
	owner: "acme"
	name:  "k8up"
}).out & "community.opmodel.dev/catalogs/acme/k8up"

// Reserved and unused (D14) — nothing publishes a platform today.
_firstPartyPlatform: (#FirstPartyPath & {
	kind: "platforms"
	name: "k8s_default"
}).out & "opmodel.dev/platforms/k8s_default"

_communityPlatform: (#CommunityPath & {
	kind:  "p"
	owner: "acme"
	name:  "edge"
}).out & "community.opmodel.dev/p/acme/edge"

// MUST FAIL — a community path with no owner. The segment is what supplies
// uniqueness structurally; without it the space is the flat namespace D5
// rejected, one subdomain over.
//
// NOTE THE NON-HIDDEN NAME, and do not "tidy" it to `_communityNoOwner`.
// Measured 2026-08-04 (cue v0.17.1): a MISSING REQUIRED FIELD inside a HIDDEN
// field is caught by neither `cue vet` nor `cue vet -c` — both exit 0 and
// print nothing, so the case silently stops being a MUST-FAIL while still
// reading like one. Conflicts and closedness violations do NOT share this
// blind spot; they fail under plain `cue vet` in a hidden field, which is why
// every other commented case in this file is spelled `_name`.
//
// This is D4's own measured condition turning up in the verification harness:
// `cue vet` without -c reports "some instances are incomplete" and exits 0.
//   plain:  some instances are incomplete; use the -c flag to show errors
//   with -c: communityNoOwner.owner: field is required but not present
//            communityNoOwner.out: required field missing: owner
//
//  communityNoOwner: #CommunityPath & {kind: "m", name: "media_server"}
//
// MUST FAIL — a first-party path carrying an owner segment. First-party space
// has exactly one publisher, and #FirstPartyPath is closed.
//   owner: field not allowed
//
//  _firstPartyOwned: #FirstPartyPath & {kind: "modules", owner: "opm", name: "postgres"}

// ─── Tags ───────────────────────────────────────────────────────────────────

// #TagRef decomposes a release tag and binds it to the major an artifact path
// declares.
//
// CUE ALREADY ENFORCES THIS HALF. Measured 2026-07-26 (cue v0.17.1):
//   $ cue mod publish v9.1.0 --dry-run     # module declared @v3
//   publish version "v9.1.0" does not match the major version "v3"
//     declared in .../cue.mod/module.cue; must be v3.N.N
//
// So the shape records a check that exists rather than one to build — worth
// stating so publish does not reimplement it, and so the boundary between
// what CUE guarantees and what OPM must add is explicit.
#TagRef: {
	// tag: the OCI tag, "v"-prefixed as CUE writes it.
	tag!: =~"^v\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

	// artifactMajor: the "@vN" suffix of the path being published to.
	artifactMajor!: =~"^v[0-9]+$"

	// bare: the tag without its "v", which is the form a catalog's identity
	// carries and what a compatibility comparison uses.
	bare: strings.TrimPrefix(tag, "v")

	// The tag's own major must equal the path's.
	_tagMajor: "v" + strings.SplitN(bare, ".", 2)[0]
	_tagMajor: artifactMajor
}

_tagOK: #TagRef & {
	tag:           "v2.1.0"
	artifactMajor: "v2"
	bare:          "2.1.0"
}

// MUST FAIL — a tag whose major disagrees with the path it is published to.
// CUE's own publish refuses this; the shape states why.
//   _tagMajor: conflicting values "v2" and "v9"
//
//  _tagSkew: #TagRef & {
//   tag:           "v9.1.0"
//   artifactMajor: "v2"
//  }

// ─── Identity completeness (D4) ─────────────────────────────────────────────

// #IdentityState: the three states an identity field can be in, and what
// publish does with each. `concrete` is the only publishable one.
//
// The gate is necessary because CUE does not supply it. Measured 2026-07-26:
// `cue mod publish v1.2.0 --dry-run` SUCCEEDED on a tree with unfilled
// identity fields, and `cue vet` without -c reports "some instances are
// incomplete" and exits 0.
#IdentityState: {
	field!: string

	// open: declared but unfilled (`Version: string`). Publishable
	// only once --version supplies a value (D3).
	// concrete: holds a value. Publishable.
	// absent: not declared at all. Never publishable — this is a malformed
	// artifact rather than an unfinished one.
	state!: "open" | "concrete" | "absent"

	publishable: [
		if state == "concrete" {true},
		if state == "open" {suppliedByFlag},
		false,
	][0]

	// suppliedByFlag: whether `--version` (or an equivalent) is filling this
	// field on this invocation.
	suppliedByFlag: bool | *false

	// D12: `--version` means ONE thing on both artifact types — fill an open
	// field, ASSERT a concrete one. The assert half is expressed here so a
	// disagreement is a unification failure rather than a check someone has
	// to remember to write.
	//
	// suppliedValue: what `--version` carries on this invocation ("" = absent).
	// declaredValue: what the artifact itself holds when state is concrete.
	suppliedValue: string | *""
	declaredValue: string | *""

	_asserted: [
		if state == "concrete" && suppliedValue != "" {declaredValue == suppliedValue},
		true,
	][0]
	_asserted: true

	// effective: the value this field will carry in the PUBLISHED artifact —
	// what it already declares, or what --version supplies into an open one.
	// "" means there is nothing concrete to compare against (D18).
	effective: [
		if state == "concrete" {declaredValue},
		if state == "open" && suppliedValue != "" {suppliedValue},
		"",
	][0]
}

_identityConcrete: #IdentityState & {field: "Version", state: "concrete", publishable: true}
_identityFilled: #IdentityState & {field: "Version", state: "open", suppliedByFlag: true, publishable: true}
_identityUnfilled: #IdentityState & {field: "Version", state: "open", publishable: false}
_identityAbsent: #IdentityState & {field: "ModulePath", state: "absent", publishable: false}

// D12: `--version` agreeing with a concrete field is a no-op, not a refusal.
_identityAssertOK: #IdentityState & {
	field:         "Version", state:       "concrete"
	declaredValue: "1.3.0", suppliedValue: "1.3.0"
	publishable:   true
}

// MUST FAIL — `--version` disagrees with a concrete declared value (D12).
//   _asserted: conflicting values false and true
//
//  _identityAssertSkew: #IdentityState & {
//   field: "Version", state: "concrete"
//   declaredValue: "1.3.0", suppliedValue: "1.4.0"
//  }

// ─── Identity derivation (D12) ──────────────────────────────────────────────

// #IdentityDerivation: the module's root package wires `metadata.version` to
// its identity package's `Version` (likewise `modulePath` / `ModulePath`), and
// publish verifies the two agree.
//
// The check exists because `core` CANNOT enforce the wiring: `#Module` has no
// way to reference an arbitrary module's identity package, so the template
// establishes the derivation and CUE enforces it only while the derivation is
// still written. A developer who REPLACES `id.Version` with a literal leaves
// nothing to conflict, and this is what catches that.
#IdentityDerivation: {
	field!:             "ModulePath" | "Version"
	inMetadata!:        string
	inIdentityPackage!: string

	agrees: inMetadata == inIdentityPackage
	agrees: true
}

_derivationOK: #IdentityDerivation & {
	field: "Version", inMetadata: "2.1.0", inIdentityPackage: "2.1.0"
}

// MUST FAIL — the derivation was replaced by a stale literal (D12).
//   agrees: conflicting values false and true
//
//  _derivationSkew: #IdentityDerivation & {
//   field: "Version", inMetadata: "2.0.0", inIdentityPackage: "2.1.0"
//  }

// ─── Local-override gate (D6) ───────────────────────────────────────────────

// #OverrideGate expresses the module/catalog asymmetry rather than describing
// it. The condition is the FILE'S PRESENCE, not whether its replacements
// currently resolve — presence is the only condition stable across machines.
#OverrideGate: {
	artifactKind!:    "module" | "catalog"
	overridePresent!: bool

	// allowFlag: the explicit escape hatch. Available to modules only; a
	// catalog that passes it still refuses, because a catalog's divergence
	// propagates into the key space of everything built against it.
	allowFlag: bool | *false

	proceed: [
		if !overridePresent {true},
		if artifactKind == "catalog" {false},
		allowFlag,
	][0]
}

_gateClean: #OverrideGate & {artifactKind: "module", overridePresent: false, proceed: true}
_gateModuleBlocked: #OverrideGate & {artifactKind: "module", overridePresent: true, proceed: false}
_gateModuleAllowed: #OverrideGate & {artifactKind: "module", overridePresent: true, allowFlag: true, proceed: true}
_gateCatalogBlocked: #OverrideGate & {artifactKind: "catalog", overridePresent: true, proceed: false}

// The catalog has no escape hatch: passing the flag changes nothing.
_gateCatalogFlagIgnored: #OverrideGate & {
	artifactKind:    "catalog"
	overridePresent: true
	allowFlag:       true
	proceed:         false
}

// ─── The plan (D1, D2) ──────────────────────────────────────────────────────

// #PublishPlan is everything publish resolves before it pushes. Every field is
// derived from the artifact or supplied deliberately; nothing is invented.
//
// `go` is constrained to true, so a plan that fails any gate is a unification
// failure rather than a value someone has to remember to inspect.
#PublishPlan: {
	artifactKind!: "module" | "catalog"

	// declaredPath: the artifact's own metadata.modulePath — the complete CUE
	// module path including the major. Under enhancement 0010 this IS the
	// registry address, so publish READS it rather than composing one.
	declaredPath!: =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*@v[0-9]+$"

	// cueModPath: the `module:` line in cue.mod/module.cue. The two must
	// agree, and publish ENFORCES that rather than generating the file (D16):
	// the module path has three statements — this line, the literal
	// self-import in source, and identity.cue's ModulePath — and rewriting
	// this one orphans the second.
	cueModPath!: string
	cueModPath:  declaredPath

	_split:       strings.SplitN(declaredPath, "@", 2)
	registryRepo: _split[0]
	major:        _split[1]

	// D13/D14: THE NAMESPACE RULES BIND ONLY WHERE OPM OWNS THE DOMAIN.
	//
	// `declaredPath`'s regex above admits any valid CUE module path, and that is
	// deliberate — under D13 path ownership is domain ownership, so a vanity
	// domain or a self-hosted registry may use any path it likes and publish
	// must not refuse it. What OPM can constrain is the two domains it owns, and
	// leaving that unstated meant #RegistryPath described a namespace that
	// nothing in the plan actually checked.
	//
	// So this is conditional rather than a blanket unification against
	// #RegistryPath: outside the owned domains it asserts nothing, and inside
	// them it is exact.
	_ownedFirstParty: strings.HasPrefix(registryRepo, "opmodel.dev/")
	_ownedCommunity:  strings.HasPrefix(registryRepo, "community.opmodel.dev/")
	_ownedDomain:     _ownedFirstParty || _ownedCommunity

	// `testing.opmodel.dev/...` is deliberately NOT caught: it is a separate
	// domain carrying fixtures (D17 relocates the test namespace onto it), and
	// it is not the namespace #RegistryPath models.
	_firstPartyShape: "^opmodel\\.dev/(modules|catalogs|platforms)/[a-z0-9._-]+$"
	_communityShape:  "^community\\.opmodel\\.dev/(m|catalogs|p)/[a-z0-9._-]+/[a-z0-9._-]+$"

	// opmodel.dev/core is a fixed path outside the kind pattern, per
	// #RegistryPath's own doc comment.
	_isCore: registryRepo == "opmodel.dev/core"

	_namespaceOK: [
		if !_ownedDomain {true},
		if _isCore {true},
		if _ownedFirstParty {registryRepo =~ _firstPartyShape},
		registryRepo =~ _communityShape,
	][0]
	_namespaceOK: true

	// THE KIND SEGMENT MUST AGREE WITH WHAT IS BEING PUBLISHED. D1 makes this
	// one implementation with two entry points, so nothing else stops
	// `opm module publish` pushing to a catalogs/ path — the artifact would be
	// decoded as a module, gated as a module, and land where consumers look for
	// catalogs.
	//
	// Note there is no `platforms` arm: artifactKind admits only module and
	// catalog, so a plan targeting opmodel.dev/platforms/<name> fails here. That
	// is D14's reservation working as intended — the segment is reserved, and
	// nothing publishes a platform today.
	_repoSegments: strings.Split(registryRepo, "/")
	_kindSegment: [
		if _ownedDomain && len(_repoSegments) > 1 {_repoSegments[1]},
		"",
	][0]

	_kindAgrees: [
		if !_ownedDomain {true},
		if _isCore {true},
		if artifactKind == "module" {_kindSegment == "modules" || _kindSegment == "m"},
		_kindSegment == "catalogs",
	][0]
	_kindAgrees: true

	tag!: #TagRef & {artifactMajor: major}

	identity!: [...#IdentityState]
	gate!: #OverrideGate & {"artifactKind": artifactKind}

	// Every identity field must be publishable, and the gate must pass.
	// _unpublishable names the offenders, so a refusal can report them.
	_unpublishable: [for i in identity if !i.publishable {i.field}]

	go: len(_unpublishable) == 0 && gate.proceed
	go: true

	// D18: THE TAG MUST NAME THE VERSION THE ARTIFACT DECLARES.
	//
	// Nothing above joins the two. #TagRef checks the tag's MAJOR against the
	// path's, and #IdentityState checks that Version is CONCRETE — so a
	// catalog declaring 1.2.0 published under v1.3.0 satisfies both and
	// yields `go: true`. The pushed bytes would interpolate 1.2.0 into every
	// transformer FQN while the registry served them as 1.3.0, which is the
	// local-versus-published divergence D2, D5 and D6 exist to remove,
	// reintroduced at the last step.
	//
	// Asserted on its own rather than folded into `go`, so one cause produces
	// one refusal naming the version rule — the asymmetry experiment 02 fixed
	// when a renamed field produced two refusals for one cause.
	_versionField: [for i in identity if i.field == "Version" {i}]
	_versionAgrees: [
		if len(_versionField) == 0 {true},
		if _versionField[0].effective == "" {true},
		_versionField[0].effective == tag.bare,
	][0]
	_versionAgrees: true
}

_planOK: #PublishPlan & {
	artifactKind: "catalog"
	declaredPath: "opmodel.dev/catalogs/opm@v1"
	cueModPath:   "opmodel.dev/catalogs/opm@v1"
	registryRepo: "opmodel.dev/catalogs/opm"
	major:        "v1"
	tag: {tag: "v1.3.0", bare: "1.3.0"}
	identity: [
		{field: "ModulePath", state: "concrete"},
		// declaredValue set so this example exercises D18 rather than
		// short-circuiting on an empty effective value.
		{field: "Version", state: "concrete", declaredValue: "1.3.0"},
	]
	gate: {overridePresent: false}
}

// D18 — --version filling an OPEN field is compared the same way: the
// effective value is what the flag supplies.
_planFilledAgrees: #PublishPlan & {
	artifactKind: "catalog"
	declaredPath: "opmodel.dev/catalogs/opm@v1"
	cueModPath:   "opmodel.dev/catalogs/opm@v1"
	tag: {tag: "v1.3.0"}
	identity: [{field: "Version", state: "open", suppliedByFlag: true, suppliedValue: "1.3.0"}]
	gate: {overridePresent: false}
}

// D13's OTHER HALF, and the one a tightening would silently break: outside the
// domains OPM owns, publish asserts nothing about the path. These four must
// PASS, and they are pinned because the namespace check above is exactly the
// kind of constraint that grows until it refuses a third party's own domain —
// which is the position D13 exists to rule out.
_planVanityDomain: #PublishPlan & {
	artifactKind: "catalog"
	declaredPath: "example.com/k8up@v1"
	cueModPath:   "example.com/k8up@v1"
	tag: {tag: "v1.3.0"}
	identity: [{field: "Version", state: "concrete", declaredValue: "1.3.0"}]
	gate: {overridePresent: false}
}

// A separate domain for fixtures, not a segment of the owned one (D17).
_planTestingDomain: #PublishPlan & {
	artifactKind: "module"
	declaredPath: "testing.opmodel.dev/modules/web_app@v1"
	cueModPath:   "testing.opmodel.dev/modules/web_app@v1"
	tag: {tag: "v1.0.0"}
	identity: [{field: "Version", state: "concrete", declaredValue: "1.0.0"}]
	gate: {overridePresent: false}
}

// Community space: four segments, owner included, `m` for a module.
_planCommunityModule: #PublishPlan & {
	artifactKind: "module"
	declaredPath: "community.opmodel.dev/m/acme/media_server@v2"
	cueModPath:   "community.opmodel.dev/m/acme/media_server@v2"
	tag: {tag: "v2.4.1"}
	identity: [{field: "Version", state: "concrete", declaredValue: "2.4.1"}]
	gate: {overridePresent: false}
}

// opmodel.dev/core — the fixed path outside the kind pattern.
_planCore: #PublishPlan & {
	artifactKind: "catalog"
	declaredPath: "opmodel.dev/core@v1"
	cueModPath:   "opmodel.dev/core@v1"
	tag: {tag: "v1.0.0"}
	identity: [{field: "Version", state: "concrete", declaredValue: "1.0.0"}]
	gate: {overridePresent: false}
}

// MUST FAIL — cue.mod disagrees with the artifact's declared identity.
//   cueModPath: conflicting values "...opm@v1" and "...other@v1"
//
//  _planPathSkew: #PublishPlan & {
//   artifactKind: "catalog"
//   declaredPath: "opmodel.dev/catalogs/opm@v1"
//   cueModPath:   "opmodel.dev/catalogs/other@v1"
//   tag: {tag: "v1.3.0"}
//   identity: [{field: "Version", state: "concrete"}]
//   gate: {overridePresent: false}
//  }
//
// MUST FAIL — an unfilled identity field.
//   go: conflicting values false and true
//
//  _planUnfilled: #PublishPlan & {
//   artifactKind: "catalog"
//   declaredPath: "opmodel.dev/catalogs/opm@v1"
//   cueModPath:   "opmodel.dev/catalogs/opm@v1"
//   tag: {tag: "v1.3.0"}
//   identity: [{field: "Version", state: "open"}]
//   gate: {overridePresent: false}
//  }
//
// MUST FAIL — the tag does not name the declared version (D18). Everything
// else about this plan is valid: the tag's major matches the path's, and the
// identity is concrete. Before D18 this yielded `go: true` and pushed bytes
// claiming 1.2.0 into a registry serving them as 1.3.0.
//   _versionAgrees: conflicting values false and true
//
//  _planTagVersionSkew: #PublishPlan & {
//   artifactKind: "catalog"
//   declaredPath: "opmodel.dev/catalogs/opm@v1"
//   cueModPath:   "opmodel.dev/catalogs/opm@v1"
//   tag: {tag: "v1.3.0"}
//   identity: [{field: "Version", state: "concrete", declaredValue: "1.2.0"}]
//   gate: {overridePresent: false}
//  }
//
// MUST FAIL — a module published to a catalogs/ path (D13, D14). D1 makes this
// one implementation with two entry points, so without this nothing stops
// `opm module publish` landing a module where consumers look for catalogs.
// Confirmed 2026-08-04 (cue v0.17.1):
//   _planWrongKind._kindAgrees: conflicting values false and true
//
//  _planWrongKind: #PublishPlan & {
//   artifactKind: "module"
//   declaredPath: "opmodel.dev/catalogs/opm@v1"
//   cueModPath:   "opmodel.dev/catalogs/opm@v1"
//   tag: {tag: "v1.3.0"}
//   identity: [{field: "Version", state: "concrete", declaredValue: "1.3.0"}]
//   gate: {overridePresent: false}
//  }
//
// MUST FAIL — the owner-scoped first-party shape D13 DECLINED. `opmodel.dev/m/
// <owner>/<name>` was D5's proposal; D13 kept first-party modules at
// opmodel.dev/modules/<name> and left owner-scoping to community space. Worth
// pinning as a case rather than trusting prose: this exact shape survived in
// enhancement 0010's own schema examples for weeks after D13 retired it,
// because a generic path regex accepts it. Confirmed 2026-08-04:
//   _planAbandonedOwnerScope._namespaceOK: conflicting values false and true
//
//  _planAbandonedOwnerScope: #PublishPlan & {
//   artifactKind: "module"
//   declaredPath: "opmodel.dev/m/acme/postgres@v2"
//   cueModPath:   "opmodel.dev/m/acme/postgres@v2"
//   tag: {tag: "v2.4.1"}
//   identity: [{field: "Version", state: "concrete", declaredValue: "2.4.1"}]
//   gate: {overridePresent: false}
//  }
//
// MUST FAIL — a first-party path under an unreserved segment (D14). The
// measured case is `opmodel.dev/releases/*`, which holds Flux artifacts and is
// not in the namespace #RegistryPath models. Confirmed 2026-08-04 — this one
// yields BOTH refusals, since `releases` is neither a valid kind segment nor
// one that agrees with artifactKind:
//   _planUnreservedSegment._namespaceOK: conflicting values false and true
//   _planUnreservedSegment._kindAgrees:  conflicting values false and true
//
//  _planUnreservedSegment: #PublishPlan & {
//   artifactKind: "module"
//   declaredPath: "opmodel.dev/releases/prod@v1"
//   cueModPath:   "opmodel.dev/releases/prod@v1"
//   tag: {tag: "v1.0.0"}
//   identity: [{field: "Version", state: "concrete", declaredValue: "1.0.0"}]
//   gate: {overridePresent: false}
//  }
//
// MUST FAIL — a nested path under a valid kind segment. This is D17's cleanup
// item `opmodel.dev/modules/test/hello_web`, which relocates to
// testing.opmodel.dev; the shape is refused because first-party space is
// exactly three segments. Confirmed 2026-08-04:
//   _planNestedPath._namespaceOK: conflicting values false and true
//
//  _planNestedPath: #PublishPlan & {
//   artifactKind: "module"
//   declaredPath: "opmodel.dev/modules/test/hello_web@v1"
//   cueModPath:   "opmodel.dev/modules/test/hello_web@v1"
//   tag: {tag: "v1.0.0"}
//   identity: [{field: "Version", state: "concrete", declaredValue: "1.0.0"}]
//   gate: {overridePresent: false}
//  }
//
// MUST FAIL — a catalog published from a tree carrying local overrides, with
// the allow flag passed. The flag does not apply to catalogs.
//   go: conflicting values false and true
//
//  _planCatalogOverride: #PublishPlan & {
//   artifactKind: "catalog"
//   declaredPath: "opmodel.dev/catalogs/opm@v1"
//   cueModPath:   "opmodel.dev/catalogs/opm@v1"
//   tag: {tag: "v1.3.0"}
//   identity: [{field: "Version", state: "concrete"}]
//   gate: {overridePresent: true, allowFlag: true}
//  }
