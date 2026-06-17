# Operational Concerns — Automated CUE Dependency Updates via Renovate

This document is the OPM Production Readiness Review (PRR-lite).

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

No runtime signals — this is CI tooling, not kernel/schema code. Operationally observable surfaces: the Renovate action logs per repo (resolution + tidy output), the opened PRs themselves (the provenance trail), and optionally Renovate's Dependency Dashboard issue per repo (a single issue listing detected-but-unmerged updates). Failures (auth, regex miss, tidy error) appear as failed Action runs, not silent no-ops. The repo's existing `ci.yml` acts as a second observable gate on each PR.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

Not a breaking change. No OPM schema or Go API changes; `opmodel.dev/core` is untouched. The enhancement adds CI config (`renovate.json`, a workflow) and a shared preset. `config.yaml.semver` is `none`. The dependency *bumps* Renovate later opens are ordinary version changes reviewed per PR; their semver impact is per-bump, not a property of this enhancement.

## Deprecation

**What gets removed and when? What replaces it?**

Nothing is removed. `task update-deps` is explicitly retained (D4). If a future enhancement folds the route table into a generated source (OQ1) or absorbs Go-module updates, the hand-maintained `#routes` and any manual steps would be revisited then — out of scope here.

## Rollback

**If this lands and proves bad, what's the rollback story?**

Trivial and per-repo. Delete (or disable on:schedule for) `.github/workflows/renovate.yml` and remove `renovate.json` in the offending repo; Renovate stops opening PRs immediately, with no residual state. Already-merged dependency bumps are normal commits and revert like any other. The shared preset repo can be reverted independently. No data-plane or runtime state survives a rollback because there is none.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

1. **Preset host repo (OQ4)** lands first — it produces the artifact (`renovate/opm-cue.json5`) every other repo `extends`. Until it exists, the per-repo `renovate.json` has nothing to point at.
2. **Each affected repo** (`core`, `library`, `catalog`, `cli`, `opm-operator`, `modules`) then adds its `renovate.json` + workflow independently — no ordering between them. A repo can be onboarded one at a time; a good rollout sequence is one pilot repo (e.g. `catalog`) to validate the regex/tidy/auth end-to-end before fanning out.

The hand-off artifact is the exported preset JSON; downstream repos consume it via Renovate's `extends`. No published OCI tag or regenerated fixture gates the rollout.
