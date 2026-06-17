# Operational Concerns — Rename #ModuleRelease to #ModuleInstance

PRR-lite. Several answers are conditional on OQ1/OQ2 (whether the wire `kind` string and label domain move) and will firm up when those resolve.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

Observability-neutral by intent — this is a terminology rename with no behavioral change. The one indirect signal: if the `kind` string changes (OQ1) and a downstream consumer is not updated in lockstep, it surfaces as the existing "unsupported kind" rejection in the library kernel / operator `Release` reconciler (the artifact renders to `kind: "ModuleInstance"` and is refused). No new error kinds are added; an existing one fires for a new reason. Rendered-object labels change key (OQ2) but not cardinality.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

Breaking for any consumer that references the renamed identifiers (`semver: major`, pending OQ4). Impact scales with how far OQ1/OQ2 go:

- **CUE identifiers only** (layer 1): breaks downstream CUE that imports `opmodel.dev/core` and names `#ModuleRelease`/`#ReleaseIdentity`/`#ctx.release`. Confined to source that compiles against `core`.
- **+ `kind` string** (OQ1): additionally breaks the library kernel and operator kind-detection at runtime.
- **+ label domain** (OQ2): additionally breaks selectors and external tooling keyed on `module-release.opmodel.dev/*`.

`core` is pre-`v1` (`@v0`) and stays there: per `core/CLAUDE.md` (`bump-minor-pre-major: true`), a breaking change ships as a `feat!:` **minor** `v0.x` tag, not a `@v0`→`@v1` jump. Design-impact field is `major` (OQ4). Default plan: hard rename (no alias, OQ3), shipping sequence core → library → opm-operator.

## Deprecation

**What gets removed and when? What replaces it?**

Removed: the identifiers `#ModuleRelease`, `#ModuleReleaseMap`, `#ReleaseIdentity`, `#ctx.release`, `#Component.#release`, `#moduleRelease`/`#moduleReleaseMetadata`. Replaced 1:1 by the `Instance`-named equivalents (see `02-design.md` mapping table). Conditionally removed (OQ1/OQ2): the `kind: "ModuleRelease"` string and the `module-release.opmodel.dev/*` label keys. Timeline: same release as the rename, unless OQ3 elects a transition-window alias. No Go functions are removed by the `core` slice itself; any library/operator symbols (e.g. `synth/release.go`) are handled in those repos' slices if D2 lands.

## Rollback

**If this lands and proves bad, what's the rollback story?**

Clean, because there is no data-plane state migration — the change is naming only. Reverting the `core` commit restores the old identifiers; downstream reverts to the prior `core` tag. The one caveat is rendered-object labels (OQ2): if the label key changed and objects were re-applied, a rollback re-applies the old key — the operator's SSA reconcile converges, but any object selected only by the new key during the window is briefly orphaned from selectors. Mitigate by rolling back label and consumers together.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

If the rename stays at layer 1 (CUE identifiers only), coordination is just `core` → any downstream CUE that imports it; no runtime lockstep. If D2/D3 land:

1. **core** — publishes the renamed schema (new OCI tag of `opmodel.dev/core`). Co-update `SPEC.md` + regenerate `INDEX.md`.
2. **library** — update kind-detection and `synth/release.go` to the new `kind` string / identity shape; consume the new `core` tag.
3. **opm-operator** — update `Release` reconciler kind-detection to accept `"ModuleInstance"`; consume the new library.

The hand-off artifact at each step is the published upstream tag the downstream pins.
