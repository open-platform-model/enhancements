# Graduation Criteria — OPM Module Publishing Workflow

This document records the gates that must hold before the enhancement advances along the design lifecycle. Treat these as design acceptance criteria, not implementation milestones — implementation progress lives in `config.yaml.implementation` and the `history` list.

## draft → accepted

The enhancement is ready to be sliced when:

- Design Goals and Non-Goals in `02-design.md` are reviewed and stable.
- Open Questions OQ1–OQ7 are resolved (each `resolved-by-D##`, `answered`, or `deferred-to-NNNN`). OQ2 and OQ5 are closed (D5, D6). Still outstanding and load-bearing: OQ1 (enforce vs generate) and OQ6 (the `--version` override shape), which together fix the publish command's contract; OQ3 (derive vs record), which fixes the library contract; and OQ7 (whether `#Catalog` is covered here or by 0001).
- Every decision (D1..DN) carries the four-field shape.
- `schemas/target.cue` compiles (`cue vet ./...` from `schemas/`), `#CanonicalModuleRef` captures the full mapping with no remaining `// OQ` markers on load-bearing fields, and `#PublishedModuleRef` demonstrably rejects a metadata/tag mismatch (a mismatched `_example` produces a unification conflict naming both values).
- An inventory of already-published modules whose `metadata.version` disagrees with their tag is recorded, since D6's acquire-time check will start refusing them — this is the migration work-list for the version dimension, alongside OQ4's for the path dimension.
- `config.yaml.semver` is set (expected `none` for the enhancement-level entry — `nameSnakeCase` is an additive `core` field already shipped; the publish workflow is new cli surface, not a break — confirm at promotion).
- `config.yaml.affects` (`core`, `library`, `cli`) is final and `area` (`cli`) appears in it.
- No `{Capitalised}` placeholder strings remain in any markdown file.
- The Cross-References table in `README.md` lists every file path the implementation will touch, each verified to exist today.
- An inventory of non-conforming in-repo modules (OQ4) is recorded so the migration slice has a concrete work-list.

## accepted → implemented

The enhancement is shipped when:

- `library/opm/helper/synth/render.go` derives the import/dependency from the canonical `modulePath/nameSnakeCase@major` reference, emitting the bare import per D5, covered by tests that exercise a hyphenated-name module (the case the `modulePath/name` guess got wrong).
- The registry acquisition path in `library` refuses a module whose `metadata` disagrees with the coordinates it was fetched by (D3/D6), with a typed error naming both. Proven against a **real registry**, not a fake: publish a module whose `metadata.version` disagrees with its tag and assert the fetch is refused. A hermetic fake cannot establish this, for the same reason the fake dynamic client could not catch enhancement 0006's server-side-apply defect — the behaviour under test belongs to the real system.
- Both the CLI and the operator inherit that refusal without their own implementations of it, demonstrated by exercising each against the same bad artifact.
- The `opm module publish` command in `cli` derives `cue.mod/module.cue`, the package clause, and the release tag from `#CanonicalModuleRef`, with tests for the conformant and non-conformant cases, and the `--version` override behaving per OQ6.
- `cli/pkg/module/module.go`'s `CanonicalModuleRef()` (shipped early via enhancement 0006 C1) is reconciled with the library helper so the D1 mapping has exactly one implementation.
- `modules/Taskfile.yml` no longer sources the release tag from `versions.yml`.
- If OQ3 lands on "record," `library/opm/module/module.go` carries the fetched registry reference and the registry loader populates it.
- Non-conforming in-repo modules from the OQ4 inventory are republished at their canonical paths; stale fixtures deleted, not aliased.
- `config.yaml.implementation.status = complete` with `date` set to the final landing date.
- `history` carries events naming each landing milestone (core already recorded; library + cli slices added).
- `README.md` carries an `> **Implementation status (YYYY-MM-DD).**` quote block whose date matches `implementation.date`.
- `## Deviations from Design` in `README.md` lists every deliberate divergence (or says "None").
