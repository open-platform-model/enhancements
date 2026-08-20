# Operational Concerns — Kernel render path parity with pure CUE

This document is the OPM Production Readiness Review (PRR-lite).

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

The primary new signal is a CI one: the parity harness in `library`, which reports a divergence between the kernel's rendered value and pure-CUE unification of the same inputs as a test failure naming the field that differs.

At runtime the enhancement is close to observability-neutral, but it improves one existing diagnostic by removing its cause. A transformer that reads a field the kernel did not supply currently fails with `#transform.output: N errors in empty disjunction`, which names neither the field nor the reason, because the disjunction in `core`'s `output: {...} | [...{...}]` swallows the underlying incompleteness. Filling all three inputs removes the most common way to reach that message. It does not fix the message itself; a transformer with a genuine typo still gets it. Improving that error is worth considering as follow-up work and is not in scope here.

New diagnostics, no new severity machinery: D7/D18's skew comparison returns structured rows on the existing warnings channel, and the resolved-versions comparison rides every compile's diagnostics as plain data. `opm/errors/match.go`'s message text is reworded where it names the removed reverse index (D17); no new error kinds, metrics or spans otherwise.

## Sizing a Render Pool

**How much memory does an operator need once this lands, and how many workers should it run?**

Both answers come from `experiments/08-concurrent-render-at-scale/`, and they are different questions than they were under ADR-002, because D8 makes a render a self-contained unit that holds nothing afterwards.

**A render is single-threaded, and there is no phase inside it left to parallelise.** Measured directly: with the collector disabled, one render of a 129-component module uses 1.04 cores. Two further measurements close the obvious workarounds. Forcing `rendered` concrete after `BuildInstance` returns costs **3.0 ms of an 1831 ms render** for 387 objects, so CUE has already evaluated every pair by the time the build call returns; there is no deferred pair work a worker could pick up. And rendering one component out of a 129-component instance still costs 1303 ms against 1860 ms for all of them, so **46% to 76% of a render is a floor that every split would re-pay**, depending on module shape and authoring style. That is an Amdahl bound on any scheme handing subsets of the pairs to parallel builds: between **1.31x and 2.16x**, for K times the memory. The transformer step itself is 1.3 to 2.4 ms per rendered object, and it is the smaller half of a render. Concurrency comes from rendering several instances at once, never from one render going faster. With Go's concurrent collector a render demands about 1.6 cores in total, so throughput saturates at roughly `physical_cores / 1.6` renders in flight: on eight physical cores that is the measured 4.0x to 4.3x at eight workers, and a ninth worker buys nothing.

**Memory is the binding constraint, and it is linear in components.** Peak resident memory per concurrent render, fitted across 2, 9, 33 and 129 components with R^2 = 0.9997:

```
working set per concurrent render  =  61 MB  +  7.75 MB x components
```

| module | P=2 | P=4 | P=8 |
| --- | --- | --- | --- |
| 10 components | 0.3 GB | 0.5 GB | 1.1 GB |
| 25 components | 0.5 GB | 1.0 GB | 2.0 GB |
| 50 components | 0.9 GB | 1.8 GB | 3.5 GB |
| 100 components | 1.6 GB | 3.3 GB | 6.5 GB |
| 129 components | 2.1 GB | 4.1 GB | 8.3 GB |

Add roughly 0.3 GB for the process itself and the module cache, then headroom: these are peaks of a sampled RSS, and Go returns memory to the OS lazily. **A pod rendering modules of ordinary size (10 to 25 components) at four concurrent renders wants about 1 GB, and 2 GB is comfortable.** A pod that must render a 129-component fleet at eight concurrent renders wants 12 GB. The largest module the operator will see is the number to size against, not the average, because the pool has no admission control that would stop several large renders coinciding.

Two practical consequences.

**The biggest lever on a large module is authoring style, not concurrency.** Experiment 07 measured 7.71 ms per component for raw resources and traits against 14.01 for blueprints, so the same 129-component fleet renders in about 1.03 s instead of 1.86 s. That 1.8x is at or above what splitting a render could reach even in the best case, at no extra memory and no extra cores, and it is worth saying to module authors rather than solving in the operator.

**Size the pool by memory, not by core count.** The core-count answer and the memory answer diverge quickly: eight workers is right for throughput on eight physical cores, and at 129 components it costs 8.3 GB. Where memory is the tighter budget, fewer workers is the correct trade, and the throughput cost is close to linear down to P=2.

**Retention is bounded by construction, which is the change.** Under D8 a worker holds 117 KB per render at 129 components and does not grow with render count. The shapes D8 rejects do grow: a per-worker reused `cue.Context` retains 582 MB per render at that size (23.4 GB through 32 renders), and today's held-platform path retains 348 MB per render. An operator running the superseded model has to plan for a process that grows until it is restarted; one running D8 does not.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

**Go module: MAJOR.** `compile.FinalizeValue` and its kernel wrapper in `opm/kernel/phases.go` leave the public surface. `MIGRATIONS.md` gains an entry with the recipe, and `cli` and `opm-operator` are checked for callers before the removal slice lands.

