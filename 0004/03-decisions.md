# Design Decisions — Automated CUE Dependency Updates via Dagger

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

### D6: Scope locked to CUE modules only

**Decision:** This enhancement automates CUE module dependency updates only. `go.mod`, GitHub Actions pins, and Dockerfiles are explicitly out of scope and deferred to a possible later enhancement.

**Alternatives considered:**

- One bot for every ecosystem (the multi-ecosystem argument for Renovate, whose native `gomod`/`github-actions`/`dockerfile` managers come free) — rejected for now: it pulls in the whole Renovate apparatus to solve a problem we don't have yet, when the immediate and only felt pain is CUE-dep drift.

**Rationale:** Minimal surface. CUE deps are the concrete gap; the other ecosystems are speculative here. Scoping to CUE keeps the mechanism a small, path-driven function instead of a managed platform.

**Source:** User decision 2026-06-18.

### D7: Path-driven Dagger module replaces self-hosted Renovate

**Decision:** The mechanism is a bespoke, path-driven **Dagger function** — `update(source, cueRegistry, ghcrToken) → Directory` — that walks a directory for CUE modules and bumps each via `cue mod get` + `cue mod tidy`. This **supersedes D1** (no self-hosted Renovate) and **D2** (no `docker` datasource, no route table).

**Alternatives considered:**

- Self-hosted Renovate with a regex custom manager (D1 + D2) — rejected: its detection layer reimplements CUE's resolver as a route table that must mirror `CUE_REGISTRY` by hand (OQ1) plus a regex that parses `module.cue` (OQ2). Both are weaker than what `cue` already does natively, and both are pure maintenance cost.
- Bespoke logic as plain shell in a GitHub Actions workflow — rejected: not reusable locally, and it would be a third copy of the bump logic alongside `task update-deps`, not a shared one.

**Rationale:** `cue mod get <mod>@vN` resolves the latest version within a pinned major, reading `CUE_REGISTRY` directly — so a Dagger wrapper around it needs no route table (OQ1 gone) and no rewrite regex (OQ2 gone). A Dagger function is path-driven and context-free, so the identical call serves local (`dagger call`) and CI (scheduled), and `task update-deps` can wrap it for a single update path (D9). The accepted cost: the Dagger engine becomes a CI dependency in each affected repo.

**Source:** User decision 2026-06-18.

### D8: Major-version pinning is inherent to `cue mod get <mod>@v<major>`

**Decision:** The major is pinned because each deps key carries `@vN` and `cue mod get <mod>@vN` resolves only within major `N`. No packageRule or `major.enabled: false` guard is needed. This **supersedes D3's mechanism**; the property — never auto-cross a major — is preserved.

**Alternatives considered:**

- Renovate's `#pinMajor` packageRule (D3) — rejected together with the Renovate path itself; it existed only to compensate for the `docker` datasource surfacing cross-major OCI tags, a problem CUE's resolver does not have.

**Rationale:** Native CUE semantics enforce the major ceiling; the guard becomes redundant rather than reimplemented.

**Source:** Design analysis 2026-06-18.

### D9: `task update-deps` is reimplemented over the Dagger function

**Decision:** `task update-deps` (`deps:update*` in `/Taskfile.yml`) is reimplemented as a thin wrapper that invokes the same Dagger function the CI workflow uses, so the local sweep and the scheduled job share one implementation. This **supersedes D4** — Renovate is gone, and the relationship is now "one shared implementation," not "two coexisting paths."

**Alternatives considered:**

