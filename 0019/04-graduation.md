# Graduation Criteria — Kernel render path parity with pure CUE

This document records the gates that must hold before the enhancement advances along the design lifecycle. Treat these as design acceptance criteria, not as implementation milestones; implementation progress lives in `config.yaml.implementation` and the `history` list.

The entry graduates **as one unit** — there is no per-phase acceptance — but implementation is phased, and the structural guarantee that Phase A is never hostage to Phase B is a gate item here: `plan.yaml` must show no Phase A slice depending on any Phase B slice.

## draft → accepted

- Every Open Question reaches a status other than `open`: resolved by a decision, or deferred to a **named** entry. Specifically:
  - OQ1, OQ2, OQ3, OQ8, OQ12, OQ13 are ratified (D8/D9 carry them); their status lines say so.
  - OQ4 (sibling access through `#moduleInstance`) resolves — it gates the Phase A slice that fills the slot.
  - OQ5 (`#TransformerContext` as projection) resolves, or is explicitly deferred with a successor named. It does not gate the parity work, so deferral is a legitimate outcome.
  - OQ6 (what the generated render module owes its own `cue.mod`) resolves **at the invariant level**: the kernel writes the complete tidied dependency set or refuses to render, and an internal check asserts no OPM-namespace path resolves from the module graph rather than the roots. The tidy-mechanism choice stays inside the Phase B slice.
  - OQ7's residue resolves: the default response per caller, where the comparison reads the module's requirement from, and whether older-than-platform gets its own signal.
  - OQ9 and OQ10 defer to enhancement 0015, named.
  - OQ11 defers to a named future platform-publishing entry.
  - OQ14 resolves: which `env` ordering is the contract, recorded with its migration note — and re-homed to Phase A, since the reordering comes from removing the strip.
- The parity oracle's equality is stated precisely enough to implement: which fixtures it covers, how `#context` is projected on the CUE side, and what "equal" means for a rendered value (structural equality of the exported value, or something narrower).
- `schemas/` (the core-schema delta, `core_schema: true`) compiles via `cue vet ./...`, and `examples.cue` exercises every NEW or CHANGED definition with concrete instances whose derived values are pinned by hidden assertions: D5's entry derivations and key binding, D12's context projection, D16's qualified default and its DNS ripple. `spec.md` drafts the `core/SPEC.md` delta for all three core slices.
- `contracts/contracts.cue` compiles via `cue vet ./...` and carries a surface for every remaining decision that has one: the parity contract, the fill obligations end-to-end, the execution unit, the authoring obligations, the render build (promotion, isolation, ordering), platform generation, skew policy, and matching-in-build. The gate across both files is that no decision's mechanism lives only in a comment while the field beside it stays a placeholder.
- `semver` in `config.yaml` is set. Current expectation is `major`, twice over: `FinalizeValue` leaves the public kernel surface (Phase A), and `#Subscription`'s `version!` leaves `core`'s `#Platform` (Phase B, D5).
- `plan.yaml` exists, validates, and its dependency graph shows every Phase A slice free of Phase B dependencies. This replaces the old "decide whether a plan is warranted" item: `affects` spans four repos, so the plan is required.
- The Cross-References table in `README.md` lists every file path the implementation will touch, each verified to exist.
- A compaction pass has collapsed the resolved-OQ prose (the OQ block is currently the entry's heaviest reading; the ratified questions fold to their D-references before the flip).

## accepted → implemented

**Phase A — parity on the current path** (all library-local; steps 1-4 of `06-operational.md`'s order):

- The parity harness exists in `library`, runs in CI, and passes for every fixture it covers. Its first recorded failure (the definition strip) is preserved in the slice's history as D1's evidence.
- `#component` is filled from the unstripped component value, and a regression test asserts a transformer renders `#component.#names.dns.fqdn`.
- `#moduleInstance` is filled, with tests covering both a plain read and the self-referential case where the filled instance contains the component being rendered. Closes open-platform-model/library#65.
- `TestFlow_WebApp_OnOpmPlatform` constructs its instance without `LookupPath` plus `FillPath`, and `#instance` wires correctly on that path; `cli` and `opm-operator` are swept for the same construction shape before the exposing slice lands.
- `FinalizeValue` no longer runs in the render path. Its removal from the public kernel surface carries a `MIGRATIONS.md` entry, and `cli` and `opm-operator` are checked for callers.
- The OQ14 ordering note ships with the strip-removal slice (a server-side-apply diff on first reconcile for modules assembling environments conditionally).
- Both closedness regression guards and the `cueregression` canary pair still pass, unchanged.

**Phase B — the single-build collapse** (cross-repo; sequenced by `plan.yaml`):

- `core` ships D5's registry reshape (`#CatalogEntry`, `version!` removed, `#composedTransformers` derived) with its `SPEC.md` co-update under the `core-schema-edit` protocol.
- The render-build assembler exists in `library`: stage, write `cue.mod` and `local-module.cue` honouring OQ6's invariant, build once, read `rendered` and `diagnostics`. The parity harness proves the new path produces what the old path produced, fixture by fixture, before the old path is removed.
- Matching runs inside the build per D10, gated on reproducing the kernel's exact pair set against the vendored kernel record; `excludeProvenance` and its denylist are deleted in the same slice.
- D7's skew comparison ships with its caller-supplied policy; `cli` and `opm-operator` each expose their surface.
- `opm/materialize` shrinks or is deleted, gated on D5 having landed in `core`.
- ADR-002 gains its superseded-by header, the new ADR states the shares-nothing and `cue.Context` lifetime rules (D8, OQ12), and `opm-operator/internal/platform/store.go`'s single held slot is removed.
- The operator generates the platform package its CR describes (D6), with the regeneration hook 0015's registrations will need left as a named extension point.
- If OQ5 resolved toward projection: `core` ships the `#TransformerContext` derivation with its `SPEC.md` co-update, and `library` deletes the corresponding Go decoding.

**Entry-level closure:**

- `config.yaml.implementation.status = complete` with `date` set to the landing date.
- `history` carries an event per landing milestone, each naming its OpenSpec slice.
- `README.md` carries an `> **Implementation status (YYYY-MM-DD).**` quote block whose date matches `implementation.date`.
- `## Deviations from Design` in `README.md` lists every deliberate divergence, or says "None".
