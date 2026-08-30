# Operational Concerns: CUE Testing and Conformance

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

Two new signals:

- **In-package**: a failing hidden assertion surfaces in a CUE repo's own check (`cue vet` output at the assertion's path, the same surface every other vet failure uses).
- **Conformance**: a per-cell drift report (the diff between a recorded outcome and the observed one, keyed by case and version cell), plus a coverage report for the raw catalog family (members with no upstream definition; upstream kinds with no member).

Where the drift report is surfaced (the suite's own CI, a product repo's release check, or both) is OQ9. No new error kinds in any product repo.

## Semver Impact

**Is this a breaking change for any consumer?**

No published definition, command or artifact changes. In-package test files may change what a published CUE module contains (OQ8); if they ship inside the module they are additive content a consumer never imports. The suite consumes published artifacts and changes none. `core`'s in-package assertions land as non-releasing commits under its commit conventions (the published schema is byte-identical).

## Deprecation

**What gets removed and when?**

Nothing in a product repo. The `examples.cue` convention in this repo of commenting out must-fail cases with their observed error text is superseded by the in-package negative idiom (D6) for new entries; existing entries are not rewritten.

## Rollback

**If this lands and proves bad, what's the rollback story?**

The suite is outside every product repo; removing it from a release check restores the previous state exactly. In-package assertions are test-only content; deleting them changes no published behaviour. There is no data-plane state. The only thing lost on rollback is the record.

## Cross-Repo Coordination

**Which repos must coordinate, and what constrains the order?**

- The conformance suite can only render with the pure-CUE oracle after that oracle is consumable from outside `library` (today it is published from a test fixture into an in-memory registry; a published or vendored form of the glue is the artefact the suite consumes).
- The raw family's upstream conformance check (D4) needs a pinned `cue.dev/x/k8s.io` snapshot to compare against; the abstraction family's pin (v0.10.0 today) is the natural first choice, and the axis question (OQ2) decides how further snapshots are named.
- 0019's D15 sweep gate ("no default-named golden changes by a byte") consumes a recorded cell for the catalog at the release before the sweep; the record must exist before the sweep's release can be gated on it. 0019's D16 flip is the suite's first schema-refusal corpus and needs no coordination beyond the published core tag.
- If the suite becomes a new repo (OQ5), this repo's `#Area` enum and the workspace routing table gain a row in the same change that creates it, so its later deliveries can be logged here.
