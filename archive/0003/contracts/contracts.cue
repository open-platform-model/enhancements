// Target schema for enhancement 0003 (OPM Module Publishing Workflow).
//
// #CanonicalModuleRef is the single normative mapping (D1) from a module's
// #Module.metadata to its canonical CUE registry reference. The cli publish
// check and the library import helper both mirror this function, so there is
// one source of truth for "given a module's metadata, here is how to import
// and publish it."
//
// Inputs are projected from core's #Module.metadata (modulePath, nameSnakeCase,
// version). nameSnakeCase already lands in core (core/src/module.cue); this
// schema does not redefine it, it consumes it.
package contracts

import (
	"strings"
	"strconv"
)

// ─── Catalog compatibility (D19) ───────────────────────────────────────────
//
// FQNs are MAJOR-keyed (D18), so matching succeeds across every compatible
// build of a catalog. That is what makes the cross-minor pattern work, and it
// is also why a second signal is needed: with `@v1` on both sides, a module
// built against catalog 1.2.0 matches a platform that materialized 1.0.0 —
// right up until it demands a primitive 1.0.0 never shipped, which surfaces as
// a missing FQN naming nothing useful.
//
// The full version is that second signal. #Catalog keeps `metadata.version`
// (D19) and stamps it onto every primitive it ships, so a module inherits a
// record of which catalog build it was authored against. Comparing that record
// against the version the platform actually resolved turns "mystery missing
// primitive" into "this platform's catalog is older than this module needs."
//
// NOTE ON SCOPE: the shapes below state the invariant; they are not a semver
// implementation. They compare MAJOR.MINOR.PATCH numerically and IGNORE
// prerelease ordering — `1.0.0-dev` compares equal to `1.0.0` here, where real
// semver sorts it lower. The production comparison is Go, where
// library/opm/materialize/filter.go already uses a real semver library. See
// OQ17 for the dev-placeholder interaction this simplification papers over.

// #SemverTriple decomposes a SemVer string into [major, minor, patch],
// discarding any prerelease or build suffix.
#SemverTriple: {
	v!:    string
	_core: strings.SplitN(v, "-", 2)[0]
	_p:    strings.Split(_core, ".")
	out: [strconv.Atoi(_p[0]), strconv.Atoi(_p[1]), strconv.Atoi(_p[2])]
}

// #VersionGTE reports whether `have` is at least `want`.
#VersionGTE: {
	have!: [int, int, int]
	want!: [int, int, int]
	out: [
		if have[0] != want[0] {have[0] > want[0]},
		if have[1] != want[1] {have[1] > want[1]},
		have[2] >= want[2],
	][0]
}

// #CatalogCompat is the check the kernel performs when a platform's
// materialized catalog meets a module that was built against a catalog build.
// `satisfied` is constrained to true, so an out-of-date platform catalog is a
// unification failure rather than a value someone has to remember to inspect.
#CatalogCompat: {
	// requiredVersion: the catalog version the MODULE was built against,
	// inherited from the stamped metadata.version on the primitives its
	// components declare.
	requiredVersion!: string

	// resolvedVersion: the catalog version the PLATFORM materialized — the tag
	// materialize resolved (library/opm/materialize catalogBuild.Version).
	resolvedVersion!: string

	// Both sides must be the same major, or they are not the same catalog
	// contract at all and the FQNs would not have matched in the first place.
	major: (#SemverTriple & {v: requiredVersion}).out[0]
	major: (#SemverTriple & {v: resolvedVersion}).out[0]

	satisfied: (#VersionGTE & {
		have: (#SemverTriple & {v: resolvedVersion}).out
		want: (#SemverTriple & {v: requiredVersion}).out
	}).out
	satisfied: true
}

// _catalogCompatOK: the supported cross-minor pattern. A module built against
// catalog 1.0.0 runs on a platform that materialized 1.2.0.
_catalogCompatOK: #CatalogCompat & {
	requiredVersion: "1.0.0"
	resolvedVersion: "1.2.0"
}

// _catalogCompatEqual: the exact-match case still passes.
_catalogCompatEqual: #CatalogCompat & {
	requiredVersion: "1.2.0"
	resolvedVersion: "1.2.0"
}

// _catalogCompatTooOld pins the failure this exists to catch — a module built
// against 1.2.0 on a platform that only materialized 1.0.0. Commented out
// because it MUST NOT vet; unified live it yields
// `satisfied: conflicting values false and true`.
//
//  _catalogCompatTooOld: #CatalogCompat & {
//   requiredVersion: "1.2.0"
//   resolvedVersion: "1.0.0"
//  }
//
// _catalogCompatMajorSkew likewise: differing majors are not the same contract.
//
//  _catalogCompatMajorSkew: #CatalogCompat & {
//   requiredVersion: "1.2.0"
//   resolvedVersion: "2.0.0"
//  }

