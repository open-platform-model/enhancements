# Dev-tag range pollution on the consumer registry path

**Date:** 2026-07-20. **Status:** verified finding, fix deferred (OQ18). **Source session:** A5 planning (explore mode), verified against live GHCR state and `library` source.

## Finding

CI branch-publish workflows push per-commit prerelease tags of the form `v1.0.0-dev.<epoch>.g<shortsha>` to the **same GHCR path consumers resolve** (`ghcr.io/open-platform-model` → `opmodel.dev/…`). Verified for `catalog_opm` (`.github/workflows/branch-publish.yml`, "Publish opmodel.dev/catalogs/opm (dev tag)", `task publish:branch`); `core` and `catalog_kubernetes` follow the same pattern. Observed on GHCR 2026-07-20: `opmodel.dev/catalogs/opm` carries `v1.0.0-alpha`, `v1.0.0-alpha.1`, and multiple `v1.0.0-dev.*` tags.

Semver prerelease ordering compares dot-separated identifiers alphanumerically: `alpha < alpha.1 < dev.*` — so **every `v1.0.0-dev.*` tag sorts above every `v1.0.0-alpha*` tag**.

`library/opm/materialize/filter.go` `filterVersions` (shared by the operator and, since 0006 C2, the CLI) applies `filter.range` as a Masterminds constraint per published version. A constraint carrying a prerelease identifier (e.g. `>=1.0.0-alpha`) admits *all* matching prereleases — including `-dev.*` — and materialization picks the highest of the selected set. Consequences:

- **Any prerelease-tolerant open range resolves whatever dev build published last.** Non-reproducible by construction, and a transformer-FQN skew machine: FQNs embed the catalog version, so a platform materializing `v1.0.0-dev.X` cannot match modules built against `v1.0.0-alpha.1` → `component has no matching transformer`.
- **Affected consumers found:** `opm-kind-demo`'s Platform (`range: ">=1.0.0-alpha"` — fixed in A5 by pinning exactly `1.0.0-alpha.1`) and the CLI's seeded subscription ranges from `opm config init` (`>=1.0.0-0 <2.0.0-0`, C2/LD8 — **still exposed**). Any user-authored Platform with an open prerelease range shares the exposure.
- The stable path is safe: an empty filter selects `highestStable` (non-prerelease only), and ranges without prerelease identifiers exclude prereleases under Masterminds semantics. The trap is exactly the prerelease-era opt-in range that every current consumer needs while the catalogs ship alphas.

## Candidate fixes (deferred — OQ18)

1. **Publish-channel separation** (bias of the A5 session): branch-publish retargets dev builds to a non-consumer path — `testing.opmodel.dev/…` already exists in the workspace registry mapping for exactly this. Consumer path then carries only release-please-cut versions. Touches `catalog_opm`/`catalog_kubernetes`/`core` CI only; no schema or kernel change.
2. **Filter-level default-deny**: `filterVersions` excludes `-dev.` prereleases unless explicitly allowed (`filter.allow`). Kernel-contract change shared by both actors; needs its own slice + spec update; risks surprising anyone intentionally consuming dev builds.
3. Both (defense in depth).

## Trip-wires while unfixed

- Never ship an open prerelease range in a pinned/reproducible context (the demo's exact pin is the pattern).
- The CLI's seeded ranges make fresh `opm config init` setups dev-tag-hostage; if a user reports nondeterministic renders or FQN mismatches after a green CI day, check which catalog version materialized (`Platform` status / render provenance) before debugging modules.
