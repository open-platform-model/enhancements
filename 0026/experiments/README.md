# Experiments: Module-Dictated Catalog Versions and the Generated Platform

Self-contained proofs-of-concept validating specific claims from the
design. See the enhancement's `02-design.md` for the claims being
tested. This file is the hand-maintained index: add a row per
experiment. Per-experiment status lives in each `NN-*/README.md`'s
`Status:` line.

| # | Concept | Status |
| - | ------- | ------ |
| 01 | one-major-per-build | Concluded |
| 02 | provider-serves-its-major | Concluded |

Both back D9, side-by-side catalog majors: 01 shows why no build may hold two majors of one catalog, 02 shows why a provider enters only the resolutions holding the major it was built against, and why the one-provider count is taken per resolution.
