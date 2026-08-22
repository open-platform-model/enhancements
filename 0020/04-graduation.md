# Graduation Criteria — Contract Promotion and Retirement

This document records the gates that must hold before the enhancement advances along the design lifecycle. Treat these as design acceptance criteria, not as implementation milestones; implementation progress lives in `config.yaml.implementation` and the `history` list.

## draft → accepted

- Goals and Non-Goals in `02-design.md` are final and reviewed, in particular the Non-Goal that preserves enhancement 0010 D34's rejection of consumer-facing deprecation windows. If review concludes this entry does reopen D34 rather than sitting beside it, that has to be settled before anything else here is worth agreeing.
- **The seasoning floor has a unit and a value.** OQ1 and OQ2 are contract-level and cannot be deferred: D10 states that a floor exists, and a floor with no unit is not a rule anyone can implement or comply with.
- **The raw-family question is answered.** OQ4 is contract-level. Enhancement 0010 D48 fixes raw-family `apiVersion`s to upstream Kubernetes, so either the family is exempt from D1/D2 or the ladder does not apply to it at all. Leaving this open would ship a promotion rule that a third of the catalog cannot obey.
- **The provenance-filter question is answered.** OQ6's concrete half, whether `promotedFrom` must join the denylist that enhancement 0010 D30's operand filter applies before unification, is settled here rather than discovered during delivery. A new metadata field that reaches the match comparison changes matching behaviour.
- Every other contract-level Open Question is resolved (`resolved-by-D##`, `deferred-to-NNNN`, or `answered`); every implementation-level question left open is explicitly `deferred-to-implementation` with the context a future implementer needs.
- Every decision carries a valid `**Kind:**` and passes the admission test. In particular: no decision in this log states *how* `library/opm/compat` performs a comparison or a scan. That is mechanism and belongs to the implementing slice.
- `schemas/` compiles (`cue vet ./...` passes), `examples.cue` carries concrete instances exercising every NEW and CHANGED definition (at least one legal promotion, one refused promotion, and one tombstone with and without `replacedBy`), and `spec.md` drafts the core SPEC.md delta in the four-part format.
- `related`, `supersedes`, `superseded_by` are final and resolve.
- `semver` is set.
- No `{Capitalised}` placeholder strings remain in any markdown file.

## accepted → implemented

- **The cross-level promotion comparison is measured before it is called done.** Enhancement 0011 D9 shipped with no named implementation because `cue.Value.Subsume`'s cross-build behaviour was unmeasured, and that entry's `04-graduation.md` made sequencing the measurement a gate; `experiments/03-d27-compat-gate` then ruled Subsume out in both directions (10/14 and 8/14 on disjoint failure sets) and established the three-rule field-wise walk at 14/14. This entry inherits that comparator but hands it a predecessor at a **different level**, which is the part that has never been run. The measurement lives in `experiments/01-cross-level-promotion/` and must be concluded, with an outcome recorded, before this entry can flip. If it returns a negative, D2 goes back for redesign rather than shipping on assumption.
- **The seasoning floor is measured against a real history**, not only against fixtures: the query "when did this key first appear" must be shown to work over `catalog_opm`'s actual published builds, including its prerelease-only stretch, because 0011 D23 records that a selector which looks right on a prerelease-only history can be wrong the day a stable ships.
- Every contract named in `## Affected Surfaces` holds in the shipped code. Core-schema deltas land per `schemas/spec.md` via the `core-schema-edit` skill.
- **The lifecycle report, if it ships, has enhancement 0015 D1 behind it.** This is a gate on the report, not on the entry: measured 2026-08-22, the publish gates enumerate members by filesystem walk over 0010 D49's filing and read a published build the same way, so D2, D3, D6 and D7 do not wait on 0015. A value-level inventory does, and shipping a report that silently omits the members a filesystem walk would have found would be worse than shipping no report.
- Every `deferred-to-implementation` Open Question was claimed and resolved during delivery.
- Contract-level deviations discovered during delivery are recorded as amending `DN`s.
- `config.yaml.implementation.status = complete` with `date` set to the landing date.
- `history` carries one or more events naming the landing milestone(s), in plan-blind wording.
- `README.md` carries an `> **Implementation status (YYYY-MM-DD).**` quote block whose date matches `implementation.date`.
- `## Deviations from Design` in `README.md` lists every deliberate divergence (or says "None").
