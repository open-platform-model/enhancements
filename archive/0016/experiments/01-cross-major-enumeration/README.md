# 01-cross-major-enumeration — Initialize a Module Instance Package from a Published Module

Status: Concluded

## Hypothesis

Listing a **major-free** module path through `modregistry.Client.ModuleVersions` against GHCR returns every published version across all majors in one call, sorted ascending, and a major-suffixed path scopes the same call to that major. Backs D5: the omitted-`--version` walk needs one listing, not one per major.

## Setup

A throwaway Go module (`cuelang.org/go v0.17.1`, the version `cli/go.mod` and `library/go.mod` pin on 2026-08-24; Go 1.26.5). `main.go` builds a `modconfig` resolver from the environment and calls `ModuleVersions` for each argument. Nothing is copied from `library/`: the claim is about CUE's registry client, so it is called directly. The only OPM input is the registry mapping from the workspace `CLAUDE.md`.

Targets: `opmodel.dev/modules/cert_manager` (bare, `@v2`, `@v1`, `@v0`), `opmodel.dev/modules/metallb`, and `opmodel.dev/catalogs/opm` for a long mixed list.

## Run

```bash
export CUE_REGISTRY='opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'
go run . opmodel.dev/modules/cert_manager opmodel.dev/modules/cert_manager@v2 \
         opmodel.dev/modules/cert_manager@v1 opmodel.dev/modules/cert_manager@v0
go run . opmodel.dev/modules/metallb opmodel.dev/catalogs/opm
```

## Outcome

**Hypothesis held.** Run 2026-08-24 against `ghcr.io/open-platform-model` (anonymous pull).

| Call | Versions | Majors present |
| --- | --- | --- |
| `opmodel.dev/modules/cert_manager` | 8 | v0 (4), v1 (3), v2 (1: `v2.0.1`) |
| `opmodel.dev/modules/cert_manager@v2` | 1 | v2 only |
| `opmodel.dev/modules/cert_manager@v1` | 3 | v1 only |
| `opmodel.dev/modules/cert_manager@v0` | 4 | v0 only |
| `opmodel.dev/modules/metallb` | 6 | v0 (3), v1 (2), v2 (1: `v2.0.1`) |
| `opmodel.dev/catalogs/opm` | 47 | v0 (9), v1 (22), v2 (16) |

- A major-free path returns every published version regardless of major in one call; a major-suffixed path scopes the same call. The scoped counts sum to the bare count (1 + 3 + 4 = 8), so nothing is dropped or duplicated.
- The list is sorted ascending by SemVer across majors, so grouping by major is a single pass.
- On the v2 line, `catalogs/opm` is prerelease-only (`v2.0.0-alpha.1` to `-alpha.5`) plus branch-publish dev builds `v2.0.0-0.dev.N.gSHA`; the dev builds sort below the named prereleases. Carried to experiment 07.

Evidence linked from D5's `Source:` in `../../03-decisions.md`.
