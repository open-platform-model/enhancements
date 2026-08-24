# Graduation Criteria — Rename #ModuleRelease to #ModuleInstance

Gates that must hold before this enhancement advances. Design acceptance criteria, not implementation milestones: delivery is derived from this entry's `delivery.yaml` log and read back with `task delivery`; the entry's documents store nothing about it.

## draft → accepted

Ready to implement when:

- Goals and Non-Goals in `02-design.md` are final and reviewed.
- **OQ1–OQ4 in `03-decisions.md` are all resolved.** ✅ Done (2026-06-22): OQ1→D3, OQ2→D4, OQ3→D8, OQ4→D8.
- Every decision (D1..DN) is locked with the four-field shape — including D2, which supersedes D1's scope.
- `schemas/target.cue` compiles (`cue vet ./...` from `schemas/`) and captures the renamed surface end-to-end, with no `// OQ#` markers left unresolved.
- `config.yaml.semver` is set (`major`).
- `config.yaml.affects` is `[core, library, opm-operator, cli]`; `area` (`core`) appears in `affects`.
- `related` (`0001`) is final and resolves.
- No placeholder strings remain in any markdown file.
- The Cross-References table in `README.md` lists every file the implementation will touch, and each path exists today.
