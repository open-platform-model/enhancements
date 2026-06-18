# Risks, Drawbacks, Alternatives — Automated CUE Dependency Updates via Dagger

This document records the honest costs of the proposed design.

## Risks and Mitigations

- **`cue mod tidy` runs in CI without the right environment.** Tidy and `cue mod get` need `cue` installed, `CUE_REGISTRY` set, and a GHCR `read:packages` token, or they fail and the PR is empty or partial. **Mitigation:** the Dagger function provisions `cue` and registry auth in its container; the workflow passes `CUE_REGISTRY` and the token; the repo's own `ci.yml` re-vets the PR as a backstop, so an inconsistent bump cannot merge green.
- **GHCR private-package auth expiry.** Internal `opmodel.dev/*` modules need a token with `read:packages`; an expired/insufficient token means no internal-dep bumps. **Mitigation:** use the workflow's `GITHUB_TOKEN` with `packages: read`; failures surface as failed Action runs, not silent no-ops.
- **The Dagger engine becomes a CI dependency in six repos.** Every caller workflow must pull and run the Dagger engine; an outage or version skew in Dagger blocks all dep-update PRs. **Mitigation:** pin the Dagger module ref; failures are isolated to the scheduled job and never touch the data plane — a broken run just means no PR that day. The single shared module (OQ4) means one place to fix.
- **Discovery misses or mishandles a module shape.** The walker must find every `cue.mod/module.cue` and the CLI's `module.cue.tmpl` templates (not valid CUE modules until rendered). A missed shape means silent staleness; a mishandled template means a broken PR. **Mitigation:** the function reuses the current `task update-deps` discovery logic, which already handles both populations; the pilot repo validates end-to-end before fan-out.
- **Bump propagation storm.** A `core` release fans out to PRs in catalog + modules simultaneously, each triggering CI. **Mitigation:** the grouped daily PR on a fixed branch (D10) collapses each repo's churn to one PR; per-repo schedules can be staggered if CI cost warrants.

## Drawbacks

- **A CI engine dependency where there was none.** Adding Dagger to six repos is more moving parts than a hosted bot would be (the accepted cost of D7). The payoff is local/CI parity and one shared implementation.
- **No changelog text in PRs.** The bump is versions, not release notes; reviewers follow the tag to the release manually. (Same property the OCI-based detection would have had.)
- **CUE-only.** `go.mod`, Actions pins, and Dockerfiles get no automation here (D6); a separate enhancement is needed if that coverage is wanted later. A hosted Renovate would have covered them natively — the deliberate trade for a smaller surface.

## Alternatives

- **Self-hosted Renovate with a regex custom manager (the superseded D1+D2 design).** Why not: its detection layer reimplements CUE's resolver as a hand-maintained route table mirroring `CUE_REGISTRY` (OQ1) plus a `module.cue`-parsing regex (OQ2). Both are weaker than CUE-native resolution and are pure maintenance cost. Renovate's real edge — multi-ecosystem coverage — is out of scope here (D6).
- **Bespoke logic as plain shell in a GitHub Actions workflow.** Why not: not runnable locally, and it becomes a third copy of the bump logic alongside `task update-deps` rather than a shared one. Dagger gives the same compute as a portable, typed function reused in both contexts.
- **Keep `task update-deps` as the only mechanism, add a cron that runs it and opens a PR.** Why not: the task requires the full-workspace checkout, so the cron would need all repos cloned and could only open cross-repo PRs in a meta repo — it cannot live in each repo's CI, which is exactly the gap. The path-driven Dagger function removes the full-checkout assumption.
