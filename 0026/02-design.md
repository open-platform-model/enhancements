# Design: Module-Dictated Catalog Versions and the Generated Platform

The platform stops holding catalog versions and starts bounding them. An authored `#PlatformSpec` names the catalog lineages a platform admits, each with a required floor and an optional ceiling, and carries no imports. A module's committed catalog pin is the version its render holds, if it lies inside the range. Today's `#Platform`, unchanged in shape, becomes a value the kernel generates per resolution rather than a file anyone maintains. Trade-off reasoning lives in `03-decisions.md`.

## Design Goals

- **A module renders against the catalog release it was tidied against**, whenever the platform admits that release. What the author tested is what runs.
- **The platform admits lineages and bounds releases; it does not pick them.** A path with its major, a floor, an optional ceiling. Admission and version selection are two facts held by two parties.
- **A pin outside the range is refused by name, never promoted.** The refusal names the module, the path, the pin, the bound and whose bound it was. Nothing silent moves an instance to a version its owner did not name.
- **Raising the floor touches only the instances below it.** The platform keeps a lever that reaches the whole fleet, and it is loud: named refusals until owners bump, never a silent re-render.
- **Provider catalogs follow the same rule with the provider module as the pinning module.** The registration's derived `version` is the pick when no consumer pins the path, the provider author declares a compatibility window, and the platform's spec entry overrides it when present.

## Non-Goals

- **Changing how matching works, or how the transformer set is derived.** The render build's match glue and the fold over embedded catalogs are exactly as 0019 left them. This entry changes which version's bytes reach the fold, nothing about the fold.
- **Changing who admits a catalog.** Static catalogs are admitted by the platform spec, provider catalogs by the RBAC-gated registration of 0015 D3. Both stay.
- **Routing between providers, classes, or capability-based selection.** 0015 D2's successor material, untouched.
- **Automatic upgrade of instances within a range.** A floor refuses, it does not promote. Whether a future entry may float an instance forward within a range is gated on enhancement 0021's answers about what a compatible module change is, and is out of scope here.
- **Module-hosted transformers.** 0015 D10 stands. A version selects bytes from a published catalog artifact; nothing here lets a module ship code.

## High-Level Approach

Two layers replace one file.

```
#PlatformSpec (authored, pure data)          consumer module's cue.mod (committed pins)
  catalogs by path, major in the path          catalogs/opm@v4   v4.1.0
  floor required, ceiling optional             core, k8s.io, ... (tidied closure)
  registry override optional
              └───────────────────┬────────────────────┘
                     kernel: admit, check, generate
                        for each catalog path the module imports:
                          in the spec? in [floor, ceiling]? else refuse by name
                        for each accepted registration: add its catalog at its version
                                    ▼
             generated platform module        <- today's #Platform, shape unchanged
               cue.mod  = the module's tidied list plus registration catalogs
               platform = one import and one #registry entry per catalog in the build
                                    ▼
                     one render build (0019 D9), unchanged from here on
```

**The spec is data.** It has no `cue.mod` dependencies and imports nothing, so it can be a Platform CR's spec and an offline CLI file with the same fields. It says which lineages exist on this platform and what range of each is admitted. That is the whole of what the platform team authors.

**The module's pin is the version.** The kernel reads the module's committed dependency list, the same list 0019 D13 already stages, and writes the render module's list from it. No tidy runs at render, no resolver is consulted, no maximum-version selection happens. The list is a promotion from committed files, as before; what changes is which file is promoted on a catalog path.

**The platform is generated per resolution.** The kernel writes a platform module whose `cue.mod` carries the catalog versions the build will hold and whose value is today's `#Platform`: one import per catalog, one `#registry` entry per path, `#composedTransformers` folded as now. Two renders with the same resolved set share one generated platform. A fleet clusters on a handful of catalog releases, so the set of generated platforms stays small.

**Provider catalogs join the same rule.** The provider module pins its own catalog, and 0015 D11 already derives the registration's `version` from that pin. That version is the pick for any render that does not pin the provider catalog itself. The registration gains a window, `floor` and `ceiling` defaulting to `version`, that the provider author sets beside the operator release the module deploys. A spec entry for the provider catalog's path is optional; when present, its range replaces the author's window, and the registration's status reports which one is in effect.

