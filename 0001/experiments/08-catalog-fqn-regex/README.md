# 08-catalog-fqn-regex — #Platform Redesign Umbrella

Status: Concluded

Pins: D19 (catalog FQN shape sub-decision)

## Hypothesis

The proposed `#CatalogFQNType` regex (D19) accepts catalog FQNs of shape `<modulePath>@<SemVer 2.0>` — `…@1.0.0`, `…@0.1.0`, `…@1.4.0-rc.1`, `…@1.0.0+build.123`, dotted-prerelease, multi-digit numerics, single-segment "modulePath" — and rejects MAJOR-only `…@v1`, partial `…@1` / `…@1.0`, four-part `…@1.0.0.4`, missing path, missing version, uppercase in path, trailing-dash prerelease, and v-prefix.

The regex does **not** structurally distinguish itself from `#FQNType` (a string with multiple path segments matches both); the two types are semantically distinct, not regex-disjoint. This experiment validates `#CatalogFQNType`'s own boundaries, not the (non-existent) regex-level disjointness.

## Setup

`./schema/fqn.cue` — `#CatalogFQNType` regex copied verbatim from `enhancements/0001/schemas/target.cue` (skill rule: copy, never reference).

Two sibling packages each importing `schema`:

- `./positive/values.cue` (package `positive`) — 8 entries that MUST satisfy `#CatalogFQNType`: plain release, the first new-shape OPM catalog tag from D23 (`0.1.0`), prerelease (short and dotted), build metadata, multi-digit numerics, single-segment "modulePath" (which `#FQNType` would reject but `#CatalogFQNType` accepts), and a deep multi-segment path.
- `./negative/values.cue` (package `negative`) — 9 entries that MUST violate `#CatalogFQNType`: legacy `@v1`, bare `@1`, missing patch `@1.0`, four-part `@1.0.0.4`, no `@version`, empty modulePath before `@`, uppercase in path, trailing-dash prerelease `@1.0.0-`, v-prefix `@v1.0.0`.

Each list is `cases: [string]: schema.#CatalogFQNType` — positive vets clean; negative errors on every entry.

`./cue.mod/module.cue` — `module: "enhancements.opmodel.dev/0001/experiments/08-catalog-fqn-regex@v0"`.

## Run

```bash
cue vet ./positive/...                    # MUST succeed
cue vet ./negative/... 2>&1 | grep -c .   # MUST report >= one error per negative entry
```

## Outcome

Observed on 2026-05-25 with cue v0.16.x:

- `cue vet ./positive/...` → exit 0; all 8 entries accepted (including the single-segment `mycatalog@1.0.0` case that distinguishes `#CatalogFQNType` from `#FQNType`).
- `cue vet ./negative/...` → exit 1; all 9 entries rejected with `out of bound =~"^[a-z0-9.-]+..."` errors naming each `cases.<key>`.

**Hypothesis held.** `#CatalogFQNType` behaves exactly as D19 specifies — accepts the `<modulePath>@<SemVer 2.0>` shape (including prerelease + build metadata + dotted identifiers + single-segment paths); rejects MAJOR-only, partial, four-part, missing-path, missing-version, uppercase, trailing-dash, and v-prefix shapes. D19's new regex is sound. Evidence cited into `03-decisions.md` D19.
