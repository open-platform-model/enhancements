# Design Decisions — Automated CUE Dependency Updates via Renovate

This document records every significant design choice with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. The log is **append-only** — never remove or renumber existing entries. If a decision is reversed, add a new decision that supersedes it (e.g. "D8 supersedes D3") and leave D3 in place as historical context.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source.

---

## Decisions

### D1: Self-hosted Renovate via `renovatebot/github-action`

**Decision:** Renovate runs self-hosted as a scheduled GitHub Action in each repo, not as the hosted Mend GitHub App.

**Alternatives considered:**

- Hosted Mend Renovate App — near-zero infra and a central dashboard, but `postUpgradeTasks` is disallowed on the hosted app for security, so PRs could only rewrite the version string and never run `cue mod tidy`.
- Hybrid (hosted app opens PRs; each repo's existing CI vets the bumped `module.cue` and fails if tidy would change something) — keeps PRs honest but never auto-applies tidy, leaving every PR a manual tidy step.

**Rationale:** Running `cue mod tidy` after a bump is the difference between a consistent module and a dangling version-string edit. Only self-hosted Renovate permits the `postUpgradeTasks` that runs it. The design goal "the opened PR is a consistent module" forces self-hosting.

**Source:** User decision 2026-06-17.

### D2: Uniform OCI (`docker`) datasource for all CUE deps

**Decision:** New versions are resolved through Renovate's `docker` datasource against the backing OCI registry, for both internal (`ghcr.io`) and external (`registry.cue.works`) deps. No `github-releases` datasource.

**Alternatives considered:**

- `github-releases` for internal `opmodel.dev/*` deps + `docker` for external `cue.dev/*` — richer PR provenance (changelogs), but needs `extractVersion` for release-please monorepo tags and a depName→GitHub-repo map to maintain, and still cannot cover `cue.dev/*`.
- Defer behind a spike before choosing — unnecessary once the spike question (tag format) was answered directly.

**Rationale:** CUE modules are OCI artifacts; one mechanism covers every dep. The load-bearing assumption — that CUE OCI tags list as clean semver — was validated live: `registry.cue.works/v2/cue.dev/x/k8s.io/tags/list` returns `["v0.0.0","v0.3.0","v0.4.0","v0.5.0","v0.6.0","v0.7.0"]`. GHCR uses the same CUE encoding (auth required to list, which the self-hosted runner already carries). Loss of changelog text in PRs is acceptable.

**Source:** User decision 2026-06-17; tag-format probe 2026-06-17.

### D3: Major version pinned — no auto cross-major bumps

**Decision:** The regex managers disable major updates (`#pinMajor`, `major.enabled: false`). A dependency's `@vN` import-path major is never crossed automatically.

**Alternatives considered:**

- Allow major bumps with `allowedVersions` ceilings per dep — more config to maintain and one mistake silently breaks an import path.
- Rely on the regex only matching `@vN` — insufficient, because on GHCR a module's `v0.x` and `v1.x` tags share one OCI repo, so the docker datasource would surface a `v1` tag as a candidate.

**Rationale:** Crossing a major changes the import path (`@v0`→`@v1`) and requires code changes — a deliberate human action, not an auto-bump. Disabling major updates over the regex managers is the simplest correct guard.

**Source:** Design analysis 2026-06-17 (GHCR shared-repo tag behavior).

### D4: Renovate augments, does not replace, `task update-deps`

**Decision:** `task deps:update` stays as the local/manual sweep; Renovate is added as the scheduled-CI path. They coexist.

**Alternatives considered:**

- Remove `task update-deps` once Renovate lands — loses the fast, offline, whole-workspace one-shot bump that is useful during local multi-repo work.

**Rationale:** The two serve different moments: the task is pull-based and workspace-wide (good for a developer bumping everything before a release rehearsal); Renovate is push-based and per-repo (good for catching drift continuously). Neither subsumes the other.

**Source:** User decision 2026-06-17.

### D5: Design home is enhancement 0004

**Decision:** This cross-OPM concern is captured as a top-level `enhancements/` entry (this one), per the routing rules for cross-cutting work.

**Alternatives considered:**

- Discuss in-conversation only — leaves no durable design contract for the per-repo slices.
- Prototype config in one repo first — better as a Phase-2 experiment under this entry than as the primary artifact.

**Rationale:** The work touches CI of six repos; the canonical home for cross-cutting design intent is `enhancements/`.

**Source:** User decision 2026-06-17.

---

## Open Questions

- **OQ1: How is the route table kept in sync with `CUE_REGISTRY`?** Status: open. `#routes` in `schemas/target.cue` mirrors the `opmodel.dev=ghcr.io/open-platform-model` / `registry.cue.works` mapping by hand. If `CUE_REGISTRY` gains a registry or remaps a host, the preset silently goes stale. Options: a check that diffs the two, or generating the route table from the same source the Taskfile reads.
- **OQ2: What exact regex robustly matches the deps block?** Status: open. The sketch in `#CustomManager.matchStrings` must tolerate both observed layouts — `{ v: "vX.Y.Z" }` and `{ v: "vX.Y.Z"; default: true }` — across formatting variants, and must not match the module's own `module:` / `language:` lines. Needs a spike against real `module.cue` files before promotion.
- **OQ3: One grouped CUE-bump PR per repo per run, or a PR per dependency?** Status: open. Grouping keeps review surface small but can hide a breaking transitive bump among routine ones; per-dep PRs are noisier but isolate risk.
- **OQ4: Which repo hosts the shared preset?** Status: open. Candidates: a dedicated `open-platform-model/.github` repo, or one of the existing repos (e.g. `core`). Affects the `extends: ["github>…"]` path every repo points at.
- **OQ5: Should Renovate touch `library/testdata/` fixtures (~63 module.cue)?** Status: open. Keeping fixtures on current deps avoids bit-rot but may generate frequent low-value PRs; the alternative is a `managerFilePatterns` exclusion for `testdata/`.
- **OQ6: Scheduling cadence and PR/branch concurrency limits per repo.** Status: open. navecd sets all limits to 0 (unlimited); OPM may want a weekly schedule and a small concurrency cap to keep CI cost bounded.
