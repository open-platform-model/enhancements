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
| 03 | [d27-compat-gate](03-d27-compat-gate/) — whether `cue.Value.Subsume` can express D9's compatibility gate, the measurement D9 defers and the acceptance criteria make a gate. **Neither direction can** (10/14 and 8/14): adding a struct field narrows while adding a disjunct widens, and D27 calls both additive, so the rule spans both lattice directions while one call tests one; a changed default is invisible to both. A three-rule field-wise walk scores 14/14 and is level-aware per 0010 D34. The gate is buildable, so **0010 D27 stands** — which is the outcome that mattered, since the alternative sent it back to publisher discipline. Authored under 0010 and moved here 2026-08-01. | Concluded |
