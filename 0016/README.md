# Enhancement 0016: Initialize a Module Instance Package from a Published Module

See [`config.yaml`](config.yaml) for metadata. This README is the index of the seven split documents plus the Scope and Cross-References tables; everything else lives in the split files.

## Summary

A published OPM module is deployed through a **module instance package**: an on-disk CUE package (`cue.mod/module.cue`, `instance.cue`, `values.cue`) that imports the module, embeds `core.#ModuleInstance`, and supplies `values` satisfying the module's `#config`. Nothing generates that package today. `opm module init` scaffolds modules for authors, and the library's `synth.Instance` builds instances only in memory. So deployers hand-copy an example package and mutate it until CUE stops complaining.

This entry adds `opm instance init`, which turns a published module into a complete, committable instance package:

- **Input:** a published module (its module path, no major needed), an instance name, and a namespace (D1).
- **Version:** mirrors `opm module init` parameter for parameter; when no version is given, picks the newest module line this CLI's core major can build (D5).
- **Values:** populated from the module's new optional `initValues` field when the author set one (D3, D4), from `debugValues` otherwise (D2), empty with a warning when neither is usable (D6).
- **Boilerplate:** dependency pins, majors, imports, and `#module:` wiring are derived from the acquired module instead of typed by hand (D1).
- **Rendering:** the renderer is CLI-side (D7); init does not validate what it wrote (D8); the generated module file pins the module exactly with a complete dependency closure (D9).

<!--
Do NOT add an implementation-status block here. Whether this design has been
delivered is DERIVED from this entry's `delivery.yaml` log: run `task delivery ID=NNNN`. A
status block written here is a snapshot that goes stale the moment another change
lands, which is exactly the drift the implementation axis was removed to stop.
-->

## Documents

1. [01-problem.md](01-problem.md): No path from a published module to a runnable instance package; author intent for "what a new deployment starts as" has no home on `#Module`
2. [02-design.md](02-design.md): Resolve and acquire the module, pick a values source (`initValues` → `debugValues` → empty), render the standalone three-file package
3. [03-decisions.md](03-decisions.md): Decision log (D1–D9)
4. [04-graduation.md](04-graduation.md): Gates that must hold before `draft → accepted`
5. [05-risks.md](05-risks.md): Risks and Mitigations, Drawbacks, Alternatives not taken
6. [06-operational.md](06-operational.md): Observability, semver impact, deprecation, rollback, cross-repo coordination
7. [07-questions.md](07-questions.md): Open Questions register (OQ1–OQ6, all resolved)

Pure-CUE definitions live in two places: [`schemas/target.cue`](schemas/target.cue) holds the `#Module` delta (`initValues` beside `debugValues`); [`contracts/contracts.cue`](contracts/contracts.cue) holds the command's request shape, the values-source ladder, the exact generated file set, and the user-facing report.

## Scope

### In scope

**Command.**

- `opm instance init [instance-name] [module-path] --namespace <ns> [--version] [--dir] [--module-path]`, a mirror of `opm module init` that resolves the module through standard `CUE_REGISTRY` routing, acquires it via the existing kernel acquire path, and writes a standalone instance package: `cue.mod/module.cue`, `instance.cue`, `values.cue` (D1, D5).
- Version selection: `--version vN` floats within a major, an exact SemVer pins; omitted, the newest release of the highest major whose core dependency matches this CLI's core major (D5).

**Values.**

- The values-source precedence ladder: `initValues` when present, `debugValues` otherwise, `values: {}` with a warning when neither is usable (D2, D3, D6), with the source named in the command output.

**Schema.**

- One additive optional field on core's `#Module`, `initValues?: _`, carrying the author-intended init values (D3, D4), landed under the `core-schema-edit` protocol.

**Generated output.**

- A generated `cue.mod/module.cue` with the module pinned exactly, core at the module's major, a complete dependency closure, and a local placeholder module path (D9).
- Generated output that loads through `LoadInstancePackage` unchanged: init output is immediately valid input to `opm instance build`, `opm instance apply`, and the operator's ModulePackage path.
- The renderer lives in the CLI beside `opm module init`; `library` ships nothing (D7).

