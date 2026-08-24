package core

import (
	"strings"
)

// IdentityPackage is the shape an artifact's committed identity package must
// match — the two values a release moves, plus everything that derives from
// them.
//
// The file it types is `identity/identity.cue`, at the root of a module or a
// catalog.
//
// It is a PUBLISH GATE (see SPEC.md §5), not a field of any artifact. Nothing
// in `core` unifies against it; a publishing tool loads the artifact's identity
// package and unifies the loaded value, so the author reads CUE's own error at
// the field rather than a hand-written expected-versus-found message that can
// drift from this definition (enhancement 0011 D21/D22).
//
// Tooling writes exactly ModulePath and Version, located by THIS schema's field
// names rather than by a marker attribute (enhancement 0010 D5). Everything
// else derives, so a publisher gains nothing new to keep in step.
//
// It applies to BOTH artifact kinds — a module carries an identity package too
// (0010 D38, 0011 D12) — which is why it ships here rather than in a catalog: a
// module need not depend on any particular catalog.
//
// `strings` is a CUE BUILTIN, so this definition adds no edge to the module
// graph. That matters because an artifact's identity/identity.cue deliberately
// carries no INTRA-MODULE import — it sits at the bottom of its own module's
// import graph so leaf packages can source ModulePath/Version without a cycle.
// That invariant is preserved here because validation is EXTERNAL: `core`
// exports the shape and the publishing tool does the unifying. An identity file
// never imports `core`, and shipping this definition does not change what it
// imports.
#IdentityPackage: {
	// Written by publish. Byte-identical to cue.mod's `module:` field, major
	// suffix included (enhancement 0010 D1).
	ModulePath!: #ModulePathType

	// Written by `version set` / `publish --version`. The build every
	// implementation key interpolates.
	Version!: #VersionType

	_ref: #ArtifactRef & {modulePath: ModulePath}

	// RegistryPath: the OCI repository, major-free. Projected through
	// #ArtifactRef rather than split again here — one decomposition site is the
	// whole point of that definition (enhancement 0010 D1).
	RegistryPath: _ref.registryPath // "opmodel.dev/catalogs/opm"

	// Major: the major the PATH declares.
	Major: _ref.major // "v1"

	// VersionMajor: derived from Version, never authored (enhancement 0010 D40),
	// and asserted equal to the major the path declares. The assertion is the
	// second declaration below — unification is the check.
	//
	// THIS IS THE ONLY ASSERTION OF THAT RELATION IN THE SYSTEM. D40 originally
	// had `core` assert it independently on both artifact types; enhancement
	// 0010 D43 removed that for #Catalog and D45 removed it for #Module, both
	// citing publish-side validation against THIS definition as what replaces
	// it. `identity_pins.cue`'s _pinModuleMajorSkewAccepted and
	// _pinCatalogMajorSkewAccepted are the deliberately-clean cases recording
	// that trade.
	//
	// So this is NOT a redundant check duplicating one on #Module or #Catalog.
	// There is nothing left to duplicate, and there is no downstream backstop
	// either. 0010 D43/D45 were written against a platform-side
	// subscription-selection major check — and that check HAS NEVER EXISTED IN
	// `core`. It was NOT removed by the scalar-subscription collapse; an
	// earlier revision of this comment said so and was wrong. Measured
	// 2026-08-08: no such assertion appears at any commit of src/, and the
	// pre-collapse subscription filter carried only range/allow/deny. Nothing
	// in #Platform / #Subscription relates a subscription's `version` to the
	// "@vN" its #registry key carries, and nothing ever did. The distinction
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
	// author has open.
	VersionMajor: "v" + strings.SplitN(Version, ".", 2)[0]
	VersionMajor: Major

	// kindPrefix: the path prefix every catalog member of a given kind hangs
	// off. The major is NOT re-appended — a catalog member declares a
	// #PackagePathType (enhancement 0010 D1).
	//
	// EXACTLY ONE BASE PREFIX PER KIND, with no ARBITRARY grouping
	// subdirectory beneath any of them (enhancement 0010 D42). A CONTRACT
	// kind's members file exactly one segment beneath the prefix, under the
	// member's own apiVersion — a segment DERIVED from the member's key, so
	// filing and key cannot drift (enhancement 0010 D49, amending D42); a
	// transformer files at the prefix itself, having no apiVersion (D44). This
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
	// Measured in enhancements/0011/experiments/01, finding (b).
	kindPrefix: {
		resources:    RegistryPath + "/resources"
		traits:       RegistryPath + "/traits"
		blueprints:   RegistryPath + "/blueprints"
		transformers: RegistryPath + "/transformers"
	}
}

