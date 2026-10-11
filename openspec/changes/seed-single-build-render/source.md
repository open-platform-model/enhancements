# Source note: seed-single-build-render

This is a seed. It records behaviour the library ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `single-build-render`. Full seed (21 requirements, from the 22 of the source spec: 2 left out, and 2 of the rest split into 5; T4.3c then took out 2 more). Written 2026-10-11 from the library at commit `a87fddaa` (`a87fddaa440c4448cf15136faf8da3732cd8cf55`).

## Sources

All read at the commit named. The source spec is `library` `openspec/specs/single-build-render/spec.md`, called "the spec" below. Code paths are in the library. The requirement text is rewritten at intent level: no Go symbol, field path or file path. Names are shortened to at most eight words, so each row gives the source name.

| Requirement here | Source requirement in the spec | Code read |
| --- | --- | --- |
| Render inputs are source-carrying artifacts | "Render inputs are source-carrying artifacts" | `opm/kernel/render.go` (the input checks of `render`), `opm/internal/renderstage/stage.go` (`serveDir`) |
| The render's dependency list is derived by promotion | "The render module's dependency list is derived by promotion", first paragraph | `opm/internal/renderstage/promote.go` (`Promote`, `defaultRoots`, `ReplacedVersion`) |
| Local replacements are promoted under dependency precedence | same requirement, second paragraph | `opm/internal/renderstage/promote.go`, `opm/internal/renderstage/modfile.go` (`ReadLocalModFile`, relative targets resolved against the input root) |
| Local replacements need the caller's opt-in | "Local replacements are honoured only when the caller opts in" | `opm/internal/renderstage/stage.go` (`Stage`, the refusal when the opt-in is off), `opm/kernel/render.go` (`RenderInput.LocalReplacements`, `Replacements`) |
| A render refuses an uncovered OPM-namespace path | "A render refuses when promotion cannot cover an OPM path" | `opm/internal/renderstage/invariant.go` (`VerifyCoverage`), `stage.go` (it re-parses the served bytes) |
| Version skew follows a caller-chosen policy | "Version skew is detected from the two committed resolutions and the response is caller-configured" | `opm/internal/renderstage/skew.go`, `opm/kernel/render.go` (`SkewPolicy`, zero value is warn), `opm/internal/modversion` (`Compare`) |
| Matching runs in the build and yields data | "Matching runs inside the build with verdicts as data", first paragraph, up to the demand gate | `opm/internal/renderstage/render.cue.tmpl` (`#Match`), `opm/kernel/render_decode.go` |
| The demand gate fails closed | same requirement, the parity and gate sentences | `render.cue.tmpl` (`resolved`, `gate`), `render_decode.go` (`gateErrors`) |
| Failed pairs are named from their rendered output | same requirement, second paragraph | `opm/kernel/render_decode.go` (`failedPairs`, `outputFailed`, `decodeRendered`), `render.go` |
| Rendered output carries provenance and is concrete | "Rendered output decodes with provenance and per-pair concreteness", without the sentence on where the output type is declared | `opm/kernel/render_decode.go` (`decodeRendered`, `splitOutput`) |
| Render is the kernel's sole render path | "Render is the kernel's sole render path", without the default-pin sentence | exported verbs of the kernel (`opm/kernel/*.go`) |
| The single-provider guard runs inside the build | "The single-provider guard runs inside the build" | `render.cue.tmpl` (`guard`, `match`), `render_decode.go` (`gateErrors`); the agreement scenario: `opm/kernel/render_inventory_parity_test.go:114-146` |
| Unresolved demands are diagnosed with alternatives | "Unresolved demands are diagnosed with alternatives" | `render.cue.tmpl` (`unresolvedResources`, `unresolvedTraits`, `#alternatives`), `opm/errors/match.go` (`describe`) |
| Trait posture governs unhandled traits | "Trait posture governs unhandled traits" | `render.cue.tmpl` (`unhandledWarnings`, `unresolvedTraits`), `render_decode.go` (`unstatedPosture`) |
| The label predicate covers every admitted label type | "The label predicate covers every admitted label type" | `render.cue.tmpl` (`_pred`, `missingLabels`) |
| A render result carries no presentation strings | "A render result carries no presentation strings" | `opm/kernel/render.go` (`RenderDiagnostics`), `render_decode.go` (`gateErrors`) |
| The render module's gate agrees with the kernel | "The render module's own gate agrees with the kernel's refusal" | `render.cue.tmpl` (`gate`), `render.go` (the gate is never read by the kernel) |
| A platform with an old core is refused | "A render refuses a platform whose core predates the provider count" | `opm/kernel/render.go`, `opm/platform/contracts.go` (`CoreFloor`), `opm/schema/paths.go` (`ProvidedBySince`) |
| An unexplained not-routable platform is refused | "A render refuses a not-routable platform no row explains" | `render_decode.go:146-148` (`gateErrors`, the not-routable cause joined last; a collision row withholds it, `:146`, and `opm/kernel/render_gate_internal_test.go:30-31` asserts that, so the requirement excludes a colliding key without stating a collision rule); the no-catch-all scenario: `opm/kernel/render_inventory_parity_test.go:114-118`, `:127-128`; the unexplained verdict: `opm/kernel/render_gate_internal_test.go:17-44` |
| Each render is its own in-memory build | "Each render is its own in-memory build in its own context" | `opm/internal/renderstage/stage.go` (`RenderRoot`, `Stage`, `Build`), `opm/internal/sourcetree/sourcetree.go` (`VolumeRoot`, `CheckRootAbsent`), `opm/kernel/render.go` |
| A render writes no staging file | "A render writes no staging file" | `opm/internal/renderstage/stage.go` (nothing is written), `opm/kernel/render_no_staging_test.go` |

