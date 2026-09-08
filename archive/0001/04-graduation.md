# Graduation Criteria: `#Platform` Redesign Umbrella

The umbrella spans CUE schema (core), Go kernel (library), catalog repackaging (catalog), and publish-flow tooling (modules). The two graduation transitions below cover the design-side and implementation-side gates respectively. Implementation milestones land in `config.yaml.history` as each piece ships.

## draft → accepted

The umbrella is ready to be sliced for implementation when all seven hold:

- `01-problem.md` and `02-design.md` are final and reviewed. Goals, Non-Goals, and the three High-Level Approach sub-sections (registry/materialize, catalog/FQNs, `#ctx` channel) are locked.
- Every Open Question in `03-decisions.md` has resolved (each entry carries `resolved-by-D##`, `deferred-to-NNNN`, or `answered`). Every decision (D1..DN) is recorded with Decision / Alternatives considered / Rationale / Source.
- `schemas/target.cue` compiles (`cue vet` from `enhancements/0001/schemas/` passes) and captures the target shape end-to-end:
  - `#Platform` / `#Subscription` / `#SubscriptionFilter`.
  - `#Module` (without `#defines`; carries inline `#ctx { release, components, ... }`).
  - `#Component` (with `metadata.resourceName` override + `#names` + hidden `#release` slot).
  - `#ReleaseIdentity` / `#ComponentNames`.
  - The SemVer `#FQNType`.
  - `#ModuleContext` / `#RuntimeContext` / `#ContextBuilder` are NOT introduced (see D1).
- `config.yaml` fields are set correctly:
  - `semver: minor` (already set: `core` is pre-1.0, so even this umbrella's breaking changes ride a minor bump within `@v0`; D12).
  - `area: core` (already set).
  - `affects: [core, library, modules]` (already set: the OPM core catalog lives inside `library/modules/opm/` per D23, so `library` covers the catalog repackage; no separate `catalog` repo).
  - `depends_on` lists only the entries a decision of this entry rests on, each carried by a `**Depends:**` line.
- No `{Capitalised}` placeholder strings remain anywhere in `enhancements/0001/` outside HTML comments.
- Cross-References table in `README.md` lists every file path the implementation will touch, verified by checking each path exists today.
- Risks (`05-risks.md`) and Operational Concerns (`06-operational.md`) have concrete content, not placeholders. Alternatives section in `05-risks.md` names the high-level paths not taken (e.g. MAJOR-only with predicate-version; kernel-injected `Catalog.Version`; Module-valued registry kept with per-platform version).
- The core editing protocol's `SPEC.md` plan is sketched: the list of SPEC sections that will be added/updated when implementation lands is captured in this file or in `02-design.md` `## Integration Points`.