**Rendered output: potentially observable, expected to be identical.** Transformers receive strictly more than before, and no existing transformer reads a definition field (measured: zero references to `#component.#` across every `catalog_opm` transformer; re-verified 2026-08-20 at 50 transformers). Output should therefore be byte-identical for every shipped transformer, and the parity harness is what proves it rather than assumes it.

**Core schema: breaking by content, absorbed within the v2 alpha line.** Four changes land, each with its `SPEC.md` co-update under `core-schema-edit` and pre-drafted in `schemas/spec.md`: D5 removes `#Subscription.version!` and reshapes the registry entry, D17 removes `#Platform.#matchers`, D16 flips the `resourceName` default, and D12 turns `#TransformerContext` into a projection. D12 is additive from a transformer author's perspective (the same field names hold the same values), and the kernel keeps filling identical values for a release, so it has no flag day; the other three are the entry's stated breaks.

**The `major` classification is also a sequencing constraint against stabilization.** Every break above ships free only while both lines are pre-release: library's alpha line absorbs the `FinalizeValue` removal and core's v2 alpha line absorbs D5, D16 and D17 as ordinary alpha increments. If `library` declares `v1.0.0` final before Phase A lands, or `core` declares `2.0.0` final before Phase B lands, the same changes stop being absorbable: the Go removal then forces a `/v2` module path and the schema removals force `opmodel.dev/core` onto a v3 line. Land this entry's breaks before either line graduates out of alpha, or the cost model of this section changes entirely.

**Rendered object names: near-neutral by ordering (D15/D16).** Rendered objects are already named `<instance>-<component>` by every hand-rolled catalog formula, so the D16 flip (landing first) only makes the computed `#names` agree with rendered reality, and the D15 sweep is gated on byte-identical goldens for every default-named fixture. Residual renames are confined to two cases: a component that sets `metadata.resourceName` explicitly (silently ignored today, honoured after the sweep) and modules using the deleted `#ResourceNameTrait` (same rendered name, moved to the core field). A rename is a replace rather than an update on first reconcile; the `modules-fleet-rename` slice records them, and the alpha stance applies: no deprecation cycle.

## Deprecation

**What gets removed and when? What replaces it?**

| Removed | Replaced by | When |
| --- | --- | --- |
| `FinalizeValue` in the render path | nothing; the unstripped value is used directly | the slice that exposes definitions |
| `compile.FinalizeValue` and the kernel wrapper as public API | nothing; no consumer need remains | a later slice, after the render path stops calling it |
| The `schemaComponents` / `dataComponents` split in `compileModuleInstance` | one components value | same slice as the render-path removal |
| Go decoding in `opm/schema/context.go` | CUE projection in `core` (D12) | Phase B, the `core-context-projection` slice |
| `#Subscription.version!` and the version-scalar registry entry | the platform module's own `cue.mod` (D5) | Phase B, the `core` reshape slice |
| `opm/materialize` (pull + index) | the platform's own imports; the composed map as a fold | Phase B, gated on D5 landing in `core` |
| Go matching in `opm/compile/match.go`, including `excludeProvenance` and the D30 denylist | CUE comprehensions inside the render build (D10) | Phase B, gated on exact pair-set reproduction |
| ADR-002's shared-materialized-platform model and `opm-operator/internal/platform/store.go`'s held slot | shares-nothing renders; a `cue.Context` does not outlive its render (D8) | Phase B, the supersession slice |

The two-step for `FinalizeValue` is deliberate: stop using it, confirm the parity harness is green, then remove it from the surface. Collapsing both into one change would mix a behaviour change with an API break.

## Rollback

**If this lands and proves bad, what's the rollback story?**

**Phase A: code-revert for the library half, release-pin for the naming half.** The four library slices are code changes with no artifact and no cluster state; reverting the commit restores the previous behaviour exactly. The naming pair publishes: D16 ships in a `core` release and the D15 sweep in a `catalogs/opm` release. Both roll back by pinning back, and both are output-neutral by construction (the flip changes only a computed value nothing renders from yet; the sweep is gated on byte-identical goldens), so a rollback changes no rendered object either. The one state-bearing change is the fleet's residual renames (`modules-fleet-rename`); reverting those is a second rename, which the alpha stance accepts.

**Phase B: ordinary release discipline rather than trivial revert.** D5 ships in a published `core` major, so rolling it back means pinning back a published artifact, not reverting a commit; the operator's package generation (D6) and the store removal (D8) revert as code but interact with live Platform CRs. The mitigation is the landing order below: the render-build assembler runs behind the parity harness against the old path before the old path is deleted, so the largest Phase B step has a within-release fallback.

Two qualifications. If a transformer is authored to read `#names` or `#moduleInstance` while this is live, reverting breaks that transformer, so the catalog side should not adopt the new capability until the parity harness has been green across a release. And if the removal of `FinalizeValue` from the public surface has already shipped in a MAJOR bump, consumers that re-pinned would need to pin back; that is why the removal is a separate, later slice.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

