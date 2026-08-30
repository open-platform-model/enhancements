# Graduation Criteria: Documentation Architecture

What must be true before this entry moves between statuses. Each gate is stated so that it can be checked rather than judged.

## draft → accepted

**Open Questions and scope.**

- Every Open Question (OQ1 through OQ6) is resolved by a decision, deferred to a named enhancement, or answered in place.
- The retirement path for `opm/docs` is decided (OQ4), including whether the area vocabulary changes.

**Taxonomy and schema.**

- The eight-section taxonomy is ratified, including the two placements that are deliberate: Diagnostics as a top-level entry point, and Concepts sized in proportion to the concept surface rather than treated as an appendix.
- The enforcement badge vocabulary is closed and compiles in `contracts/contracts.cue`, and each of the four values has at least one worked example drawn from a real constraint.
- The generated-versus-authored field classification covers every field a reference entry will carry, so that no field's provenance is decided during implementation.

**Coordination and mechanics.**

- The cross-repo ordering constraints are stated in `06-operational.md ## Cross-Repo Coordination`, with an explicit dependency order and no landing whose concern spans two repos; landings are logged per change in `delivery.yaml`.
- `task vet:one ID=0018` passes and `task check ID=0018` passes or its warnings are documented in the PR body.
