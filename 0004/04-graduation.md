# Graduation Criteria — Automated CUE Dependency Updates via Renovate

This document records the gates that must hold before the enhancement advances along the design lifecycle.

## draft → accepted

The enhancement is ready to be implemented when:

- Goals and Non-Goals in `02-design.md` are final and reviewed.
- Every decision (D1..DN) is locked, and every Open Question is resolved (`resolved-by-D##`, `deferred-to-NNNN`, or `answered`). In particular OQ2 (regex) and OQ4 (preset host repo) must close, since both block any implementation slice.
- `schemas/target.cue` compiles (`cue vet ./...` from the directory passes) and the regex in `#CustomManager.matchStrings` is the spike-validated form, not the sketch.
- `related` (`0002`) resolves to an existing enhancement; `supersedes` / `superseded_by` are final.
- `semver` in `config.yaml` is set (`none`).
- No `{Capitalised}` placeholder strings remain in any markdown file.
- Cross-References table in `README.md` lists every file path the implementation will touch.

## accepted → implemented

The enhancement is shipped when:

- The shared preset is exported from `schemas/target.cue` to a committed `renovate/opm-cue.json5` in the host repo (OQ4), with a regenerate task.
- Each affected repo (`core`, `library`, `catalog`, `cli`, `opm-operator`, `modules`) carries a `renovate.json` extending the preset and a `.github/workflows/renovate.yml` running self-hosted Renovate with `cue`, `CUE_REGISTRY`, GHCR `read:packages`, and `cue mod tidy` allow-listed.
- At least one pilot repo has produced a real dependency-bump PR whose `cue mod tidy` ran and whose `ci.yml` passed — end-to-end proof, ideally recorded as an experiment under `experiments/`.
- `config.yaml.implementation.status = complete` with `date` set to the landing date.
- `history` carries events naming the preset landing and each repo onboarding.
- `README.md` carries an `> **Implementation status (YYYY-MM-DD).**` quote block whose date matches `implementation.date`.
- `## Deviations from Design` in `README.md` lists every deliberate divergence (or says "None").
