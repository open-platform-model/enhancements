# Graduation Criteria — Initialize a Module Instance Package from a Published Module

This document records the gates that must hold before the enhancement
advances along the design lifecycle. Treat these as design acceptance
criteria, not as implementation milestones — implementation progress lives
in `config.yaml.implementation` and the `history` list.

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

## accepted → implemented

The enhancement is shipped when:

- `core/src/module.cue` carries the new optional field per `schemas/target.cue`, landed under the `core-schema-edit` protocol with its `SPEC.md` co-update and `src/INDEX.md` regeneration, and published on the v2 line (a `feat:` — additive).
- The CLI command exists under `cli/internal/cmd/instance/`, registered in the `instance` command group, with test coverage for: the values-source precedence ladder (new field → `debugValues` → empty per OQ3), the generated three-file package loading through `LoadInstancePackage`, and a generated package building successfully via `opm instance build` against a registry-acquired module fixture.
- The generated `cue.mod/module.cue` pins the resolved module version and the correct core major per OQ6's decision, covered by a test against a module whose core major differs from the CLI's own default.
- If OQ4 chose a shared library renderer: the exported helper lands in `library` with synth rewired onto it, and `library task check` is green before the CLI consumes it.
- `opm instance init` output reports the resolved version and values source per `#InstanceInitReport`.
- The CLI reference on `opmodel.dev` regenerates after the command lands (follows, does not gate).
- `config.yaml.implementation.status = complete` with `date` set to the landing date; `history` carries one or more events naming the landing milestone(s), with `slice:` refs to the OpenSpec changes in each target repo.
- `README.md` carries the `> **Implementation status (YYYY-MM-DD).**` quote block whose date matches `implementation.date`, and `## Deviations from Design` lists every deliberate divergence (or says "None").
