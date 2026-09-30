# Graduation Criteria: Module-Dictated Catalog Versions and the Generated Platform

These are design acceptance criteria, not implementation milestones:
delivery is logged in this entry's `delivery.yaml` and read back with
`task delivery`. The entry's documents store nothing about delivery
progress.

Repo-wide checks (semver set, placeholders gone, CUE compiles, cross-refs
resolve) live in `gates.cue` and `task vet`, not here. What belongs here
is what is true of THIS design and no other.

## draft → accepted

Beyond the repo-wide gates, six criteria specific to this design must hold:

- OQ1, OQ2 and OQ3 are resolved into decisions: the record of held catalog versions has a named field, the platform's relation to `core`'s version is stated, and the reference versions for the module-less readiness build are named per path kind.
- OQ9, OQ10, OQ11, OQ12, OQ13 and OQ18 are resolved into decisions, so side-by-side majors (D9) can be delivered: the source of a provider's declaring major is named, per-module migration is confirmed or replaced, the split of the module-less build and the meaning of Ready across its slices are stated, the platform-level home of the over-subscription report is named, registration acceptance's source for the declaring major is fixed, and the platform-less path's answer for a module importing two majors follows OQ10.
- `schemas/examples.cue` exercises an authored platform with a static entry, a static entry with a ceiling, a provider entry, a disabled entry and an entry admitting prereleases, an authored platform admitting two majors of one catalog, plus a resolved platform for one render, and pins must-fail cases for a missing floor, a ceiling on a different major than the path, and a prerelease bound without opt-in.
- 0019 D13, 0019 D6, 0015 D2, 0015 D3, 0015 D8 and 0015 D11 each have their amendment stated in this entry's decision that depends on them, in one sentence a reader of the older entry can find.
- The refusal vocabulary is complete: not admitted, below floor, above ceiling, prerelease without opt-in, shared-path requirement exceeded, platform range excluding a registration's version, and a module importing two majors of one catalog each name the parties and the values involved.
- `config.yaml.semver` reflects that one shipped core definition is renamed with its shape kept, the vacated name is reused for a new shape, one definition is added, the meaning of `#CatalogEntry.version` widens, and the Platform CRD's spec changes.
