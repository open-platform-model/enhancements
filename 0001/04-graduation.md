# Graduation Criteria — `#Platform` Redesign Umbrella

The umbrella spans CUE schema (core), Go kernel (library), catalog repackaging (catalog), and publish-flow tooling (modules). The two graduation transitions below cover the design-side and implementation-side gates respectively. Implementation milestones land in `config.yaml.history` as each piece ships.

## draft → accepted

The umbrella is ready to be sliced for implementation when:

- `01-problem.md` and `02-design.md` are final and reviewed — Goals, Non-Goals, and the three High-Level Approach sub-sections (registry/materialize, catalog/FQNs, runtime context) are locked.
- Every Open Question in `03-decisions.md` has resolved (each entry carries `resolved-by-D##`, `deferred-to-NNNN`, or `answered`). Every decision (D1..DN) is recorded with Decision / Alternatives considered / Rationale / Source.
- `schemas/target.cue` compiles (`cue vet` from `enhancements/0001/schemas/` passes) and captures the target shape end-to-end: `#Platform` / `#Subscription` / `#SubscriptionFilter`; `#Module` (without `#defines`); `#Component` (with `metadata.resourceName` override + `#names`); `#ModuleContext` / `#RuntimeContext` / `#ComponentNames`; `#ContextBuilder`; the SemVer `#FQNType`.
- `config.yaml` carries `semver: major` (already set), `area: core` (already set), `affects: [core, library, catalog, modules]` (already set), and `related` reflects whatever follow-up enhancements have been numbered (currently empty; expected to remain empty until 0002+ exist).
- No `{Capitalised}` placeholder strings remain anywhere in `enhancements/0001/` outside HTML comments.
- Cross-References table in `README.md` lists every file path the implementation will touch — verified by checking each path exists today.
- Risks (`05-risks.md`) and Operational Concerns (`06-operational.md`) have concrete content, not placeholders. Alternatives section in `05-risks.md` names the high-level paths not taken (e.g. MAJOR-only with predicate-version; kernel-injected `Catalog.Version`; Module-valued registry kept with per-platform version).
- The core editing protocol's `SPEC.md` plan is sketched — i.e. the list of SPEC sections that will be added/updated when implementation lands is captured in this file or in `02-design.md` `## Integration Points`.

## accepted → implemented

The umbrella is shipped when:

- **Core schema lands** in `opmodel.dev/core@v0` (or `@v1` if the cumulative change has already triggered a major bump): `#FQNType` regex updated; `#MajorVersionType` removed from primitive metadata; `metadata.version` on `#Resource` / `#Trait` / `#Blueprint` / `#ComponentTransformer` is `#VersionType`; `#Module.#defines` removed; `#Module.#ctx` added; `#Platform.#registry` reshaped to `#Subscription`; `#knownResources` / `#knownTraits` removed; `#composedTransformers` / `#matchers` downgraded to optional kernel-filled slots; `#Component.metadata.resourceName` and `#Component.#names` added; `#ModuleContext` / `#RuntimeContext` / `#ComponentNames` / `#ContextBuilder` published. `core/SPEC.md` co-updated per the core editing protocol; `core/INDEX.md` regenerated via `task generate:index`. `task check` from the core repo passes.
- **Library kernel rewired**: `Kernel.Registry` field added with default `"ghcr.io/open-platform-model"`; `library/opm/materialize/` package implemented with the OCI pull + top-level package scan + FQN indexing flow; `Match` signature changed to take `*MaterializedPlatform`; `library/opm/compile/match.go` rewritten with the lookup → unify → predicate algorithm and structured `MissingFQN` / `UnifyError` / `MaterializeError` diagnostics; legacy import `opmodel.dev/core/v1alpha2@v1` removed from every library consumer; library `task check` passes.
- **Catalog repackaged** at `catalog/opm/`: `Catalog: { Version, ModulePath }` constant introduced at the package root; every primitive sources `metadata.version` from `Catalog.Version` and `metadata.modulePath` from `Catalog.ModulePath`; no `#Module.#defines` wrapper anywhere; first SemVer-FQN OCI tag published end-to-end.
- **Publish task** in `modules/Taskfile.yml` extended with the temp-build-dir stamping flow: `rsync` source → `.build/catalog/`; overwrite `Catalog.Version` with the requested SemVer; `cue vet` from build dir; `cue mod publish` from build dir. Rehearsed against a non-production tag at least once.
- **Library fixture migrated**: `library/modules/opm_platform/platform.cue` uses `#Subscription`-shaped registry; imports `opmodel.dev/core@v0`; old fixture deleted, not aliased.
- **`config.yaml.implementation.status = complete`** with `date` set to the landing date of the final piece. `history` carries one event per landed piece (core land, library land, catalog land, fixture migration), each dated.
- `README.md` carries an `> **Implementation status (YYYY-MM-DD).**` quote block whose date matches `implementation.date`.
- `## Deviations from Design` in `README.md` lists every deliberate divergence from the design above (or says "None").
