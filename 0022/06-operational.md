# Operational Concerns — Machine-Readable Artifact Metadata in cue.mod/module.cue

This document is the OPM Production Readiness Review (PRR-lite). Five fixed prompts, each answered briefly.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

One new publish refusal (the block disagrees with the module file or identity; CUE's diagnostic names the field, the action names the writer verb), one new publish warning (block missing, until the D8 date), and the same two conditions in `opm module vet`. The OCI manifest gains annotations a consumer can list. 0016's report line can say "template, skipped" from `kind`. No metrics, no long-running signals.

## Semver Impact

**Is this a breaking change for any consumer? If so, what is the backwards-compatibility plan?**

No. `core` gains two definitions nothing in `core` unifies against (additive, `feat:`). The CLI gains a gate that fires only when a block is present, a warning that becomes a refusal only from a dated release (D8), a writer that touches trees only when invoked, and annotations nobody is required to read. Published artifacts are content-addressed and untouched. Enhancement-level `semver`: `minor`.

Backwards direction: an old CLI reading a new artifact sees a `custom` block it never looks at; CUE's own tooling has carried the field since v0.9.0. Forward direction: a new reader against an old artifact falls back to `deps` (D7). Only the core v2 line is in scope.

## Deprecation

**What gets removed and when? What replaces it?**

Nothing is removed. Path-prefix kind inference stays as the fallback and as the OPM-domain cross-check (OQ2). Once every first-party artifact carries the block and the D8 date has passed, readers may drop the `deps` fallback in their own entries.

## Rollback

**If this lands and proves bad, what is the rollback story?**

The block is inert data: stop reading it and nothing changes. The gate can be disabled without touching any artifact. Annotations can stop being written. Trees that carry the block keep publishing (CUE never rejects the namespace). The only irreversible part is the key name in already-published artifacts, which is why D1 chose it defensively.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

Sequence: `core` (definitions and SPEC §5.4) → `cli` (gate, writer, annotations, 0016 reader) → `catalog_opm` and `modules` (run the writer once per tree, commit, next release carries the block) → `opmodel.dev` (registry-namespaces and module-file reference pages) → the 0011 amendment (append the D3/D8-amending decision; OQ4 wording).

- `core` ships first; publish resolves the gate from the schema cache by name, so a CLI against an older core simply finds no gate and skips (the same posture the identity gate takes toward a core v1 schema).
- `cli` lands the gate and writer together; the D8 refusal date is set in that release's changelog.
- `catalog_opm` and `modules` need one writer run each; the trees change only in `cue.mod/module.cue`, so no artifact content moves.
- The 0016 reader lands with, or after, 0016's own `cli` slice; it is that entry's delivery to log.

Four hand-offs in a line; the constraints here suffice, and landings are logged in `delivery.yaml` as they happen.
