# Source note: seed-published-module-resolution

This is a seed. It records behaviour the CLI ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `published-module-resolution`. Full seed (6 requirements). Written 2026-10-11 from the CLI at commit `09b0b812`. The requirement text is rewritten at intent level: no Go symbol, flag name or file path. The version selector is named by what it is, because the admission test bans a flag name in a requirement.

## Sources

The repo spec is `cli` `openspec/specs/published-module-resolution/spec.md` at `09b0b812`; it has 4 requirements, which cite `0016:D5:R1`, `R2` and `R3/R7`. The code is read at the same commit. Where the spec and the code differ, the code wins (next section).

| Requirement here | Source requirement in the CLI's spec | Code read |
| --- | --- | --- |
| A module is named by a major-free path | same file, "A published module is named by a major-free module path" (`0016:D5:R1`) | `internal/modref/modref.go` at `09b0b812` (`ParsePath`: URL check, `@` check, element rules); `internal/cmdutil/module_arg.go` (`moduleArgError`: refusal is exit 2) |
| The version selector floats or pins | same file, "The version selector floats within a major or pins a tag" (`0016:D5:R2`), first part: the two forms, the malformed value, the missing pin | `internal/modref/modref.go` (`ParseSelector`); `internal/modref/resolve.go` (`resolveExact`, `resolveFloat`) |
| A float never selects a development build | same file, same requirement, second part: the newest release and the development build | `internal/modref/resolve.go` (`Newest`); `internal/publish/compat.go` (`IsDevTag`); `internal/modref/resolve_test.go` (`TestNewest`) |
| No selector selects the highest core-compatible major | same file, "No selector selects the highest core-compatible major" (`0016:D5:R3`) | `internal/modref/resolve.go` (`resolveHighestCompatible`, `coreMajorOf`); `internal/cmdutil/module_arg.go` (`CoreMajor`) |
| Resolution reports its choice on standard error | same file, "Resolution reports the choice and never corrupts command output", first part (`0016:D5:R3`) | `internal/modref/report.go` (`Report`); `internal/output/log.go` (the logger writes to standard error); callers `internal/cmdutil/module_arg.go` and `internal/cmd/instance/init.go` print each line with it |
| Unreachable registry exits 3, refusal exits 2 | same file, same requirement, second part (`0016:D5:R7`) | `internal/modref/resolve.go:60-74` (`Resolve`: a failed listing is a connectivity error, an empty listing is a refusal) and `:172-183` (`coreMajorOf`: a failed module-file read is a connectivity error); `internal/cmdutil/module_arg.go` (`moduleArgError`); `internal/cmd/instance/init.go` (`initError`); `internal/exit/exit.go` (codes 2 and 3) |

The decision behind the spec is `0016:D5` (archived entry 0016, `archive/0016/03-decisions.md`, "D5").

## Where the code and the spec differ

The code wins. None of these contradicts the spec; the code states more.

- A float to a major that has no published version is refused with exit 2, naming the module path, the major and the registry. The spec states the pin case only. Added to requirement 2 and a scenario.
- A float to a major that holds only development builds is refused with exit 2. The spec states the rule that a float never selects one, not the refusal. Added to requirement 3 and a scenario.
- A module path with no published version at all is refused with exit 2 before any selector is read (`internal/modref/resolve.go:68-74`). The spec does not state it. Added as a scenario of requirement 6, whatever the selector.
- A path of any other shape (one element, an uppercase letter, a character outside the set) is refused with exit 2 before any registry access. The spec states the shape rule and two refusals only. Added as a scenario of requirement 1.
- In the walk, a major that holds only development builds is skipped with its own reason. The spec words it as "no selectable release". Added as a scenario of requirement 4.
- Reading a release's module file during the walk is part of resolution, and its failure exits 3 like a failed listing. The spec says "cannot be reached" only. Stated in requirement 6.

## Left out

- The registry precedence (flag, then environment variable, then config file). The spec lists it in the last requirement. The CLI's `config` capability holds it, and 0021 changed which registry a platform resolves (`DECISIONS.md` 2026-10-11 06:40 (3)). The seed says only that the CLI configuration routes the module path.
- How a command tells a local directory from a published module, the ambiguity refusal, and the refusal of a version selector with a local directory. The repo spec for it is `cmd-structure` (`openspec/specs/cmd-structure/spec.md`, the `module build` requirement). It is not this capability and no seed holds it. See the question for the owner in the report.
- The `opm instance init` surface (positionals, `--from`, prompts, directories, output) and its classification of an unreachable registry while it acquires the archive (`0021:D8:R12`). The `instance-init` capability holds them. That spec points back here for the version rules, as `module-synthetic-instance` does.
- Operator install. It resolves the operator module through the same code, with an exact pin as its default (`internal/operator/plan_install.go`, `ResolveTarget`). The pin is the install command's choice, so the `operator-lifecycle` capability holds it (0021 amended it). The rules here do not change for it.
- Acquiring the module after it is resolved, and the core pin of the generated instance package. They belong to `module-synthetic-instance` and `instance-init`.
- The behaviour of the platform a command renders against. It is the `platform-resolution` seed's (owner, `DECISIONS.md` 2026-10-11 11:20, which reversed the 06:40 (3) exclusion).
- Behaviour a live entry owns: none found. A search of the live entries at `1870515` for the resolver, a major-free path or the highest core-compatible major returned nothing.
- Render-side rules (`seed-single-build-render` holds them) and the catalog and registration rules of the other seeds: this capability does not touch them. It ends at an exact version; the kernel acquires and renders from there.

## Where this seed touches the others

None of the six sibling seeds states a rule about naming or selecting a published module version. The nearest is `catalog-acquisition` (how the kernel reads a catalog it is given by path and version). This seed ends before it: it turns the user's path and selector into the exact version they receive. Which platform a command renders against is the `platform-resolution` seed's and is not stated here.

## Consolidation (T4.3c, 2026-10-11)

One rule lives in one seed (DECISIONS.md 2026-10-11 10:00). What this seed gave up, and where each rule now lives:

- Scope: the major-free path rule is for a command that takes a published module as its subject. The template reference of `opm module init` (which floats within a major, for example `standard@v1`) is not such a module and is `module-authoring`'s grammar (T4.R16).

sampled: 2026-10-11 18705155
