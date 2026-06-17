# Design — Automated CUE Dependency Updates via Renovate

This document answers the question: "What is the proposed solution and how does it work?"

## Design Goals

- A new upstream version of any CUE dependency in any `cue.mod/module.cue` across the affected repos produces a pull request in that repo, without human polling.
- Detection runs on a schedule in CI, per repo, using each repo's own checkout — no full-workspace layout required.
- Each PR carries provenance: which dependency, old→new version, and the upstream source it was resolved from.
- The opened PR is a *consistent* module — `cue mod tidy` has run, so the bump is not a bare version-string edit that the repo's own `cue vet` would later reject.
- A dependency's pinned major (`@vN` in the deps key) is never crossed automatically; a `v0`→`v1` move is a deliberate human action, not an auto-bump.
- The detection/route configuration lives in one place and is reused by every repo, so adding a registry or repo does not mean editing N copies.

## Non-Goals

- Replacing `task update-deps`. The task stays as the fast local/manual path; Renovate is the scheduled-CI path. (D4)
- Automating Go module (`go.mod`) updates. Renovate's native `gomod` manager already handles those and can be enabled in the same config later; this enhancement scopes to CUE modules only.
- Auto-merging dependency PRs. PRs are opened for human review; auto-merge policy is a later, separate decision.
- Bumping the CUE language/tool version (`language.version` in `module.cue`). Possible as a follow-on (datasource `github-releases` on `cue-lang/cue`), explicitly out of this entry's scope.
- Cross-major migrations (`@v0`→`@v1`), which change import paths and require code changes.

## High-Level Approach

Renovate has no native CUE-module manager, so the mechanism is a **regex custom manager** pointed at `cue.mod/module.cue`, resolving new versions through the **`docker` (OCI) datasource** — the universal lookup that works for both internal (`ghcr.io`) and external (`registry.cue.works`) CUE deps. This is the same shape the `kharf/navecd` project uses for its CUE deps, adapted from its GitHub-releases datasource to OCI because half of OPM's deps (`cue.dev/*`) are not GitHub-backed.

Renovate runs **self-hosted** via the `renovatebot/github-action` on a schedule in each repo. Self-hosting is required, not incidental: only self-hosted Renovate permits `postUpgradeTasks`, and running `cue mod tidy` after a version bump is what makes the PR a consistent module rather than a dangling string edit. (D1)

The detection config is authored once as a **shared CUE-exported preset** and `extends`ed by a one-line `renovate.json` in each repo. The preset's core is a **route table** mapping CUE module-path host prefixes to OCI registries, mirroring `CUE_REGISTRY`. Because a module's `@v0` and `@v1` tags share one OCI repository on GHCR, the preset disables major updates for these managers so the pinned major is never crossed.

## Schema / API Surface

The full preset shape is in [`schemas/target.cue`](schemas/target.cue). Headline constructs:

- `#RegistryRoute` — `{ hostPrefix, registryUrl, packageNameTemplate }`. The route table `#routes` has two entries today: `opmodel.dev/` → `https://ghcr.io` with package `open-platform-model/{{{package}}}` (host replaced by prefix, matching the `opmodel.dev=ghcr.io/open-platform-model` registry mapping), and `cue.dev/` → `https://registry.cue.works` with package `cue.dev/{{{package}}}` (host kept as a path component, matching the registry fallback). This map is the single coupling Renovate must keep in step with `CUE_REGISTRY`.
- `#managers` — one regex `#CustomManager` generated per route. Its `matchStrings` regex matches a deps key `"<hostPrefix><package>@vN"` and captures `package` plus the pinned `currentValue` (`v: "vX.Y.Z"`). `datasourceTemplate: "docker"`, `versioningTemplate: "semver"`.
- `#pinMajor` — a packageRule with `major.enabled: false` over the regex managers, so the `@vN` ceiling is enforced.
- `#postUpgrade` — `cue mod tidy` as a `postUpgradeTasks` command scoped to `**/cue.mod/module.cue`.
- `config` — assembles `customManagers`, `packageRules`, `postUpgradeTasks` into the exported preset.

## Integration Points

- **Preset host repo (TBD — OQ4):** the CUE source `schemas/target.cue` exported to a committed `renovate/opm-cue.json5`, plus a Taskfile target to regenerate it (`cue export` → JSON5).
- **Each affected repo (`core`, `library`, `catalog`, `cli`, `opm-operator`, `modules`):**
  - `renovate.json` — `{ "extends": ["github>open-platform-model/<host-repo>//renovate/opm-cue.json5"] }`.
  - `.github/workflows/renovate.yml` — scheduled `renovatebot/github-action`, with `cue` installed, GHCR `read:packages` auth, `CUE_REGISTRY` set, and `cue mod tidy` allow-listed via `allowedPostUpgradeCommands`.
- **`library` caveat:** ~63 `module.cue` files, most under `testdata/` fixtures. Whether Renovate should touch test fixtures (keeps them current vs. PR noise) is OQ5.

## Before / After

Scenario: `opmodel.dev/core` cuts `v0.6.0`.

Before — `modules/jellyfin/cue.mod/module.cue` stays at `"opmodel.dev/core@v0": { v: "v0.5.0" }` until a maintainer runs `task update-deps` on a full-workspace checkout and pushes each repo.

After — the next scheduled Renovate run in the `modules` repo resolves `ghcr.io/open-platform-model/core` tags, sees `v0.6.0 > v0.5.0` (within major `v0`), rewrites the pin, runs `cue mod tidy`, and opens a PR titled e.g. `chore(deps): update opmodel.dev/core to v0.6.0` with the old→new diff. A reviewer merges; release-please does the rest. `task update-deps` still works unchanged for local sweeps.
