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
