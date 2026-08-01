# Graduation Criteria — Module and Catalog Publishing

This document records the gates that must hold before the enhancement advances along the design lifecycle. Treat these as design acceptance criteria, not implementation milestones — implementation progress lives in `config.yaml.implementation` and the `history` list.

## draft → accepted

The design is ready to be sliced when:

- Every Open Question is resolved. Check with `task questions:open ID=0011`; walk any remaining rows with the `enhancement-open-questions` skill. **OQ2 (credentials) and OQ3 (tag immutability) are blocking** — the first because publish cannot be built without knowing how it authenticates, the second because the whole design assumes a tag names fixed bytes.
- Every decision (D1..DN) carries the four-field shape with a specific `Source:`.
- `schemas/target.cue` compiles (`cue vet ./...` from `schemas/`), and every commented MUST-FAIL case has been confirmed to fail with the error recorded beside it.
- Enhancement 0010 is `accepted`, because this entry writes the fields that entry defines and cannot be finalised while their shape is still moving. **Satisfied 2026-08-01** — 0010 flipped to `accepted` with an empty Open Question queue.
- **D9's compatibility gate is measured before the command is specified**, because a gate that cannot be built as described sends 0010 D27 back to publisher discipline. **Satisfied 2026-08-01** — [`experiments/03-d27-compat-gate`](experiments/03-d27-compat-gate/) rules out `cue.Value.Subsume` in both directions and demonstrates a field-wise walk at 14/14, level-aware per 0010 D34. The gate is buildable, so D27 stands. This bullet is recorded late: D9 called the measurement a graduation gate from the day it was written, and `04-graduation.md` never carried it.
- The joint migration window with 0010 is written down and owned. Both entries change identity values across the whole published fleet; landing them separately moves every artifact's identity twice.
- The command surface is fixed: exact names, exact flags, and what each refuses. Two specifics sit under this bullet. Whether `opm module version set` exists at all — it does not, because enhancement 0010 D2 leaves a module with no version field to write, so what OQ4 must settle is what replaces `publish:smart` for modules rather than which command writes it. And whether `--version` stays one flag with two meanings (OQ8), since its catalog form writes and asserts while its module form only names a tag.
- The refusal messages are drafted, not deferred. Every gate in this design is a refusal, so the message *is* the feature — each one names the offending value, the file that declares it, and the action that clears it.
- Cross-References in `README.md` names every file path the implementation will touch, and each one exists today.

## accepted → implemented

The design is shipped when:

- `opm module publish` and `opm catalog publish` exist as one implementation with two entry points, with test coverage on every refusal path, not only the happy path.
- `opm catalog version set` writes `identity/identity.cue` idempotently, preserving formatting, comments, and any type assertion on the field — with real catalog repos as fixtures rather than synthetic ones.
- `opm catalog registry check` verifies a published catalog against the registry, and the same verification runs when a catalog is added to a `#Platform` registry.
- The identity-completeness gate is exercised against a tree with an unfilled field and refuses, with a message naming the field and its file.
- The local-override gate is exercised in all four states: module clean, module blocked, module allowed by flag, catalog blocked with the flag passed and ignored.
- Every catalog repo's copy-and-stamp publish task is **deleted**, not disabled, and its release workflow calls the new command.
- `modules/Taskfile.yml`'s checksum-driven publish and `modules/versions.yml` are deleted, and whatever OQ4 chose is in place and has published at least one real module.
- The owner-scoped namespace migration has run, and the artifacts sharing the namespace without being modules — the `library/testdata` fixture and the legacy `v1alpha1` paths — have been dealt with explicitly rather than left behind.
- A publish has been rehearsed end to end against a non-production registry, including the failure cases, before the first real one.
- `config.yaml.implementation.status = complete` with `date`; `history` names the landing milestones; `README.md` carries the implementation-status quote block and a filled `## Deviations from Design`.