// #CanonicalModuleRef computes the canonical registry coordinates of a module
// from its metadata. Pure function: every output is derived, none are authored.
//
// D13 + D16 rewrite. `metadata.version` no longer exists (D13), and
// `metadata.modulePath` now carries the module's COMPLETE CUE module path
// including the major suffix (D16) — so this is no longer a function that
// *composes* a registry address out of a prefix and a name. The address is
// declared; what remains is projecting the package name and pairing the path
// with the tag an artifact was published at or resolved by.
#CanonicalModuleRef: {
	// ── Inputs (projected from #Module.metadata) ──────────────────────────

	// modulePath: the full CUE module path, major included (D16). This IS the
	// registry address and IS metadata.fqn — nothing is recombined.
	modulePath!: string // e.g. "opmodel.dev/m/acme/zot_registry_ttl@v0"

	nameSnakeCase!: string // e.g. "zot_registry_ttl" (core: snake_case of name)

	// ── Derived ───────────────────────────────────────────────────────────

	// importPath: what an `import` statement and a cue.mod dependency key
	// carry. Under D16 this is modulePath verbatim.
	importPath: modulePath

	// registryPath: the path with the major stripped — the OCI repository the
	// artifact's tags live under.
	registryPath: strings.SplitN(modulePath, "@", 2)[0]

	// major: read from the path rather than parsed out of a semver (D16). CUE
	// states it here; nothing else needs to compute it.
	major: strings.SplitN(modulePath, "@", 2)[1]

	// packageName: the module's CUE package name MUST equal nameSnakeCase, so a
	// bare import of modulePath binds to it (D5).
	packageName: nameSnakeCase

	// leafMatchesName: D1's constraint, now expressible over ONE field rather
	// than as a relationship between two independently-authored ones — the
	// declared path's leaf must be the module's snake-cased name.
	leafMatchesName: strings.HasSuffix(registryPath, "/" + nameSnakeCase)
	leafMatchesName: true

	// importQualified: the import spelling naming the package explicitly.
	// Retained for diagnostics (OQ2 resolved by D5 — the bare form binds).
	importQualified: importPath + ":" + packageName
}

// #PublishedModuleRef is a #CanonicalModuleRef bound to the artifact a module
// was actually published as or fetched from.
//
// D13 RETIRED THIS SHAPE'S VERSION HALF. It previously stated D3's invariant —
// the version declared inside the module equals the version of the artifact
// carrying it — as a unification that failed on a mismatched pair. With
// metadata.version deleted there is no second version to disagree, so the
// invariant is not enforced here; it is unrepresentable.
//
// What survives is the ADDRESSING half (D1/D6): the artifact must live where
// the module says it lives. Under D16 that is a comparison of one complete
// declared path against the path actually fetched, rather than against an
// address reassembled from a prefix and a name.
//
// artifactVersion is retained as the resolved tag — the value the kernel
// stamps into the D14/D15 label and writes to spec.module.version. It is
// recorded, not checked, because nothing inside the module claims a version
// for it to be checked against.
//
// The `self=` alias is required: embedded fields are unified into the value but
// are not in lexical scope, so the constraint below reaches them through it.
#PublishedModuleRef: self={
	#CanonicalModuleRef

	// The OCI coordinates in hand — the reference passed to the registry
	// loader, or the tag a publish is about to write.
	artifactPath!:    string
	artifactVersion!: string

	// The surviving invariant (D1/D6 path half): the artifact lives where the
	// metadata says it lives.
	artifactPath: self.importPath
}

// _publishedExample: podinfo declares its full CUE module path including the
// major (D16) and no version at all (D13). The artifact it was fetched from
// carries the tag; the module does not claim one.
_publishedExample: #PublishedModuleRef & {
	modulePath:    "opmodel.dev/modules/test/podinfo@v0"
	nameSnakeCase: "podinfo"

	artifactPath:    "opmodel.dev/modules/test/podinfo@v0"
	artifactVersion: "v0.1.3"
}

// _mismatchedPathExample pins what IS still an error: an artifact fetched from
// a path the module does not claim. Commented out because it must not vet.
//
//  _mismatchedPath: #PublishedModuleRef & {
//   modulePath:      "opmodel.dev/modules/test/podinfo@v0"
//   nameSnakeCase:   "podinfo"
//   artifactPath:    "opmodel.dev/modules/other/podinfo@v0"  // conflicts
//   artifactVersion: "v0.1.3"
//  }

