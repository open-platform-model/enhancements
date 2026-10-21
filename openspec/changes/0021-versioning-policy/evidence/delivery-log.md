# Delivery log: 0021

The old `delivery.yaml` of 0021, kept as a record. The landed repo changes are ticked in `../tasks.md` with their change names. Source: `delivery.yaml` of `0021` at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements`. Decision and requirement numbers below are the old ones; the old text is `decision-log.md`. The old log held no `no_work` claims.

| Date | Repo | What landed | Change |
| --- | --- | --- | --- |
| 2026-10-01 | core | The publish job refuses a version GHCR already holds, and the publish task targets only a local registry (D10 R2 and R3 for core). | `guard-release-immutability` |
| 2026-10-01 | opm-controller | Draft-first release: assets attach to the draft and it is published last, and the image push refuses to re-point a version tag (D10 R1, R3 and R8 for the controller). | `adopt-draft-first-release` |
| 2026-10-01 | cli | Draft-first release: release-please drafts the release, goreleaser fills and publishes it, and recovery refuses a published one (D10 R1 and R8 for the CLI). | `adopt-draft-first-release` |
| 2026-10-05 | library | Registry fetch failures are typed as they leave the library (`ErrTransient`, `FetchError`, `Classify`). Author-defect resolution failures stayed unclassified by design, and the CLI still matched one by text, so D8 R12 waited on an owner ruling. | `type-fetch-errors-and-check-cancellation` |
| 2026-10-05 | opm-controller | The controller decides retry or stall from the library's typed fetch errors, instead of an acquisition marker and a network-error probe, for every kernel call. D8 R12 itself is the library's. | `classify-registry-errors-by-type` |
| 2026-10-05 | cli | The CLI reads its connectivity, unpublished and absent answers from the library's typed fetch errors, with exit codes unchanged. Two text matches stay (compat unprovided import, platform build hint). D8 R12 itself is the library's. | `classify-registry-errors-by-type` |
| 2026-10-05 | library | Library issue 218: author-defect resolution failures leave the library typed as `ResolutionError` with a kind, by the owner's strict reading of D8 R12. This is the library half of R12. | `type-author-resolution-errors` |
| 2026-10-08 | cli | CLI issue 346: the CLI decides fetch and resolution answers from the library's error types, and a guard test refuses a new text match. Four named text matches stay, none a fetch or resolution failure (D8 R12, CLI half). | `drop-resolution-text-matches` |
| 2026-10-08 | library | Library issue 222: a token endpoint's 401 or 403 classifies as unauthorized instead of unreachable, through one anchored text match inside the library. This is the owner's recorded exception to D8 R12 (library ADR-014). | `classify-token-endpoint-refusal` |

## Ticks that the old log did not hold

Five lines of `../tasks.md` are ticked from the repos, not from the old log. They were found on 2026-10-11 by reading the archived changes in the sibling checkouts.

- `install-operator-from-module` (cli) and `release-operator-module` (opm-controller) each carry an `enhancement.yaml` that declares 0021 (decision D11, and D9 for the CLI one). The old log did not hold them.
- `adopt-beta-release-line` (core, cli and opm-controller) states in its proposal that it moves the line to beta and, for the CLI, compares only `MAJOR.MINOR` in the ceiling. None of the three declares 0021 in an `enhancement.yaml`.

Not ticked and found in the same read: `add-operator-module` (opm-controller, authors the module, no declaration of 0021) and `stop-operator-install-manifest` (opm-controller, open, marked blocked in its own proposal).
