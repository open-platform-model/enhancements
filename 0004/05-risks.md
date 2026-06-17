# Risks, Drawbacks, Alternatives — Automated CUE Dependency Updates via Renovate

This document records the honest costs of the proposed design.

## Risks and Mitigations

- **Route table drifts from `CUE_REGISTRY`.** If a host mapping changes in the workspace Taskfile but not in `#routes`, Renovate queries the wrong registry and either finds no tags (no PRs, silent staleness) or the wrong ones. **Mitigation:** OQ1 — a CI check that diffs `#routes` against `CUE_REGISTRY`, or generate the table from one source.
- **Regex over- or under-matches.** A brittle `matchStrings` could miss a deps layout (no PR) or match `module:`/`language:` lines (garbage PR). **Mitigation:** OQ2 — spike the regex against every real `module.cue` before promotion; the regex is data in the preset, cheap to correct.
- **`postUpgradeTasks` runs `cue mod tidy` in CI without the right environment.** Tidy needs `cue` installed, `CUE_REGISTRY` set, and GHCR `read:packages` auth, or it fails and the PR is the bare string edit we wanted to avoid. **Mitigation:** the workflow provisions all three; the repo's own `ci.yml` re-vets the PR as a backstop, so an un-tidied bump cannot merge green.
- **Bump propagation storm.** A `core` release fans out to PRs in catalog + modules simultaneously, each triggering CI. **Mitigation:** OQ6 — per-repo concurrency caps and a weekly schedule bound the blast radius.
- **GHCR private-package auth expiry.** Internal modules need a token with `read:packages`; an expired/insufficient token means no internal-dep PRs. **Mitigation:** use the workflow's `GITHUB_TOKEN` with `packages: read`; failures surface as action logs, not silent.

## Drawbacks

- **Self-hosting is more setup than the hosted app.** Each repo carries a workflow with CUE + auth + an allow-listed command (D1's accepted cost).
- **No changelog text in PRs.** The OCI datasource gives versions, not release notes (D2's accepted cost); reviewers follow the tag to the release manually.
- **A second update path to keep coherent.** `task update-deps` and Renovate must not fight; both write the same `v:` pins. In practice both converge to "latest within major," so a race just means one no-ops, but the duplication is real (D4).
- **The route map is hand-maintained config.** Adding a registry means editing `#routes` (until OQ1 is resolved).

## Alternatives

- **Keep `task update-deps` as the only mechanism, add a cron that runs it and opens a PR.** Why not: the task requires the full-workspace checkout, so the cron would need all repos cloned and could only open cross-repo PRs in a meta repo — it cannot live in each repo's CI, which is exactly the gap.
- **Write a bespoke Go/CUE tool that lists OCI tags and bumps pins.** Why not: reinvents Renovate's scheduling, PR management, dedup, and dashboard for no gain over a regex custom manager.
- **Hosted Mend app only (no tidy).** Why not: ruled out in D1 — cannot run `cue mod tidy`, so PRs are inconsistent modules.