`plan.yaml` is the source of truth for sequencing; this section is its narrative. Two constraints drive the order. Within Phase A, one measured constraint: exposing definitions changes the flow fixture from shipping no value to shipping a broken one, so the fixture repair cannot follow the exposure. Between phases, one structural guarantee: no Phase A slice depends on any Phase B slice, so the parity work lands regardless of how long the collapse takes.

**Phase A:**

1. **`library`, parity harness.** Additive, no behaviour change. Lands first so every subsequent slice is checked against the oracle rather than against the existing suite. Its initial failure on the definition strip is the evidence for D1.
2. **`library`, fixture repair plus `#component` fill.** One slice, because the ordering constraint binds them. Produces: a render path that passes definitions through, and a regression test that a transformer reads `#names`.
3. **`library`, `#moduleInstance` fill.** Consumes step 2's parity harness coverage. Produces: the third input filled, plus the self-reference test. Closes open-platform-model/library#65.
4. **`library`, remove `FinalizeValue` from the public surface.** Consumes steps 2 and 3 being green. Produces: the MAJOR bump and the `MIGRATIONS.md` entry that `cli` and `opm-operator` re-pin against.
5. **`core`, the D16 default flip.** Lands independently and before the sweep: rendered objects are already named `<instance>-<component>` by the hand-rolled formulas, so flipping the computed default is output-neutral for rendered fleets and closes core#49's computed-versus-rendered divergence. `metadata.resourceName` defaults to the instance-qualified form unified with `#NameType`, plus a hidden assertion for a legible overlong-name refusal; `SPEC.md` co-update under `core-schema-edit`.
6. **`catalog`, the D15 names sweep.** Consumes step 2 (the fill makes `#names` readable inside `#transform`) and step 5 (the flip makes the read byte-identical to the hand-rolled output). All 50 transformers move to reading `#component.#names` for the primary object under D15's carve-outs; `#ResourceNameTrait` and `#WorkloadName` are deleted, fixtures migrating to `metadata.resourceName`; the core dep bumps to the D16 release. Gate: no default-named golden changes by a byte. Ships behind a catalog release whose consumers run a kernel carrying the fill, since a `#names` read against an unfixed kernel fails with the empty-disjunction error.
7. **`modules`, the fleet rename.** Revalidates the v2 staging fleet under the new naming; the residual renames (explicit `metadata.resourceName` starts winning, trait users move to the core field) land without a deprecation cycle per the alpha stance.
**Phase B (cross-repo, after Phase A's step 4):**

8. **`core`, D5 registry reshape.** `#CatalogEntry` replaces `#Subscription`, `#composedTransformers` becomes derived, `SPEC.md` co-update under `core-schema-edit`. Nothing downstream moves until this publishes.
9. **`library`, render-build assembler.** Stage, write `cue.mod` and `local-module.cue` under OQ6's invariant, build once, read `rendered` and `diagnostics`. Runs behind the parity harness against the old path; the old path is deleted only when every fixture agrees.
10. **`library`, matching into the build (D10).** Gated on exact pair-set reproduction against the vendored kernel record; deletes `excludeProvenance` and the D30 denylist in the same slice, with the Go-matcher fallback recorded in D10 if error quality regresses.
11. **`library`, skew detection and policy (D7)**, with `cli` and `opm-operator` each exposing their surface.
12. **`library` + `opm-operator`, D8 supersession.** ADR-002 gains its superseded-by header, the new ADR carries the shares-nothing and context-lifetime rules, ADR-003's federation rationale is retired in place, `store.go`'s held slot is removed, `opm/materialize` shrinks or goes.
13. **`opm-operator`, D6 package generation**, shipping the named extension point where 0015's effective transformer set folds in.
14. **`core`, `#TransformerContext` projection (D12).** Additive; separable by a release because unification agrees while both fill paths are in place, after which the Go fills are removed and the harness's `equality` collapses to `structural`.

**Interim operator stopgap, recorded here as a decision of this entry:** until step 10 lands, the operator holds the ADR-002 shape that experiment 06 measured racing, and the live exposure is sharper than that experiment's: today no controller sets `MaxConcurrentReconciles`, so reconciles within a controller are already serial, but three controllers share one `*kernel.Kernel` across their goroutines against `library`'s documented one-Kernel-per-goroutine rule, with no lock anywhere. The stopgap therefore serialises shared-Kernel access across the controllers (render and platform paths alike) behind one mutex, at the measured cost of 2.5x to 5.5x render throughput: undefined behaviour is not an acceptable resting state even though no wrong value was ever observed. The serialisation is explicitly a stopgap: experiment 08 priced it, and D8 exists because it is also the slower architecture at every module size.

**0015 hand-off:** this entry reaching `accepted` is the trigger for re-baselining 0015's integration surface (its `match.go` line anchors, the materialize-based inventory, the `store.go` re-keying), and OQ9/OQ10 live there from that point.
