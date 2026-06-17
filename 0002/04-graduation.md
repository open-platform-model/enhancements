# Graduation Criteria — Rename #ModuleRelease to #ModuleInstance

Gates that must hold before this enhancement advances. Design acceptance criteria, not implementation milestones — implementation progress lives in `config.yaml.implementation` and `history`.

## draft → accepted

Ready to implement when:

- Goals and Non-Goals in `02-design.md` are final and reviewed.
- **OQ1–OQ4 in `03-decisions.md` are all resolved** — in particular OQ1 (does `kind` move?) and OQ2 (do labels move?), since they decide whether `affects` is `[core]` or `[core, library, opm-operator]`. No `accepted` while the wire-contract scope is undecided.
- Every decision (D1..DN) is locked with the four-field shape.
- `schemas/target.cue` compiles (`cue vet ./...` from `schemas/`) and captures the renamed surface end-to-end, with no `// OQ#` markers left unresolved.
- `config.yaml.semver` is set (expected `major`, pending OQ4).
- `config.yaml.affects` reflects the resolved scope (grows beyond `[core]` iff D2/D3 land); `area` (`core`) appears in `affects`.
- `related` (`0001`) is final and resolves.
- No placeholder strings remain in any markdown file.
- The Cross-References table in `README.md` lists every file the implementation will touch, and each path exists today.

## accepted → implemented

Shipped when:

- Every `core/src` target in `## Integration Points` is renamed to match `schemas/target.cue` (including the `module_release.cue` → `module_instance.cue` file move).
- `core/SPEC.md` co-updated under the `core-schema-edit` protocol; `core/INDEX.md` regenerated via `task generate:index`.
- If D2/D3 landed: the library kind-detection / `synth/release.go` and the operator `Release` reconciler kind-detection updated and tested against the new `kind` string, each tracked as a `history` event with a `slice:` ref.
- Any `library/modules/` fixtures referencing the old identifiers migrated to the new names; old names deleted, not aliased (unless OQ3 elected an alias window, in which case the alias and its removal date are recorded).
- `core task check` / `task vet` green.
- `config.yaml.implementation.status = complete` with `date` = landing date; `history` carries the landing milestone(s).
- `README.md` carries the `> **Implementation status (YYYY-MM-DD).**` block (date matches `implementation.date`).
- `## Deviations from Design` in `README.md` lists every divergence (or "None").
