# Graduation Criteria — Automated CUE Dependency Updates via Dagger

This document records the gates that must hold before the enhancement advances along the design lifecycle.

## draft → accepted

The enhancement is ready to be implemented when:

- Goals and Non-Goals in `02-design.md` are final and reviewed.
- Every decision (D1..DN) is locked, and every Open Question is resolved (`resolved-by-D##`, `deferred-to-NNNN`, or `answered`). OQ1, OQ2, OQ3, OQ4, OQ5, OQ6 are all closed.
- `schemas/target.cue` compiles (`cue vet ./...` from the directory passes) and the `#UpdateFn` signature is the one the implementation will expose.
- `related` (`0002`) resolves to an existing enhancement; `supersedes` / `superseded_by` are final.
- `semver` in `config.yaml` is set (`none`).
- No `{Capitalised}` placeholder strings remain in any markdown file.
- Cross-References table in `README.md` lists every file path the implementation will touch.

## accepted → implemented

The enhancement is shipped when:

- The Dagger module (`open-platform-model/daggerverse//cue-deps`, exposing `#UpdateFn`, tagged `cue-deps/vX.Y.Z`) and the reusable `workflow_call` workflow (`open-platform-model/.github`) are committed (D12).
- `/Taskfile.yml`'s `task update-deps` is reimplemented as a wrapper over the Dagger function (D9), and a local `dagger call update --source=.` reproduces the bump the old bash task produced.
- Each affected repo (`core`, `library`, `catalog`, `cli`, `opm-operator`, `modules`) carries a `.github/workflows/cue-deps.yml` caller — daily `schedule`, `uses:` the reusable workflow, passing `CUE_REGISTRY` and a GHCR `read:packages` token — that opens a grouped PR on `chore/cue-deps` (D10).
- The walker handles the CLI's `module.cue.tmpl` templates (render-to-scratch sub-case) and the `library/testdata/` fixtures (D11) without error.
- At least one pilot repo has produced a real grouped dependency-bump PR whose `cue mod tidy` ran and whose `ci.yml` passed — end-to-end proof, ideally recorded as an experiment under `experiments/`.
- `config.yaml.implementation.status = complete` with `date` set to the landing date.
- `history` carries events naming the Dagger module landing, the `task update-deps` rewire, and each repo onboarding.
- `README.md` carries an `> **Implementation status (YYYY-MM-DD).**` quote block whose date matches `implementation.date`.
- `## Deviations from Design` in `README.md` lists every deliberate divergence (or says "None").
