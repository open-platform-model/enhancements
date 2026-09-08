# 02-semver-fqn-regex — #Platform Redesign Umbrella

Status: Concluded

Pins: OQ13 → resolved-by-D5

## Hypothesis

The proposed `#FQNType` regex accepts canonical SemVer 2.0 suffixes — `…@1.0.0`, `…@1.4.0-rc.1`, `…@1.0.0-alpha.2+build.42` — and rejects MAJOR-only `…@v1`, partial `…@1` / `…@1.0`, four-part `…@1.0.0.0`, and prerelease without a leading dot.

## Setup

`./schema/fqn.cue` — `#FQNType` regex copied verbatim from `enhancements/0001/schemas/target.cue` (skill rule: copy, never reference).

Two sibling packages each importing `schema`:

- `./positive/values.cue` (package `positive`) — 9 entries that MUST satisfy `#FQNType`: plain release, prerelease (short / dotted / numeric), build metadata, build-only, two-digit majors, hyphenated subpath, deep path.
- `./negative/values.cue` (package `negative`) — 9 entries that MUST violate `#FQNType`: legacy `@v1`, bare `@1`, missing patch `@1.0`, four-part `@1.0.0.0`, trailing dash `@1.0.0-`, missing-prerelease-before-build `@1.0.0-+a`, v-prefix `@v1.0.0`, slash-separator instead of `@`, uppercase in name.

Each list is `cases: [string]: schema.#FQNType` — positive vets clean; negative errors on every entry.

`./cue.mod/module.cue` — `module: "enhancements.opmodel.dev/0001/experiments/02-semver-fqn-regex@v0"`.

## Run

```bash
cue vet ./positive/...                    # MUST succeed
cue vet ./negative/... 2>&1 | grep -c .   # MUST report >= one error per negative entry
```

## Outcome

Observed on 2026-05-23 with cue v0.16.1:

- `cue vet ./positive/...` → exit 0; all 9 entries accepted.
- `cue vet ./negative/...` → exit 1; all 9 entries rejected with `out of bound =~"^[a-z0-9.-]+..."` errors naming each `cases.<key>`.

**Hypothesis held.** Regex behaves exactly as the design specifies — accepts SemVer 2.0 (including prerelease + build metadata + dotted identifiers); rejects MAJOR-only, partial, four-part, malformed prerelease, v-prefix, and case-bound violations. OQ13 closed via D5 (`03-decisions.md`).
