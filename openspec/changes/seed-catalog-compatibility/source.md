# Source note: seed-catalog-compatibility

This is a seed. It records behaviour that ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `catalog-compatibility`. Full seed (8 requirements). Written 2026-10-11 from `cli` at commit `09b0b812`.

## Sources

All read at the commit named. The requirement text is rewritten at intent level: no Go symbol, flag, file path or error text. The CLI's own specs are two: `catalog-compatibility` (3 requirements) and `catalog-registry-check` (4), as the map row names. Predecessor selection, the dev rule, the prerelease rule, the refusal content and the connectivity rule of the publish gate are written in a third spec, `artifact-publishing`, and the supervisor ruled (DECISIONS.md 2026-10-11 10:15) that `seed-artifact-publishing` states them. This seed restates none of them.

Spec paths are `cli` `openspec/specs/<name>/spec.md`. Code paths are `cli` paths. The decisions behind them are 0010:D27, D30, D34, D35 and 0011:D7 (read in `archive/0010` and `archive/0011` of this repo). 0011:D9, D23 and D26 are the publish gate's.

| Requirement here | Source requirement in the CLI's spec | Code read |
| --- | --- | --- |
| Compatible means additive only | `catalog-compatibility`, "Compatibility Comparison" (first paragraph and 7 of its scenarios) | `internal/compat/compat.go:37-43` (kinds), `:166-231` (`walkStruct`), `:232-247` (`required`: a field marked `!` is required before any default is read, `:233-241`, so only a regular field with a default passes), `:393-420` (`checkDefaults`); narrowing a value domain is the leaf finding `domain narrowed`, carrying CUE's diagnostic (`internal/compat/compat.go`, the subsumption check at `:150-151`, kind at `:42`), and the requirement now names it as an incompatibility (T4.R22) |
| Only authored defaults are compared | same, third paragraph and the four list-default scenarios | `internal/compat/compat.go:279-303` (`openListDefaults`), `:393-444` (`checkDefaults`, `authoredDefault`, `implicitListDefault`) |
| Provenance and hidden fields are not contract surface | same, fourth paragraph (first sentence) and "Provenance inside a member reference is ignored" | `internal/compat/compat.go:12-20` (`provenanceDenylist`), `:166-231` and `:320-345` (hidden labels skipped); `internal/publish/compat.go:348-381` (`compareMember`), `:383-456` (restamped member) |
| Closed lists are walked at equal length | same, fourth paragraph (last two sentences) and the three list scenarios | `internal/compat/compat.go:249-277` (`walkList`), `:347-392` (`closedListPairs`, `leafIdentical`); the unequal-length scenario names a closed list, because dropping a fixed element of an open list can widen it (T4.R22) |
| The comparison binds only what the promise binds | `catalog-compatibility`, "Level Classification" (all but the ordering and the parity test) | `internal/compat/level.go:45-83`; `internal/compat/compat.go:60-80` (`CheckAtLevel`) |
| The check verifies a published build | `catalog-registry-check`, "Out-of-band verification of a published catalog" (all three scenarios) | `internal/publish/check.go:86-137`, `:168-215`; `internal/cmd/catalog/registry.go:19` (the aid sentence) |
| The check judges a build as publish would | `catalog-registry-check`, "`--compat` follows the publish gate's dev-build rules" and "...prerelease-line rule" (both; the scenario on dev history is the publish gate's) | `internal/publish/check.go:140-166` (`checkCompat`); the scenario names a stable build because the gate compares no beta or GA member of a dev tag or a release prerelease (`internal/publish/compat.go:54-60`, `:147-150`) |
| The check's exit code names the cause | `catalog-registry-check`, "An unpublished coordinate exits 5 and every other registry answer exits 3" (first half) | `internal/cmd/catalog/registry.go:103-113`; `internal/publish/check.go:217-244`; `internal/cuemod/connectivity.go:60-63`; `internal/exit/exit.go:7-12` |

## Where the repo spec and the code differ

The code wins in each case.

- "Out-of-band verification" says the check reports the member inventory "per kind and apiVersion", and the command's help says the same. The report groups member names by package and prints no API version (`internal/publish/check.go:246-275`). The seed says "grouped by package".
- The check's help text lists the exit codes 0, 2 and 3 and omits 5 (`internal/cmd/catalog/registry.go:56`). The spec and `checkError` have 5 for a version the registry does not hold. The seed has all of 0, 1, 2, 3 and 5.
- "Compatibility Comparison" says lists whose two sides have equal length are walked element-wise. The code walks closed lists only; an open list with fixed elements gets the default rule on its elements and its value domain is judged at the leaf (`internal/compat/compat.go:249-277`). The seed says "closed lists".
- The spec is silent on hidden fields; the code skips them in the walk and in the default pass (`internal/compat/compat.go:166-231`, `:320-345`). The seed states it. The spec is also silent that a member identical but for its two stamps is passed before any walk (`internal/publish/compat.go:348-381`); the seed states it as "A restamped member passes".

## Left out

- The publish gate: predecessor selection (the backward scan, the permanent claim of a published beta key, the API version bump), the dev rule, the prerelease rule, the refusal content, the exemption of transformers and alpha members from the gate, and the rule that a failed walk renders no verdict. The map row names predecessor selection here, but the supervisor ruled (DECISIONS.md 2026-10-11 10:15) that `seed-artifact-publishing` states them, in "The compatibility gate compares against history", "A compatibility refusal names its member and predecessor", "Dev builds and prerelease lines are exempt, visibly" and "A connectivity failure mid-walk is never a GO". This seed keeps the comparison itself, the level rule, and the check's agreement with publish.
- "Template Version Selection" (the third requirement of `catalog-compatibility`): a stable-preferring selector for the template version, used by the scaffold command only. The repo's `template-modules` spec holds the same rule ("An `@vN` suffix selects the newest release within that major (stable preferred, prerelease fallback)"), so `module-authoring` (row 28 of the map) states it. Its one sentence about the gate (a newer prerelease is the predecessor, not the latest stable build) is a scenario of `seed-artifact-publishing`.
- Total ordering of API versions (`CompareAPIVersions` in "Level Classification"). No command outside tests calls it at the commit read (`git grep` finds the definition and its test only). Enhancement 0020 adds promotion between levels and needs an ordering; it owns this.
- The parity test that pins the API version grammar against core. It is a test, not behaviour. The requirement says the grammar is core's.
- The known limitation at the end of "Compatibility Comparison": a leaf that changed and also carries a validator or a pending comprehension is judged by the forward subsumption alone, so narrowing the validator's alternatives is not detected and widening them reports `domain narrowed`. The spec says the fix is unowned. It is a defect, not an intent, and a seed does not promise it.
- The sentence that the comparison is a field-wise walk and not a single subsumption call, and the measurement behind it (0011:D9). It is a mechanism. Its observable effects are kept: both kinds of addition pass and a changed default is reported with the accepted values unchanged.
- "The CLI SHALL take the not-held decision from the library's typed fetch classification and SHALL NOT match the registry error's message text" (end of the exit-code requirement of `catalog-registry-check`). It carries the token 0021:D8:R12. Enhancement 0021 owns that behaviour.
- The compatibility surface of a module's configuration schema, and a gate over it. Enhancement 0021 proposes it. The comparison seeded here is over catalog contracts.
- Promotion between levels, tombstones and the predecessor of a promoted contract. Enhancement 0020 owns them.

## Where this seed touches the others

- `artifact-publishing` (row 27): it holds the publish gate that calls this comparison, with the predecessor scan, the exemptions, the refusal and the connectivity rule. This seed holds what is compared (the additive-only rule and the level) and the out-of-band check. The check's compatibility mode "agrees with publish" and points there; its report scenarios name the exempt outcomes the check prints on its own compat row (`dev-exempt`, prerelease-exempt) without stating when they apply. Enhancement 0020 changes the predecessor lookup, which `artifact-publishing` states.
- `primitive-keying`: it states that a contract's API version tells whether the additive-only promise binds ("The additive-only promise is readable off the level"). This seed states what the comparison does with that level (alpha is not compared, a bad API version is an error). The two describe the same split from the schema side and from the comparison side. No sentence is repeated.
- `catalog-member-gate`: it states that the API version is not checked against the identity. This seed does not touch that rule.
- `artifact-identity` and `platform-registry`: the check verifies the declared path and version against the coordinate; those seeds hold the rules of the identity and of the registry key. This seed holds only the command that reports the disagreement and its exit code.
- `single-build-render`, `contract-fulfilment`: none. This seed states no render rule.

## Notes for the sample

- "Hidden fields are not compared", "A restamped member passes", "Another metadata field is still compared" and "A coordinate that is not a path and a version exits 1" have no repo spec sentence. They are read from the code at the lines above.
- "A 403 on the tag lookup is read as not published" is the spec's statement. The code decides by the library's fetch classification (`internal/cuemod/connectivity.go:60-63`); a 403 was not run.

## Consolidation (T4.3c, 2026-10-11)

One rule lives in one seed (DECISIONS.md 2026-10-11 10:00). What this seed gave up, and where each rule now lives:

- The alpha exemption (decided here, the rule of thumb did not decide): which levels the additive-only promise binds is `primitive-keying`'s ("The additive-only promise is readable off the level", core's `#APIVersionGated`). This seed keeps what the comparison adds: the level is read from the contract's own API version, a contract the promise does not bind is not evaluated, an off-ladder API version is an error. The requirement is renamed "The comparison binds only what the promise binds" and the scenario "Beta and a bare major are compared" is gone. `artifact-publishing` says only that its gate skips a member the comparison does not bind.
- "The check judges a build as publish would": the dev-build and prerelease exemptions and the choice of predecessor are `artifact-publishing`'s (DECISIONS.md 10:15). The scenarios "A dev build reports exempt" and "A release prerelease reports exempt members" are gone; one scenario states that a violating build exits 2.
