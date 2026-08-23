# Enhancement 0016 — Initialize a Module Instance Package from a Published Module

See [`config.yaml`](config.yaml) for metadata. This README is the index of the seven split documents plus the Scope and Cross-References tables; everything else lives in the split files.

## Summary

A published OPM module is deployed through a **module instance package** — an on-disk CUE package (`cue.mod/module.cue`, `instance.cue`, `values.cue`) that imports the module, embeds `core.#ModuleInstance`, and supplies `values` satisfying the module's `#config`. Nothing generates that package today: `opm module init` scaffolds modules for authors, and the library's `synth.Instance` builds instances only in memory, so deployers hand-copy an example package and mutate it until CUE stops complaining.

This entry adds `opm instance init`: point the CLI at a module's OCI reference and tag, give an instance name and namespace, and get a complete, committable instance package whose boilerplate — dependency pins, majors, imports, `#module:` wiring — is derived from the acquired artifact instead of typed by hand (D1). The generated `values.cue` is populated from the module's `debugValues` by default (D2), and the enhancement proposes a new optional `#Module` field (working name `initValues`, OQ1) through which authors state what a fresh deployment should start from — taking precedence over `debugValues`, whose testing/debugging contract stays unchanged (D3).

<!--
Do NOT add an implementation-status block here. Whether this design has been
delivered is DERIVED from the plans side — run `task delivery ID=NNNN`. A
status block written here is a snapshot that goes stale the moment the plan
moves, which is exactly the drift the implementation axis was removed to stop.
-->

## Documents

1. [01-problem.md](01-problem.md) — No path from a published module to a runnable instance package; author intent for "what a new deployment starts as" has no home on `#Module`
2. [02-design.md](02-design.md) — Acquire the module from the registry, pick a values source (`initValues` → `debugValues` → empty), render the standalone three-file package
3. [03-decisions.md](03-decisions.md) — Decision log (D1–D3)
4. [04-graduation.md](04-graduation.md) — Gates that must hold before `draft → accepted`
5. [05-risks.md](05-risks.md) — Risks and Mitigations, Drawbacks, Alternatives not taken
6. [06-operational.md](06-operational.md) — Observability, semver impact, deprecation, rollback, cross-repo coordination
7. [07-questions.md](07-questions.md) — Open Questions register

Pure-CUE definitions live in [`schemas/target.cue`](schemas/target.cue) — the `#Module` delta (`initValues` beside `debugValues`) — and [`contracts/contracts.cue`](contracts/contracts.cue) — the command's request shape, the values-source ladder, the exact generated file set, and the user-facing report.

## Scope

### In scope

- `opm instance init <module-ref>` — resolves the module through standard `CUE_REGISTRY` routing, acquires it via the existing kernel acquire path, and writes a standalone instance package: `cue.mod/module.cue` (module pinned to the resolved tag, core at the module's major), `instance.cue`, `values.cue` (D1). Exact flag surface pending OQ2.
- The values-source precedence ladder: the new `#Module` field when present, `debugValues` otherwise, an empty/skeleton scaffold when neither is usable (D2, D3; empty-case shape pending OQ3) — with the source named in the command output.
- One additive optional field on core's `#Module` carrying the author-intended init values (D3; name/shape pending OQ1), landed under the `core-schema-edit` protocol.
- Generated output that loads through `LoadInstancePackage` unchanged — init output is immediately valid input to `opm instance build`, `opm instance apply`, and the operator's ModulePackage path.
- Whatever renderer-sharing with `library/opm/helper/synth` OQ4 settles on.

### Out of scope

- **Deploying or applying anything.** Init writes local files; existing build/apply commands execute them.
- **Exporting a *deployed* instance to files.** That is enhancement [0014](../0014/) (cluster → git); this entry is registry → disk, pre-deployment.
- **Changing `debugValues`' contract.** It remains the testing/debugging fixture; this entry only additionally reads it as a fallback.
- **Interactive/wizard-driven values collection, registry search/discovery, and version-bump ergonomics for already-generated packages** — candidate follow-ons, not part of this design.
- **`opm module init`** (author-side module scaffolding) — untouched.
- **Operator and modules-fleet changes.** The operator consumes instance packages through existing paths; module authors adopt the new field at their own pace.

## Relationship to adjacent enhancements

- **[0002](../0002/)** renamed the Release family to Instance vocabulary; this entry is written entirely in that vocabulary (`#ModuleInstance`, instance packages).
- **[0014](../0014/)** covers the opposite direction of the same lifecycle: 0014 turns a *deployed* instance into committable files; 0016 turns a *published module* into committable files before any deployment exists. Both produce GitOps-ready artifacts and deliberately share the "generated, not hand-assembled" stance.
- **[0011](../0011/)** owns publish-time gates; OQ5 notes a potential hook (validating `initValues` against `#config` at publish) that would land there, not here.

## Deviations from Design

None at this stage. Update this section when implementation lands and any deliberate divergences from the design need to be documented.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `core/src/module.cue` | `#Module` — gains the optional init-values field beside `debugValues` |
| `core/SPEC.md` | Co-updated specification section for the new field (`core-schema-edit` protocol) |
| `cli/internal/cmd/instance/instance.go` | Instance command group — registers the new init subcommand |
| `cli/internal/cmd/module/init.go` | Existing author-side scaffolding — the sibling command this one deliberately does not touch |
| `library/opm/helper/synth/instance.go` | In-memory instance synthesis — renderer-sharing candidate (OQ4) and the documented `debugValues` frontend-policy boundary |
| `library/opm/helper/loader/file/instance_test.go` | `LoadInstancePackage` behavior the generated package must satisfy |
| `modules/jellyfin/module.cue` | Concrete `#config`/`debugValues` example used throughout the entry |
| `opm-kind-demo/web_app/instance.cue` | The hand-written instance-package shape init generates instead |
