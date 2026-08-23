# Graduation Criteria — {Enhancement Title}

This document records the entry-specific gates that must hold before this
design is frozen. Treat them as design acceptance criteria, not as
implementation milestones: delivery is tracked on the plans side and read
back with `task delivery` — this entry stores nothing about it.

Repo-wide checks (semver set, placeholders gone, CUE compiles, cross-refs
resolve) are not repeated here — they live in `gates.cue` and `task vet`.
What belongs here is what is true of THIS design and no other.

## draft → accepted

The enhancement is ready to be implemented when:

- {Goals and Non-Goals in `02-design.md` are final and reviewed.}
- {Every **contract-level** Open Question is resolved
  (`resolved-by-D##`, `deferred-to-NNNN`, or `answered`); every
  implementation-level question left open is explicitly
  `deferred-to-implementation` with the context a future implementer
  needs. No question is merely unanswered.}
- {Every decision in `03-decisions.md` carries a valid `**Kind:**`
  (contract | policy | scope) and passes the admission test — mechanism
  decisions have been moved out or left to the implementing slices.}
- {No document in the entry prescribes mechanism: no filename, identifier
  spelling, directory layout, or code structure is stated as instruction.
  Paths cited as evidence are fine; paths cited as the address of an edit
  are not.}
- {If `core_schema: true`: `schemas/` compiles (`cue vet ./...` passes),
  `examples.cue` carries concrete instances that actually exercise every
  new or changed definition, and `spec.md` drafts the core SPEC.md delta
  (four-part format) — `task vet` enforces file presence at `accepted`.
  If `core_schema: false`: no `schemas/` exists; any `contracts/` compiles.}
- {`related`, `supersedes`, `superseded_by` in `config.yaml` are final
  and resolve to existing enhancements.}
- {`semver` in `config.yaml` is set (major / minor / none).}
- {No `{Capitalised}` placeholder strings remain in any markdown file.}
