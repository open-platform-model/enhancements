# Experiments: kernel render path parity with pure CUE

Self-contained proofs-of-concept validating specific claims from the
design. See the enhancement's `02-design.md` for the claims being
tested. This file is the hand-maintained index. Add a row per
experiment. Per-experiment status lives in each `NN-*/README.md`'s
`Status:` line.

| # | Concept | Status |
| - | ------- | ------ |
| 01 | purecue-render-flow | Concluded |
| 02 | platform-authority-mvs | Concluded |
| 03 | sealed-platform-roundtrip | Concluded (refuted) |
| 04 | render-build-cost | Concluded |
| 05 | match-in-one-build | Concluded |
| 06 | concurrent-render | Concluded |
| 07 | module-scale-cost | Concluded |
| 08 | concurrent-render-at-scale | Concluded |

## Reading 02 and 03 together

They are the two candidate answers to one question: in a single-build render
pipeline, what stops a consumer module from deciding which transformer bytes a
platform executes?

- **02** tests enforcement at build time, via the render module's own dependency
  list and `cue.mod/local-module.cue`. Concluded: authority holds, provided the
  kernel lists the path.
- **03** tests enforcement at artifact time, by sealing the platform into
  catalog-independent CUE. Concluded: refuted on today's tooling.

02 having held is what demotes 03 from "the alternative mechanism" to "an
optimisation for reuse", so the two are best read in that order.

## Reading 04 and 05 together

They are the two halves of "can the collapse actually be built", opened after
02 and 03 settled that it is correct.

- **04** asked what a per-render build COSTS, and whether process-level reuse
  recovers enough of it to retire ADR-002's materialize-once model (OQ8).
  Concluded: 2.1x the current path, memory flat, so reuse is an optimisation.
  A shared cue.Context recovers only ~14%, which removes the cheapest
  reuse strategy from OQ8's list.
- **05** asks what matching LOSES when it moves into the build: the same pairs,
  the D30 carve-out, D28's fail-closed refusals, and whether one failing pair
  poisons the rest. Concluded: nothing that matters. Same five pairs as the
  vendored kernel record, D30 deleted rather than ported (provenance is EQUAL
  in one build; a genuine conflict still disqualifies through plain &),
  fail-closed refusals expressible in-build with the evidence readable as data
  through the Go API beside the failing gate, and failure isolation holds for
  error-class failures. Two measured boundaries: an unstated trait posture
  refuses as an incomplete-value bottom rather than as a diagnostics row, and
  an incomplete (non-error) pair output is invisible to == _|_ — caught by
  vet -c at a path naming the pair key.

04 measures an execute-only build on purpose, so 05's cost delta stays
attributable to matching rather than to the collapse.

## 06 continues 04

Experiment 04 measured a per-render cost sequentially and left the throughput
ceiling untested. 06 asks whether renders run at the same time at all: if a
cue.Context cannot be shared and nothing else parallelises, 04's 2.1x sits
under a ceiling that applies equally to today's path, which changes what the
number means rather than what it says.

Concluded: there is no such ceiling. Renders parallelise to about 4x on eight
cores and the 2.1x multiplier survives concurrency, so 04's verdict stands.
Two results arrived sideways. Memory is retained per RENDER for as long as the
cue.Context that produced it lives, which refutes 06's own memory hypothesis
and applies to today's path too; and the safety answer is inverted, with a
shared cue.Context race-clean and ADR-002's shared materialized platform
producing thousands of race reports. Read 04 for what a render costs and 06
for what may be shared between renders.

## 07 finishes 04

Experiment 04 attached a limit to its own verdict: the 2.1x came from a
two-component module with five pairs, and "a large module should be measured
before the ratio is quoted as general". 07 is that measurement, on two
purpose-built large fixtures that grow in different directions (a 129-component
fleet, and a 32-component module of deep guarded components), each authored both
with blueprints and with raw resources and traits so that authoring style is a
measured variable rather than an assumption.

Concluded: the 2.1x is a FIXED cost, not a general ratio. Per-render cost fits
`fixed + slope x components` with R^2 above 0.9996 in every case; the single
build's fixed term is about 85 ms of catalog resolution and evaluation and does
not move, while its per-component term is LOWER than today's path in every
fixture and style. The curves cross between 5 and 14 components, and past that
the collapse is the cheaper option. The experiment's own second hypothesis was
refuted and is the more useful half: the definitional payload the collapse stops
stripping costs nothing, because no transformer reads it and CUE never evaluates
it, whereas finalizing it costs the baseline more per component than carrying it
costs the single build.

Read 04 for what one render costs, 06 for what may be shared between renders, and
07 for how either number moves when the module is real.

## 08 closes 06 and 07 against each other

06 measured concurrency on a two-component module; 07 measured cost on modules
up to 129 components. Neither could answer the question an operator actually
has, because 06 had the concurrency without the size and 07 had the size without
the concurrency. 08 runs 07's fixtures, byte for byte, through 06's worker pool.

Concluded: size changes none of 06's answers. Concurrent speedup is flat across
a 64-fold size range (4.28x, 4.33x, 4.24x, 4.05x at 2, 9, 33 and 129
components), resident memory grows sub-linearly in workers, the race detector
stays silent, and no concurrent render ever produced a wrong value across 2688
renders.

The result neither parent could produce: 07's crossover disappears. 07 compared
the two paths SEQUENTIALLY and found the single build cheaper only above roughly
a dozen components, but 06 established today's path cannot be run concurrently
at all. Compared against today's path serialised, which is what an operator can
safely deploy, the single build wins at every size, from 2.48x at two components
to 5.49x at 129. One correction rides along: today's path retains 348 MB per
render too, so per-render retention is a property of holding a cue.Context
rather than a cost the collapse introduces.
