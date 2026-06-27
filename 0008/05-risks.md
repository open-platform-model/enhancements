# Risks, Drawbacks, Alternatives — CUE-Native CRD Schemas as Single Source of Truth

This document records the honest costs of the proposed design. Risks
describe what could go wrong; Drawbacks describe what definitely costs
something; Alternatives describe the high-level paths not taken (per-
decision detail lives in `03-decisions.md`).

## Risks and Mitigations

- **The openapi encoder emits a schema the API server rejects.** CUE's `encoding/openapi` targets generic OpenAPI 3.0.0; the structural-schema subset is stricter (single-of properties/additionalProperties/items per sub-schema, no `$ref`, constrained junctors, non-empty types). A CUE construct that round-trips to non-structural OpenAPI would produce a CRD `kubectl create` rejects. **Mitigation:** validate the central feasibility claim in a spike before `accepted` (a graduation gate); `core/SPEC.md` already forbids the most dangerous constructs (CUE templating in `spec`); add a generation-time check that applies each CRD against a real API server (envtest) in CI.

- **Recursive/self-referential CUE values break `ExpandReferences`.** The encoder cannot inline self-referential values, and structural schemas forbid `$ref`. A recursively-defined field would fail generation. **Mitigation:** none of the three current kinds is recursive; add a generator error that names the offending path, and document the constraint in the `#CRD` SPEC section so authors learn it at write time, not generate time.

- **Disjunctions collapse to `any` in generated Go.** `gengotypes` (and the CUE type model generally) maps `string | int` and enum-style disjunctions to Go `any`, weakening the Go type even though the CRD schema keeps the constraint. **Mitigation:** D8 keeps emission behind our own tool boundary so we can emit named string types with enum-validated CRD fields rather than bare `any`; accept `any` only where the field is genuinely a JSON passthrough (e.g. `values`).

- **A regeneration silently changes an existing CRD's schema.** Re-deriving from CUE could alter field ordering, descriptions, or nullability versus the hand-tuned CRDs, causing an unintended API change on a live cluster. **Mitigation:** the accepted→implemented gate requires byte-compatibility (modulo formatting) for unchanged fields, with any deliberate difference enumerated in Deviations; the `crdgen:check` diff makes every change reviewable.

- **`gengotypes` is removed or changed upstream.** It is experimental. **Mitigation:** D8 — do not depend on it as the sole mechanism; an in-tree emitter over the CUE Go API is the fallback.

- **`core` and the generator version-skew.** The generator consumes the *published* `core`; if it pins an old version, generated types lag the contract. **Mitigation:** the generator pins the same `core` version the operator's kernel uses (single pin in `go.mod` / module config); CI runs `task update-deps` discipline.

## Drawbacks

- **A new build step and a new tool to maintain.** `cmd/crdgen` is real code (CUE Go API + assembly + controller-gen orchestration) that must be kept working across CUE and controller-tools upgrades. The status quo had no such tool.
- **The CRD definition is split across `core` (schema + facets as data) and controller-gen (deepcopy only).** Simpler than today's CUE-vs-Go split, but still two tools in the pipeline rather than one.
- **Authors must learn the `#CRD` envelope.** Adding a CRD now means writing a CUE `#CRD` value (with scope, printer columns, CEL as data) instead of Go structs with familiar kubebuilder markers — a new idiom for contributors who know kubebuilder.
- **CEL stays a hand-authored island.** D6 carries CEL verbatim; CEL rules are not validated against the CUE contract, so a CEL rule referencing a field CUE renamed would only fail at apply time.
- **Generated `api/v1alpha1` is no longer hand-editable.** Any per-type Go method or doc comment must live in a separate non-generated file, a small ongoing discipline.

## Alternatives

- **Go stays the source of truth; derive CUE.** Keep hand-authored Go + controller-gen as today, and generate CUE for `core`/consumers via `cue get go` or `cue get crd` (both mature, well-supported — this is the direction the ecosystem actually goes). **Why not:** it formalises the inversion the problem statement names — `core/` becomes a derived artefact of `opm-operator/`, contradicting `core/`'s role as the published upstream contract. (D1.)

- **CRD YAML as the pivot.** Author the CRD YAML once; derive CUE via `cue get crd` and Go via some CRD→Go path. **Why not:** there is no first-class CRD→Go generator, so the Go types end up orphaned or hand-maintained anyway — the worst of both worlds. (D1, `research/findings.md` §7.)

- **Do nothing; rely on discipline.** Keep the two definitions and trust review. **Why not:** that is the status quo whose unenforced, cross-repo drift (now spanning `cli` per 0006) is the entire motivation.

- **Adopt timoni/Holos-style tooling wholesale.** Use an existing CUE+Kubernetes toolchain. **Why not:** every mature tool (timoni `mod vendor crds`, Holos, `cue get crd`) goes CRD→CUE, the opposite direction; none generates CRD YAML *from* CUE as source of truth, so adopting them would mean adopting Direction B, not A. (`research/findings.md` §5.)
