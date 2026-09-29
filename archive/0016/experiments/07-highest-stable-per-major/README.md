# 07-highest-stable-per-major — Initialize a Module Instance Package from a Published Module

Status: Concluded

## Hypothesis

The version selector `opm module init` uses (`compat.HighestStable`: newest stable, prerelease fallback) and the publish-side `selectCatalogVersion` predicate (development builds `X.Y.Z-0.dev.N.gSHA` never selectable) agree per major on the real GHCR listings; where they disagree, the disagreement is stated so D5 can name which rule `opm instance init` applies.

## Setup

A Go module with both selectors **copied**: `HighestStable` from `library/opm/compat/predecessor.go` (library commit 11da9b0) and `selectCatalogVersion`/`qualifies`/`isNumericIdentifier` from `cli/internal/platform/catalog.go` (cli commit 2370bd6). Fixtures are the real listings experiment 01 recorded for `opmodel.dev/catalogs/opm` and `opmodel.dev/modules/cert_manager`, plus two synthetic majors holding only dev builds (new `-0.dev` spelling and old `-dev` spelling). The program groups each list by major and prints each selector's pick.

## Run

```bash
go run .
```

## Outcome

**Hypothesis held on the real listings; refuted on the synthetic dev-only major, which is the case D5 must cover.** Run 2026-08-24.

| Listing | Major | HighestStable | catalog release pick | catalog prerelease pick | Agree |
| --- | --- | --- | --- | --- | --- |
| catalogs/opm | v2 | `v2.0.0-alpha.5` | (none) | `v2.0.0-alpha.5` | yes |
| cert_manager | v2 | `v2.0.1` | `v2.0.1` | (none) | yes |
| synthetic, only `-0.dev` builds | v3 | `v3.0.0-0.dev.2.gbbbbbbb` | (none) | (none) | **no** |
| synthetic, only old `-dev` builds | v4 | `v4.0.0-dev.2.gbbbbbbb` | (none) | `v4.0.0-dev.2.gbbbbbbb` | yes (both wrong) |

(The v0 and v1 rows agree too and are irrelevant to this enhancement.)

- On every real major the two selectors pick the same version: stable when one exists, else the newest named prerelease. `catalogs/opm@v2` being alpha-only is the live example of the prerelease fallback.
- On a major that holds only branch-publish dev builds, `HighestStable` returns the last dev build (it falls back to the last element unconditionally) while the publish predicate returns nothing. A module whose newest major is still dev-only would be scaffolded against a dev build by the `module init` rule.
- The old `-dev.N.gSHA` spelling, a named prerelease by SemVer, fools both selectors. It occurs only on pre-v2 lines on GHCR today, so it is out of scope, but a future tag scheme change would reintroduce it.

D5 was revised on 2026-08-24: `opm instance init` selects with the publish predicate (stable, else newest named prerelease, never a dev build), and a major with nothing selectable is skipped like an incompatible one and reported. Evidence linked from D5's `Source:`.
