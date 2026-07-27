# Experiments — Module and Catalog Publishing

Self-contained proofs-of-concept validating specific claims from the
design. See the enhancement's `02-design.md` for the claims being
tested. This file is the hand-maintained index — add a row per
experiment. Per-experiment status lives in each `NN-*/README.md`'s
`Status:` line.

| # | Concept | Status |
| - | ------- | ------ |
| 01 | [version-set-write-back](01-version-set-write-back/) — `version set` as a surgical AST edit located by the `@opm()` marker (D3), and what the naive rewrite deletes. | Running |
| 02 | [publish-plan-gates](02-publish-plan-gates/) — `#PublishPlan` executed: coordinates derived from the artifact (D2), and each gate (D4, D6) refusing with the offender named. | Running |
