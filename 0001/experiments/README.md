# Experiments — #Platform Redesign Umbrella

Self-contained proofs-of-concept validating specific claims from the
design. See the enhancement's `02-design.md` for the claims being
tested. This file is the hand-maintained index — add a row per
experiment. Per-experiment status lives in each `NN-*/README.md`'s
`Status:` line.

| #  | Concept                          | Pins                       | Status    |
| -- | -------------------------------- | -------------------------- | --------- |
| 01 | names-cascade                    | D2, D3, OQ19, OQ20         | Concluded   |
| 02 | semver-fqn-regex                 | OQ13                       | Concluded   |
| 03 | same-fqn-divergent-unify         | 02-design integrity claim, OQ14 | Concluded |
| 04 | catalog-stamping-flow            | OQ9, OQ10, OQ11, OQ12      | Concluded   |
| 05 | multi-version-match              | OQ1, OQ4, OQ7              | Concluded   |
| 06 | filter-resolution-order          | OQ2 (and OQ3)              | Concluded   |
| 07 | ctx-cycle-freedom                | D2 cycle-freedom claim; 05-risks.md "#ctx evaluation circularity" | Concluded |

## Hypotheses

### 01-names-cascade

A two-component `#Module` with `#release` wired via the `#components` pattern constraint evaluates `#components.<id>.#names.dns.fqdn` and `#ctx.components.<id>.dns.fqdn` to byte-identical strings; `metadata.resourceName: *name | #NameType` override wins when set, falls back to `metadata.name`, which itself defaults to the map key.

### 02-semver-fqn-regex

The proposed `#FQNType` regex accepts `…@1.0.0`, `…@1.4.0-rc.1`, `…@1.0.0-alpha.2+build.42`; rejects `…@v1`, `…@1`, `…@1.0`, `…@1.0.0.0`, and pre-release without leading dot.

### 03-same-fqn-divergent-unify

Two synthetic `#ComponentTransformer` values stamped at identical FQN `…@1.0.0` with identical bodies collapse to one map entry under unification; with divergent bodies they produce a CUE error naming the diverging field. Proves the matcher never has to detect divergence — CUE does.

### 04-catalog-stamping-flow

A pure-CUE catalog package with root `Catalog: { Version: string | *"0.0.0-dev", ModulePath }` constant — and a subpackage `resources/container.cue` that reads `Catalog.Version` via standard cross-package import — vets clean in source tree at `0.0.0-dev`; after `rsync → .build/ → overwrite Catalog.Version → cue export` every primitive's `metadata.version` is the requested SemVer; reverting the source tree leaves zero diff.

### 05-multi-version-match

A synthetic `#composedTransformers` map carrying `container@1.0.4`, `container@1.1.0`, `container@1.4.0` resolves App A's `container@1.0.4` declaration against the 1.0.4 entry, App B's `container@1.4.0` against the 1.4.0 entry, and emits one `MissingFQN`-shaped diagnostic for an App C that pins `container@2.0.0` — naming the adjacent in-range SemVers as alternatives.

### 06-filter-resolution-order

Given a synthetic version list `[1.0.0, 1.1.0, 1.2.0, 1.3.2, 1.4.0, 2.0.0]` and filter `{ range: ">=1.0.0 <2.0.0", allow: ["2.0.1"], deny: ["1.3.2"] }`, the selected set is `[1.0.0, 1.1.0, 1.2.0, 1.4.0, 2.0.1]` — range first, then allow appends, then deny subtracts.

### 07-ctx-cycle-freedom

A `#Module` with N components — where each component body references both `#names.dns.fqdn` (self) and `#ctx.components.<other-id>.dns.fqdn` (cross) — evaluates to a fully concrete value without a CUE cycle error, because `#names` depends only on `metadata + #release` and `#ctx.components` is a downstream projection. A control case where `#names` is flipped to depend on `#ctx.components` errors with a cycle.
