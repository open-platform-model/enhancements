# Operational Concerns — CUE-Native CRD Schemas as Single Source of Truth

This document is the OPM Production Readiness Review (PRR-lite). Five
fixed prompts — answer every one, even briefly. The answers tell future
operators, contributors, and on-call responders what to expect when the
enhancement lands. Leave a prompt blank only if it is genuinely N/A; say
so explicitly when it is.

## Observability

**What new signals, metrics, diagnostics, or error types does this
enhancement introduce, and how are they surfaced?**

This is mostly a build-time, not a runtime, change — the operator and CLI behave identically at runtime; only the *origin* of their types changes. New diagnostics are developer-facing:

- `cmd/crdgen` emits build-time errors naming the offending CUE path when a construct cannot be expressed as a structural schema (e.g. a recursive value, or a non-OpenAPIv3 construct that slipped past `core/SPEC.md`).
- The `crdgen:check` CI step emits a diff between committed and freshly-generated artefacts when drift is detected — the primary new signal, surfaced in CI logs.
- Optionally (recommended), an envtest-backed CI step that applies each generated CRD to a real API server, surfacing structural-schema rejections at generation time rather than on a user's cluster.

Runtime observability is unchanged: the same CRDs, the same operator conditions/events. One *improvement* — invalid specs now fail at `kubectl apply` with structural-schema messages instead of as reconcile-time CUE errors, which is strictly better operator-facing diagnostics.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the
backwards-compatibility plan?**

- **`opmodel.dev/core`:** adding `#CRD`, `#CRDVersion`, `#PrinterColumn`, `#CELValidation` and the per-kind `#CRD` instances is **additive → minor** within `@v0`, *provided* anchoring the CRDs does not force a change to the existing `#ModuleInstance`/`#Platform` field shapes. Whether any such change is needed is OQ5 and must be resolved before `accepted`; if a field shape must change, that portion is breaking and rides its own enhancement. The intent is zero field-shape change.
- **`opm-operator`:** no API change for *users* — the CRDs and Go types serialise identically. Internally, the hand-authored types are replaced by generated ones; the goal is byte-compatible CRDs for unchanged fields (an accepted→implemented gate).
- **`cli`:** no change required; it imports the operator's `api/v1alpha1` (per 0006) and must build unchanged against the generated types.
- **Cluster (CRDs already applied):** the regenerated CRDs must be schema-compatible with what is deployed; the byte-compatibility gate is what prevents an accidental live-cluster API change.

Shipping sequence: `core` (publish the new definitions) → `opm-operator` (generator + regenerated artefacts) → `cli` (rebuild against the new types). See Cross-Repo Coordination.

## Deprecation

**What gets removed and when? What replaces it?**

- The hand-authored Go API structs in `opm-operator/api/v1alpha1/*_types.go` are **deleted** (not deprecated) and replaced by generated output, in the same release that lands the generator. No transition window — the generated types are drop-in replacements with identical serialization.
- The controller-gen `crd` invocation in `.tasks/dev.yaml` is removed and replaced by `crdgen`; controller-gen `object` (deepcopy) stays.
- The kubebuilder marker comments that encoded scope/printer-columns/CEL/validation move from Go comments into CUE `#CRD` data (D4); the markers themselves are removed from the (now generated) Go.
- No CUE definitions are removed — `#ModuleInstance`/`#Platform` are reused as the schema bodies.

## Rollback

**If this lands and proves bad, what's the rollback story?**

Clean and low-stakes, because the artefacts are byte-compatible by gate:

- **Code rollback:** revert the `opm-operator` slice — the previous commit restores the hand-authored types and the controller-gen `crd` target. The generated and hand-authored CRDs are byte-compatible for unchanged fields, so the deployed CRDs need no change.
- **`core` rollback:** the new `#CRD` definitions are additive; consumers that don't use them are unaffected, so `core` need not be rolled back even if the operator slice is.
- **No data-plane state:** this changes type *definitions*, not stored resources. Existing `ModuleInstance`/`Platform`/`ModulePackage` objects on the cluster are untouched and remain valid under both the old and new (byte-compatible) CRDs.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

1. **`core/`** — author `#CRD` + instances + SPEC.md section (via `core-schema-edit`); publish `opmodel.dev/core@v0.x` (release-please). Artefact consumed downstream: the published OCI module.
2. **`opm-operator/`** — bump the `core` pin to the published version; add `cmd/crdgen`; regenerate `api/v1alpha1` + `config/crd/bases`; run controller-gen `object`; wire `crdgen:check`. Artefact consumed downstream: the operator's `api/v1alpha1` Go package (imported by `cli`).
3. **`cli/`** — bump the `opm-operator` dependency; rebuild against the generated types; no source change expected (0006 contract). Verify the build is green.

Each hand-off is a published version pin, so the waves are independently reviewable. The `core` and `opm-operator` slices should each be tracked as OpenSpec changes in their repos, with `history` events appended here (`slice:` refs) as they land.
