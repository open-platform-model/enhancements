# Graduation Criteria: Contract Promotion and Retirement

These are the entry-specific gates that must hold before this design is frozen. They are design acceptance criteria, not implementation milestones: delivery is derived from this entry's `delivery.yaml` log and read back with `task delivery`, and the entry's documents store nothing about it.

## draft → accepted

**Design finalized.**

- Goals and Non-Goals in `02-design.md` are final and reviewed, in particular the Non-Goal that preserves enhancement 0010 D34's rejection of consumer-facing deprecation windows. If review concludes this entry does reopen D34 rather than sitting beside it, that has to be settled before anything else here is worth agreeing.

**Open Questions resolved.**

- **The seasoning floor has a unit and a value.** OQ1 and OQ2 are contract-level and cannot be deferred: D10 states that a floor exists, and a floor with no unit is not a rule anyone can implement or comply with.
- **The raw-family question is answered.** OQ4 is contract-level. Enhancement 0010 D48 fixes raw-family `apiVersion`s to upstream Kubernetes, so either the family is exempt from D1/D2 or the ladder does not apply to it at all. Leaving this open would ship a promotion rule that a third of the catalog cannot obey.
- **The provenance-filter question is answered.** OQ6's concrete half, whether `promotedFrom` must join the denylist that enhancement 0010 D30's operand filter applies before unification, is settled here rather than discovered during delivery. A new metadata field that reaches the match comparison changes matching behaviour.
- Every other contract-level Open Question is resolved (`resolved-by-D##`, `deferred-to-NNNN`, or `answered`); every implementation-level question left open is explicitly `deferred-to-implementation` with the context a future implementer needs.

**Decision integrity.**

- Every decision carries a valid `**Kind:**` and passes the admission test. In particular: no decision in this log states *how* `library/opm/compat` performs a comparison or a scan. That is mechanism and belongs to the implementing slice.

**Mechanical checks.**

- `schemas/` compiles (`cue vet ./...` passes), `examples.cue` carries concrete instances exercising every NEW and CHANGED definition (at least one legal promotion, one refused promotion, and one tombstone with and without `replacedBy`), and `spec.md` drafts the core SPEC.md delta in the four-part format.
- `depends_on`, `supersedes`, `superseded_by` in `config.yaml` are final and resolve; every `depends_on` id is carried by a `**Depends:**` line in a live decision.
- `semver` is set.
- No `{Capitalised}` placeholder strings remain in any markdown file.
