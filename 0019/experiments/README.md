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
| 05 | match-in-one-build | Draft |
| 06 | concurrent-render | Concluded |

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
  poisons the rest.

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