- Keep the current bash `task update-deps` as an independent implementation (D4's framing) — rejected: duplicate bump logic that must be kept coherent, the exact drawback D4 accepted.
- Remove `task update-deps` entirely — rejected: the fast local one-shot is still wanted; only its implementation is unified, not its interface.

**Rationale:** A single code path eliminates the local-vs-CI drift risk by construction. The `task` interface stays for muscle memory; its body becomes a `dagger call`.

**Source:** User decision 2026-06-18.

### D10: One grouped PR per repo per run, on a fixed branch, daily

**Decision:** The CI workflow opens one grouped CUE-dependency PR per repo per run on a fixed branch (`chore/cue-deps`), refreshed daily. `peter-evans/create-pull-request` on that fixed branch updates the existing open PR in place when new bumps appear, and closes it if the diff reverts. This **resolves OQ3 and OQ6**.

**Alternatives considered:**

- Per-dependency PRs (OQ3) — rejected: noisier, and the per-repo dep set is small (2–3), so isolation buys little.
- A fresh branch per run (OQ6) — rejected: would stack duplicate PRs instead of updating the open one, which is the behavior the user explicitly wanted.

**Rationale:** A small dep set makes grouping low-risk and keeps the review surface to one PR; the fixed branch gives "update the same PR" natively, no custom PR-lifecycle code.

**Source:** User decision 2026-06-18.

### D11: Test-fixture modules are included

**Decision:** The walker bumps every discovered CUE module, including the ~63 `module.cue` files under `library/testdata/` fixtures.

**Alternatives considered:**

- Exclude `testdata/` via a path filter — rejected: fixtures would bit-rot off current deps, and a stale fixture is a worse signal than a reviewable PR.

**Rationale:** Keeping fixtures on current deps surfaces real incompatibilities early. The grouped daily PR (D10) bounds the resulting churn to one PR per repo, and the repo's own `ci.yml` re-vets each bump before merge.

**Source:** User decision 2026-06-18.

### D12: Dagger module in `daggerverse`, reusable workflow in `.github`

**Decision:** The Dagger module lives in an `open-platform-model/daggerverse` monorepo at subpath `cue-deps/` (its own `dagger.json`), following the daggerverse catalog convention, and is independently versioned via subpath-prefixed git tags (`cue-deps/vX.Y.Z`). The reusable `workflow_call` GitHub workflow lives in `open-platform-model/.github`. Each consumer repo's caller `uses:` the workflow in `.github`, which invokes the module from `daggerverse`. Resolves OQ4.

**Alternatives considered:**

- A single host repo (`open-platform-model/.github`) holding both the module and the reusable workflow — rejected: mixes the org's module catalog with its reusable-CI surface; the daggerverse convention keeps all org Dagger modules discoverable and independently versioned in one place, separate from workflow definitions.
- A dedicated `open-platform-model/cue-deps` repo — rejected: a whole repo for one module; the daggerverse monorepo is the idiomatic home and absorbs future modules without new repos.

**Rationale:** "daggerverse" is the established convention for an org-level monorepo/catalog of Dagger modules — each in its own subdirectory with independent subpath-prefixed version tags. Reusable GitHub workflows conventionally live in the org `.github` repo. The split puts each artifact in its idiomatic home: versioned, discoverable Dagger units in `daggerverse`; org-shared CI in `.github`.

**Source:** User decision 2026-06-18; daggerverse pattern — [docs.dagger.io/api/daggerverse](https://docs.dagger.io/api/daggerverse/), [Dagger 0.13 monorepo support](https://dagger.io/blog/dagger-0-13).

### D13: Multi-ecosystem parked — deferred to a separate enhancement after investigating Renovate-in-Dagger

**Decision:** Go and other non-CUE ecosystems stay fully out of scope for 0004. The CUE-only design ships as-is; multi-ecosystem automation, if pursued, lands as a separate future enhancement rather than by widening 0004. This reaffirms and closes D6.

**Alternatives considered:**

- **Architecture A — wrap Renovate in Dagger and let Renovate do everything** (Go natively + CUE via a `customManagers` regex manager). Rejected: a deep-research review confirmed it reintroduces the `CUE_REGISTRY`-mirroring route table and the `module.cue`-parsing regex that D7 eliminated (un-deciding D7/D8 for no gain), and a verified execution-model mismatch makes it a leaky abstraction — Renovate is platform-integrated (clones, branches, and opens PRs via the platform API, requiring a token) and has **no mode that runs offline/local AND mutates files**, unlike the CUE path's `update(source) → Directory`. (`--platform=local` supports only `dryRun` `lookup`/`extract`; `full` errors with "Cannot sync git when platform=local".)
- **Architecture B — one composed Dagger module with two internal paths** (keep the bespoke `cue mod` path; add a `renovate()` function depending on an existing daggerverse Renovate module for Go/other, with Dagger orchestrating). Feasible and the honest form of "two engines under one orchestrator" — but it is a single invocation surface over two distinct engines with different PR models, not a unified engine, and it adds self-hosted Renovate plus platform-token plumbing. **Deferred, not rejected:** it is the documented starting point for the future multi-ecosystem enhancement.
- **Defer Go to Dependabot now** — a viable minimal-effort path (one `dependabot.yml` per Go repo, native CVE updates). Not adopted into 0004 because it is orthogonal CI config a Go repo can add independently, with no bearing on this CUE-focused design.

**Rationale:** Keep 0004 a small, coherent, shippable CUE-only design. The research established that folding in Go via Renovate is feasible but either leaky (A) or a second engine bolted alongside (B) — neither belongs inside a CUE-dependency enhancement. Parking preserves the option (B is the recorded starting point) without blocking 0004.

**Source:** User decision 2026-06-18; deep-research report 2026-06-18 — Renovate execution-model mismatch ([local platform](https://docs.renovatebot.com/modules/platform/local/), [renovate#27498](https://github.com/renovatebot/renovate/discussions/27498)); existing daggerverse Renovate modules `github.com/act3-ai/dagger/renovate`, `github.com/chrira/dagger-renovate`.

---

## Open Questions

- **OQ1: How is the route table kept in sync with `CUE_REGISTRY`?** Status: resolved-by-D7 (eliminated). The Dagger function calls `cue`, which reads `CUE_REGISTRY` directly; there is no route table to keep in sync, so the drift risk no longer exists.
- **OQ2: What exact regex robustly matches the deps block?** Status: resolved-by-D7 (eliminated). `cue mod get` + `cue mod tidy` read and rewrite the deps block natively; there is no rewrite regex. The function still reads the deps *keys* to feed `cue mod get`, exactly as the current bash task does — robust enough and not version-string-fragile.
- **OQ3: One grouped CUE-bump PR per repo per run, or a PR per dependency?** Status: resolved-by-D10. Grouped, one PR per repo per run.
- **OQ4: Which repo hosts the shared Dagger module + reusable workflow?** Status: resolved-by-D12. Split: the Dagger module lives at `open-platform-model/daggerverse` subpath `cue-deps/` (subpath-prefixed version tags `cue-deps/vX.Y.Z`); the reusable `workflow_call` workflow lives at `open-platform-model/.github`.
- **OQ5: Should the walker touch `library/testdata/` fixtures (~63 module.cue)?** Status: resolved-by-D11. Yes — included.
- **OQ6: Scheduling cadence and PR/branch behavior per repo.** Status: resolved-by-D10. Daily; a fixed branch (`chore/cue-deps`) so the open PR is updated in place rather than duplicated.
