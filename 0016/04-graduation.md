# Graduation Criteria — Initialize a Module Instance Package from a Published Module

This document records the entry-specific gates that must hold before this design is frozen. Treat these as design acceptance
criteria, not as implementation milestones — delivery is derived from this entry's `delivery.yaml` log and read back with `task delivery`; the entry's documents store nothing about it.

## draft → accepted

The enhancement is ready to be implemented when:

- Goals and Non-Goals in `02-design.md` are final and reviewed.
- OQ1 is resolved: the new `#Module` field's final name, shape, and its relation to `#config` (schema-asserted vs init-time-reported conformance) are decided and reflected in `schemas/target.cue`.
- OQ2 is resolved: the command surface (flags/positionals), the accepted reference syntax, and missing-`--version` resolution semantics are locked.
- OQ3 is resolved: the empty-source scaffold behavior (bare struct vs `#config`-derived skeleton vs refuse) is decided.
- OQ4 is resolved: the renderer's home (shared library helper vs CLI-side) is decided, and `config.yaml.affects` matches the answer (with or without `library`).
- OQ5 is resolved: init-time validation policy is decided, including the failure mode for a template source that does not satisfy `#config`.
- OQ6 is resolved: the generated `cue.mod/module.cue` pinning and dep-closure strategy is decided.
- `schemas/target.cue` and `contracts/contracts.cue` compile (`cue vet ./...` from `schemas/` and from `contracts/` passes) and together capture the target shape end-to-end with no remaining `// OQN:` markers on undecided fields.
- `config.yaml.semver` is set. Expectation: `minor` — the core change is one additive optional field.
- Cross-References table in `README.md` lists every file path the implementation will touch, each verified to exist.
- No `{Capitalised}` placeholder strings remain in any markdown file; `task vet:one ID=0016` and `task check ID=0016` pass (or deferred warnings are documented in the PR body).
