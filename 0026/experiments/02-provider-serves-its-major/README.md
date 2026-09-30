# 02-provider-serves-its-major: Module-Dictated Catalog Versions and the Generated Platform

Status: Concluded

## Hypothesis

A provider built against one major of its declaring catalog serves only that major: its requirement refuses the other major's components at plain unification, so counting it against every provider on a platform that admits both majors reports a false over-subscription that one resolution per declaring major does not (D9 R4, R5).

## Setup

Copied, unmodified, from `core/src/` at commit `cbe93e0` (two commits after release `2.0.0-alpha.12`, which changed only comments in `resource.cue` and `trait.cue`): `types.cue`, `resource.cue`, `trait.cue`, `blueprint.cue`, `transformer.cue`, `catalog.cue`, `platform.cue`. `platform.cue` is the shipped `#Platform`, the render-time value D3 renames `#ResolvedPlatform`.

Added in `probe/`:

- `members.cue`: the same two-major member source as experiment 01, `opmodel.dev/catalogs/opm@v4` at 4.2.0 and `opmodel.dev/catalogs/opm@v5` at 5.0.0, sharing the contract keys. The `backup` trait is provider-fulfilled.
- `providers.cue`: two provider catalogs, `opmodel.dev/catalogs/k8up@v2` built against opm@v4 and `opmodel.dev/catalogs/k8up@v3` built against opm@v5. Each ships one transformer whose `requiredTraits` carries the backup trait as the major it was built against publishes it, stamped with that major's `catalogVersion` by `#Catalog`. The file also holds the same-major match, `bothProvidersOneBuild` (the declaring catalog plus both providers, the count taken across every provider) and one resolution per declaring major (`resolutionV4`, `resolutionV5`).
- `case_cross.cue`: the v4-built provider's requirement unified with a v5 component's backup value. Guarded by `@if(cross)`.

Rung 2 of the render match is plain unification of the component's value with the transformer's requirement, with no provenance carve-out (0019 D10), so unifying the two values here is the check the render glue makes. The same two facts show through a real library render with a two-major platform and one provider per major: the other-major provider is unify-disqualified and the platform is refused as over-subscribed (experiment 07, case `mplat_bprov_both`). This probe reproduces both in CUE alone.

## Run

From `probe/`, with cue v0.17.1:

```bash
cue vet -c=false .
cue eval -e matchSameMajor.metadata .                      # v4 provider, v4 component
cue eval -t cross -e matchCrossMajor .                     # v4 provider, v5 component
cue eval -e bothProvidersOneBuild.#contracts .             # count across both providers
cue eval -e resolutionV4.#contracts . && cue eval -e resolutionV5.#contracts .
```

## Outcome

Measured 2026-09-30, cue v0.17.1.

- **Same major: unifies.** The v4-built requirement and a v4 component's backup value unify to one trait, `catalogVersion: "4.2.0"`.
- **Cross major: refused at unification.** File references elided:

  ```
  matchCrossMajor.metadata.catalogVersion: conflicting values "4.2.0" and "5.0.0"
  matchCrossMajor.spec.backup: field not allowed
  ```

  A provider built only against opm@v4 can never match a component on opm@v5, whatever the platform admits. The provider has to ship a transformer built against opm@v5 for opm@v5 components to use it.
- **Counted across every provider: over-subscribed.** `bothProvidersOneBuild` reports `providedBy` backup as `[k8up@v2, k8up@v3]`, `overSubscribed` lists the backup key, and `routable` is `false`. The single-provider count reads two providers of one contract, although each can only ever match its own major's components.
- **Counted per resolution: routable.** `resolutionV4` holds opm@v4 and k8up@v2 only and `resolutionV5` holds opm@v5 and k8up@v3 only; each reports one provider, empty `overSubscribed`, `routable: true` and `fulfilled: true`.

**Hypothesis held.** A provider's reach is fixed by the major it was built against, and the one-provider rule is correct only when counted over a set holding one major of the declaring catalog. Linked from D9 in `03-decisions.md`.
