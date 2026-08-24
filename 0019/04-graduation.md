# Graduation Criteria — Kernel render path parity with pure CUE

This document records the entry-specific gates that must hold before this design is frozen. Treat these as design acceptance criteria, not as implementation milestones; delivery is derived from this entry's `delivery.yaml` log and read back with `task delivery`; the entry's documents store nothing about it.

The entry graduates **as one unit** — there is no per-phase acceptance — but implementation is phased, and the structural guarantee that Phase A is never hostage to Phase B is a gate item here: Phase A work must land free of any dependency on Phase B work, stated as a design constraint in `06-operational.md`.

## draft → accepted

- Every Open Question reaches a status other than `open`: resolved by a decision, or deferred to a **named** entry. Specifically:
  - OQ1, OQ2, OQ3, OQ8, OQ12, OQ13 are ratified (D8/D9 carry them); their status lines say so.
  - OQ4 (sibling access through `#moduleInstance`) resolves — it gates the Phase A slice that fills the slot.
  - OQ5 (`#TransformerContext` as projection) resolves, or is explicitly deferred with a successor named. It does not gate the parity work, so deferral is a legitimate outcome.
  - OQ6 (what the generated render module owes its own `cue.mod`) resolves **at the invariant level**: the kernel writes the complete tidied dependency set or refuses to render, and an internal check asserts no OPM-namespace path resolves from the module graph rather than the roots. The tidy-mechanism choice stays inside the Phase B slice.
  - OQ7's residue resolves: settled by D18 (default warn-and-render, configurable warn/refuse only; comparison between the two committed resolutions; older-than-platform as diagnostics data).
  - OQ9 and OQ10 defer to enhancement 0015, named.
  - OQ11 dissolves via D6's 2026-08-20 revision: publishing a #Platform is disallowed outright, so no successor entry is owed.
  - OQ14 resolves: which `env` ordering is the contract, recorded with its migration note — and re-homed to Phase A, since the reordering comes from removing the strip.
- The parity oracle's equality is stated precisely enough to implement: which fixtures it covers, how `#context` is projected on the CUE side, and what "equal" means for a rendered value (structural equality of the exported value, or something narrower).
- `schemas/` (the core-schema delta, `core_schema: true`) compiles via `cue vet ./...`, and `examples.cue` exercises every NEW or CHANGED definition with concrete instances whose derived values are pinned by hidden assertions: D5's entry derivations and key binding, D12's context projection, D16's qualified default and its DNS ripple. `spec.md` drafts the `core/SPEC.md` delta for all three core slices.
- `contracts/contracts.cue` compiles via `cue vet ./...` and carries a surface for every remaining decision that has one: the parity contract, the fill obligations end-to-end, the execution unit, the authoring obligations, the render build (promotion, isolation, ordering), platform generation, skew policy, and matching-in-build. The gate across both files is that no decision's mechanism lives only in a comment while the field beside it stays a placeholder.
- `semver` in `config.yaml` is set. Current expectation is `major`, twice over: `FinalizeValue` leaves the public kernel surface (Phase A), and `#Subscription`'s `version!` leaves `core`'s `#Platform` (Phase B, D5).
- Phase A work is free of Phase B dependencies, stated as design constraints in `06-operational.md ## Cross-Repo Coordination`; the landing record accretes in `delivery.yaml` as changes land. `affects` spans four repos, so the constraints must be explicit.
- The Cross-References table in `README.md` lists every file path the implementation will touch, each verified to exist.
- A compaction pass collapses the resolved-OQ prose at the flip: `enhancement-compaction` gates COLLAPSE-OQ to `accepted`, so the collapse lands as the first commit after the status flips, folding the ratified questions to their D-references.
