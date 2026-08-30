# Open Questions: Automated CUE Dependency Updates via Dagger

## Open Questions

- **OQ1: How is the route table kept in sync with `CUE_REGISTRY`?** Status: resolved-by-D7 (eliminated). The Dagger function calls `cue`, which reads `CUE_REGISTRY` directly; there is no route table to keep in sync, so the drift risk no longer exists.
- **OQ2: What exact regex robustly matches the deps block?** Status: resolved-by-D7 (eliminated). `cue mod get` + `cue mod tidy` read and rewrite the deps block natively; there is no rewrite regex. The function still reads the deps *keys* to feed `cue mod get`, exactly as the current bash task does: robust enough and not version-string-fragile.
- **OQ3: One grouped CUE-bump PR per repo per run, or a PR per dependency?** Status: resolved-by-D10. Grouped, one PR per repo per run.
- **OQ4: Which repo hosts the shared Dagger module + reusable workflow?** Status: resolved-by-D12. Split: the Dagger module lives at `open-platform-model/daggerverse` subpath `cue-deps/` (subpath-prefixed version tags `cue-deps/vX.Y.Z`); the reusable `workflow_call` workflow lives at `open-platform-model/.github`.
- **OQ5: Should the walker touch `library/testdata/` fixtures (~63 module.cue)?** Status: resolved-by-D11. Yes, included.
- **OQ6: Scheduling cadence and PR/branch behavior per repo.** Status: resolved-by-D10. Daily; a fixed branch (`chore/cue-deps`) so the open PR is updated in place rather than duplicated.
