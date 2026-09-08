# Open Questions: Rename the Release artifact family to Instance vocabulary (cross-cutting)

## Open Questions

All four open questions are now resolved (2026-06-22). They were the crux that determined whether this stayed core-only or became cross-repo; the user chose the cross-repo, fully-consistent path, which is recorded in D2–D8.

- **OQ1: Does the `kind` discriminator string change from `"ModuleRelease"` to `"ModuleInstance"`?** Status: resolved-by-D3 (yes: `kind` strings move, including `BundleInstance` and the GitOps `ModulePackage` kind).

- **OQ2: Does the label domain change from `module-release.opmodel.dev/*` to `module-instance.opmodel.dev/*`?** Status: resolved-by-D4 (yes: label keys move everywhere defined and consumed).

- **OQ3: Hard rename, or a transition window with a `#ModuleRelease` alias in `core`?** Status: resolved-by-D8 (hard rename, no alias: pre-`v1` core, no external CLI/operator users).

- **OQ4: Confirm `config.yaml.semver: major` and the CUE-module tag mechanics.** Status: resolved-by-D8 (`semver: major` design impact), release-axis mechanics later revised by D13 (artifacts ship as `v1.x.x-alpha.x` prereleases; core advances to `opmodel.dev/core@v1`, superseding D8's `v0.x` minor).
