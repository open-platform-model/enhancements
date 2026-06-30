# Operational Concerns — OPM Module Publishing Workflow

This document is the OPM Production Readiness Review (PRR-lite). Five fixed prompts — answer every one.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

Two new failure surfaces, both diagnostic-only (no metrics/traces):

- A publish-time validation error from `opm publish` (cli) when a module's `cue.mod/module.cue` `module:` path or `package` clause does not match `#CanonicalModuleRef` — surfaced as a CLI error naming the expected vs actual coordinates.
- A load-time mismatch error from the registry loader (library) when a fetched module's resolved coordinates don't match the canonical mapping (OQ5) — a typed error (`oerrors`-style) naming the offending module path and the expected canonical reference. This replaces today's downstream, hard-to-attribute `module not found` / `field not allowed` at render time with an explicit, early signal.

The `core` contribution (`nameSnakeCase`) is observability-neutral — a derived metadata field.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

- `core`: `nameSnakeCase` is an **additive** field on `#Module.metadata` (a `feat:` minor within `@v0`), already shipped. Adding a derived field does not break existing modules — they gain the field on re-evaluation against the new schema.
- `library`: changing how `synth.Instance` derives the import path is an internal mechanism change; the public Go signatures are preserved (the render change's own SemVer note). If OQ3 lands on recording a reference, that adds a field to `*module.Module` (additive, minor).
- `cli`: `opm publish` gains a validation/generation step — new behavior, not a break to an existing flag contract (confirm at accept once the command surface is pinned).
- The migration of non-conforming **published module identities** (OQ4) is the only consumer-visible break, and it is to specific in-repo modules, not to a shared schema or API.

## Deprecation

**What gets removed and when? What replaces it?**

No CUE definitions or Go functions are removed. What is retired is the *practice* of authoring a module's registry path independently of its identity — replaced by the canonical mapping enforced at publish. Concretely, the non-conforming registry coordinates of in-repo modules (e.g. `…/web-app@v1`) are deprecated in favor of their canonical forms (`…/web_app@v0`) in the migration slice; the old coordinates are deleted in the same release once in-repo consumers are moved, unless an external-consumer window is required.

## Rollback

**If this lands and proves bad, what's the rollback story?**

- `core`: `nameSnakeCase` is additive and unused by anything that predates it; rolling back the library/cli slices leaves the field harmless (consumers simply ignore it). No data-plane state.
- `library`: revert `render.go` to the previous derivation; since the render change is gated on this convention, a rollback reverts both together.
- `cli`: drop the publish validation step; modules already pushed remain consumable.
- The migration (renamed module coordinates) is the only piece with persistent effect — a rollback would require re-publishing the old coordinates if external consumers had pinned them, which is why OQ4 fixes hard-switch vs window.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

1. **core** (done) — publish `opmodel.dev/core@v0` carrying `metadata.nameSnakeCase`. Downstream consumes it as a published dep.
2. **library** — re-pin `core` to the version carrying `nameSnakeCase`; rewire `synth.Instance` (and optionally the registry loader / module type) onto `#CanonicalModuleRef`. Produces the helper the cli reuses.
3. **cli** — re-pin `core`; add the `opm publish` validation/generation, reusing the library helper so the publish check and the render resolution share one mapping.
4. **migration** — republish non-conforming in-repo modules at canonical coordinates; update the fixtures/releases that import them, in the same change that flips them.

Each hand-off is a published artifact (core OCI tag) or a shared Go helper (library → cli); the enhancement is `implemented` only when all four have landed.
