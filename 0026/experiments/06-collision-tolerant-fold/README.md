# 06-collision-tolerant-fold: Module-Dictated Catalog Versions and the Generated Platform

Status: Concluded

## Hypothesis

A contract fold that folds only keys with exactly one defining entry, and reports every other key as a collision with `routable` false, keeps a platform that enables two or three majors of one catalog with shared keys evaluable, and changes nothing for a platform with one enabled major. This is the core fix OQ17 asks about: today the same platform fails to evaluate (experiment 01, case A), against core SPEC.md § 3.4's rule that no report makes the platform fail to evaluate.

## Setup

`probe/`: copied, unmodified, from `core/src/` at commit `cbe93e0` (release `2.0.0-alpha.12` plus two comment-only commits): `types.cue`, `resource.cue`, `trait.cue`, `blueprint.cue`, `transformer.cue`, `catalog.cue`. Copied from the same commit and patched: `platform.cue` (`core.patch` is the exact diff, marked `FOLD PROBE`):

- `#contracts` first collects, per contract key, the set of enabled entries defining it; `defined` and `definedBy` take only keys with one definer.
- `#ContractInventory` gains `collisions` (the sorted keys with more than one definer) and `collidingEntries` (key to the sorted defining entries), and `routable` becomes true exactly when nothing is over-subscribed and nothing collides.

Added in `probe/`: `members.cue`, experiment 01's two-major member source (opm@v4 at 4.2.0, opm@v5 at 5.0.0, shared container and provider-fulfilled backup keys) plus opm@v3 at 3.1.0, which also lists a `volume` contract no other major defines; `cases.cue`, four platforms; `report.cue`, the measured fields.

`toy/fold.cue`: the standalone model of the same fold that was run first on 2026-09-30, copied verbatim. It does not use core: a toy registry with opm@v3 and opm@v4 sharing a legacy container key, a v3-only volume key, and opm@v5 with a module-qualified key (experiment 03's shape).

## Run

With cue v0.17.1:

```bash
cd probe && cue vet -c=false . && cue export -e report .
cd ../toy && cue eval -e contracts.definedBy -e contracts.collisions -e contracts.collidingEntries -e contracts.routable .
```

## Outcome

Measured 2026-09-30, cue v0.17.1. Keys below drop the `opmodel.dev/catalogs/` prefix.

- **Two majors sharing keys (experiment 01's case A): evaluates.** `collisions` is `[opm/resources/container@v1beta1, opm/traits/backup@v1alpha1]`, `collidingEntries` names `[opm@v4, opm@v5]` for each, `definedBy` and `requiredBy` are empty, and `routable` is `false`.
- **Three majors: evaluates.** The two shared keys collide across `[opm@v3, opm@v4, opm@v5]`; the v3-only `opm/resources/volume@v1beta1` is folded as before, `definedBy` naming opm@v3. `routable` is `false`.
- **One major, and one major with the second disabled: unchanged.** `collisions` is empty, `definedBy` names opm@v4 for both keys, `requiredBy` lists `opm/transformers/deployment-transformer@4.2.0`, and `routable` is `true`.
- **Toy model: evaluates.** `definedBy` holds the v3-only volume key and opm@v5's qualified container key, `collisions` is the legacy container key, `collidingEntries` is `[opm@v3, opm@v4]`, and `routable` is `false`.
- **Limitation.** A colliding key leaves `defined`, so it also leaves `requiredBy`, `unfulfilled` and the comparability check: the report says which keys collide and between which entries, not which transformers demand them.

**Hypothesis held.** Folding only single-definer keys and reporting the rest keeps the platform evaluable with shared keys across two or three majors, leaves a one-major platform unchanged, and turns today's evaluation failure into a named report with `routable` false. Linked from OQ17 and `05-risks.md`.
