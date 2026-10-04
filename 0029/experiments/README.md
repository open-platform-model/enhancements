# Experiments — Gated Ownership Transfer from CLI to Operator

Self-contained proofs-of-concept validating specific claims from the
design. See the enhancement's `02-design.md` for the claims being
tested. This file is the hand-maintained index — add a row per
experiment. Per-experiment status lives in each `NN-*/README.md`'s
`Status:` line.

| # | Concept | Status |
| - | ------- | ------ |
| 01 | [provenance-digest-reachability](01-provenance-digest-reachability/): which local renders the marker misses, whether the strict re-render catches republished bytes, and whether the CLI can predict the operator's fetch | Concluded |
| 02 | [applier-identity-and-field-transfer](02-applier-identity-and-field-transfer/): whether an access review predicts the operator's apply, what the first reconcile changes, and what field ownership the CLI keeps | Concluded |