// CatalogMemberFQNGate is the rule a publishing tool unifies every catalog
// member against — primitive OR transformer — to check that what the catalog
// AUTHORED agrees with what its identity package IMPLIES.
//
// It is a PUBLISH GATE (see SPEC.md §5), not part of any artifact. Each
// `declared*` field is stated twice: once as the value the catalog wrote, once
// as the value identity implies. Unification does the comparing, so the author
// reads CUE's own diagnostic.
//
// It is the enforcement point five decisions delegate to. Enhancement 0010 D17,
// D21, D25, D42 and D49 all state the catalog-member path and FQN rule and
// implement it nowhere; D21 in particular REMOVED `core`'s fqn derivation for every
// catalog member, accepting a measured loss — a catalog on 1.2.0 shipping
// `fqn: ".../secrets@1.1.0"` passes `cue vet -c` at exit 0 — explicitly in
// exchange for this gate. Under D4 a wrong key is permanent: modules match
// against it forever.
//
// A string comparison in Go would discard information this form keeps. A member
// one segment too deep fails on BOTH declaredModulePath and declaredFQN, and
// the second arrives wrapped as `2 errors in empty disjunction` because
// #FQNType is a disjunction (measured, enhancement 0010 D42).
//
// IT IS DELIBERATELY NOT EMBEDDED IN #Resource, #Trait, #Blueprint OR
// #ComponentTransformer. Expressing it inside a member's own definition would
// re-derive that member's `fqn` inside `core` and undo enhancement 0010 D21 —
// the derivation removal is what lets a contract declared in one catalog be
// fulfilled by a transformer in another on an independent release cadence.
// Unifying the gate is the check; the derivation stays out.
#CatalogMemberFQNGate: {
	identity!: #IdentityPackage
	kind!:     "resources" | "traits" | "blueprints" | "transformers"
	name!:     #NameType

	// What the catalog actually authored.
	declaredFQN!:            #FQNType
	declaredModulePath!:     #PackagePathType
	declaredCatalogVersion!: #VersionType

	// Optional at the top level and REQUIRED for the three primitive kinds
	// (enhancement 0010 D44). A transformer declares none — it carries no
	// apiVersion at all — so requiring it unconditionally would force every
	// transformer to author a value nothing reads.
	declaredAPIVersion?: #APIVersionType
	if kind != "transformers" {
		declaredAPIVersion!: #APIVersionType
	}

	// What identity/identity.cue implies. The path must sit under THIS catalog
	// (enhancement 0010 D17), and a CONTRACT kind files one segment beneath
	// its kind prefix, under the member's own apiVersion — derived from the
	// key, so filing and key cannot drift (enhancement 0010 D49). A
	// transformer files at the prefix itself (no apiVersion, D44); its arm is
	// selected before declaredAPIVersion is reached, the same measured
	// ordering _keyVersion relies on. The provenance must name THIS build.
	declaredModulePath: [
		if kind == "transformers" {identity.kindPrefix[kind]},
		identity.kindPrefix[kind] + "/" + declaredAPIVersion,
	][0]
	declaredCatalogVersion: identity.Version

	// The key is interpolated from the CONTRACT for the three primitive kinds
	// and from the BUILD for a transformer (enhancement 0010 D4).
	//
	// The transformer branch is selected BEFORE declaredAPIVersion is reached,
	// which is what spares the absent optional. Measured 2026-08-03 against cue
	// v0.17.1: kind "transformers" with the field absent yields the build with
	// no error; kind "resources" supplying it yields the apiVersion; kind
	// "resources" omitting it fails `declaredAPIVersion: field is required but
	// not present`.
	_keyVersion: [
		if kind == "transformers" {identity.Version},
		declaredAPIVersion,
	][0]

	// The KEY does not carry the filing segment: the apiVersion reaches a
	// contract key once, as its "@vN" suffix, never as a path component
	// (enhancement 0010 D49). Filing is versioned; the key space stays flat.
	declaredFQN: identity.kindPrefix[kind] + "/" + name + "@" + _keyVersion

	// NOTE what is absent: apiVersion is NOT checked against identity. Nothing
	// implies it. A primitive's contract level is a judgement its author makes
	// about that primitive's own shape, independent of the catalog's module
	// major and of the catalog's release SemVer (enhancement 0010 D4, D25) —
	// which is the entire point of the field. A gate that derived it would be
	// asserting a relation that does not exist.
}
