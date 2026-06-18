# Operational Concerns — Automated CUE Dependency Updates via Dagger

This document is the OPM Production Readiness Review (PRR-lite).

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

No runtime signals — this is CI tooling, not kernel/schema code. Operationally observable surfaces: the Dagger run logs per repo (discovery, `cue mod get`/`cue mod tidy` output, the old→new summary), and the opened PRs themselves (the provenance trail). Failures (auth, missing `cue`, a tidy error, an engine outage) appear as failed Action runs, not silent no-ops. The repo's existing `ci.yml` acts as a second observable gate on each PR. Because the same Dagger function runs locally, a maintainer can reproduce any CI bump with a single `dagger call` to diagnose.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

Not a breaking change. No OPM schema or Go API changes; `opmodel.dev/core` is untouched. The enhancement adds CI config (a per-repo caller workflow), a shared Dagger module + reusable workflow, and rewires `task update-deps`'s implementation behind an unchanged interface. `config.yaml.semver` is `none`. The dependency *bumps* the workflow later opens are ordinary version changes reviewed per PR; their semver impact is per-bump, not a property of this enhancement.

## Deprecation

**What gets removed and when? What replaces it?**

The bash bodies of `deps:update:modules` / `deps:update:templates` in `/Taskfile.yml` are replaced by a call to the Dagger function (D9); the `task update-deps` interface stays. Nothing else is removed. If a later enhancement broadens scope to `go.mod` / Actions (D6), that is additive and out of scope here.

## Rollback

**If this lands and proves bad, what's the rollback story?**

Trivial and per-repo. Delete (or disable `on: schedule` for) `.github/workflows/cue-deps.yml` in the offending repo; the scheduled bumps stop immediately, with no residual state. Already-merged dependency bumps are normal commits and revert like any other. The shared Dagger module + reusable workflow can be reverted independently. `task update-deps` can be reverted to its bash body if the Dagger wrapper regresses. No data-plane or runtime state survives a rollback because there is none.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

1. **`daggerverse` then `.github` (D12)** land first — `open-platform-model/daggerverse//cue-deps` ships the module (`#UpdateFn`, tagged `cue-deps/vX.Y.Z`); `open-platform-model/.github` ships the reusable `workflow_call` that invokes it and that every caller `uses:`. Until both exist, the per-repo caller has nothing to point at.
2. **`/Taskfile.yml`** is rewired to call the function (D9) — independent of the per-repo rollout, but a good early validation that the function reproduces the old bash behavior locally.
3. **Each affected repo** (`core`, `library`, `catalog`, `cli`, `opm-operator`, `modules`) then adds its caller workflow independently — no ordering between them. A repo can be onboarded one at a time; a good rollout sequence is one pilot repo (e.g. `catalog`) to validate discovery/tidy/auth end-to-end before fanning out.

The hand-off artifact is the published Dagger module ref + the reusable workflow; downstream repos consume them via `uses:`. No published OCI tag or regenerated fixture gates the rollout.
