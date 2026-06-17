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

	// importQualified: the always-safe import spelling that names the package
	// explicitly. OQ2 (../03-decisions.md) decides whether the library helper
	// emits the bare importPath or this qualified form against the
	// kernel-pinned CUE toolchain.
	importQualified: importPath + ":" + packageName
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
