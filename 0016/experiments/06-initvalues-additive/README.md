# 06-initvalues-additive — Initialize a Module Instance Package from a Published Module

Status: Concluded

## Hypothesis

Adding `initValues?: _` to `#Module` invalidates no existing module, and a module that *sets* `initValues` evaluated against the core schema **without** the field is either accepted or rejected in a way this experiment states unambiguously. Backs D3 and D4, and decides whether 06-operational must name a core version floor for authors adopting the field.

## Setup

Pure CUE inside a throwaway module `experiment06.local/x@v0` (language `v0.17.0`). `schemaold/` is a byte copy of `core/src/*.cue` (core commit a11aefc, package `core`); `schemanew/` is the same copy with the one-line `initValues?: _` added beside `debugValues` in `module.cue`. Fixtures import the schema as `experiment06.local/x/schemaold:core` (explicit package qualifier, since the directory name differs from the package name).

Two modifications to the copy, both outside the schema definitions: core's pin fixture files (`platform_and_match_pins.cue`, `identity_pins.cue`, `identity_package_pins.cue`, which are core's own tests, not schema) are not copied, and one explanatory comment in `module_instance.cue` was reworded. Every definition is byte-identical to core.

Two hand-written fixture modules per matrix cell, mirroring the `#config`/`debugValues` shape of `modules/cert_manager` and `modules/metallb` (modules commit 7c946b0) with catalog imports removed so the experiment is self-contained. `matrix/plain-*` carry only `debugValues`; `matrix/init-*` additionally set `initValues`. `run.sh` vets all four cells and reads `initValues` back through the new schema.

## Run

```bash
bash run.sh
```

## Outcome

**Hypothesis held; the interesting cell rejects.** Run 2026-08-24.

| Fixture | schema without the field | schema with the field |
| --- | --- | --- |
| plain (debugValues only) | vet passes | vet passes |
| with `initValues` | **`certManager.initValues: field not allowed`** (and the same for metallb) | vet passes; `initValues.controller` reads back as `{logLevel: 2, replicas: 1}` |

- The change is additive for every existing module (both `plain` cells pass).
- `#Module` is a closed definition, so a module that sets `initValues` does not evaluate against a core that lacks the field. An author adopting `initValues` must first move the module's `opmodel.dev/core@v2` pin to the tag that ships the field. That is a **core version floor within the v2 line**, written into 06-operational (Semver Impact, Cross-Repo Coordination) and 05-risks on 2026-08-24. It is not a breaking change (no existing module changes behavior); it is the ordinary "new field, new minimum" of any additive schema change.

Evidence linked from D4's `Source:` in `../../03-decisions.md`.
