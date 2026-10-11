# Source note: seed-instance-init

This is a seed. It records behaviour the CLI ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `instance-init`. Full seed (9 requirements, from 7 in the repo spec). Written 2026-10-11 from the CLI at commit `09b0b812`. Its spec and code were last changed at `be1157d5`.

## Sources

All read at the commit named. The requirement text is rewritten at intent level: no Go symbol, flag or file path in it. Two repo requirements are split because the text limit is 500 characters. The module's `initValues` and `debugValues` fields are named in the values requirements, as the repo spec names them.

| Requirement here | Source requirement in the CLI's spec | Code read |
| --- | --- | --- |
| Init writes a standalone instance package | `cli` `openspec/specs/instance-init/spec.md` at `09b0b812`, "Init writes a complete standalone instance package" (first paragraph, the instance file bullet, the two scenarios) | `internal/instinit/render.go` `Render`, `renderInstanceFile`; `internal/cmd/instance/init.go` `initPackage`; `internal/workflow/render/instance_deps_test.go` builds a package that `Write` produced |
| The package pins its dependencies and is tidy | same requirement (module file bullet, module path paragraph, the module path scenario) | `render.go` `renderModuleFile`, `DefaultPackageModulePath`; `write.go` `write` runs `cuemod.Tidy`, the same function `opm module tidy` calls (`internal/cmdutil/tidy.go:32`); `init.go` `corePin` |
| Init takes its inputs from arguments or prompts | "Init arguments mirror module init" (positionals, `--from`, prompting, `--dir` default) | `init.go` `collectInputs`, `classifyInitArgs`, `promptIfMissing`; `init_test.go` `TestClassifyInitArgs`, `TestCollectInputs_PromptsInOrder` |
| Inputs are checked before any registry access | "Init arguments mirror module init" (name rule, prompted values) and "Init writes a complete standalone instance package" (package module path) | `init.go` `checkName`, `nameRule`, `collectInputs` (`module.CheckPath` on the package module path) |
| Values start from the author's intended source | "Values start from the author's intended source" (ladder, non-concrete `initValues`, non-struct source, partly concrete `debugValues`) | `internal/instinit/values.go` `PickValues`, `concrete`; `values_test.go` `TestPickValues` cases for each scenario |
| The values source is named and flagged | same requirement (comment, report, empty-file warning) | `render.go` `sourceComment`; `init.go` `report`; `values.go` `IsEmpty` |
| Init writes all or nothing | "Init writes all or nothing, and only where a standalone package belongs" | `init.go` `checkTarget`; `write.go` `write` (staging beside the target, rename, cleanup); `write_test.go` `TestWrite_FailureLeavesNothing` |
| Init reports its result without validating | "Init reports what it wrote and does not validate it" (first paragraph, the success and violation scenarios) | `init.go` `report`, `initPackage` (no evaluation of the package) |
| Unreachable means the registry gave no response | the same requirement (exit codes, unreachable scenarios) and "Only a registry that gave no response counts as unreachable" (first sentences) | `init.go` `initError`, `acquireModule`, `corePin`; `write.go` `write`; `internal/cuemod/connectivity.go` `IsConnectivityError`; `init_test.go` `TestInstanceInit_RegistryUnreachable` |

## Left out

- "Init selects the module version like every published-module command": version selection, the core-major walk and the skipped-major report belong to the seed `published-module-resolution`. So does the rule that the module path has no major and the exit 2 refusal of a major suffix. One rule lives in one seed. Enhancement 0022 changes that walk, so it stays with the seed that holds it.
- The THEN of the repo scenario "Missing module path on a terminal": its answer carries a major suffix and the refusal is the `published-module-resolution` rule. The scenario of that name is kept here and rewritten: the answer is used as if it had been an argument. A prompted namespace is checked in the scenario "Invalid prompted namespace".
- The report line that names the resolution (module path, major, version, how chosen): `published-module-resolution` holds it.
- How a module author declares `initValues` and `debugValues`, and that `initValues` is not checked against the config contract: seed `module-init-values`. This seed holds only how init picks among them.
- The instance FQN and UUID derived from the name and namespace: seed `instance-identity`. Init sets the name and namespace and states no identity rule.
- The sentence "The CLI SHALL take the unreachable decision from the library's typed fetch classification and SHALL NOT match message text" (`Source: 0021:D8:R12`). Enhancement 0021 owns it, and it is a placement rule, not behaviour a user observes. The observable half (what counts as unreachable) stays.
- The CUE language version of the generated module file (`LanguageVersion` in `render.go`) and the staging directory name: mechanism.
- The check "the directory appeared while initializing" in `write.go`: a race guard inside all-or-nothing, not a rule of its own.
- Prompt and refusal wording, and the golden-file tests of the rendered files: mechanism and test shape.
- Whether init refuses a catalog or a template as the module: no repo spec or code line states it. Enhancement 0022 mentions it as a refusal init must make.

## Where spec and code differ

- The repo spec says the package module path must be "any valid major-qualified module path". The code refuses a path that `module.CheckPath` rejects, with exit 2 (`collectInputs`), but does not require a major: CUE's `CheckPath` accepts a path with no version (review T4.R16, `mod/module/path.go:155-180` of CUE v0.17.1; not re-read by me). The seed states the refusal and does not state the major rule. A fix of the repo spec is for the last phase.
- The repo spec says init refuses an existing "directory". The code refuses any existing path (`os.Lstat` in `checkTarget`), a file included. The seed says "already exists".
- The repo spec says the package "loads from CUE's module cache when the registry is unreachable" (`Source: 0016:D1:R2, 0016:D9:R2`). I found no CLI test that runs that case offline; the code stages the package and tidies it against the registry, which fills the cache. The seed keeps the sentence from the spec. Not run.
- The repo spec defines "unreachable" as "no HTTP response". The code takes the decision from the library's classification (`IsConnectivityError` calls `fetchKindIs(err, FetchUnreachable)`); the library was not read. The seed states the spec's definition.

## Consolidation (T4.3c, 2026-10-11)

One rule lives in one seed (DECISIONS.md 2026-10-11 10:00). What this seed gave up, and where each rule now lives:

- The scenario "Registry unreachable" is gone: the exit 3 for a registry that cannot be reached while the module path is resolved is `published-module-resolution`'s ("Unreachable registry exits 3, refusal exits 2"). This seed keeps the exit codes of init and the unreachable cases of the dependency closure and of the module's own module file.
