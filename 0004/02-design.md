# Design — Automated CUE Dependency Updates via Dagger

This document answers the question: "What is the proposed solution and how does it work?"

## Design Goals

- A new upstream version of any CUE dependency in any `cue.mod/module.cue` across the affected repos produces a pull request in that repo, without human polling.
- Detection runs on a schedule in CI, per repo, using each repo's own checkout — no full-workspace layout required.
- The bump mechanism is **one implementation** invoked identically locally and in CI, so `task update-deps` and the scheduled job cannot drift apart.
- Each PR is a *consistent* module — `cue mod tidy` has run, so the bump is not a bare version-string edit that the repo's own `cue vet` would later reject.
- A dependency's pinned major (`@vN` in the deps key) is never crossed automatically; a `v0`→`v1` move is a deliberate human action.
- The shared compute and CI wiring live in one place and are reused by every repo, so adding a repo does not mean re-authoring the logic.

## Non-Goals

- Multi-ecosystem dependency updates. `go.mod`, GitHub Actions pins, and Dockerfiles are out of scope; this enhancement automates CUE modules only (D6). A unified bot is a separate, later enhancement.
- Auto-merging dependency PRs. PRs are opened for human review; auto-merge policy is a later, separate decision.
- Bumping the CUE language/tool version (`language.version` in `module.cue`). Possible as a follow-on, explicitly out of this entry's scope.
- Cross-major migrations (`@v0`→`@v1`), which change import paths and require code changes.

## High-Level Approach

The mechanism is a **path-driven Dagger function**. Point it at a directory; it walks for CUE modules and bumps each one's dependencies using CUE's own resolver. This is the existing `task update-deps` logic — parse the `deps:` keys, run a single `cue mod get <dep>@v<major>` resolution pass, then `cue mod tidy` — lifted out of bash into a typed, containerized Dagger module so it runs the same way everywhere.

The function takes three inputs: the `source` directory to walk, the `CUE_REGISTRY` value, and a GHCR token (`read:packages`) for the internal `opmodel.dev/*` modules. It returns the mutated directory plus an old→new summary. Because it is path-driven and context-free, the **same** invocation serves two callers:

- **Local:** `dagger call update --source=. --cue-registry=$CUE_REGISTRY --ghcr-token=env:GH_TOKEN export --path=.`, and `task update-deps` is reimplemented as a thin wrapper over exactly this call (D9). One code path, not two.
- **CI:** a daily scheduled workflow runs the identical call, then hands the mutated tree to `peter-evans/create-pull-request` on a **fixed branch** (`chore/cue-deps`), which opens one grouped PR and updates it in place on subsequent runs rather than stacking duplicates (D10).

Two properties fall out of using CUE's native resolver instead of a third-party manager:

- **No registry route table.** `cue` reads `CUE_REGISTRY` directly to map each module host to its OCI registry. The design never mirrors that mapping, so it cannot drift from it (eliminates OQ1).
- **No `module.cue`-parsing regex.** `cue mod get` and `cue mod tidy` read and rewrite the deps block themselves. There is no brittle regex rewriting version strings (eliminates OQ2). The only parsing is reading the existing deps *keys* to feed `cue mod get`, exactly as the current bash task does.

The major is pinned for free: each deps key already carries `@vN`, and `cue mod get <mod>@vN` resolves only within major `N` (D8). No extra guard is needed.

## Schema / API Surface

The full contract is in [`schemas/target.cue`](schemas/target.cue). It models the CI wiring, authored in CUE and exported to YAML — the same CUE-as-source-of-truth pattern the superseded Renovate design used for its preset, now pointed at the workflow. Headline constructs:

- `#UpdateFn` — the Dagger function signature every consumer depends on: `{ source, cueRegistry, ghcrToken } → Directory`. The stable contract reused local + CI.
- `#RegistryAuth` / `#auth` — which backing OCI registries need credentials (`ghcr.io` → `read:packages`; `registry.cue.works` → public reads). This is the only registry config left, and unlike the old route table it does not duplicate `CUE_REGISTRY`'s host→registry map — it only names auth needs.
- `#PRConfig` — the fixed branch, grouped flag, and daily schedule (D10).
- `config` — assembles the function ref, auth needs, and PR config into the exported contract.

## Integration Points

- **`open-platform-model/daggerverse` (D12):** the Dagger module at subpath `cue-deps/` (its own `dagger.json`, exposing `update`/`#UpdateFn`), following the daggerverse catalog convention and independently versioned via subpath-prefixed tags (`cue-deps/vX.Y.Z`).
- **`open-platform-model/.github` (D12):** the reusable `workflow_call` workflow (`.github/workflows/cue-deps.yml`) that invokes the daggerverse module and opens the PR, authored once.
- **Each affected repo (`core`, `library`, `catalog`, `cli`, `opm-operator`, `modules`):** a ~10-line `.github/workflows/cue-deps.yml` caller — a daily `schedule` trigger, `uses: open-platform-model/.github/.github/workflows/cue-deps.yml@…`, passing `CUE_REGISTRY` and the GHCR token. No per-repo module-dir list: discovery is path-driven.
- **`/Taskfile.yml`:** `task update-deps` (`deps:update*`) is reimplemented to call the Dagger function so the local sweep and CI share one implementation (D9). The CLI's `module.cue.tmpl` templates are a discovery sub-case the function must handle (render-to-scratch, as the current task does) — they are not valid CUE modules until rendered.
- **`library` note:** ~63 `module.cue` files, most under `testdata/` fixtures, are included — keeping them on current deps avoids bit-rot, accepting some PR churn (D11).

## Before / After

Scenario: `opmodel.dev/core` cuts `v0.6.0`.

Before — `modules/jellyfin/cue.mod/module.cue` stays at `"opmodel.dev/core@v0": { v: "v0.5.0" }` until a maintainer runs `task update-deps` on a full-workspace checkout and pushes each repo.

After — the next daily Dagger run in the `modules` repo walks the checkout, finds the module, runs `cue mod get opmodel.dev/core@v0` (which `cue` resolves to `v0.6.0` within major `v0` via `CUE_REGISTRY`), runs `cue mod tidy`, and opens (or updates) a grouped PR on `chore/cue-deps` titled e.g. `chore(deps): bump CUE deps` with the old→new summary. A reviewer merges; release-please does the rest. `task update-deps` runs the same function for local sweeps.
