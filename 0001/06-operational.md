# Operational Concerns — `#Platform` Redesign Umbrella

## Observability

The umbrella introduces three new structured diagnostic kinds, emitted by the kernel and surfaced through `MatchPlan` and the materialize result:

- **`MaterializeError`** — emitted by `Kernel.Materialize`. Names the failing subscription path (the `#registry` map key per D13), the filter, the OCI registry consulted, and the underlying `cuelang.org/go/mod` error. Emitted on pull failure, on a same-SemVer-different-content unification failure at index build time, and on a top-level scan that finds zero `#ComponentTransformer` values in a selected build.
- **`MissingFQN`** — emitted by `Match` when the consumer Module declares a primitive FQN absent from materialized `#composedTransformers`. One error per `(release, component, FQN)` triple. Carries:
  - `release`: the release name (a single materialized platform serves multiple releases; the diagnostic names the failing one explicitly).
  - `component`: the component name.
  - `fqn`: the missing FQN as the consumer declared it.
  - `alternatives`: every key in `#composedTransformers` whose `modulePath/name` prefix matches the missing FQN (i.e. every other SemVer of the same primitive that IS on the platform). Computed as `strings.HasPrefix(composedKey, modulePath+"/"+name+"@")`.

  Example: a consumer pinning `container@1.5.0` against a platform carrying `1.0.4`, `1.1.0`, `1.4.0` produces `{release: "app-x", component: "api", fqn: ".../container@1.5.0", alternatives: [".../container@1.0.4", ".../container@1.1.0", ".../container@1.4.0"]}`. Shape sketched and validated end-to-end in experiment 05-multi-version-match.
- **`UnifyError`** — emitted by `Match` when the FQN lookup succeeds but `unify(consumer_primitive, transformer.requiredResources[FQN])` fails. One error per pair. Carries the FQN, both primitive values' relevant fields, and the CUE error path so authors can locate the divergence.

All three implement the existing diagnostic interface used by `MatchPlan`; no new top-level UX is required. The library logs a pull plan (subscription → selected versions) at `info` before `Materialize` executes so operators can correlate failures with intent.

Cross-catalog primitive references (D16 — transformer in catalog A referencing a resource owned by catalog B) route through these same diagnostic kinds: `MaterializeError` when catalog B is not subscribed at all (the transformer's CUE evaluation fails at materialize time with an unresolvable import); `MissingFQN` / `UnifyError` when B is subscribed but the referenced SemVer is outside the materialised set. No new diagnostic kind. The author-time CUE-import pin on catalog A and the platform-time `#SubscriptionFilter` on catalog B are independent surfaces; the operator is responsible for keeping them aligned (see the 05-risks.md author-time-vs-platform-time-drift note).

## Semver Impact

**Minor (within `@v0`).** Every consumer of `opmodel.dev/core@v0` is affected by the schema change, but per `core`'s pre-1.0 versioning rule breaking changes ride a minor bump within `@v0` — no `@v1` cut until `core` is signalled stable (D12). The shipping sequence:

1. `core/` lands the schema change and `SPEC.md` co-update (one PR per the core editing protocol). Published as a new `core` minor on `opmodel.dev/core@v0`.
2. `library/` rewires Go consumers in lockstep (`Kernel.Registry`, `Materialize`, `Match` signature, `library/opm/materialize/` package, `MatchPlan` diagnostic kinds, library fixture). The library import update from `opmodel.dev/core/v1alpha2@v1` to `opmodel.dev/core@v0` is a hard cutover — see `OQ24` for the sequencing relative to the in-flight core repo split's Part B.
3. `catalog/opm/` repackages and republishes as the first SemVer-FQN catalog (`opmodel.dev/catalogs/opm@1.0.0` or whatever the post-stamp tag becomes).
4. `modules/` publish task updated with the temp-build-dir stamping flow; rehearsed against a throwaway tag before any production publish.

No alpha aliases, no transitional `v1alpha2`-compatible shims. The umbrella is a clean cutover; the single existing platform fixture migrates in the same PR as the kernel rewire.

## Deprecation

Removed in this enhancement, not reintroduced under any alias:

- `#Module.#defines` (whole field).
- `#Platform.#knownResources`, `#Platform.#knownTraits` (whole fields).
- `#ModuleRegistration` (whole construct — replaced by `#Subscription`).
- `#MajorVersionType` usage in primitive `metadata.version` (the type itself survives; `#BundleFQNType` still references it).
- The MAJOR-only `#FQNType` regex.
- The library fixture's `opmodel.dev/core/v1alpha2@v1` import.
- Today's hand-derived per-component DNS / `resourceName` logic inside individual transformers (transformers read `#component.#names` or the renderer-supplied identity instead).

No deprecation window. The cutover ships as a single connected release.

## Rollback

Pre-cutover artefacts remain consumable: any consumer still on the previous `core@v0` minor (or `v1alpha2`) keeps working against the previous library tag and the previous catalog tags. Rollback for a deployment that has already cut over is:

1. Pin the library import back to the previous `opmodel.dev/core` tag.
2. Re-pin the platform fixture to the previous Module-valued shape (recover from git).
3. Pin every catalog dependency to the previous OCI tag (the new SemVer-FQN catalogs are additive — old tags are not deleted; the old `#defines`-shaped builds remain pullable).
4. Roll the cluster's `opm-controller` / CLI back to the version that consumed the previous library.

No data-plane state survives a code rollback in a way that would block restart — `Materialize` is in-process state and re-derives from the pulled OCI on next call. Existing rendered Kubernetes resources continue to apply / converge under the old controller.

Half-cutover states (e.g. library on new shape, catalog still on old) fail at materialize time with `MaterializeError` — explicit, structured, easy to revert from.

## Cross-Repo Coordination

Order is critical because each downstream consumes the upstream's published artefact:

1. **`core/`** — schema change + `SPEC.md` co-update + `INDEX.md` regeneration. Output: a new `core` minor tag on `opmodel.dev/core@v0` (D12 — no `@v1` cut).
2. **`library/`** — consumes the new `core` tag. Output: new library tag carrying `Kernel.Registry`, `Materialize`, the new `Match` signature, the new diagnostic kinds, and the migrated `opm_platform` fixture.
3. **`catalog/opm/`** — repackages source; publishes the first SemVer-FQN OCI tag via the new `modules/Taskfile.yml` publish task. Output: `opmodel.dev/catalogs/opm@1.0.0` (or first concrete SemVer).
4. **`modules/`** — publish-task change merged before step 3; rehearsed against a throwaway tag; then drives step 3.
5. **`opm-operator/`** and **`cli/`** — pick up the new library tag in their respective `go.mod`s; rerun their integration tests against the new core + library + catalog combination. No code change required inside `opm-operator/` or `cli/` if the library API is stable beyond the surface this enhancement touches.
6. **`releases/`** — per-environment `ModuleRelease` configs pin to the new module tags. Operator regenerations are scoped per environment.

Hand-offs: each step's output is an OCI tag (steps 1, 2, 3) or a merged PR with a green CI matrix (steps 4, 5, 6). No step skips a hand-off; broken intermediate states are caught by CI before the next step's pull.
