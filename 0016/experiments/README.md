# Experiments — Initialize a Module Instance Package from a Published Module

Self-contained proofs-of-concept validating specific claims from the
design. See the enhancement's `02-design.md` for the claims being
tested. This file is the hand-maintained index — add a row per
experiment. Per-experiment status lives in each `NN-*/README.md`'s
`Status:` line.

All eight were run and concluded on 2026-08-24. Only the core v2 line is in scope; where a listing carries pre-v2 majors they appear solely as lines the D5 walk skips.

| # | Concept | Backs | Status | Result |
| - | ------- | ----- | ------ | ------ |
| 01 | cross-major-enumeration | D5 | Concluded | held |
| 02 | core-major-probe | D5 | Concluded | held; found majors with no core dependency (D5 skip rule) |
| 03 | generated-package-builds | D1, D9 | Concluded | held; build verdict is platform-relative (D8) |
| 04 | nonconcrete-initvalues-render | D4 | Concluded | refuted in part; D4 revised (defaults resolve, optionals dropped) |
| 05 | nonstruct-debugvalues | D6 | Concluded | held |
| 06 | initvalues-additive | D3, D4 | Concluded | held; `#Module` is closed, core version floor recorded |
| 07 | highest-stable-per-major | D5 | Concluded | dev-only major diverges; D5 adopts the publish predicate |
| 08 | moduleish-refusal | D5 | Concluded | held; failed init must leave nothing behind (D5) |
