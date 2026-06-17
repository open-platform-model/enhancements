# Problem Statement — Automated CUE Dependency Updates via Renovate

This document answers the question: "Why does this enhancement need to exist?"

## Current State

CUE dependencies across the workspace are updated by one workspace-root task, `task deps:update` (aliased `task update-deps`), defined in `/Taskfile.yml`. It walks every `cue.mod` directory under `catalog`, `cli`, `opm-operator`, `modules`, and `$HOME/.opm`, parses the `deps:` block out of each `cue.mod/module.cue`, runs a single `cue mod get <all-deps>` resolution pass followed by `cue mod tidy`, and prints a per-dep old→new diff. A second pass (`deps:update:templates`) does the same for the CLI's `cue.mod/module.cue.tmpl` template files by rendering them into a scratch module first. The root `CLAUDE.md` documents the convention and explicitly forbids hand-editing version pins: "Never manually edit version pins in `cue.mod/module.cue` — use `task update-deps`."

The dependency graph has two populations. Internal OPM modules — `opmodel.dev/core@v0`, `opmodel.dev/catalogs/opm@v0`, `opmodel.dev/modules/*` — are published by release-please to `ghcr.io/open-platform-model` (the `opmodel.dev=ghcr.io/open-platform-model` mapping in `GHCR_CUE_REGISTRY`). External CUE modules — `cue.dev/x/k8s.io@v0` — resolve through `registry.cue.works`. Both are OCI registries; CUE stores each module version as an OCI tag, and those tags list as clean semver (verified 2026-06-17: `registry.cue.works/v2/cue.dev/x/k8s.io/tags/list` returns `["v0.0.0","v0.3.0",…,"v0.7.0"]`).

The workspace is not a monorepo. `core`, `library`, `catalog*`, `cli`, `opm-operator`, `modules` are each a separate git repository with its own `.github/workflows/`. There is no shared CI surface — each repo runs its own `ci.yml` / `release.yml`.

## Gap / Pain

The update path is entirely manual and human-triggered. Nothing detects that an upstream dependency has published a new version; a maintainer has to remember to run `task update-deps` from a checkout that has all repos cloned side by side. Between runs, dependency drift is invisible — a repo can sit on a months-old `opmodel.dev/core` for as long as nobody runs the task. There is no scheduled signal, no PR, no provenance trail of *when* a bump happened or *what* changed upstream.

The task's workspace-wide design is also a poor fit for the per-repo reality. It only works from a layout where every repo is checked out under one root; it cannot run inside any single repo's CI, where the other repos do not exist. So the one tool that does the bumping structurally cannot run in the place where automation lives.

## Concrete Example

`opmodel.dev/core` cuts `v0.6.0`. Today nothing happens automatically. `modules/jellyfin/cue.mod/module.cue` keeps `"opmodel.dev/core@v0": { v: "v0.5.0" }` and `catalog_opm/src/cue.mod/module.cue` keeps `"opmodel.dev/core@v0": { v: "v0.5.0" }` indefinitely. The bump lands only when a maintainer, on a full-workspace checkout, runs `task update-deps`, sees the printed `core: v0.5.0 -> v0.6.0`, then commits and pushes the change in each affected repo separately — and only then does each repo's release-please publish a new version downstream consumers can pick up. A `core` patch can take weeks to propagate through `catalog → modules` purely because no one ran the task.

## User Stories

- As a catalog/module author, I want a PR to appear when a dependency I rely on publishes a new version, so that I review and merge instead of polling registries by hand. Today: drift is silent until someone runs `task update-deps`.
- As a kernel maintainer publishing `core`, I want downstream repos to be nudged toward my new release automatically, so that propagation isn't gated on a manual workspace-wide sweep. Today: I must run the sweep myself or wait for someone to.
- As a release engineer, I want a dated, reviewable provenance trail for every dependency bump (what changed, when, from where), so that a regression can be traced to a specific bump. Today: bumps land inside unrelated commits with no upstream linkage.

## Why Existing Workarounds Fail

`task update-deps` is the workaround, and it has three structural limits that no amount of polish fixes: it is pull-only (a human must invoke it), it requires the full-workspace checkout (so it cannot live in any repo's CI), and it produces no per-bump provenance (the change is a bare version-string edit with no link to the upstream release). These are properties of *where* and *how* the task runs, not bugs to fix — which is why a scheduled, per-repo, PR-generating mechanism is needed alongside it rather than a better version of the task.
