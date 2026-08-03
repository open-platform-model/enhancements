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

// #RegistryPath: the shape of a canonical published path. The leading segment
// after the domain is a RESERVED KIND segment, which is what makes the
// namespace partitionable — tooling can tell a module from a catalog from a
// schema by reading the path rather than fetching and decoding the artifact.
//
//   modules   opmodel.dev/m/<owner>/<name>
//   catalogs  opmodel.dev/catalogs/<name>
//   schema    opmodel.dev/core
#RegistryPath: {
	domain!: string
	kind!:   "m" | "catalogs"

	// owner: present for modules, absent for catalogs. Owner-scoping is what
	// supplies uniqueness structurally, so two publishers may both ship
	// "postgres" without a land grab and without the registry arbitrating.
	owner?: string
	name!:  string

	out: [
		if owner != _|_ {domain + "/" + kind + "/" + owner + "/" + name},
		domain + "/" + kind + "/" + name,
	][0]
}

_moduleNamespace: (#RegistryPath & {
	domain: "opmodel.dev"
	kind:   "m"
	owner:  "acme"
	name:   "media_server"
}).out & "opmodel.dev/m/acme/media_server"

_catalogNamespace: (#RegistryPath & {
	domain: "opmodel.dev"
	kind:   "catalogs"
	name:   "opm"
}).out & "opmodel.dev/catalogs/opm"

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
}

_identityConcrete: #IdentityState & {field: "Version", state: "concrete", publishable: true}
_identityFilled:   #IdentityState & {field: "Version", state: "open", suppliedByFlag: true, publishable: true}
_identityUnfilled: #IdentityState & {field: "Version", state: "open", publishable: false}
_identityAbsent:   #IdentityState & {field: "ModulePath", state: "absent", publishable: false}

// D12: `--version` agreeing with a concrete field is a no-op, not a refusal.
_identityAssertOK: #IdentityState & {
	field: "Version", state: "concrete"
	declaredValue: "1.3.0", suppliedValue: "1.3.0"
	publishable: true
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
	artifactKind!:   "module" | "catalog"
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

_gateClean:          #OverrideGate & {artifactKind: "module", overridePresent: false, proceed: true}
_gateModuleBlocked:  #OverrideGate & {artifactKind: "module", overridePresent: true, proceed: false}
_gateModuleAllowed:  #OverrideGate & {artifactKind: "module", overridePresent: true, allowFlag: true, proceed: true}
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
	// agree; whether publish enforces this or generates the file is OQ5.
	cueModPath!: string
	cueModPath:  declaredPath

	_split:       strings.SplitN(declaredPath, "@", 2)
	registryRepo: _split[0]
	major:        _split[1]

	tag!: #TagRef & {artifactMajor: major}

	identity!: [...#IdentityState]
	gate!:     #OverrideGate & {"artifactKind": artifactKind}

	// Every identity field must be publishable, and the gate must pass.
	// _unpublishable names the offenders, so a refusal can report them.
	_unpublishable: [for i in identity if !i.publishable {i.field}]

	go: len(_unpublishable) == 0 && gate.proceed
	go: true
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
		{field: "Version", state: "concrete"},
	]
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
