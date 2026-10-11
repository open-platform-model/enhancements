# 0026: Module-Dictated Catalog Versions and the Generated Platform

A platform pins one exact version of each catalog, and every module renders against it, even if the author tested another. This entry splits the pin in two: the platform sets a range, and the module picks inside it.

## Why

One number admits a catalog and picks every instance's version. A module that needs a newer definition waits for a platform edit, and a bump re-renders every instance at once.

## What Changes

- A module renders against the catalog version it was tested with, when the platform admits it.
- The platform names the catalogs it admits, each with a floor, an optional ceiling and a prerelease opt-in.
- A pin outside the range is refused by name, never moved.
- A provider states a window for its own catalog. The platform may override it.
- Several majors of one catalog run side by side, one major per render.

## What this is not

- Not a change to matching, to the transformer set, or to who admits a catalog.
- Not provider routing, bridge transformers, or floating an instance forward without its owner.
- Not module-hosted transformer code.

## Example

```text
platform: catalogs/opm@v4  floor 4.0.0, no ceiling
module gotify   pins 4.1.0   before: renders at 4.3.0   after: renders at 4.1.0
module fileflows pins 4.6.0  before: refused             after: renders at 4.6.0
platform sets floor 4.2.0    gotify is refused by name; the others do not move
```

## Capabilities

- **New:** `catalog-version-selection`, `authored-platform`
- **Changed:** `registration-acceptance`, `transformer-registration`, `contract-fulfilment`, `single-build-render`, `platform-registry`, `platform-module-generation`, `platform-contract-inventory`

## Impact

- **Breaking, before GA:** a shipped core definition is renamed, and the Platform resource spec changes shape.
- **Five repos** change: core, library, cli, opm-operator and catalog_opm.
- **Platform teams** write ranges instead of exact pins. **Module authors** gain the version they tested.

## Open questions

- Blocking: Where does a render record the catalog versions it held, and does the exported instance carry them? Candidates: readable path and version pairs on the instance status, the render digest only, or both. The GitOps export of enhancement 0014 may reproduce them or not.
- Blocking: Does the platform hold a pin or a floor for `core`? Candidates: no platform field, so the module's core pin binds and a major mismatch is the only refusal; a required core floor beside the catalog floors; or an exact core pin. The kernel is compiled against one core major.
- Blocking: Which reference version does each path use for the module-less readiness build and the contract inventory? A static catalog uses its floor. A provider catalog could use the registration's version or the effective ceiling. The readiness answer is exact only at those versions.
- Not blocking: Which platform faults fail at acceptance and which at render, and does a bad platform fail whole or per entry? Version ordering lives in the kernel, not in CUE. The offline CLI has no cluster to write a condition to.
- Blocking: How many distinct resolutions does a real fleet produce, and what do generation, invalidation and the cache cost against one generation per platform change? A measurement over the workspace module fleet's committed pins would settle it.
- Not blocking: Is the registry override on an admission entry needed, and how does it compose with the trust policy of enhancement 0023? Identity is the path, so the entry only changes where a path resolves.
- Not blocking: Does the registration window need a prerelease flag? A provider that pins a prerelease of its own catalog already makes the default window a prerelease.
- Blocking: How does resolution know which major of its declaring catalog a provider serves, and does a provider build that imports two majors enter both resolutions? Recommendation: derive the major from the provider's own dependency list, as the registration's version is derived. No recommendation on the two-major build.
- Blocking: Is migration across a catalog major per module, or may one module move component by component? Recommendation: per module. A per-component answer would replace the refusal of a module that imports two majors.
- Blocking: How is the module-less readiness build split when several majors are admitted, what does Platform Ready mean when one slice is broken, and what does `opm platform check` report? Options: one build per admitted major of a multi-major catalog, or one per consistent combination across catalogs. No recommendation on the split.
- Blocking: Where is over-subscription reported at platform level once the one-provider count is taken per resolution? Candidates: the authored platform's inventory with each provider paired to its major, each slice of the module-less build, or each resolution at render only.
- Blocking: Does registration acceptance learn a provider's declaring major from the registered build's dependencies, or from a value declared on the registration? Recommendation: derive it, following the answer to the provider-major question.
- Not blocking: Must a provider's own major upgrade run side by side, or does it stay an atomic swap? Recommendation: keep the atomic swap. Running both would need provider routing.
- Not blocking: May a new catalog major ship a bridge transformer that consumes the previous major's contracts? Recommendation: no bridges in this entry. Retire a major only after draining it.
- Not blocking: How does a platform operator see that a major is drained before disabling it? Recommendation: answer the question about the record of held versions first. A drain count is then a query over it.
- Blocking: What happens when a render given no platform comes from a module that imports two majors of one catalog? Recommendation: the same refusal by name as on a platform. It follows the per-module answer.
