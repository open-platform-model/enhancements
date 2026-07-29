# Experiments — Module and Catalog Publishing

Self-contained proofs-of-concept validating specific claims from the
design. See the enhancement's `02-design.md` for the claims being
tested. This file is the hand-maintained index — add a row per
experiment. Per-experiment status lives in each `NN-*/README.md`'s
`Status:` line.

| # | Concept | Status |
| - | ------- | ------ |
| 01 | [version-set-write-back](01-version-set-write-back/) — `version set` as a surgical AST edit (D3), and what the naive rewrite deletes. **Its `role`-marker recommendation is rejected** by 0010 D22 / D8 — the edit mechanics stand, the locator changed; see the note at the top of its README. | Running |
| 02 | [publish-plan-gates](02-publish-plan-gates/) — `#PublishPlan` executed: coordinates derived from the artifact (D2), each gate (D4, D6) refusing with the offender named, and identity located by its schema-fixed path (D8). | Running |
