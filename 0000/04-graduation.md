# Graduation Criteria — {Enhancement Title}

This document records the gates that must hold before the enhancement
advances along the design lifecycle. The validator (future) checks the
gate items at each promotion. Treat these as design acceptance criteria,
not as implementation milestones — implementation progress lives in
`config.yaml.implementation` and the `history` list.

## draft → accepted

The enhancement is ready to be implemented when:

- {Goals and Non-Goals in `02-design.md` are final and reviewed.}
- {Every decision recorded in `03-decisions.md` (D1..DN) is locked — no
  open trade-offs in the design.}
- {If `core_schema: true`: `schemas/` compiles (`cue vet ./...` passes),
  `examples.cue` carries concrete instances that actually exercise every
  new or changed definition, and `spec.md` drafts the core SPEC.md delta
  (four-part format) — `task vet` enforces file presence at `accepted`.
  If `core_schema: false`: no `schemas/` exists; any `contracts/` compiles.}
- {`related`, `supersedes`, `superseded_by` in `config.yaml` are final
  and resolve to existing enhancements.}
- {`semver` in `config.yaml` is set (major / minor / none).}
- {No `{Capitalised}` placeholder strings remain in any markdown file.}
- {Cross-References table in `README.md` lists every file path the
  implementation will touch.}

## accepted → implemented

The enhancement is shipped when:

- {Every CUE schema target named in `## Integration Points` is updated
  to match the delta in `schemas/target.cue`, and the core SPEC.md
  co-update follows `schemas/spec.md` (via the `core-schema-edit` skill).}
- {Every Go target named in `## Integration Points` carries the new
  behavior with test coverage on the new paths.}
- {Catalog / module artefacts repackaged where the enhancement requires
  it; publish task changes (if any) merged and rehearsed at least once.}
- {Fixture(s) under `library/modules/` migrated to the new shape; old
  fixtures deleted, not aliased.}
- {`config.yaml.implementation.status = complete` with `date` set to
  the landing date.}
- {`history` carries one or more events naming the landing milestone(s).}
- {`README.md` carries an `> **Implementation status (YYYY-MM-DD).**`
  quote block whose date matches `implementation.date`.}
- {`## Deviations from Design` in `README.md` lists every deliberate
  divergence from the design (or says "None").}
