# Graduation Criteria — OPM Module Publishing Workflow

This document records the gates that must hold before the enhancement advances along the design lifecycle. Treat these as design acceptance criteria, not implementation milestones — implementation progress lives in `config.yaml.implementation` and the `history` list.

## draft → accepted

The enhancement is ready to be sliced when:

- Design Goals and Non-Goals in `02-design.md` are reviewed and stable.
- Open Questions OQ1–OQ5 are resolved (each `resolved-by-D##`, `answered`, or `deferred-to-NNNN`) — in particular OQ1 (enforce vs generate) and OQ3 (derive vs record) are settled, since they fix the cli and library contracts.
- Every decision (D1..DN) carries the four-field shape.
- `schemas/target.cue` compiles (`cue vet ./...` from `schemas/`) and `#CanonicalModuleRef` captures the full mapping with no remaining `// OQ` markers on load-bearing fields.
- `config.yaml.semver` is set (expected `none` for the enhancement-level entry — `nameSnakeCase` is an additive `core` field already shipped; the publish workflow is new cli surface, not a break — confirm at promotion).
- `config.yaml.affects` (`core`, `library`, `cli`) is final and `area` (`cli`) appears in it.
- No `{Capitalised}` placeholder strings remain in any markdown file.
- The Cross-References table in `README.md` lists every file path the implementation will touch, each verified to exist today.
- An inventory of non-conforming in-repo modules (OQ4) is recorded so the migration slice has a concrete work-list.

## accepted → implemented

The enhancement is shipped when:

- `library/opm/helper/synth/render.go` derives the import/dependency from the canonical `modulePath/nameSnakeCase@major` reference, with the package-name qualification resolved per OQ2, covered by tests that exercise a hyphenated-name module (the case the `modulePath/name` guess got wrong).
- The `opm publish` command in `cli` validates (and/or generates) `cue.mod/module.cue` and the package clause against `#CanonicalModuleRef`, with tests for the conformant and non-conformant cases.
- If OQ3 lands on "record," `library/opm/module/module.go` carries the fetched registry reference and the registry loader populates it.
- Non-conforming in-repo modules from the OQ4 inventory are republished at their canonical paths; stale fixtures deleted, not aliased.
- `config.yaml.implementation.status = complete` with `date` set to the final landing date.
- `history` carries events naming each landing milestone (core already recorded; library + cli slices added).
- `README.md` carries an `> **Implementation status (YYYY-MM-DD).**` quote block whose date matches `implementation.date`.
- `## Deviations from Design` in `README.md` lists every deliberate divergence (or says "None").
