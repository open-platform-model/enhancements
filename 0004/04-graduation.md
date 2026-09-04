# Graduation Criteria: Automated CUE Dependency Updates via Dagger

These are design acceptance criteria checked before promoting this design from draft to accepted; delivery is tracked separately in `delivery.yaml`.

## draft → accepted

Seven gates must all hold before promoting this design from draft to accepted:

1. Goals and Non-Goals in `02-design.md` are final and reviewed.
2. Every decision (D1..DN) is locked, and every Open Question is resolved (`resolved-by-D##`, `deferred-to-NNNN`, or `answered`). OQ1, OQ2, OQ3, OQ4, OQ5, OQ6 are all closed.
3. `contracts/contracts.cue` compiles (`cue vet ./...` from the directory passes) and the `#UpdateFn` signature is the one the implementation will expose.
4. `depends_on`, `supersedes`, `superseded_by` in `config.yaml` are final and resolve; every `depends_on` id is carried by a `**Depends:**` line in a live decision.
5. `semver` in `config.yaml` is set (`none`).
6. No `{Capitalised}` placeholder strings remain in any markdown file.
7. Cross-References table in `README.md` lists every file path the implementation will touch.
