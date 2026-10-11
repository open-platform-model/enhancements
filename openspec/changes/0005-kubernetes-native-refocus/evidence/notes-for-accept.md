# Notes for the owner at accept

These points come from the conversion and its review. The old entry did not hold them as open questions, so they are not in the proposal. The owner decides each at accept.

- **The premise: the entry regenerates a mirror that was retired.** The entry regenerates the `k8s@v1` mirror catalog from one shared source (old 0005:D1, whose measurement names that mirror). The `catalog_opm` repo retired that mirror on 2026-10-02. The conversion stays faithful to the old text. The owner decides at accept whether the premise still holds.
- **`breaking` is `false` and the old text calls the change a breaking minor.** The old `config.yaml` had no `semver` key, so the conversion set `breaking: false`. The old `operational.md` says that regeneration "may tighten or rename schemas, which is a breaking minor for modules pinning them", and absorbs this in the pre-1.0 cadence. The catalogs have since moved to major versions, so the design says that argument does not hold as written. The owner settles `breaking` at accept.
