// Contracts for enhancement 0016 — Initialize a Module Instance Package
// from a Published Module.
//
// CLI command contracts for `opm instance init`: the command's resolved
// input (#InstanceInitRequest), the version-selection rule (#VersionSelector,
// #VersionSelection), its user-facing success report (#InstanceInitReport),
// the vocabulary naming which content populated the generated values.cue
// (#ValuesSource), and the exact file set the command writes
// (#ScaffoldedPackage). None of this adds or changes an opmodel.dev/core
// definition — the core-schema delta lives in ../schemas/target.cue. The
// eventual source of truth is the CLI implementation; these shapes are the
// design contract it must satisfy.
//
// Every Open Question is resolved (07-questions.md); no field is gated.
package contracts

// #InstanceInitRequest: the resolved input of `opm instance init` after
// flag parsing. The surface mirrors `opm module init` (D5): the instance
// name stands where the new module path stands, the deployed module where
// the template stands.
#InstanceInitRequest: {
	// Instance identity, written into instance.cue metadata. Prompted for
	// when omitted on a terminal; refused when omitted without one (D5).
	name!:      string
	namespace!: string

	// The published module to deploy, as a MAJOR-FREE module path resolved
	// to an OCI repository via standard CUE_REGISTRY routing. A major
	// suffix is refused ("use --version"); an OCI URL or bare word is
	// refused (D5).
	modulePath!: string & !~"@" // e.g. "opmodel.dev/modules/cert_manager"

	// Version selection (D5). Absent means "highest core-compatible major,
	// newest release".
	version?: #VersionSelector

	// Target directory. Defaults to the instance name; must not exist and
	// must not already hold a module or instance package (D5).
	dir?: string

	// The generated package's own module path. Never published; defaults
	// to "instance.local/<name>@v0" (D9).
	modulePathOverride?: string
}

// #VersionSelector: what --version may say. "v3" floats to the newest
// release within major v3 (stable preferred, prerelease fallback); a bare
// SemVer pins that exact tag.
#VersionSelector: =~"^v[0-9]+$" | =~"^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$"

// #VersionSelection: how the resolved version was arrived at, reported to
// the user (D5). When the selector was absent, `skipped` lists every
// higher major passed over because its opmodel.dev/core dependency major
// differs from this CLI build's core major.
#VersionSelection: {
	major:    =~"^v[0-9]+$"
	version:  string // bare SemVer, e.g. "3.0.0"
	strategy: "exact" | "float-major" | "highest-compatible-major"
	cliCoreMajor: =~"^v[0-9]+$"
	skipped: [...{major: =~"^v[0-9]+$", coreMajor: =~"^v[0-9]+$"}]
}

// #ValuesSource: which content populated the generated values.cue —
// reported to the user so a debug-derived or empty scaffold is visibly
// that (D2, D6).
#ValuesSource: "initValues" | "debugValues" | "empty"

// #ScaffoldedPackage: the exact file set init writes — the same on-disk
// instance-package shape LoadInstancePackage consumes, so init output is
// immediately valid input to `opm instance build` / `apply` and the
// operator's ModulePackage path (D1).
#ScaffoldedPackage: {
	files: {
		// The generated package's own module file: local placeholder (or
		// overridden) module path, language version, the deployed module
		// pinned to the exact resolved version, opmodel.dev/core at the
		// major the module itself depends on, and the rest of the
		// dependency closure — equivalent to a tidied module file, so the
		// package builds with no further step (D9).
		"cue.mod/module.cue": #GeneratedFile

		// Imports core and the module, embeds core.#ModuleInstance, states
		// metadata {name, namespace}, wires `#module: <module package>`.
		"instance.cue": #GeneratedFile

		// `values: {...}` rendered from the selected #ValuesSource by
		// serialization (never template expansion). Source "empty" yields
		// `values: {}` (D6); a non-concrete initValues renders as partial
		// scaffolding (D4).
		"values.cue": #GeneratedFile
	}
}

#GeneratedFile: {
	content: string
}

// #InstanceInitReport: what the command tells the user on success. Init
// does not validate the package it wrote (D8); `next` names the command
// that does.
#InstanceInitReport: {
	modulePath: string
	selection:  #VersionSelection
	valuesSource: #ValuesSource
	dir:        string

	// Non-fatal notices — "values.cue scaffolded from debugValues; review
	// before deploying" when valuesSource is "debugValues"; "no initValues
	// or debugValues; values.cue is empty" when it is "empty" (D2, D6).
	warnings: [...string]

	// The validation command for the generated directory (D8).
	next: string // e.g. "opm instance vet <dir>/instance.cue"
}

// Sanity: every source in the ladder produces a report.
_exampleReport: #InstanceInitReport & {
	modulePath: "opmodel.dev/modules/cert_manager"
	selection: {
		major:        "v2"
		version:      "2.0.1"
		strategy:     "highest-compatible-major"
		cliCoreMajor: "v2"
		skipped: [{major: "v3", coreMajor: "v3"}]
	}
	valuesSource: "debugValues"
	dir:          "cert-manager"
	warnings: ["values.cue scaffolded from debugValues; review before deploying"]
	next: "opm instance vet cert-manager/instance.cue"
}