### Out of scope

**Not this command's job.**

- **Deploying or applying anything.** Init writes local files; existing build/apply commands execute them.
- **`opm module init`** (author-side module scaffolding), untouched.
- **Operator and modules-fleet changes.** The operator consumes instance packages through existing paths; module authors adopt the new field at their own pace.

**Deferred to a different entry or command.**

- **Exporting a *deployed* instance to files.** That is enhancement [0014](../0014/) (cluster → git); this entry is registry → disk, pre-deployment.
- **A publish-time gate on `initValues` conformance.** If wanted, it is [0011](../0011/)'s decision.
- **Validating the generated package at init time.** The report names `opm instance vet`; running it is the user's next step (D8).

**Unaffected.**

- **Changing `debugValues`' contract.** It remains the testing/debugging fixture; this entry only additionally reads it as a fallback.
- **Anything outside the core v2 line.** Pre-v2 module majors exist on GHCR; they appear in this design only as lines the D5 walk skips.

**Candidate follow-ons, not part of this design.**

- Interactive/wizard-driven values collection, a `#config`-derived skeleton, registry search/discovery, and version-bump ergonomics for already-generated packages.

## Relationship to adjacent enhancements

- **[0002](../0002/)** renamed the Release family to Instance vocabulary; this entry is written entirely in that vocabulary (`#ModuleInstance`, instance packages).
- **[0014](../0014/)** covers the opposite direction of the same lifecycle: 0014 turns a *deployed* instance into committable files; 0016 turns a *published module* into committable files before any deployment exists. Both produce GitOps-ready artifacts and deliberately share the "generated, not hand-assembled" stance.
- **[0019](../0019/)** is the kernel render path the generated package is handed to, and this entry lands after it. Init's contract does not change with 0019, but the user's next command does, so the ordering constraint lives in `06-operational.md`. Three of 0019's decisions bear directly on init's output:
  - Catalog version skew between a module and its platform becomes a kernel-detected, warn-and-render signal (D7, D18 in 0019): the failure experiment 03 met as "unresolved demands" against a platform on a different catalog pin.
  - The render step becomes one CUE build with a render `cue.mod` derived by promotion from the inputs (D9, D13 in 0019), the same derivation D9 here performs for the generated module file.
  - The platform reshape (D5, D6 in 0019) defines what `opm instance vet`/`build` evaluate against.
- **[0011](../0011/)** owns publish-time gates and the `opm module init` scaffolding this command mirrors (D5); a publish-time check that `initValues` satisfies `#config` would land there, not here (D8).

## Deviations from Design

None at this stage. Update this section when implementation lands and any deliberate divergences from the design need to be documented.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `core/src/module.cue` | `#Module`: gains the optional init-values field beside `debugValues` |
| `core/SPEC.md` | Co-updated specification section for the new field (`core-schema-edit` protocol) |
| `cli/internal/cmd/instance/instance.go` | Instance command group the new init subcommand joins |
| `cli/internal/cmd/module/init.go` | The sibling command whose parameters, prompting and exit codes D5 mirrors |
| `cli/internal/scaffold/ref.go` | The reference grammar (`@vN` float, exact pin) and version resolution D5 reuses |
| `library/opm/materialize/enumerate.go` | Evidence that listing a major-free module path enumerates every published major (D5) |
| `library/opm/schema/loader.go` | `DefaultSchemaModule`, the core major a CLI build is bound to (D5) |
| `library/opm/helper/synth/instance.go` | In-memory instance synthesis: the documented `debugValues` frontend-policy boundary this entry defines for one frontend; unchanged (D7) |
| `library/opm/helper/loader/file/instance_test.go` | `LoadInstancePackage` behavior the generated package must satisfy |
| `modules/cert_manager/module.cue` | Concrete `#config`/`debugValues` example used throughout the entry |
| `opm-kind-demo/web_app/instance.cue` | The hand-written instance-package shape init generates instead |