// ─── Catalogs (D7) ─────────────────────────────────────────────────────────
//
// #Catalog carries no `name`: its metadata is modulePath + version, and its
// FQN is modulePath@version with no name segment (core/src/catalog.cue). The
// addressing half is therefore degenerate — registryPath IS modulePath — and
// the whole exposure is the version dimension, where #Catalog is weaker than
// #Module because `version!` carries a *"0.0.0-dev" DEFAULT: silence publishes
// a placeholder rather than failing.
//
// These shapes exist so the publish command and the materialize-side check
// share one derivation of major/importPath/depVersion instead of each
// open-coding the "v" + version prefix that 01-problem.md records getting
// wrong once already.

// #CanonicalCatalogRef computes the canonical registry coordinates of a
// catalog from its metadata. D17 applies D13 + D16 here unchanged: no version
// field exists, and modulePath carries the full CUE module path including the
// major.
#CanonicalCatalogRef: {
	// ── Inputs (projected from #Catalog.metadata) ─────────────────────────

	// modulePath: the full CUE module path, major included (D16/D17). This IS
	// the registry address, the #Platform.#registry subscription key's resolved
	// form, and #Catalog.metadata.fqn.
	modulePath!: string // e.g. "opmodel.dev/catalogs/opm@v1"

	// ── Derived ───────────────────────────────────────────────────────────

	importPath: modulePath

	// registryPath: the path with the major stripped — the OCI repository the
	// catalog's tags live under, and the prefix its primitives hang off.
	registryPath: strings.SplitN(modulePath, "@", 2)[0]

	// major: read from the path (D16). This is what #Catalog's pattern
	// constraint stamps onto every #transformers entry in place of the deleted
	// catalog version, so it is the matcher's key space in one value.
	major: strings.SplitN(modulePath, "@", 2)[1]

	// transformerPrefix: the modulePath every stamped transformer receives.
	// Composed by splitting the major OUT and re-appending it, because under
	// D16 the major sits mid-string rather than at the end.
	transformerPrefix: registryPath + "/transformers"

	// transformerFQN: the shape of a stamped transformer's FQN under D17 —
	// major-keyed, not semver-keyed. A patch or minor catalog release no
	// longer changes this string, so it no longer invalidates the matcher.
	transformerFQN: {
		name!: string
		out:   transformerPrefix + "/" + name + "@" + major
	}
}

// #PublishedCatalogRef binds a #CanonicalCatalogRef to the artifact a catalog
// was published as or materialized from. Same invariant as
// #PublishedModuleRef, same failure mode: a conflict naming both values.
//
// The consumer side is `library/opm/materialize` rather than
// AcquireModuleFromRegistry — catalogs arrive through subscription
// resolution, so that pull is the catalog's acquire point (D6 via D7).
// D17 retires this shape's version half exactly as D13 did for modules:
// with no catalog version there is nothing for the tag to disagree with.
// artifactVersion is recorded — it is what materialize resolved and what the
// kernel reports — not checked.
#PublishedCatalogRef: self={
	#CanonicalCatalogRef

	artifactPath!:    string
	artifactVersion!: string

	// The surviving invariant: the artifact lives where the metadata says.
	artifactPath: self.importPath
}

// _publishedCatalogExample under D17. The catalog declares its full module
// path and no version; the artifact it was materialized from carries the tag.
// Contrast the state this replaces (workspace registry, 2026-07-25): the same
// catalog shipped identity/version_override.cue declaring Version
// "1.0.0-alpha.2", generated into the artifact and absent from source, which
// experiment 01 measured making local and published FQNs disagree.
_publishedCatalogExample: #PublishedCatalogRef & {
	modulePath: "opmodel.dev/catalogs/opm@v1"

	artifactPath:    "opmodel.dev/catalogs/opm@v1"
	artifactVersion: "v1.0.0-alpha.2"
}

// _transformerFQNExample pins the D17 key shape: major-keyed, so the alpha.2
// and 1.1.0 releases of this catalog produce the SAME matcher key and a module
// built against either matches a platform subscribed to the other.
_transformerFQNExample: (_publishedCatalogExample.transformerFQN & {name: "deployment"}).out & "opmodel.dev/catalogs/opm/transformers/deployment@v1"

// _example pins the zot case from 01-problem.md so the mapping stays honest:
// metadata.name "zot-registry-ttl" → nameSnakeCase "zot_registry_ttl" →
// importable at opmodel.dev/modules/zot_registry_ttl@v0.
_example: #CanonicalModuleRef & {
	modulePath:    "opmodel.dev/modules/zot_registry_ttl@v0"
	nameSnakeCase: "zot_registry_ttl"

	registryPath: "opmodel.dev/modules/zot_registry_ttl"
	importPath:   "opmodel.dev/modules/zot_registry_ttl@v0"
	major:        "v0"
	packageName:  "zot_registry_ttl"
}
