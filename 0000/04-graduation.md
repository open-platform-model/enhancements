# Graduation Criteria — {Enhancement Title}

This document records the gates that must hold before the enhancement
advances along the design lifecycle. The validator (future) checks the
gate items at each promotion. Treat these as design acceptance criteria,
not as implementation milestones — implementation progress lives in
`config.yaml.implementation` and the `history` list.

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

## accepted → implemented

The enhancement is shipped when:

- {Every contract named in `## Affected Surfaces` holds in the shipped
  code — the delivery of this design is complete (the plan side owns the
  slice-by-slice record; this entry never names it). Core-schema deltas
  land per `schemas/spec.md` via the `core-schema-edit` skill.}
- {Every `deferred-to-implementation` Open Question was claimed and
  resolved during delivery (`task plans:deferred` reports none left for
  this entry).}
- {Contract-level deviations discovered during delivery are recorded as
  amending `DN`s (never silent divergence); mechanical deviations stay in
  the implementing slices' own records.}
- {`config.yaml.implementation.status = complete` with `date` set to
  the landing date.}
- {`history` carries one or more events naming the landing milestone(s).}
- {`README.md` carries an `> **Implementation status (YYYY-MM-DD).**`
  quote block whose date matches `implementation.date`.}
- {`## Deviations from Design` in `README.md` lists every deliberate
  divergence from the design (or says "None").}
