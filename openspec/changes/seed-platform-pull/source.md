# Source note: seed-platform-pull

This is a seed. It records behaviour the CLI ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `platform-pull`. Four requirements, all the pull command's own. Written 2026-10-11 from `cli` at commit `09b0b812` and `library` at `a87fdda`. The behaviour comes from enhancement 0015, the decision that gave the CLI a pull command ("fetch, not write-back"; its requirements R1 to R3).

## Sources

All read at the commits named. The requirement text is rewritten at intent level: no Go symbol, flag, field path or file path. The overwrite option is `--force`; the seed does not name it.

| Requirement here | Source requirement in the CLI's spec | Code read |
| --- | --- | --- |
| Pull writes the cluster's platform module | `cli` `openspec/specs/platform-pull/spec.md` at `09b0b812`, "opm platform pull writes the cluster's platform package to a directory" | `internal/cmd/platform/pull.go` (`RunPlatformPull`, `copyModule`, `readModuleFiles`); `internal/platform/cluster.go` (`ClusterPlatformGetterFor`: one `Get`, no write); `library` `opm/helper/platformmodule/write.go` (`WriteTo` writes regular files) |
| Pull reports what it reproduced | same file, "pull reports what it reproduced" (the warnings sentence included) | `internal/cmd/platform/pull.go` (`pullReport`, `describeGeneration`); `internal/platform/resolve.go` (`Resolution.Describe`) |
| Pull never overwrites by accident | same file, "pull refuses to overwrite by accident" | `internal/cmd/platform/pull.go` (`checkPullTarget`, `copyModule`) |
| Pull has no local fallback | same file, "pull has no local fallback" | `internal/cmd/platform/pull.go` (`pullResolveError`); `internal/platform/resolve.go` (`resolveCluster`, `ErrNoClusterPlatform`); `internal/platform/cluster.go`; `internal/platform/spec.go` (`DecodeCR`); `internal/platform/generate.go` (`generatorEntries`) |

Tests read for the scenarios: `internal/cmd/platform/pull_test.go` (writes the cached module, twice gives identical bytes, non-empty target refused, overwrite replaces, no Platform exits not-found and creates no directory, legacy spec exits validation, the report, the spec fallback in the report).

## Where the spec and the code differ

The code wins. Each point is in the seed.

- A target that is a file is refused with or without the overwrite option (`checkPullTarget`). The spec is silent. Scenario "A file target is refused".
- The target is checked before the cluster is read (`RunPlatformPull`, first call). The spec is silent. Scenario "The target is judged before the cluster is read". It holds when the failure is a cluster that cannot be reached at the read. A kubeconfig that cannot be resolved fails earlier, before the command runs, and is not a rule of this seed.
- A Platform the user may not read is treated as absent and exits with the not-found code (`GetterFor`, `resolveCluster` under no-fallback). The spec says "without a readable Platform CR". Scenario "A Platform the user may not read".
- A status registry entry without a version is refused naming the entry (`DecodeCR`). The spec does not say it. Scenario "A hand-edited status is refused".
- The validation code covers every failure after the Platform was read and before the module was written, not only the two examples the spec gives (`pullResolveError`, default branch). A registry that cannot be reached while the dependency list is derived is one more such failure. The requirement says "such as".
- The package identity is printed from the status, as recorded, and never verified or stored in the module (`Resolution.PackageIdentity`). Enhancement 0015 R3 says the pulled package "carries" the identity. The CLI spec says the command prints it. The requirement follows the spec and the code.

## Code-only statements

The CLI spec does not say these two. They rest on code and are marked here so that the owner sees them in the sample.

- The scenario "The directory holds real files" (requirement 1). The spec says only that the module's files are written. The code copies the generated module through the library writer, which writes regular files (`copyModule`; `library` `opm/helper/platformmodule/write.go`).
- "The generation the operator last built from" in requirement 3. The spec lists the name and generation only. The code prints the observed generation beside the generation (`describeGeneration`).

## Left out

- How the platform is resolved: the choice between the recorded registry and the authored subscriptions, the enabled flag of a recorded entry, the stale-status and not-Ready conditions that raise a warning, the precedence of the platform sources of each command, and the claim that the CLI's module equals the operator's for the same generator release. All of it is `cli` `platform-resolution`, and the owner gave it its own seed, `seed-platform-resolution` (DECISIONS.md 2026-10-11 11:20; it replaces the 06:40 ruling 3 exclusion). Pull states only what it reports about the source it used, and that it relays the warnings. Requirement 1's first scenario says only that the pinned catalogs are the recorded ones.
- The skew policy (`Resolution.SkewPolicy`). Pull does not use it. It belongs to platform resolution (`seed-platform-resolution`).
- The cache of generated modules (a directory named by a content hash, staging and rename, concurrent writes). A mechanism no consumer observes. The pulled directory is a copy of it.
- How the module is generated: pure and deterministic output, the dependency list from published module files, the reserved module path, core pinned at the verified release, one importing entry per catalog, a disabled entry kept pinned. All of it is held by `seed-platform-module-generation`. Requirement 1 says only that the written module is the generated one.
- What Platform status records (package identity, resolved registry with source, version and whether an entry registers transformers, the Ready reasons). Held by `seed-platform-module-generation`, "Platform status names the package and its registry". Pull reads these and reports them.
- The Platform singleton and its spec shape. Held by `seed-platform-module-generation`. Scenarios name the singleton as `cluster` only.
- Registry entry rules (one entry per catalog path, expected version). Held by `seed-platform-registry`.
- Contract inventory reports and which of them fail a check (`opm platform check`). `seed-platform-contract-gates` owns them.
- The content digest on Platform status that 0015 D6 names as an operator follow-up. It is not shipped.
- The kubeconfig and context options and the exit code for a kubeconfig that cannot be resolved. Standard cluster options, not a rule of this capability.
- No live entry owns this capability. A search of the live entry folders in the base for "platform pull" finds only the verb in two vendored CUE copies under 0013's experiments, never the command. Entry 0026 (platform generation) changes the platform type the generator embeds. The requirements here name no type, so a rename does not make any of them wrong.