## Where the seed differs from the source spec

- Two source requirements are split into five requirements, because one requirement of at most 500 characters cannot hold them. The promotion requirement gives the replacement rules their own requirement. The matching requirement gives the demand gate and the failed pairs their own. No sentence is added; each part keeps the scenarios of its source paragraph.
- The scenario "Verdicts decode beside a failing gate" moves with the demand gate. The scenarios "Healthy pairs render beside a failing pair" and "Failed pairs are reported on a gate refusal" move with the failed pairs.
- Two scenarios name no fixture set: "The inventory and the render agree" and "An explained verdict raises no catch-all" state the library's parity test (`opm/kernel/render_inventory_parity_test.go:114-146`, over-subscription rows against the inventory; `:117`, no catch-all; `:127-128`, the routable verdict) with a stated platform, not the test's whole fixture set. The catch-all itself is `opm/kernel/render_decode.go:146-148`. The test also has colliding platforms; collision rules stay out of the seeds (DECISIONS.md 2026-10-11 15:10), so the scenarios name none.
- Four scenarios restate a SHALL sentence of the source that had no scenario of its own: "An empty runtime name is refused", "A non-concrete output is not a failed pair", "The pair set equals plain predicate matching" and "An unstated posture fails closed". The code backs each (`render.go`; `render_decode.go`, `outputFailed` and the concreteness check; `unstatedPosture`).

