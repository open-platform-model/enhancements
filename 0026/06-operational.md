# Operational Concerns: Module-Dictated Catalog Versions and the Generated Platform

This document is the OPM Production Readiness Review (PRR-lite). Five fixed prompts; every one answered.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

Six refusals, each naming the parties and values involved: catalog not admitted (module, path); pin below floor and pin above ceiling (module, path, pin, bound, and whether the bound is the platform's or the provider's); prerelease pin without opt-in (module, path, pin); shared-path requirement exceeded (provider catalog, consumer module, path, both versions); platform range excluding a registration's version (registration, path, range, version). The first four surface in the render's diagnostics and, for the operator, on the instance's conditions; the last two at registration acceptance on the registration's conditions.

Every render records the catalog versions it held (D1); the field is OQ1's. The registration's status carries the effective window and its source, platform or provider (D6), and a warning condition when the spec exceeds the provider's declared window. The platform readiness answer states the reference versions it evaluated at (OQ3).

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

`opmodel.dev/core` renames one shipped definition with its shape kept (`#Platform` becomes `#ResolvedPlatform`), reuses the vacated name for the authored pure-data platform, and adds `#CatalogAdmission`. The rename breaks any consumer reading the shipped `#Platform`; the kernel is the only one, and `opmodel.dev/core@v2` is pre-GA (alpha), so it lands without a major. At GA the same move would be a major, which is why it lands now. `#CatalogEntry.version` keeps its derivation and widens in meaning from "the platform's pin" to "the version this build holds"; a consumer reading it as the platform's pin is wrong once module pins bind. The meaning shift is called out in SPEC.md.

The Platform CRD's spec changes shape: a map of catalogs with floor, optional ceiling and optional registry replaces an exact version per path. That is a breaking change to the CR consumers author and needs a CRD version or a conversion, decided by the operator's implementing change under enhancement 0008's route. The `transformer-registration` contract gains two fields with defaults: additive for catalog_opm and for every existing provider, whose window defaults to its exact version. `config.yaml.semver` is set at promotion once OQ2 and OQ3 settle whether anything else moves.

## Deprecation

**What gets removed and when? What replaces it?**

The hand-authored platform module for offline CLI renders is replaced by an authored `#Platform` file with the same fields as the Platform CR's spec. The names `#PlatformSpec` and `#Subscription` from this entry's first draft never ship. The exact-version-per-path form of the Platform CR is replaced by the range form. 0019 D13's rule that the platform wins on catalog paths is replaced by D1; 0019 D6's once-per-CR platform generation is replaced by per-resolution generation. Nothing in core is removed; the shipped `#Platform` continues under the name `#ResolvedPlatform`.

## Rollback

**If this lands and proves bad, what's the rollback story?**

Core is additive; a previous library builds against the same core major. Published catalogs and modules are untouched: no artifact changes, and every module's `cue.mod` pin was already committed before this entry. Reverting the kernel restores platform-wins promotion and the authored platform module, and every instance renders again at the platform's pin, which is a fleet-wide change of held versions and must be treated as one. The Platform CR's range form does not read back as the exact form; a rollback of the operator needs the CR restored to its previous shape, which is why the CRD version question belongs to the implementing change.

## Cross-Repo Coordination

**Which repos must coordinate, and what constrains the order?**

- `core` publishes the authored `#Platform`, `#CatalogAdmission` and `#ResolvedPlatform` before any consumer can author a platform or generate a resolved one; the library's rename of its `#Platform` reader lands in the same step.
- The `transformer-registration` contract in catalog_opm carries `floor` and `ceiling` before a provider module can author a window; a provider on the previous contract still registers, with an exact window by default.
- The library's render-list derivation, the resolved-platform generation and the refusal vocabulary exist before either frontend can consume an authored platform; the CLI's offline path and the operator's CR path are independent consumers of the same kernel behaviour.
- The operator's acceptance-side reading of an admission entry (D6, D7) needs the range-form CR, so the CRD shape lands with or before it.
- Enhancement 0027 consumes this entry's range vocabulary; nothing here depends on 0027.
