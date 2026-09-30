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
| 03 | module-qualified-keys | Concluded |
| 04 | major-segment-keys | Concluded |
| 05 | major-as-matching-scope | Concluded |
| 06 | collision-tolerant-fold | Concluded |
| 07 | render-shipped-core | Concluded |
| 08 | render-module-qualified-keys | Concluded |
| 09 | render-major-as-matching-scope | Concluded |

All nine back D9, side-by-side catalog majors.

- **01 and 02 are D9's own evidence.** 01 shows why no build may hold two majors of one catalog. 02 shows why a provider enters only the resolutions holding the major it was built against, and why the one-provider count is taken per resolution.
- **03 to 05 measure the rejected alternatives in core alone.** 03 puts the declaring module path with its major into every contract key, the spelling D9 names; 04 puts the major in as a key path segment; 05 keeps shared keys and scopes matching by the declaring major.
- **06 is the core fix OQ17 asks about**: a contract fold that reports colliding keys instead of failing to evaluate.
- **07 to 09 render through the real library.** 07 is the shipped library and core with no patch, 08 renders 03's keys, 09 renders 05's scoping with a patched render glue.

01 to 06 are pure CUE and run from their `probe/` directory with `cue` alone. 07 to 09 need a library checkout: each carries a `run.sh` that clones library (and core, for 08 and 09) at a pinned commit into a fresh work directory, applies the experiment's patches and runs one probe test.