- Two scenarios of the source were reworded so that each states what a consumer of the render sees. "The synthetic roots are absolute" (which also covered a registry module's root) became "A render works on every operating system". "A render that writes is caught" (a test of the library) became "A fetched dependency fills only the module cache", from the same requirement's module-cache sentence.
- Platform shape. The capability `platform-registry` states the shape of a platform, and the `platform-artifact` seed states its refusal ("Acquisition refuses an incomplete registry entry"). Only acquisition refuses an entry with no embedded catalog (`opm/internal/loader/shape.go:152-170`, called from `opm/kernel/acquire.go:298`); `opm/kernel/render.go` has no such check. This seed states none of it: one rule lives in one seed.

## Code and spec checked against each other

The code agrees with the spec on every point read. Two wording differences do not change a verdict.

- The message of an unprovided row. The spec says it states that the contract is provider-fulfilled and that nothing on the platform provides it. The code writes "provider-fulfilled, no provider on this platform" (`opm/errors/match.go`). The seed states the fact and not the words.
- The spec lists four cases for an unresolved row, one of them a contract defined by more than one enabled entry (the collision case, left out below). The code has five branches: a row with alternatives reads the same whether or not a defining catalog is known (`opm/errors/match.go`, `describe`). The seed states the three remaining cases and says the defining catalog is diagnostic only, as the spec does.

## Left out

- "A render reports every contract its instance requires". Enhancement 0013 owns it: the spec cites `0013:D24`, the converted 0013 states it as "A secret source in use is a dependency" in its `secret-sources` capability, and its delivery log records the library change that shipped it. The seed would collide with 0013's requirement when 0013 is delivered.
- "Matching stays in the glue and derived rules move into core one at a time". It is a rule about where code lives, recorded in the library's ADR 012. Its only scenario checks that a document says so. It fails the admission test: a consumer observes no behaviour from it. If the owner wants it, it belongs to a decision record, not a requirement.
- In "Render is the kernel's sole render path": the sentence that the kernel's default core schema pin is a release carrying the registry shape (it belongs to the schema-dispatch capability, and the pin is a version number that changes with each release), and the scenario that lists the removed Go identifiers (replaced by a scenario that states the absence of the verbs).
- In "Rendered output decodes with provenance and per-pair concreteness": the rule that the compiled-output type is declared in one package and the scenario "One compiled-output type". It is a code-layout rule. Enhancement 0021 (R11) will change what the render operation hands to a caller, so the seed does not state the output type.
- The render-time catalog-pin check and the per-resolution single-provider count. The spec does not describe them, because they are not shipped, and enhancement 0026 (D1, D7, D9) owns them.
- Two behaviours that no archived enhancement entry backs. They are repo behaviour and stay out of every seed (DECISIONS.md 2026-10-11 12:30 and 14:45):
  - The source requirement "A caller may skip unprovided provider-fulfilled demands": the per-render skip switch, the skipped-demand rows and the omitted component. The library change that shipped it is marked "No enhancement" (`proposal.md:38` of the archived library change `2026-09-29-render-skips-unprovided-provider-demands`). What went with it: the skipped demands in the list of decoded verdicts, the "omitted component leaves the pair set" scenario, the skip clauses of the demand gate, the skipped-demand scenario of the no-presentation-strings requirement and the optional-trait scenario of the skip requirement.
  - The source requirement "A render refuses a platform whose enabled entries share contract keys": the collision refusal, which the library change calls an interim safety net recommended by 0026 OQ17 (`proposal.md:5` of the archived library change `2026-09-30-refuse-colliding-contracts`; 0026 is a live entry, not an archived one). What went with it: the colliding entries in the unresolved row, the case "defined by more than one enabled entry", and the collision references in the inventory-agreement, gate-cause and module-gate scenarios.
  The over-subscription refusal and the not-routable refusal stay: archived 0015 backs them (`0015:D2` and `0015:D18`). The not-routable requirement now names the over-subscription row as the only row that explains a false verdict.

## Consolidation (T4.3c, 2026-10-11)

One rule lives in one seed (DECISIONS.md 2026-10-11 10:00). What this seed gave up, and where each rule now lives:

- "The single-provider guard runs inside the build" no longer defines the counting unit; it points to `contract-fulfilment`. It states what the render does with the inventory's count.
- "The label predicate covers every admitted label type" compares a transformer's required labels with the component's matching labels, the wording `component-matching` holds.
- The skip request and the collision refusal came out, as "Left out" says. The over-subscription and not-routable refusals stay, backed by archived 0015.
