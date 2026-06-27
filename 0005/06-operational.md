# Operational Concerns — Kubernetes-Native Refocus: Generated Mirror and Composed Abstractions

This document is the OPM Production Readiness Review (PRR-lite). Five fixed prompts — answered even briefly.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

The generated lifecycle metadata becomes the operator's source for new reconcile signals: apply-order phase (sequencing), per-resource readiness (status reporting), and prune actions (resources removed between releases). The operator surfaces readiness and prune decisions per resource; exact metric/diagnostic shapes are operator-slice detail. Generation itself is build-time — its diagnostics (unmapped kinds, schema-emit failures) surface in the generator's output and CI, not at runtime. The catalogs remain observability-neutral as CUE artifacts.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

`opmodel.dev/core@v0` is unchanged (D3) — no core impact. `catalog_kubernetes` and `catalog_opm` are pre-1.0 (`@v0`, `bump-minor-pre-major: true`); regenerating their surface and re-pointing `catalog_opm` at shared types may tighten or rename schemas, which is a breaking minor for modules pinning them — expected and absorbed by the pre-1.0 cadence. Modules using the `#Objects` hatch are unaffected. `config.yaml.semver` is set at promotion.

## Deprecation

**What gets removed and when? What replaces it?**

Hand-written `catalog_kubernetes` resources/schemas/transformers are replaced by generated output (same release). `catalog_opm`'s independently-vendored `cue.dev/x/k8s.io` usage is replaced by the shared strict generated types. The hardcoded `library/pkg/resourceorder` list is replaced by per-kind `applyPhase` metadata. No transition window is planned beyond the pre-1.0 cadence; old hand-written sources are deleted, not aliased.

## Rollback

**If this lands and proves bad, what's the rollback story?**

Catalogs are versioned OCI artifacts; consumers pin versions, so rollback is re-pinning to the last hand-written release. Because core is untouched, the library/operator continue to work against prior catalog versions. The generator is build-time, so reverting it has no data-plane effect. Operator changes that consume lifecycle metadata must degrade gracefully when metadata is absent (older catalog versions), which is a requirement on the operator slice.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

Sequence: (1) generation tooling lands and emits both projections; (2) `catalog_kubernetes` regenerates and publishes (open projection, OCI tag); (3) `catalog_opm` re-points at the shared strict types and publishes; (4) `library` consumes `applyPhase`/readiness metadata; (5) `opm-operator` reconciles against the metadata; (6) `opmodel.dev` documents the workflow. Each hand-off is a published OCI catalog tag the downstream pins. The generator's home (OQ2) determines where step 1 lives.
