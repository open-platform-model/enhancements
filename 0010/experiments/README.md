# Experiments — Module and Catalog Identity

Self-contained proofs-of-concept validating specific claims from the
design. See the enhancement's `02-design.md` for the claims being
tested. This file is the hand-maintained index — add a row per
experiment. Per-experiment status lives in each `NN-*/README.md`'s
`Status:` line.

| # | Concept | Status |
| - | ------- | ------ |
| 01 | [identity-marker-discovery](01-identity-marker-discovery/) — the `@opm()` marker as a machine-readable handle (D5), and open-vs-concrete as the distinction D6 rests on. Carries the target `#Module` / `#Catalog` / primitive shapes as authored CUE. **The marker it discovers was dropped by D22**, and it ran **before D13** — see the two notes at the top of its README for what each reversal affects. | Running |
| 02 | [primitive-closedness-skew](02-primitive-closedness-skew/) — whether `Match`'s always-unify rung enforces an additive-only promise when a component and a transformer are built from different builds of one MAJOR-keyed primitive. Ran before the model it tests was recorded; its outcome then became the evidence for **D24, D26 and D27**. Finding 2 — provenance in the unified value defeats contract keys outright — was not predicted and is D26's whole basis. | Concluded |
