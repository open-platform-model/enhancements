// Target schema for enhancement 0004 — Automated CUE Dependency Updates via Renovate.
//
// This is not an OPM runtime schema. It is the shape of the *shared Renovate
// preset*, authored in CUE and exported to the JSON that Renovate consumes —
// the same pattern navecd uses with its renovate.cue. The shared preset is
// the single source of truth; each repo's renovate.json does nothing but
// `extends` it. Modelling it here keeps the OCI-route map (the load-bearing
// coupling) under `cue vet` instead of buried in hand-written JSON.
//
// As decisions land in ../03-decisions.md, tighten the fields marked with
// `// OQN:` comments.
package schema

// #RegistryRoute maps a CUE module-path host prefix (as it appears in a
// cue.mod/module.cue `deps` key) to the OCI registry that backs it. This map
// MIRRORS CUE_REGISTRY — it is the one place Renovate and the workspace
// registry configuration must agree, and the primary drift risk (see OQ1).
#RegistryRoute: {
	// Host prefix as written in deps keys, e.g. "opmodel.dev/".
	hostPrefix!: string
	// OCI registry base URL the `docker` datasource queries.
	registryUrl!: string
	// Renovate template producing the OCI repository name from the captured
	// `package` group (the module path with hostPrefix already stripped by
	// the regex). Triple-brace = no HTML-escaping of the value.
	packageNameTemplate!: string
}

// The route table. Derived from GHCR_CUE_REGISTRY / CUE_REGISTRY in the
// workspace Taskfile:
//   opmodel.dev=ghcr.io/open-platform-model   (host replaced by prefix)
//   <fallback>=registry.cue.works             (host kept as path component)
#routes: [...#RegistryRoute] & [
	{
		hostPrefix:          "opmodel.dev/"
		registryUrl:         "https://ghcr.io"
		packageNameTemplate: "open-platform-model/{{{package}}}"
	},
	{
		hostPrefix:          "cue.dev/"
		registryUrl:         "https://registry.cue.works"
		packageNameTemplate: "cue.dev/{{{package}}}"
	},
]

// #CustomManager is a Renovate regex-type custom manager. One is emitted per
// route: the regex captures the `package` (module path minus hostPrefix) and
// the pinned `currentValue` from inside the deps block, and the datasource is
// always `docker` (CUE modules are OCI artifacts; tags list as clean semver —
// validated against registry.cue.works on 2026-06-17).
#CustomManager: {
	customType:           "regex"
	managerFilePatterns!: [...string]
	matchStrings!: [...string]
	datasourceTemplate:   "docker"
	registryUrlTemplate!: string
	packageNameTemplate!: string
	versioningTemplate:   "semver"
	// OQ2: the exact regex must tolerate both deps-key layouts —
	//   "<mod>@vN": { v: "vX.Y.Z" }
	//   "<mod>@vN": { v: "vX.Y.Z"; default: true }
	// A spike-validated regex replaces this sketch.
}

// One manager per route. `package` strips the hostPrefix because the prefix
// is baked into packageNameTemplate. The `@vN` in the key is matched but NOT
// captured into the version — the major is pinned by the import path and must
// never move (see #pinMajor).
#managers: [for r in #routes {
	#CustomManager
	managerFilePatterns: [#"/(^|/)cue\.mod/module\.cue$/"#]
	matchStrings: [
		#"\#(r.hostPrefix)(?<package>[^@"]+)@v\d+":\s*\{[^}]*?v:\s*"(?<currentValue>[^"]+)""#,
	]
	registryUrlTemplate: r.registryUrl
	packageNameTemplate: r.packageNameTemplate
}]

// CUE modules pin their major in the import path (`@v0`). On GHCR a module's
// v0.x and v1.x tags share ONE OCI repo, so the docker datasource would
// otherwise surface a v1 bump that silently breaks the import path. Disabling
// major updates for these managers is the guard.
#pinMajor: {
	matchManagers: ["custom.regex"]
	matchDatasources: ["docker"]
	major: enabled: false
}

// Self-hosted-only: after a bump, re-resolve and tidy so the PR is a
// consistent module, not just a rewritten version string. Requires the
// command to be allow-listed in the self-hosted Renovate config and `cue`
// + registry auth present in the runner.
#postUpgrade: {
	commands: [
		"cue mod tidy",
	]
	fileFilters: [#"**/cue.mod/module.cue"#]
	executionMode: "update"
}

// The exported preset. Per-repo renovate.json is just:
//   { "extends": ["github>open-platform-model/<host-repo>//renovate/opm-cue.json5"] }
config: {
	customManagers: #managers
	packageRules: [#pinMajor]
	postUpgradeTasks: #postUpgrade
	// OQ3: one grouped CUE-bump PR per repo per run vs per-dep PRs.
}
