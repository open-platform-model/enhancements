# Source note: seed-render-parity

This is a seed. It records behaviour `library` ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `render-parity`. Full seed (11 requirements). Written 2026-10-11 from `library` at commit `a87fdda` (the 10 requirements of its main spec, with the kernel-refusal rule split out as its own requirement, and the harness code and fixtures they describe). Origin: enhancement 0019, decisions 0019:D1 and 0019:D14.

## Sources

All read at the commit named. The requirement text is rewritten at intent level: no Go symbol, file path, test name or environment variable. `#transform`, `#names` and `#moduleInstance` are definitions of `opmodel.dev/core@v2` (`core` `f3b7ecd`, `src/transformer.cue:130-136`, `src/component.cue:200`).

"Spec" is `library` `openspec/specs/render-parity/spec.md`. "Harness" is `opm/kernel/parity_harness_test.go`, "compare" is `opm/kernel/parity_compare_test.go` and its unit test `parity_compare_unit_test.go`, "probe" is `opm/kernel/parity_probe_test.go`, "oracle" is `testdata/parity/oracle/render.cue`.

| Requirement here | Spec requirement | Code read |
| --- | --- | --- |
| Pure-CUE unification is the render oracle | "Pure-CUE unification is the render oracle" | compare: `checkParity` (`parity_compare_test.go:185-214`; the report is `compareRendered`, `:151-177`: both object counts when the counts differ, `:152-153`, else the first differing path, `firstDiffPath`; it applies in the no-divergence branch, `:202-207`); oracle: `#Render` |
| A kernel refusal is a disagreement | "Pure-CUE unification is the render oracle" (its sentence "a kernel failure is a disagreement", split out) | compare: `checkParity` `:195-198` ("kernel failed to render: <error>", no path), `:202-207` (the case fails when no divergence is expected) |
| The oracle must render | none (the spec is silent) | compare: `checkParity` (oracle error checked first); `TestParityCheck_Contract` "oracle error is a fixture failure" |
| Both renderers resolve identical inputs | "Both renderers resolve identical inputs" | compare: `parityCase` `parity_compare_test.go:41-54` (a row holds name, instance, component, transformer, equality and expected divergence, and no other input); the probe rows are not in the shipped case table and take their instance and transformer at run time (probe: `parity_probe_test.go:47-53, 66-72, 173-174`); harness: `TestParity_ShippedCatalog` (instance by directory, platform from `opm_platform`), `loadOracle`; `testdata/parity/opm_platform/platform.cue:1-12`; `testdata/parity/shipped/shipped.cue` |
| Both sides resolve one catalog build | "The shipped case table names the catalog build the parity module pins" | harness: `shippedCatalogVersion`, `resolveShippedCases`, the version checks in `TestParity_ShippedCatalog` |
| The case table covers every matched pair | "Matched pair sets agree"; the third scenario of the pin requirement | harness: `assertPairSetsAgree`, `assertRowsCoverPairs`; probe: `runParityProbe` |
| Equality is structural and order-sensitive | "Equality is structural and order-sensitive" | compare: `encodeOrdered`, `firstDiffPath`, `compareRendered`, `checkParity`; unit test `TestParityEncoder_ReportsReordering` |
| Known divergences are recorded and asserted to reproduce | "Known divergences are recorded and asserted to reproduce" | compare: `checkParity` `:202-213` (with a divergence set, a kernel error or any difference passes; the recorded text is never compared with the difference; agreement fails), `assertParity` `:268-278` (logs the reproduced divergence) |
| A divergence closes by removing kernel behaviour | the Purpose of the spec; no requirement states it. Only the failure message is stated here (see "Dropped") | compare: header comment and the message of `checkParity`; 0019:D1 |
| Probe transformers expose definition and instance inputs | "Probe transformers expose definition and instance inputs" | probe: `parityProbes`, `runParityProbe` |
| The shipped catalog stays discriminated | "The shipped catalog stays discriminated", without its gating sentence | harness: `TestParity_ShippedCatalogDiscriminated` |

## Disagreements between spec and code (the code wins)

