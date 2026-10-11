# Source note: seed-cli-kernel-render

This is a seed. It records behaviour the CLI ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `cli-kernel-render`. Written 2026-10-11 from `cli` at commit `09b0b812` (spec `openspec/specs/kernel-render/spec.md`, 8 requirements). Library facts read at `a87fdda`, core facts at `f3b7ecd`. The seed states only what the CLI adds around the kernel render: what reaches every render (values files, the registry), the runtime name, and what the user sees as warnings and refusals. Rules of the render itself belong to `seed-single-build-render` (DECISIONS.md 2026-10-11 07:45, 08:10). The requirement text is rewritten at intent level: no Go symbol, file path or flag.

## Sources

Paths are in `cli` unless another repo is named.

| Requirement here | Source requirement in `kernel-render` | Code read |
| --- | --- | --- |
| Every render goes through the library kernel | "All renders go through the library kernel" (first paragraph; the observable part: the rendered set and the refusals are the kernel's) | `internal/workflow/render/render.go` (`renderInstance`, `newRenderInput`), `internal/workflow/render/validation.go` (`printValidationError`) |
| Values files and the registry reach every render | "CLI entry points map onto kernel entry points" (scenarios: instance file with extra values, registry mapping supplied once; the acquire-verb sentences are left out) | `render.go:71` (`AcquireInstanceFromDir` with the values sources), `module.go` (`moduleValues`), `internal/config/kernel.go` (`NewKernel(registry)`) |
| The CLI renders under its own runtime name | "Runtime identity in rendered output" | `internal/workflow/render/env.go:19-22`; library `opm/k8s/labels/labels.go:12` (`ManagedByCLI = "opm-cli"`); core `src/transformer.cue:262` (managed-by label set from the runtime name) |
| Advisory facts reach the user as warnings | "All renders go through the library kernel", third paragraph, and the scenarios "Render warnings reach the user" and "Unhandled optional trait warns" | `render.go` (`formatAdvisories`) |
| Kernel refusals exit as validation failures | Scenarios "Typed render causes keep their exit codes" and "Skew refusal is a validation failure"; "Local-replacement renders warn", scenario "A malformed local file is a validation failure" | `render.go` (`renderInstance`), `validation.go` (`printValidationError`), `internal/exit/exit.go:8-9` (general 1, validation 2) |
| Honoured local replacements warn | "Local-replacement renders warn (0010 D19)": all but the inert-redirect sentence | `render.go` (`newRenderInput` sets the opt-in), `replacements.go` (`replacementWarnings`) |
| An ignored module replacement is reported | Same requirement, the inert-redirect sentence and the scenario "Module-side replacement of a platform path is reported inert" | `replacements.go` (second loop) |
| An older-core platform gets a re-pin hint | "A platform pinning an older core is refused as a re-pin" (first scenario; the second is left out, see below) | `internal/platform/repin.go`, `validation.go` (`refusalHint`: the hint only for a platform directory the user named) |

## Where spec and code disagree

The code wins.

- The spec says one kernel is constructed per command invocation. The code builds a kernel in more than one place on one path: `internal/cmdutil/instance_arg.go:104` when it resolves an instance argument, and `render.go:48` and `module.go:50` when it renders. The rule is internal, so the seed does not state it.
- The spec says the replacement warning names "whether the module or the platform supplied it". The code words the supplier as `instance` or `platform` (`replacements.go`, `replacedByInstance`), and words a replacement carried into a generated platform under the module side. The seed says "which side supplied it" and "the module side".
- The spec lists the registry-gated parity check, the cross-binary skew scenario and the package-absence scenario as requirements. The code has none of them as behaviour: the first is a test, the second is marked a future check, the third is build structure. All three are left out.

## Left out

- **Duplicate apply identities** (second paragraph of the first requirement and its two scenarios). `seed-duplicate-object-identities` holds the check, its wording and "A runtime refuses a duplicate before apply", which says the CLI refuses as a validation failure. One rule lives in one seed.
- **"Render digests are kernel-derived and operator-parity"**, whole. The shared digest, its exclusion of the managed-by value and the CLI/operator agreement are 0012:D6 (R2, R3), and digests are on the list of 0012:D1. 0012 is live. The registry-gated parity check is a test, and the cross-binary skew scenario is a future check. The map row (T4.1b row 30) names "kernel-derived digests": this is the owner question below.
- **"A colliding platform is refused naming the entries to disable"**, whole. It is repo behaviour that no archived entry backs: the archived `cli` change `name-contract-collisions` cites only 0026 OQ17, which says the fix landed independent of the entry, and no live decision states a collision rule. The kernel half is also left out of `seed-single-build-render` (DECISIONS.md 2026-10-11 14:45); the not-routable refusal stays there. The CLI-only rules stay without a holder: one row per colliding contract printed before every other row, an unresolved demand on a colliding key worded as defined by more than one enabled entry, no platform-source hint beside a collision, and the not-routable refusal printing the kernel's message. The owner decides whether any of them is seeded.
- **Which platform a render uses** (the named directory, the cluster Platform, the render's own pins), **where the skew policy comes from** (the config key, the cluster Platform) and the effective-registry rule: these live in `seed-platform-resolution` (owner, 11:20; DECISIONS.md 2026-10-11 12:30), from cli `platform-resolution`. The hints for a platform generated from the render's own pins (`moduleDepsProviderHint` and its three siblings in `validation.go`) go with it. This seed keeps one observable of that area, the warning for a module replacement honoured with no platform named, as a scenario of the warning requirement.
- **The skip switch**, whole: the switch on every render command, its warnings, its hint, and the refusal of the switch for an operator-managed instance (the last requirement and bullet of the repo's "Unprovided provider-fulfilled demands are skipped on request"). It is repo behaviour that no archived entry backs: the archived `cli` change `add-skip-unprovided-flag` says "No enhancement entry backs them" (`orchestration.md:7`). The kernel half is also left out of `seed-single-build-render`, for the same reason (DECISIONS.md 2026-10-11 14:45).
- **The second scenario of the re-pin requirement** ("A generated platform is never refused for its core"). The CLI code does not show how a generated platform pins core: generation is the library's and the operator's, and `seed-platform-module-generation` is the place for it. The seed states the verified part only: the hint goes to a directory the user named.
- **The render-side rules the CLI passes through**, held by `seed-single-build-render`: the opt-in for local replacements and their precedence, the old-core refusal itself, the skew comparison, trait posture, and the single-provider guard.
- **How an input reaches the kernel**: the acquire verb for an instance file, a module directory, a published module and a platform directory, and that the kernel builds the instance from a module and the resolved values. A consumer sees the values file take effect and the one registry, not the route. The scenario "A module directory becomes an instance in the kernel" went with it.
- **Internal structure**: the ban on CLI match, execute and finalize code (also dropped from the first requirement) and the absence of the old render packages (structure, not behaviour), the ban on importing operator packages, one kernel per invocation, no per-call load options, no raw-value tier, sharing one CUE context, and that no built platform is held between renders. No consumer observes them.
- **The publish gate scenario** ("Publish gate acquires through the kernel"): publishing belongs to the artifact-publishing capability.
- **Exact warning and hint sentences.** The seed names the facts each carries, not the words.
- **`platform check` and `platform pull`**: separate commands, held by `seed-platform-contract-gates` and `seed-platform-pull`.

## Touches other seeds

- `seed-single-build-render`: local replacements, the old-core refusal and the skew comparison. This seed states the command side only. The skip switch is left out of both seeds (above).
- `seed-platform-resolution`: the platform source choice, the skew policy source and the effective registry.
- `seed-duplicate-object-identities`: the CLI's refusal of a shared identity. Not restated here.
- `seed-platform-contract-gates`: the platform check also names the re-pin command for a directory the user named. That is the check command; this seed covers the render commands.
- Live entries: 0012 (digests, the Kubernetes tier, apply and deletion) owns the digest left out above. No live entry states the collision rules. 0012:D6 also says the frontend that renders fills the runtime name; the requirement "The CLI renders under its own runtime name" states only the value the CLI gives (`opm-cli`) and leaves the stamping rule and the digest to 0012. The map also names 0013 and 0014 for this capability. I found no match for the render, its warnings or its refusals in their decisions (a search of their `03-decisions.md` for local replacement, skew, unhandled trait, exit code and runtime name found only the 0012 lines above and an unrelated 0013 line), and none of the requirements here names secrets or export. This is a search, not a read of every decision.

## Consolidation (T4.3c, 2026-10-11)

One rule lives in one seed (DECISIONS.md 2026-10-11 10:00). What this seed gave up, and where each rule now lives:

- "An older-core platform gets a re-pin hint" now holds the hint for the platform check too (a new scenario, moved in from `platform-contract-gates`).
- "Honoured local replacements warn" says the CLI turns replacements on for every render; the precedence and the inert module-side redirect are `single-build-render`'s. "An ignored module replacement is reported" keeps only the warning. The skew scenario keeps the exit as a validation failure and the facts named; the timing (before evaluation) is `single-build-render`'s.
