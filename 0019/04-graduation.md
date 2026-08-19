# Graduation Criteria — Kernel render path parity with pure CUE

This document records the gates that must hold before the enhancement advances along the design lifecycle. Treat these as design acceptance criteria, not as implementation milestones; implementation progress lives in `config.yaml.implementation` and the `history` list.

## draft → accepted

- OQ1, OQ2 and OQ3 reach a status other than `open`. Each may resolve to a decision, or be deferred to a successor enhancement with that entry named. What it may not do is dangle, because it decides whether the later slices are a cleanup or a rewrite.
- OQ4 resolves, because D3 fills `#moduleInstance` and OQ4 asks what that slot is allowed to reach. It gates a slice.
- OQ5 resolves, or is explicitly deferred with a successor named. Unlike OQ4 it does not gate the parity work, so deferral is a legitimate outcome.
- The parity oracle's equality is stated precisely enough to implement: which fixtures it covers, how `#context` is projected on the CUE side, and what "equal" means for a rendered value (structural equality of the exported value, or something narrower).
- `schemas/target.cue` compiles via `cue vet ./...` and states the parity contract and the fill obligations end-to-end.
- `semver` in `config.yaml` is set. Current expectation is `major`, because `FinalizeValue` is exposed as a public kernel method and leaves the public surface.
- A decision exists on whether `plan.yaml` is warranted; `affects` spans two repos, so this is the natural moment to run `task new:plan`.
- The Cross-References table in `README.md` lists every file path the implementation will touch, each verified to exist.

## accepted → implemented

- The parity harness exists in `library`, runs in CI, and passes for every fixture it covers.
- `#component` is filled from the unstripped component value, and a regression test asserts a transformer renders `#component.#names.dns.fqdn`.
- `#moduleInstance` is filled, with tests covering both a plain read and the self-referential case where the filled instance contains the component being rendered.
- `TestFlow_WebApp_OnOpmPlatform` constructs its instance without `LookupPath` plus `FillPath`, and `#instance` wires correctly on that path.
- `FinalizeValue` no longer runs in the render path. Its removal from the public kernel surface carries a `MIGRATIONS.md` entry, and `cli` and `opm-operator` are checked for callers.
- Both closedness regression guards and the `cueregression` canary pair still pass, unchanged, on the final tree.
- If OQ5 resolved toward projection: `core` ships the `#TransformerContext` derivation with its `SPEC.md` co-update, and `library` deletes the corresponding Go decoding.
- `config.yaml.implementation.status = complete` with `date` set to the landing date.
- `history` carries an event per landing milestone, each naming its OpenSpec slice.
- `README.md` carries an `> **Implementation status (YYYY-MM-DD).**` quote block whose date matches `implementation.date`.
- `## Deviations from Design` in `README.md` lists every deliberate divergence, or says "None".
