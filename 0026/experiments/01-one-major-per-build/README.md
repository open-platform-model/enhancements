# 01-one-major-per-build: Module-Dictated Catalog Versions and the Generated Platform

Status: Concluded

## Hypothesis

A single build that holds two majors of one catalog whose contract keys are shared fails to evaluate under today's `core`, while one build per major of that catalog evaluates cleanly, so a platform can carry two majors side by side only if no build ever holds both (D9 R2, R3).

## Setup

Copied, unmodified, from `core/src/` at commit `cbe93e0` (two commits after release `2.0.0-alpha.12`, on the published `opmodel.dev/core@v2` line; those two commits changed only comments in `resource.cue` and `trait.cue`): `types.cue`, `resource.cue`, `trait.cue`, `blueprint.cue`, `transformer.cue`, `catalog.cue`, `platform.cue`. These seven files are the whole closure the probe needs; the pin files, the module and instance definitions and the identity package were left out. `platform.cue` here is the shipped `#Platform`, which D3 renames `#ResolvedPlatform` with its shape unchanged, so it is the render-time value this entry generates.

Added, all in `probe/` beside the copies:

- `members.cue`: one member source instantiated as two majors of one catalog, `opmodel.dev/catalogs/opm@v4` at 4.2.0 and `opmodel.dev/catalogs/opm@v5` at 5.0.0. Each defines a `container` resource and a provider-fulfilled `backup` trait under the same contract keys (keys carry no catalog major, 0010 D4) and ships a deployment transformer requiring the container.
- `case_shared.cue`: case A, both majors enabled in one build. Guarded by `@if(shared)` so the other cases can be read without its errors.
- `builds.cue`: case C (both majors present, only v4 lists the contracts, v5 ships its transformer alone: this sidesteps case A's conflict to show what the demand fold does with two majors' transformers on one key), case D (v5 on record but disabled), and case E (one build per major, `perMajorV4` and `perMajorV5`).

The probe mirrors cases A, C and D of a scratch probe run the same day against a full copy of `core/src` at the same commit, which gave the same results.

## Run

From `probe/`, with cue v0.17.1:

```bash
cue vet -c=false .                                              # cases C, D, E evaluate
cue eval -t shared -e twoMajorsShared.#contracts .              # case A
cue eval -e oneListerBothTransformers.#contracts .              # case C
cue eval -e oneMajorDisabled.#contracts .                       # case D
cue eval -e perMajorV4.#contracts . && cue eval -e perMajorV5.#contracts .   # case E
```

## Outcome

Measured 2026-09-30, cue v0.17.1.

- **Case A, both majors in one build: fails to evaluate.** Four conflicts, two per shared key, file references elided:

  ```
  twoMajorsShared.#contracts.defined."opmodel.dev/catalogs/opm/resources/container@v1beta1".metadata.catalogVersion: conflicting values "4.2.0" and "5.0.0"
  twoMajorsShared.#contracts.defined."opmodel.dev/catalogs/opm/traits/backup@v1alpha1".metadata.catalogVersion: conflicting values "4.2.0" and "5.0.0"
  twoMajorsShared.#contracts.definedBy."opmodel.dev/catalogs/opm/resources/container@v1beta1": conflicting values "opmodel.dev/catalogs/opm@v5" and "opmodel.dev/catalogs/opm@v4"
  twoMajorsShared.#contracts.definedBy."opmodel.dev/catalogs/opm/traits/backup@v1alpha1": conflicting values "opmodel.dev/catalogs/opm@v5" and "opmodel.dev/catalogs/opm@v4"
  ```

  This violates core SPEC.md § 3.4's "No report MUST make the platform value fail to evaluate", which the shipped fold was written to keep: the fold was never designed for two definers of one key.
- **Case C, conflict sidestepped: both majors' transformers claim the same contract.** `requiredBy` for the container key lists `deployment-transformer@4.2.0` and `deployment-transformer@5.0.0`, `comparable` reports the pair, and `discriminated` is `false`. Inside one build a v4 component would be claimed by the v5 transformer too.
- **Case D, one major disabled: evaluates.** `definedBy` names opm@v4 only, `routable: true`, `discriminated: true`. This is the only side-by-side shape that works today: one major at a time.
- **Case E, one build per major: both evaluate.** Each `definedBy` names its own major and each `requiredBy` lists only its own major's transformer.

**Hypothesis held.** Two majors of one catalog cannot share a build under today's contract keys, and one build per major works with no change to `core`, the fold or matching. Linked from D9 in `03-decisions.md` and from `05-risks.md`.
