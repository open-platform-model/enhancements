# Experiments — Module and Catalog Identity

Self-contained proofs-of-concept validating specific claims from the
design. See the enhancement's `02-design.md` for the claims being
tested. This file is the hand-maintained index — add a row per
experiment. Per-experiment status lives in each `NN-*/README.md`'s
`Status:` line.

| # | Concept | Status |
| - | ------- | ------ |
| 01 | [identity-marker-discovery](01-identity-marker-discovery/) — the `@opm()` marker as a machine-readable handle (D5), and open-vs-concrete as the distinction D6 rests on. Carries the target `#Module` / `#Catalog` / primitive shapes as authored CUE. **The marker it discovers was dropped by D5 (absorbing D22)** on the strength of its own finding 3, and it ran **before the contract/build key split** — see the two notes at the top of its README, and the Conclusion for what each reversal left standing. | Concluded |
| 02 | [primitive-closedness-skew](02-primitive-closedness-skew/) — whether `Match`'s always-unify rung enforces an additive-only promise when a component and a transformer are built from different builds of one MAJOR-keyed primitive. Ran before the model it tests was recorded; its outcome then became the evidence for **D24, D26 and D27**. Finding 2 — provenance in the unified value defeats contract keys outright — was not predicted and is D26's whole basis. | Concluded |
| 03 | [provenance-operand-filter](03-provenance-operand-filter/) — whether D26's operand-side exclusion is *implementable*, given that removing a field from an immutable `cue.Value` means a syntax round-trip that could drop the closedness experiment 02 showed the whole model rests on. Fixtures copied from 02 plus a description-drift build. Closedness survived; `catalogVersion` alone did not suffice. Evidence for **D30**, which resolves **OQ12**. | Concluded |
| 04 | [component-label-union](04-component-label-union/) — whether the matching label can move off a primitive's **component fragment** onto the primitive itself, making the fragment a pure wrapper and putting the label under D27 without extending it. Eight variants across two designs. The union `core/SPEC.md` states normatively three times **cannot be built** — primitive categorisation labels collide — and every *filtered* repair forces dropping the `!` marker, because CUE will not iterate a struct holding an unset required field. Giving matching its **own field** removes the filter and all three costs with it, and makes the component side symmetric with `requiredLabels`. Evidence for **D36**, which resolves **OQ16**. | Concluded |
