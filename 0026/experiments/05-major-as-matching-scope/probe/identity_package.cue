package core

import (
	"strings"
)

// WHY #IdentityPackage is a publish gate rather than a field: nothing in
// `core` unifies against it; a publishing tool loads the artifact's identity
// package and unifies the loaded value, so the author reads CUE's own error at
// the field rather than a hand-written expected-versus-found message that can
// drift from this definition (0011:D21/D22).
//
// Tooling writes exactly ModulePath and Version, located by THIS schema's field
// names rather than by a marker attribute (0010:D5). Everything
// else derives, so a publisher gains nothing new to keep in step.
//
// It applies to BOTH artifact kinds — a module carries an identity package too
// (0010:D2, 0011:D12) — which is why it ships here rather than in a catalog: a
// module need not depend on any particular catalog.
//
// `strings` is a CUE BUILTIN, so this definition adds no edge to the module
// graph. That matters because an artifact's identity/identity.cue deliberately
// carries no INTRA-MODULE import — it sits at the bottom of its own module's
// import graph so leaf packages can source ModulePath/Version without a cycle.
// That invariant is preserved here because validation is EXTERNAL: `core`
// exports the shape and the publishing tool does the unifying. An identity file
// never imports `core`, and shipping this definition does not change what it
// imports. SPEC.md § 5.2 Rationale, "Why exactly two fields are authored" and
// "Why validation is external, and why we don't have `identity.cue` import
// `core` and embed this definition".

