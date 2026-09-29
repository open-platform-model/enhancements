# Problem Statement: Module-Dictated Catalog Versions and the Generated Platform

A module is written and tested against one catalog release, and it renders against a different one: whichever release the platform pinned. The platform's pin is both the floor and the ceiling for every module on the cluster, so a module that needs a newer definition waits for a platform edit, and a platform bump moves every instance at once. This entry is about who holds a catalog's version in a render, and how the platform bounds it without holding it.

## Current State

**The platform's pin wins on every shared path.** Under enhancement 0019 the kernel derives the render module's dependency list by promotion: the platform module's tidied list is promoted whole, the instance module's list is unioned in only for paths the platform does not carry, and on a shared path the platform's entry wins (0019 D13). A catalog path is always shared, because the platform imports the catalog to embed it (0019 D5), so the module's own `cue.mod` pin on that catalog is inert. The disagreement is reported as skew (0019 D7, D18) and nothing else happens with it.

**The platform is an authored CUE module with an import per catalog.** `#Platform` is a path-keyed registry of `#CatalogEntry` values, each carrying the imported catalog whole, with `version` derived from the embedded catalog's stamped identity and `#transformers` derived from its transformer map. The exact catalog version lives in the platform module's `cue.mod`, tidied once at platform-package generation (0019 D6), and is deliberately not a field anyone authors in the platform value. Two authored forms exist: a platform module the CLI takes as an explicit directory, and a Platform CR from which the operator generates the platform module. The CLI's explicit form is a module directory only; it refuses a data-only platform file.

**A render with no platform holds its own pins.** When the CLI is given no platform directory and uses no cluster Platform, it generates a platform module from the render's own committed dependency list: the module's `cue.mod` for a module render, the instance package's for an instance render. The generated platform carries one enabled registry entry per `opmodel.dev/catalogs/*` dependency at the version pinned there, closes over those catalogs' own requirements, and floors `core` at the release the kernel was verified against.

The kernel's promotion is unchanged on that path, so the platform still wins every shared path, but its pins are the render's own and the skew policy is not applied: every pinned path is at least what the render requires. There is no admission step, no range and no registration on this path, and no local default platform: the CLI never reads one from its home directory. Verified against cli 1.0.0-alpha.24, `openspec/specs/platform-resolution/spec.md`.

**A provider catalog enters the effective registry with one exact version.** Enhancement 0015 D11 derives a registration's `version` from the provider module's own dependency on its catalog and verifies it at acceptance. 0015 D8 compares the provider catalog's committed requirements on shared paths against the platform's resolved versions once, at acceptance, and that comparison is sufficient because there is exactly one platform version to compare against.

**Versions carry compatibility promises.** Within a major, catalog contracts evolve additively (0010 D27), and enhancement 0021 binds a module's version to its `#config` schema by the same subsumption rule. A newer release inside a major accepts everything the older one accepted. That promise is what 0015 D8 and 0019 D13 both lean on, and it holds in one direction only: newer is safe for old consumers, never the reverse.

## Gap / Pain

All three gaps are about renders against a platform, which is every operator render and every CLI render given a platform directory or a cluster Platform. A render with no platform holds its own pins already, and has no admission to relax.

**Gap 1: a module cannot use a catalog definition the platform has not pinned yet.** A module tidied against catalog release 4.6.0 that uses a trait added in 4.5.0 renders on a platform pinned at 4.3.0 with an unknown-key failure. The module author did nothing wrong, the platform team did nothing wrong, and the fix is a platform edit that touches every other instance on the cluster. Catalog evolution is throttled to the slowest platform.

**Gap 2: a platform bump is a fleet-wide, silent re-render.** Because every instance renders at the platform's pin, raising it re-renders all of them in the same reconcile window. No instance changed, no generation bumped, no owner chose the moment. 0019 D13 and 0015 D13 accept this blast radius explicitly on the argument that platform changes are rare and platform-team-driven. Catalog releases are neither, and the concrete example in enhancement 0021 shows what one of them can do: a patch release renaming a volume component orphans a claim on every instance it reaches.

**Gap 3: the version a module was tested against is not the version that runs.** A module's `cue.mod` records exactly what its author validated. A render against a platform discards it. Under the additive discipline the discarded pin is usually harmless, but the render is then correct by policy rather than by construction, and the skew diagnostic that reports the gap has nothing to offer but the observation.

## Concrete Example

Three modules on one cluster, one platform pin.

```
platform cue.mod           catalogs/opm@v4  v4.3.0           <- one number for the fleet

module gotify   cue.mod    catalogs/opm@v4  v4.1.0    tested at 4.1.0, renders at 4.3.0
module jellyfin cue.mod    catalogs/opm@v4  v4.3.0    tested at 4.3.0, renders at 4.3.0
module fileflows cue.mod   catalogs/opm@v4  v4.6.0    uses a trait added in 4.5.0

                                  render at 4.3.0
gotify     ─────────────────────▶  fine, silently on newer bytes than tested
jellyfin   ─────────────────────▶  fine
fileflows  ─────────────────────▶  refused: unknown key, the trait does not exist at 4.3.0

platform team bumps to v4.6.0 so fileflows can render
                                  render at 4.6.0
gotify     ─────────────────────▶  re-rendered, owner did not ask
jellyfin   ─────────────────────▶  re-rendered, owner did not ask
fileflows  ─────────────────────▶  renders
```

The single number does two jobs at once, admitting a lineage and picking every instance's version, and the two jobs pull in opposite directions the moment two modules want different releases.

The provider case has the same shape with nobody holding the pin. A module declares the `backup` trait from `catalogs/opm`. The transformer lives in `catalogs/k8up`, which the module never imports. Once module pins are free, a second module that does import `catalogs/k8up` directly at 1.9.0 has nothing to be checked against, and the k8up operator installed on the cluster accepts CRs from some catalog releases and not from others. That window exists in the world and has no field.

## User Stories

- As an **application module author**, I want my module to render against the catalog release I tested it with, so that the render is what I validated rather than what happens to be pinned. Today: the platform's pin replaces mine, and a newer definition I need is unavailable until the platform team edits their file.
- As a **platform team operator**, I want to state which catalog lineages and which range of releases my cluster admits, and change that range without moving every instance, so that admission and version selection are separate acts. Today: one exact pin is both, and raising it is a fleet-wide re-render.
- As a **provider module author**, I want to state which releases of my catalog emit resources the operator I deploy accepts, so that a consumer pinning outside that window is refused by name. Today: the registration carries one exact version and there is no window.

## Why Existing Workarounds Fail

**Pin the platform at the newest catalog release, always.** Every module renders on bytes newer than it was tested against, every catalog release is a fleet re-render, and the platform team has surrendered the one control the pin gave them.

**Fork the platform per module cohort.** `#Platform` is a cluster singleton by design, and the CR carries a CEL rule to keep it one. Two platforms would mean two effective registries and two answers to every readiness question.

**Ship the transformer inside the module.** Rejected by 0015 D10 and by 0019 D13's authority rule: the platform decides what code executes. It also gives up the fleet-wide fix lever entirely, the Helm chart-library failure where a fix reaches an instance only when its author re-releases.

**Render without a platform.** The CLI renders against the render's own pins whenever no platform is given, and the render then holds the tested version. It works only where no platform exists: the operator always renders against its Platform, and a CLI render against a cluster that has one takes the platform's pin. It also admits whatever the module pins, bounded by nothing, and carries no registrations, so a provider-fulfilled demand is unresolved on this path.

**Report the skew and carry on.** The current state. It names the problem on every render and cannot act on it, because the render list is derived before the diagnostic is written.
