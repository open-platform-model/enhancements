# Graduation Criteria — Automated CUE Dependency Updates via Dagger

This document records the entry-specific gates that must hold before this design is frozen.

## draft → accepted

The enhancement is ready to be implemented when:

- Goals and Non-Goals in `02-design.md` are final and reviewed.
- Every decision (D1..DN) is locked, and every Open Question is resolved (`resolved-by-D##`, `deferred-to-NNNN`, or `answered`). OQ1, OQ2, OQ3, OQ4, OQ5, OQ6 are all closed.
- `contracts/contracts.cue` compiles (`cue vet ./...` from the directory passes) and the `#UpdateFn` signature is the one the implementation will expose.
- `related` (`0002`) resolves to an existing enhancement; `supersedes` / `superseded_by` are final.
- `semver` in `config.yaml` is set (`none`).
- No `{Capitalised}` placeholder strings remain in any markdown file.
- Cross-References table in `README.md` lists every file path the implementation will touch.
