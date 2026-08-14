# Experiments — Attribute-Declared Secret Fields

Self-contained proofs-of-concept validating specific claims from the
design. See the enhancement's `02-design.md` for the claims being
tested. This file is the hand-maintained index — add a row per
experiment. Per-experiment status lives in each `NN-*/README.md`'s
`Status:` line.

| # | Concept | Status |
| - | ------- | ------ |
| 01 | [attribute-propagation](01-attribute-propagation/) — does a CUE field attribute survive everything the OPM artifact shape does to it, and can a Go walk find it? | Concluded |
| 02 | [resolve-in-place](02-resolve-in-place/) — a working prototype of the proposed `library/opm/secret` kernel pass: discover, resolve both arms to `#SecretRef`, materialise | Concluded |
| 03 | [kernel-omission](03-kernel-omission/) — the OQ2 measurement: does the arm rewrite survive the real published kernel's build path when implemented as omission, via both candidate mechanisms? | Concluded |
| 04 | [rewrite-performance](04-rewrite-performance/) — prices the two rewrite mechanisms (decode-encode vs prune-graft) and the bake-style serialization rider across five value-tree shapes | Concluded |
