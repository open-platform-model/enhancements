# Operational Concerns — Kernel render path parity with pure CUE

This document is the OPM Production Readiness Review (PRR-lite).

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

The primary new signal is a CI one: the parity harness in `library`, which reports a divergence between the kernel's rendered value and pure-CUE unification of the same inputs as a test failure naming the field that differs.

At runtime the enhancement is close to observability-neutral, but it improves one existing diagnostic by removing its cause. A transformer that reads a field the kernel did not supply currently fails with `#transform.output: N errors in empty disjunction`, which names neither the field nor the reason, because the disjunction in `core`'s `output: {...} | [...{...}]` swallows the underlying incompleteness. Filling all three inputs removes the most common way to reach that message. It does not fix the message itself; a transformer with a genuine typo still gets it. Improving that error is worth considering as follow-up work and is not in scope here.

No new error kinds, metrics or spans. `opm/errors` is untouched.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

**Go module: MAJOR.** `compile.FinalizeValue` and its kernel wrapper in `opm/kernel/phases.go` leave the public surface. `MIGRATIONS.md` gains an entry with the recipe, and `cli` and `opm-operator` are checked for callers before the removal slice lands.

**Rendered output: potentially observable, expected to be identical.** Transformers receive strictly more than before, and no existing transformer reads a definition field (measured: zero references to `#component.#` across all 51 `catalog_opm` files carrying a `#transform`). Output should therefore be byte-identical for every shipped transformer, and the parity harness is what proves it rather than assumes it.

**Core schema: none, unless OQ5 resolves toward projection.** If it does, `#TransformerContext`'s fields become derived rather than filled. That is additive from a transformer author's perspective, since the same field names hold the same values, and it carries a `SPEC.md` co-update under the `core-schema-edit` protocol. The kernel can keep filling identical values for a release, so there is no flag day.

## Deprecation

**What gets removed and when? What replaces it?**

| Removed | Replaced by | When |
| --- | --- | --- |
| `FinalizeValue` in the render path | nothing; the unstripped value is used directly | the slice that exposes definitions |
| `compile.FinalizeValue` and the kernel wrapper as public API | nothing; no consumer need remains | a later slice, after the render path stops calling it |
| The `schemaComponents` / `dataComponents` split in `compileModuleInstance` | one components value | same slice as the render-path removal |
| Go decoding in `opm/schema/context.go` | CUE projection in `core` | only if OQ5 resolves toward projection |

The two-step for `FinalizeValue` is deliberate: stop using it, confirm the parity harness is green, then remove it from the surface. Collapsing both into one change would mix a behaviour change with an API break.

## Rollback

**If this lands and proves bad, what's the rollback story?**

Straightforward, and this is one of the design's better properties. Every slice is a code change in `library` with no artifact, no published bytes and no cluster state. Reverting the commit restores the previous behaviour exactly; nothing has been written to a registry and no rendered object's shape has changed in a way that outlives the revert.

Two qualifications. If a transformer is authored to read `#names` or `#moduleInstance` while this is live, reverting breaks that transformer, so the catalog side should not adopt the new capability until the parity harness has been green across a release. And if the removal of `FinalizeValue` from the public surface has already shipped in a MAJOR bump, consumers that re-pinned would need to pin back; that is why the removal is a separate, later slice.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

The order is driven by one measured constraint rather than by repo dependencies: exposing definitions changes the flow fixture from shipping no value to shipping a broken one, so the fixture repair cannot follow the exposure.

1. **`library`, parity harness.** Additive, no behaviour change. Lands first so every subsequent slice is checked against the oracle rather than against the existing suite. Its initial failure on the definition strip is the evidence for D1.
2. **`library`, fixture repair plus `#component` fill.** One slice, because the ordering constraint binds them. Produces: a render path that passes definitions through, and a regression test that a transformer reads `#names`.
3. **`library`, `#moduleInstance` fill.** Consumes step 2's parity harness coverage. Produces: the third input filled, plus the self-reference test. Closes open-platform-model/library#65.
4. **`library`, remove `FinalizeValue` from the public surface.** Consumes steps 2 and 3 being green. Produces: the MAJOR bump and the `MIGRATIONS.md` entry that `cli` and `opm-operator` re-pin against.
5. **`core`, `#TransformerContext` projection**, only if OQ5 resolves toward it. Produces: derived context fields plus the `SPEC.md` co-update. `library` then deletes its decoding in a follow-on slice, and the two can be separated by a release because unification agrees while both are in place.

Steps 1 through 4 are `library`-local and need no upstream artifact. Step 5 is the only genuine cross-repo hand-off, and it is gated on an open question.

The single-build collapse (OQ1 through OQ3) is deliberately absent from this sequence. If those resolve in its favour it is a further enhancement with its own coordination, not a step appended here.

Whether this warrants a `plan.yaml` is a `draft → accepted` gate item. `affects` spans two repos, but only one hand-off is real and it is conditional, so the narrative above may be sufficient.