**Refusal replaces promotion.** A consumer pin below the floor is refused. Raising the floor is therefore the platform's fleet-wide lever, and it is a lever that names every instance it stops rather than moving them.

## Schema / API Surface

Full shapes in [`schemas/target.cue`](schemas/target.cue).

- **`#PlatformSpec`** (NEW): the authored platform, pure data. `metadata`, `type`, and `catalogs`, a path-keyed map of `#Subscription`. Mirrors the Platform CRD's spec; enhancement 0008's generation is the intended route from one to the other.
- **`#Subscription`** (NEW): one admitted lineage. `path` with the major, `enable`, an optional `registry` naming where the path resolves, a required `floor`, an optional `ceiling`. Same major is structural through the path; ordering is a kernel check, since CUE has no semver comparison.
- **`#Platform`, `#CatalogEntry`** (UNCHANGED): the render-time value. `version` keeps its derivation and widens in meaning to "the version this build holds".
- **The registration window** is a catalog_opm contract change, not core: the `transformer-registration` resource's spec gains `floor` and `ceiling` defaulting to `version`, and the CR mirrors them in spec and reports the effective window in status.

## Affected Surfaces

**core.** Two new definitions, `#PlatformSpec` and `#Subscription`. No existing definition changes shape. `#CatalogEntry.version`'s documented meaning widens from "the platform's pin" to "the version this build holds". SPEC.md gains a section for the spec and a paragraph on the generated platform.

**library.** The render-module derivation of 0019 D13 changes its source on catalog paths: the module's committed list, bounded by the spec, instead of the platform's. The kernel gains the spec-to-platform generation, keyed by the resolved catalog set. Three refusals become kernel diagnostics: catalog not admitted, pin outside range, and a provider catalog whose shared-path requirement exceeds the consumer's pin. Every render records the catalog versions it held.

**opm-operator.** The Platform CRD's spec takes the `#PlatformSpec` shape: a map of catalogs with floor, optional ceiling and optional registry, replacing an exact version per path. Registration acceptance reads the spec entry for the claimed catalog, if any, and writes the effective window and its source to the registration's status. A warning condition marks a spec range that exceeds the provider's declared window. Platform-package generation becomes per-resolution.

**cli.** Offline renders start from a `#PlatformSpec` file instead of a platform module; the module-form platform under the CLI's hack tooling goes away. `opm platform check` evaluates against the static floors and the registration versions as reference versions.

**catalog_opm.** The `transformer-registration` contract gains `floor` and `ceiling` with `version` as their default, and the rendering transformer copies them to the CR.

## Before / After

**The three modules from the problem statement.** Spec admits `catalogs/opm@v4` with floor 4.0.0 and no ceiling.

| Module pins `opm` at | Before, platform at 4.3.0 | After |
| --- | --- | --- |
| 4.1.0 | renders at 4.3.0, silently | renders at 4.1.0 |
| 4.3.0 | renders at 4.3.0 | renders at 4.3.0 |
| 4.6.0 | refused, unknown key | renders at 4.6.0 |
| 3.9.0 | refused, different major | refused, `catalogs/opm@v3` not admitted |

Platform team later sets `floor: 4.2.0`. Before: a bump re-rendered all three. After: the 4.1.0 module is refused by name until its owner bumps; the other two do not move.

**The provider.** k8up module 2.1.0 pins `catalogs/k8up@v1` at 1.6.0 and declares floor 1.4.0, ceiling 1.8.0. No spec entry for the path.

| Consumer pins `k8up` at | Before | After |
| --- | --- | --- |
| nothing | 1.6.0, registration's version | 1.6.0, same |
| 1.7.0 | platform's version wins, pin inert | 1.7.0, inside the author's window |
| 1.9.0 | platform's version wins, pin inert | refused, above the installed provider's ceiling |

Platform team adds a spec entry for the path with ceiling 1.9.0. The 1.9.0 consumer renders, the registration's status reads `source: platform`, and a warning condition records that the platform exceeded the author's claim. Delete the entry and the author's window binds again.
