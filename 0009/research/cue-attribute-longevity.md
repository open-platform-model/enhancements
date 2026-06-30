# Research — Are CUE attributes (`@attr(...)`) at risk of removal?

Gathered 2026-06-29. Snapshot of evidence, not a maintained spec. Drives decision **D5** (attribute-based dispatch) and the attribute-longevity risk in `05-risks.md`.

## Question

OPM enhancement 0009 dispatches operational Ops via a CUE `@op(...)` attribute read by the Go SDK (`cue.Value.Attribute`). A CUE community meeting reportedly discussed adding **custom functions** to CUE, and someone reportedly asked whether **attributes would be removed**. If attributes were removed, 0009's dispatch mechanism (D5/D6) would collapse. This dossier checks whether removal is real.

## Verified findings

- **No deprecation or removal of attributes exists or is proposed.** No deprecation notice in the language spec's attributes section (<https://cuelang.org/docs/reference/spec/#attributes>), and none on the Go SDK `cue.Value.Attribute` / `Attributes` API (<https://pkg.go.dev/cuelang.org/go/cue>). The spec frames attributes as *"meta information … [that] do not influence the evaluation of CUE"* — i.e. exactly the inert-metadata role 0009 relies on.

- **CUE's own custom-function mechanism is built *on* an attribute, not in place of one.** WASM/external functions are declared with the `@extern` attribute (<https://pkg.go.dev/cuelang.org/go/cue/interpreter/wasm>):
  ```cue
  @extern("wasm")
  package p
  add: _ @extern("foo.wasm", abi=c, sig="func(int64, int64): int64")
  ```
  So the "custom functions" topic does not threaten attributes — it *consumes* them. This directly inverts the meeting concern.

- **Attributes are being actively extended.** Issue [#4269](https://github.com/cue-lang/cue/issues/4269) adds attributes on list elements (described as "purely additive, all existing CUE files remain valid"); Discussion [#4304](https://github.com/cue-lang/cue/discussions/4304) (March 2026) proposes `struct.HasAttr` / `struct.FilterByAttr` builtins for querying attributes. Both signal investment, not deprecation.

- **Maintainer posture affirms attributes.** Discussion [#1009](https://github.com/cue-lang/cue/discussions/1009) ("Attribute doubts/proposals") — maintainer @myitcv discusses design constraints with no hint of removal. Long-term stewardship was announced via CUE Labs ([#4160](https://github.com/cue-lang/cue/discussions/4160), Marcel van Lohuizen).

- **Placement constraint (affects 0009 schema authoring).** In [#1009](https://github.com/cue-lang/cue/discussions/1009), @myitcv: *"We would be surprised if we ever move to allow attributes to be defined before an identifier."* → CUE supports **field attributes** (after the field value) and **declaration / file-level attributes**, but **not** attributes placed *before* a field/identifier. The "before the field" placement seen in some hof.io examples is therefore not a portable CUE form; 0009 must use the on-field / declaration placement (`opKind: "exec" @op(...)`), which `schemas/target.cue` already does.

## Caveats / what could NOT be verified

- **The exact community-meeting exchange was not found in public records.** The Feb 2025 ([#3766](https://github.com/cue-lang/cue/discussions/3766)) and Jun 2025 ([#3951](https://github.com/cue-lang/cue/discussions/3951)) community updates discuss custom / user-defined functions, but neither publicly documents a "will attributes be removed?" question and answer. The exchange may exist only in a meeting recording / Slack not transcribed publicly, or may have been about the `@extern` *interface* specifically rather than attributes in general.

- **One genuinely experimental surface — but it is NOT attributes.** The WASM `@extern` *interface* is documented as experimental ("may change in the future"). This is relevant only if OQ1 (artifact form) leans on CUE's **evaluation-time** WASM functions. That is distinct from 0009's model, where ops execute at **runtime** through the library orchestrator and the attribute is only inert dispatch metadata — the most stable way to depend on attributes.

## Verdict

Relying on `@attr(...)` read via `cue.Value.Attribute()` for runtime dispatch is **safe**: no removal is planned, the API is stable, attributes are foundational to CUE's own extensibility (including the very custom-functions feature the meeting concerned), and they are being extended. Residual risk is low and is tracked in `05-risks.md`.

## Sources

- Spec — attributes: <https://cuelang.org/docs/reference/spec/#attributes>
- Go SDK — `cue.Value.Attribute`: <https://pkg.go.dev/cuelang.org/go/cue>
- WASM `@extern` (experimental): <https://pkg.go.dev/cuelang.org/go/cue/interpreter/wasm>
- Discussion #1009 — Attribute doubts/proposals: <https://github.com/cue-lang/cue/discussions/1009>
- Discussion #484 — User-defined functions?: <https://github.com/cue-lang/cue/discussions/484>
- Issue #4269 — Allow attributes on list elements: <https://github.com/cue-lang/cue/issues/4269>
- Discussion #4304 — `struct.HasAttr` / `struct.FilterByAttr`: <https://github.com/cue-lang/cue/discussions/4304>
- Discussion #4160 — Announcing CUE Labs: <https://github.com/cue-lang/cue/discussions/4160>
- Community updates #3766 (2025-02-27) / #3951 (2025-06-05): <https://github.com/cue-lang/cue/discussions/3766>, <https://github.com/cue-lang/cue/discussions/3951>