// IdentityPackage is the shape an artifact's committed identity package must
// match — the two values a release moves, plus everything that derives from
// them. The file it types is `identity/identity.cue`, at the root of a module
// or a catalog. A PUBLISH GATE, not a field of any artifact: a publishing
// tool unifies the loaded package against it. See SPEC.md § 5.2.
#IdentityPackage: {
	// WHY ModulePath: 0010:D1.

	// Written by publish. Byte-identical to cue.mod's `module:` field, major
	// suffix included.
	ModulePath!: #ModulePathType

	// Written by `version set` / `publish --version`. The build every
	// implementation key interpolates.
	Version!: #VersionType

	_ref: #ArtifactRef & {modulePath: ModulePath}

	// WHY RegistryPath: 0010:D1.

	// RegistryPath: the OCI repository, major-free. Projected through
	// #ArtifactRef rather than split again here — one decomposition site is the
	// whole point of that definition.
	RegistryPath: _ref.registryPath // "opmodel.dev/catalogs/opm"

	// Major: the major the PATH declares.
	Major: _ref.major // "v1"

	// WHY this is the only assertion of that relation in the system: 0010:D40
	// originally had `core` assert it independently on both artifact types;
	// 0010:D43 removed that for #Catalog and 0010:D45 removed it for
	// #Module, both citing publish-side validation against THIS definition as
	// what replaces it. `identity_pins.cue`'s _pinModuleMajorSkewAccepted and
	// _pinCatalogMajorSkewAccepted are the deliberately-clean cases recording
	// that trade.
	//
	// So this is NOT a redundant check duplicating one on #Module or #Catalog.
	// There is nothing left to duplicate, and there is no downstream backstop
	// either. 0010:D43/D45 were written against a platform-side
	// subscription-selection major check — and that check HAS NEVER EXISTED IN
	// `core`. It was NOT removed by the scalar-subscription collapse; an
	// earlier revision of this comment said so and was wrong. Measured
	// 2026-08-08: no such assertion appears at any commit of src/, and the
	// pre-collapse subscription filter carried only range/allow/deny. Nothing
	// in #Platform ever related an entry's `version` to the "@vN" its
	// #registry key carries: not the removed Subscription definition, and
	// not #CatalogEntry, whose key binding constrains the embedded catalog's
	// modulePath but not the version major (0019:D5). The distinction
	// is about ownership rather than exposure: an unbuilt check has an owner
	// (the platform-side major-agreement check belongs to `library`'s
	// subscription-collapse work, not yet started), where a deleted one would
	// be a regression nobody holds. What is left today is a materialize-time
	// registry resolution failure naming a tag — a "@v1" module publishes v1.*
	// tags, so a 2.0.0 request simply does not resolve. That names the symptom,
	// not the mistake.
	//
	// Deleting this assertion therefore removes the relation from the system
	// outright.
	//
	// Asserting it here is also what puts the failure where it can be read: the
	// two values are WRITTEN in this file, so the error names the file the
	// author has open. SPEC.md § 5.2 Rationale, "Why the version/path major
	// relation is asserted here and nowhere else" and "Why it is asserted at
	// the point the values are written".

	// WHY VersionMajor: 0010:D40.

	// VersionMajor: derived from Version, never authored, and asserted equal to
	// the major the path declares. The assertion is the second declaration below
	// — unification is the check. THIS IS THE ONLY ASSERTION OF THAT RELATION IN
	// THE SYSTEM; deleting it removes the relation outright. See SPEC.md § 5.2.
	VersionMajor: "v" + strings.SplitN(Version, ".", 2)[0]
	VersionMajor: Major

	// WHY EXACTLY ONE BASE PREFIX PER KIND, with no ARBITRARY grouping
	// subdirectory beneath any of them (0010:D42). A CONTRACT
	// kind's members file exactly one segment beneath the prefix, under the
	// member's own apiVersion — a segment DERIVED from the member's key, so
	// filing and key cannot drift (0010:D49, amending 0010:D42); a
	// transformer files at the prefix itself, having no apiVersion (0010:D44). This
	// map plus that derivation is a COMPLETE statement of the catalog's key
	// space, not a convenience for the common case: #CatalogMemberFQNGate
	// unifies a member's declared path with the derived filing path and builds
	// its key from kindPrefix[kind] directly, so a member under a segment its
	// key does not imply is refused rather than tolerated.
	//
	// ENUMERATED RATHER THAN A PATTERN CONSTRAINT, and the difference is not
	// stylistic. `[Kind=string]: RegistryPath + "/" + Kind` is unusable at the
	// call site: `id.kindPrefix.resources` yields `undefined field`, because a
	// pattern constrains keys that already exist rather than generating them.
	// Measured in enhancements/0011/experiments/01, finding (b). SPEC.md § 5.2
	// Rationale, "Why `kindPrefix` is enumerated rather than a pattern
	// constraint" and "Why no arbitrary grouping segment is admitted beneath a
	// kind prefix, and why the apiVersion segment is".

	// WHY kindPrefix: 0010:D1.

	// kindPrefix: the path prefix every catalog member of a given kind hangs off.
	// The major is NOT re-appended — a catalog member declares a
	// #PackagePathType. Exactly one base prefix per kind; a contract kind files
	// one apiVersion segment beneath it, a transformer at the prefix itself.
	// Enumerated, not a pattern constraint.
	kindPrefix: {
		resources:    RegistryPath + "/resources"
		traits:       RegistryPath + "/traits"
		blueprints:   RegistryPath + "/blueprints"
		transformers: RegistryPath + "/transformers"
	}
}

// WHY #CatalogMemberFQNGate exists and is shaped this way. It is the
// enforcement point five decisions delegate to. Enhancement 0010:D17,
// D21, D25, D42 and D49 all state the catalog-member path and FQN rule and
// implement it nowhere; 0010:D21 in particular REMOVED `core`'s fqn derivation for every
// catalog member, accepting a measured loss — a catalog on 1.2.0 shipping
// `fqn: ".../secrets@1.1.0"` passes `cue vet -c` at exit 0 — explicitly in
// exchange for this gate. Under 0010:D4 a wrong key is permanent: modules match
// against it forever.
//
// A string comparison in Go would discard information this form keeps. A member
// one segment too deep fails on BOTH declaredModulePath and declaredFQN, and
// the second arrives wrapped as `2 errors in empty disjunction` because
// #FQNType is a disjunction (measured, 0010:D42).
//
// IT IS DELIBERATELY NOT EMBEDDED IN #Resource, #Trait, #Blueprint OR
// #ComponentTransformer. Expressing it inside a member's own definition would
// re-derive that member's `fqn` inside `core` and undo 0010:D21 —
// the derivation removal is what lets a contract declared in one catalog be
// fulfilled by a transformer in another on an independent release cadence.
// Unifying the gate is the check; the derivation stays out. SPEC.md § 5.3
// Rationale, "Why this gate exists at all", "Why it unifies rather than
// comparing, and what a string comparison would discard" and "Why the gate
// is not embedded in the member definitions".