- The spec says the instance and the platform both enter the kernel side from the on-disk packages the oracle build imports. In the code only the instance is the package the oracle imports. The platform is a nested module of its own that imports the same catalog build; the oracle never imports it, and the harness checks that both resolve one build (`platform.cue:1-12`). The requirement states the code.
- The spec has the harness check the oracle's catalog build against the pin. The code also checks that the build the kernel's render resolved is that build (`parity_harness_test.go`, the `ResolvedVersions` assertion). The requirement states both.
- The spec says a failure names "the first differing path". That holds when both sides render. When the kernel's render fails, the message carries the refusal and no path (`parity_compare_test.go:195-198`). The requirement "A kernel refusal is a disagreement" and its scenario say so.
- The spec says a case with an expected divergence is asserted to diverge in the named way. The code never compares the recorded text with the difference: any kernel error or difference passes (`parity_compare_test.go:202-215`). The requirement states the code.
- The spec says the probe group has no expected divergence. The probe file notes both rows recorded one on landing and both were retired; the table holds none now. No difference in the requirement.

## Left out

- "The old path was proven equal to Render before deletion": a record of a one-time proof kept in the archive of `library-render-cutover`. It states no behaviour a reader can check today.
- The assertion, in the shipped group, that the render's demand equals the instance's declared contracts: it is a scenario of the `single-build-render` repo spec (`library` `openspec/specs/single-build-render/spec.md:487`), a render-path rule the harness only asserts. The written `seed-single-build-render` carries no requirement by that name; the join should check that someone holds it.
- The rule that the kernel's matched pair set equals plain predicate matching: held by `seed-single-build-render`. Here only the harness check and the row coverage are stated.
- The inventory parity test (`render_inventory_parity_test.go`): it ties the render's over-subscription rows to the platform inventory. That belongs to `contract-fulfilment` and `single-build-render`.
- `opm/catalog/provides_parity_test.go`: a different parity (the catalog's provider set against the operator walk). It belongs to `catalog-acquisition`.
- The meaning of "comparable" and "discriminated": held by the future `platform-contract-inventory` seed. The discriminated requirement states only that the harness checks the shipped catalog against it.
- The pure-CUE oracle as a published artifact for the conformance suite: 0024 owns it (its design, "The suite renders through the pure-CUE oracle").
- The file layout of the harness and its fixtures (which module holds which fixture): no consumer observes it.
- Test-suite mechanics, dropped after review (should-fix 4): the gating of registry-backed cases (skipped in short runs and without a registry, forced by a variable CI sets; the probe cases never skipped) and the "harness is test code only" rule. They describe how the test suite runs, not what the parity contract guarantees. The same holds for the gating sentence of "The shipped catalog stays discriminated". Code: `parity_harness_test.go` (`skipUnlessRegistry`), `flow_integration_test.go:240-254`, `library` `.github/workflows/test.yml:92`.
- Dropped after review (should-fix 4): the scenario that the harness checks its own comparison on reordered values (`TestParityEncoder_ReportsReordering`): a self-test of the encoder.

## Dropped after review (reviews/T4.R14.md, should-fix 3)

- The clause "the fix SHALL NOT add kernel behaviour that emulates CUE more closely" rested on archived decision 0019:D1 only; no repo spec or code states it. It is a rule for whoever fixes the kernel, not behaviour. What stays is what a consumer observes: the failure message calls the kernel the defective side and names removal, not loosening, as the fix (spec Purpose; message of `checkParity`).

## Live entries that touch this capability

- 0017 (layered defaults) accepts two divergences from plain CUE and adds a finalize step to the kernel (its design, "Plain CUE stays the floor"; it considered and rejected full parity). If it lands, "A divergence closes by removing kernel behaviour" and "Pure-CUE unification is the render oracle" may need a MODIFIED delta. This seed states the shipped rule only.
- 0025 (self-describing modules) rejects a post-processor over rendered output because a second build breaks the oracle. No change to a requirement here.
- 0024 (cue conformance) renders through the oracle; it does not change the harness.
