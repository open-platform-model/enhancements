# Graduation Criteria: {Enhancement Title}

These are design acceptance criteria, not implementation milestones:
delivery is logged in this entry's `delivery.yaml` and read back with
`task delivery`. The entry's documents store nothing about delivery
progress.

Repo-wide checks (semver set, placeholders gone, CUE compiles, cross-refs
resolve) live in `gates.cue` and `task vet`, not here. What belongs here
is what is true of THIS design and no other.

## draft → accepted

Seven gates must all hold before promoting this design from draft to
accepted:

- {Goals and Non-Goals in `02-design.md` are final and reviewed.}
- {Every **contract-level** Open Question is resolved
  (`resolved-by-D##`, `deferred-to-NNNN`, or `answered`); every
  implementation-level question left open is explicitly
  `deferred-to-implementation` with the context a future implementer
  needs. No question is merely unanswered.}
- {Every decision in `03-decisions.md` carries a valid `**Kind:**`
  (contract | policy | scope) and passes the admission test: mechanism
  decisions have been moved out or left to the implementing slices.}
- {No document in the entry prescribes mechanism: no filename, identifier
  spelling, directory layout, or code structure is stated as instruction.
  Paths cited as evidence are fine; paths cited as the address of an edit
  are not.}
- {If `core_schema: true`: `schemas/` compiles (`cue vet ./...` passes),
  `examples.cue` carries concrete instances that actually exercise every
  new or changed definition, and `spec.md` drafts the core SPEC.md delta
  (four-part format), `task vet` enforces file presence at `accepted`.
  If `core_schema: false`: no `schemas/` exists; any `contracts/` compiles.}
- {`related`, `supersedes`, `superseded_by` in `config.yaml` are final
  and resolve to existing enhancements.}
- {`semver` in `config.yaml` is set (major / minor / none).}
- {No `{Capitalised}` placeholder strings remain in any markdown file.}