// CatalogMemberFQNGate is the rule a publishing tool unifies every catalog
// member against — primitive OR transformer — to check that what the catalog
// AUTHORED agrees with what its identity package IMPLIES. A PUBLISH GATE, not
// part of any artifact: each `declared*` field is stated twice, once as
// authored and once as implied, and unification does the comparing. See
// SPEC.md § 5.3.
#CatalogMemberFQNGate: {
	identity!: #IdentityPackage
	kind!:     "resources" | "traits" | "blueprints" | "transformers"
	name!:     #NameType

	// What the catalog actually authored.
	declaredFQN!:            #FQNType
	declaredModulePath!:     #PackagePathType
	declaredCatalogVersion!: #VersionType

	// WHY declaredAPIVersion: 0010:D44.

	// Optional at the top level and REQUIRED for the three primitive kinds. A
	// transformer declares none — it carries no apiVersion at all — so requiring
	// it unconditionally would force every transformer to author a value nothing
	// reads.
	declaredAPIVersion?: #APIVersionType
	if kind != "transformers" {
		declaredAPIVersion!: #APIVersionType
	}

	// WHY derived from the key: so filing and key cannot drift (enhancement
	// 0010:D49). The transformer arm is selected before declaredAPIVersion is
	// reached, the same measured ordering _keyVersion relies on. SPEC.md
	// § 5.3 Rationale, "Why the filing segment is derived rather than
	// authored, and why transformers don't carry one".

	// WHY declaredModulePath: 0010:D17; 0010:D49; 0010:D44.

	// What identity/identity.cue implies. The path must sit under THIS catalog; a
	// CONTRACT kind files one segment beneath its kind prefix, under the member's
	// own apiVersion, a transformer at the prefix itself. The provenance must
	// name THIS build.
	declaredModulePath: [
		if kind == "transformers" {identity.kindPrefix[kind]},
		identity.kindPrefix[kind] + "/" + declaredAPIVersion,
	][0]
	declaredCatalogVersion: identity.Version

	// WHY the list-index form: the transformer branch is selected BEFORE
	// declaredAPIVersion is reached, which is what spares the absent optional.
	// Measured 2026-08-03 against cue v0.17.1: kind "transformers" with the
	// field absent yields the build with no error; kind "resources" supplying
	// it yields the apiVersion; kind "resources" omitting it fails
	// `declaredAPIVersion: field is required but not present`.

	// WHY _keyVersion: 0010:D4.

	// The key is interpolated from the CONTRACT for the three primitive kinds and
	// from the BUILD for a transformer. List-index form: the transformer arm is
	// selected before the optional is reached.
	_keyVersion: [
		if kind == "transformers" {identity.Version},
		declaredAPIVersion,
	][0]

	// WHY declaredFQN: 0010:D49.

	// The KEY does not carry the filing segment: the apiVersion reaches a
	// contract key once, as its "@vN" suffix, never as a path component. Filing
	// is versioned; the key space stays flat.
	declaredFQN: identity.kindPrefix[kind] + "/" + name + "@" + _keyVersion

	// NOTE what is absent: apiVersion is NOT checked against identity. Nothing
	// implies it. A primitive's contract level is a judgement its author makes
	// about that primitive's own shape, independent of the catalog's module
	// major and of the catalog's release SemVer (0010:D4, D25) —
	// which is the entire point of the field. A gate that derived it would be
	// asserting a relation that does not exist.
}
