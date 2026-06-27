# Operational Concerns — Manifest Passthrough: Side-Channel Raw and Kustomize Manifests

This document is the OPM Production Readiness Review (PRR-lite). Five fixed prompts — answered below.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

- **New error class: passthrough render failure.** Reading a `raw` glob or running `kustomize build` can fail before any apply happens (missing path, malformed YAML, kustomization error). The operator surfaces this on the release `status` conditions (a Render/Reconciling failure with the source path and Kustomize error), mirroring how render errors are already reported; the CLI surfaces it to stderr and a non-zero exit before applying anything. Failures must be atomic — a bad side manifest fails the reconcile rather than partially applying.
- **Provenance marker.** Every passed-through object carries a `passthrough` provenance marker (`schemas/target.cue` `#PassthroughProvenance`) on the existing component-provenance slot, so `status.inventory` entries and cluster objects can be filtered to "rendered vs side-channel" for diffing and debugging.
- **Inventory.** Side objects appear in `status.inventory` like any rendered resource — no new inventory surface, but the inventory count/digest now includes them, which is the intended visibility.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

- **`opmodel.dev/core@v0`: no change.** Per D1 the core schema and library kernel are untouched, so `semver: none` for core. No `@v0`→`@v1` pressure from this enhancement.
- **opm-operator CRDs: additive.** `spec.extraManifests` is a new optional field on `ModuleRelease`/`Release`; existing CRs without it are unaffected. Backward-compatible CRD revision.
- **cli: additive.** A new optional release-file field / flag; existing release files render unchanged.
- No downstream consumer must update to keep working; updating unlocks the feature.

## Deprecation

**What gets removed and when? What replaces it?**

- **Nothing is deprecated.** This enhancement is purely additive. It does not replace the typed component path, the existing `#Objects` hatch, or any apply/prune logic. If OQ2 later concludes that this side-channel subsumes part of 0005's `#Objects` hatch, that deprecation would be recorded in 0005, not here.

## Rollback

**If this lands and proves bad, what's the rollback story?**

- **Code rollback is clean.** Reverting the operator/CLI slices removes the renderer and the spec field. Releases that never set `extraManifests` are entirely unaffected.
- **Data-plane caveat.** Objects already applied from a side-channel and recorded in `status.inventory` were created with OPM ownership labels. After a code rollback the operator no longer renders them, so on the next reconcile they would be treated as stale and **pruned** (if `prune: true`) — the same as removing them from intent. Operators rolling back should expect side-channel resources to be garbage-collected, or set `prune: false` / remove the `extraManifests` declaration deliberately before rollback if they want the objects to persist unmanaged.
- The library kernel and `core` are unchanged, so no artifact-compatibility concerns there.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

1. **Shared renderer package first** (location per OQ5) — embeds `krusty`, exposes `Render(sources, fsRoot)` with hardened options. Nothing else can integrate until this exists.
2. **opm-operator** — add the CRD field, regenerate CRDs, wire the renderer into the render path, extend label stamping, verify staging/inventory/prune. This is the primary slice and the one that proves the end-to-end ownership story.
3. **cli** — add the release-file field/flag, fold renderer output into `build`/`apply`. Can land in parallel with the operator once the shared package exists, but should match the operator's resolved semantics (D4).
4. **core / library** — no landing. Their non-involvement is itself a checked outcome (the non-goal held).

No published-artifact hand-off is required between repos (no OCI tag or regenerated fixture gates another repo); the only shared dependency is the renderer package, consumed as a normal Go import.
