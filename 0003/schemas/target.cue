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
package schema

import "strings"

// #CanonicalModuleRef computes the canonical registry coordinates of a module
// from its metadata. Pure function: every output is derived, none are authored.
#CanonicalModuleRef: {
	// ── Inputs (projected from #Module.metadata) ──────────────────────────
	modulePath!:    string // e.g. "opmodel.dev/modules"
	nameSnakeCase!: string // e.g. "zot_registry_ttl" (core: snake_case of name)
	version!:       string // e.g. "0.1.0" (metadata.version, no leading "v")

	// ── Derived coordinates ───────────────────────────────────────────────

	// major: the "vN" qualifier from the version's major component.
	major: "v" + strings.SplitN(version, ".", 2)[0]

	// registryPath: the bare CUE registry module path (no @major suffix). The
	// path leaf MUST be nameSnakeCase — this is what binds identity to address.
	registryPath: modulePath + "/" + nameSnakeCase

	// packageName: the module's CUE package name MUST equal nameSnakeCase, so a
	// bare import of registryPath@major binds to it.
	packageName: nameSnakeCase

	// importPath: the major-qualified path written in an `import` statement and
	// as a cue.mod/module.cue dependency key.
	importPath: registryPath + "@" + major

	// depVersion: the exact version string for a cue.mod dep entry ("vX.Y.Z").
	depVersion: "v" + version

	// importQualified: the import spelling that names the package explicitly.
	// OQ2 is resolved (D5): the bare importPath binds, because D1 makes the
	// path leaf equal the package name. This form is retained for diagnostics
	// and for reporting a non-conforming module's actual coordinates.
	importQualified: importPath + ":" + packageName
}

// #PublishedModuleRef is a #CanonicalModuleRef bound to the artifact a module
// was actually published as or fetched from. It states D3's invariant as a
// constraint rather than a convention: the version declared inside the module
// and the version of the artifact carrying it are the SAME value, so unifying
// a mismatched pair is an error rather than a silently accepted disagreement.
//
// Consumers unify the coordinates they resolved by; producers unify the
// coordinates they are about to push to. Both fail the same way.
// The `self=` alias is required: embedded fields are unified into the value but
// are not in lexical scope, so the constraints below reach them through it.
#PublishedModuleRef: self={
	#CanonicalModuleRef

	// artifactPath and artifactVersion are the OCI coordinates in hand — the
	// reference passed to the registry loader, or the tag a publish is about
	// to write.
	artifactPath!:    string
	artifactVersion!: string

	// The invariant. artifactVersion is the v-prefixed release tag, so it must
	// equal depVersion, which is "v" + metadata.version. A module whose
	// metadata says 0.1.3 cannot be the artifact published as v0.2.0.
	artifactVersion: self.depVersion

	// The addressing half of the same idea (D1): the artifact must live where
	// the metadata says it lives.
	artifactPath: self.importPath
}

// _publishedExample pins the invariant: podinfo declaring metadata.version
// "0.1.3" is the artifact at .../podinfo@v0 tagged v0.1.3, and nothing else.
_publishedExample: #PublishedModuleRef & {
	modulePath:    "opmodel.dev/modules/test"
	nameSnakeCase: "podinfo"
	version:       "0.1.3"

	artifactPath:    "opmodel.dev/modules/test/podinfo@v0"
	artifactVersion: "v0.1.3"
}

// _example pins the zot case from 01-problem.md so the mapping stays honest:
// metadata.name "zot-registry-ttl" → nameSnakeCase "zot_registry_ttl" →
// importable at opmodel.dev/modules/zot_registry_ttl@v0.
_example: #CanonicalModuleRef & {
	modulePath:    "opmodel.dev/modules"
	nameSnakeCase: "zot_registry_ttl"
	version:       "0.1.0"

	registryPath: "opmodel.dev/modules/zot_registry_ttl"
	importPath:   "opmodel.dev/modules/zot_registry_ttl@v0"
	depVersion:   "v0.1.0"
	packageName:  "zot_registry_ttl"
}
