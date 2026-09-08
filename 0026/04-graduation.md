# Graduation Criteria: Module-Dictated Catalog Versions and the Generated Platform

These are design acceptance criteria, not implementation milestones:
delivery is logged in this entry's `delivery.yaml` and read back with
`task delivery`. The entry's documents store nothing about delivery
progress.

Repo-wide checks (semver set, placeholders gone, CUE compiles, cross-refs
resolve) live in `gates.cue` and `task vet`, not here. What belongs here
is what is true of THIS design and no other.

## draft → accepted

Beyond the repo-wide gates, five criteria specific to this design must hold:

- OQ1, OQ2 and OQ3 are resolved into decisions: the record of held catalog versions has a named field, the platform's relation to `core`'s version is stated, and the reference versions for the module-less readiness build are named per path kind.
- `schemas/examples.cue` exercises a spec with a static entry, a static entry with a ceiling, and a provider entry, and pins at least one must-fail case for a missing floor and one for a ceiling on a different major than the path.
- 0019 D13, 0019 D6, 0015 D3, 0015 D8 and 0015 D11 each have their amendment stated in this entry's decision that depends on them, in one sentence a reader of the older entry can find.
- The refusal vocabulary is complete: not admitted, below floor, above ceiling, shared-path requirement exceeded, and spec range excluding a registration's version each name the parties and the values involved.
- `config.yaml.semver` reflects that no existing core definition changes shape while the meaning of `#CatalogEntry.version` widens and the Platform CRD's spec changes.
