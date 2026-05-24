# 06-filter-resolution-order — #Platform Redesign Umbrella

Status: Concluded

Pins: OQ2 → resolved-by-D10, OQ3 → resolved-by-D11

## Hypothesis

Given a synthetic version list `[1.0.0, 1.1.0, 1.2.0, 1.3.2, 1.4.0, 2.0.0]` and filter `{ range: ">=1.0.0 <2.0.0", allow: ["2.0.1"], deny: ["1.3.2"] }`, the selected set is `[1.0.0, 1.1.0, 1.2.0, 1.4.0, 2.0.1]` — range first (selects the in-range subset), then `allow` appends out-of-range force-includes, then `deny` subtracts. **Dual structure**: CUE pins the abstract semantic; Go pins the library that will actually ship in the kernel.

## Setup

Two side-by-side subdirs:

### `./cue/`

- `./cue/cue.mod/module.cue` — `module: "enhancements.opmodel.dev/0001/experiments/06-filter-resolution-order/cue@v0"`.
- `./cue/filter.cue` — copy `#SubscriptionFilter` shape from `enhancements/0001/schemas/target.cue`; substitute `in_range` (a pre-filtered list) for the unparseable-in-CUE `range` string. `#resolve` runs three steps: start with `in_range`, append `allow` entries not already present, subtract `deny` entries.
- `./cue/cases.cue` — canonical case: `in_range: ["1.0.0", "1.1.0", "1.2.0", "1.3.2", "1.4.0"]`, `allow: ["2.0.1"]`, `deny: ["1.3.2"]`; expected `["1.0.0", "1.1.0", "1.2.0", "1.4.0", "2.0.1"]`. Unification of `expected` against `resolved.out` makes mismatch a hard CUE error.

### `./go/`

- `./go/go.mod` — `module enhancements.opmodel.dev/0001/experiments/06-filter-resolution-order`, Go 1.22, dep `github.com/Masterminds/semver/v3 v3.3.0`.
- `./go/resolve.go` — `Resolve(input []string, f Filter) ([]string, error)` parses each input through `semver.NewVersion`, checks against `semver.NewConstraint(f.Range)`, then runs the same three-step `range → allow → deny` order against the parsed range string `">=1.0.0 <2.0.0"`.
- `./go/resolve_test.go` — `TestCanonicalCase` runs the same canonical input against the parsed range; demonstration, not a CI test fixture.

Two-side agreement = order is robust to library implementation. Disagreement = finding worth recording.

## Run

```bash
( cd cue && cue eval -c ./... )                       # MUST succeed
( cd go && go test -run TestCanonicalCase -v ./... )  # MUST print expected ordered set
```

## Outcome

Observed on 2026-05-23 with cue v0.16.1, Go 1.26.2, Masterminds/semver v3.3.0:

- CUE side `canonical.resolved.out == ["1.0.0", "1.1.0", "1.2.0", "1.4.0", "2.0.1"]`; `canonical.check` unifies with `expected` (byte-identical).
- Go side `TestCanonicalCase` passes with `resolved (range → allow → deny): [1.0.0 1.1.0 1.2.0 1.4.0 2.0.1]`.
- Both sides agree on order: range first, allow appends (one entry), deny subtracts (one entry, originally in the in-range subset).

**Hypothesis held.** Three-step resolution order is robust under both abstract CUE semantics and concrete Masterminds/semver parsing. OQ2 closed via D10 (filter order); OQ3 closed via D11 (Go-side Masterminds/semver v3 inside Materialize — CUE cannot evaluate range syntax natively). Range-parsing-is-Go-side caveat added to `02-design.md` Materialize section.
