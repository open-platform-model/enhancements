# Design — CUE-Native CRD Schemas as Single Source of Truth

This document answers the question: "What is the proposed solution and how
does it work?" Design Goals and Non-Goals together define the boundary of
the enhancement; the High-Level Approach should be understandable without
deep implementation knowledge. All trade-off reasoning lives in
`03-decisions.md`, not here.

## Design Goals

- One authored definition per CRD type. The `ModuleRelease`, `Release`, and `Platform` shapes are written once, in CUE, in `core/`; the Go API types and the CRD YAML are generated artefacts, never hand-edited.
- The generated CRD's `openAPIV3Schema` reflects the CUE contract's validations, so the API server rejects at `kubectl apply` what the kernel would reject at evaluation time.
- The operator and the CLI compile against generated Go types that are, by construction, consistent with the published `core` contract — closing the 0006 cross-repo drift.
- `core/` stays a pure-CUE module with no Go and no build-time codegen, honouring its constitution; all generation lives downstream and consumes the *published* `core`.
- Drift is mechanically impossible to merge: CI regenerates from `core` and fails on any diff against the committed CRD YAML and Go types.
- The facets CUE cannot own (deepcopy/`runtime.Object`, CEL transition logic) are handled by the existing tool that does own them (controller-gen for deepcopy) or carried verbatim (CEL), with no lossy translation attempted.

## Non-Goals

- Translating CEL to or from CUE. CEL `x-kubernetes-validations` rules are carried as opaque strings; new CEL-shaped validation stays authored as CEL.
- Writing a deepcopy generator. deepcopy remains controller-gen's `object` output over the generated structs.
- Generating controllers, RBAC roles, or webhook configuration from CUE. Only the CRD types (schema + CRD metadata) and their Go shapes are generated.
- Changing any field shape, validation, or the API version (`v1alpha1`). This is an authoring/generation change; the resources serialise identically before and after.
- Making `core` the source of truth for non-CRD Go types (inventory entries, internal helpers). Only the API/CRD types.

## High-Level Approach

Define each CRD natively in `core/` as a `#CRD` value: a small envelope that pairs the **Kubernetes object metadata of the CRD itself** (group, kind, plural/singular, scope, short names, per-version served/storage flags) with the **schema body** (the existing `#ModuleRelease` / `#Platform` domain definitions, whose `spec`/`status` are already OpenAPIv3-compatible) and the **non-schema facets that controller-gen expresses as markers today** (status subresource, printer columns, CEL validations) — but expressed as plain CUE *data* rather than Go comments.

Generation happens **downstream of `core`**, in a Go tool that lives in `opm-operator` (or a shared `cmd/`), and imports `opmodel.dev/core` as a published module dependency — it never reaches into core's source tree. The tool runs three transforms over each `#CRD`:

1. **Schema body → structural OpenAPI.** Use `cuelang.org/go/encoding/openapi` with `ExpandReferences: true` (CUE's documented "Structural OpenAPI form required by CRDs targeting Kubernetes 1.15+") to emit the `openAPIV3Schema` for each version's `spec`/`status`.
2. **Assemble the CRD manifest.** Wrap the schema body with the `#CRD` metadata, splice in the status subresource, printer columns, short names, scope, and the verbatim CEL `x-kubernetes-validations` strings. Write `config/crd/bases/*.yaml`.
3. **Schema body → Go structs.** Emit the `api/v1alpha1` Go types (with json tags and the `+kubebuilder:object:root=true` marker on the root types) from the same CUE. Then run controller-gen `object` over the result to produce `zz_generated.deepcopy.go`.

A `task` target regenerates all three; a CI check re-runs it and fails on any diff, so drift cannot be merged. The kubebuilder/controller-runtime contract is preserved end-to-end: the operator still gets typed Go structs implementing `runtime.Object`, and the CRDs are still valid structural schemas.

## Schema / API Surface

The new surface is the `#CRD` envelope and its sub-shapes, defined in full in [`schemas/target.cue`](schemas/target.cue). Headline shapes:

- `#CRD` — one per custom resource. Carries `group`, `names` (`kind`/`plural`/`singular`/`shortNames`), `scope` (`Namespaced | Cluster`), and `versions: [...#CRDVersion]`. The `ModuleRelease`/`Release`/`Platform` definitions become `#CRD` instances.
- `#CRDVersion` — `name` (e.g. `v1alpha1`), `served`/`storage` flags, the `schema` (a reference to the domain definition whose `spec`/`status` form the body), `subresources` (status on/off + scale if ever needed), `additionalPrinterColumns: [...#PrinterColumn]`, and `validations: [...#CELValidation]`.
- `#PrinterColumn` — `name`, `type`, `jsonPath`, optional `priority` — a direct, lossless model of `+kubebuilder:printcolumn`.
- `#CELValidation` — `rule` (the CEL expression, carried verbatim), `message`/`messageExpression`, optional `reason`/`fieldPath`/`optionalOldSelf` — a direct model of `+kubebuilder:validation:XValidation`. The design never parses or rewrites `rule`.

The schema *bodies* (`spec`/`status` field shapes) are **not** re-authored here — they are the existing `#ModuleRelease` / `#Platform` definitions in `core/src/`. `#CRD` references them, so there is exactly one definition of each field. `schemas/target.cue` mirrors the existing shapes locally only so the file compiles standalone for review (the same convention 0006 used).

## Integration Points

**core/** (load `core-schema-edit` before editing — SPEC.md co-update is gated):

- `core/src/crd.cue` *(new)* — the `#CRD`, `#CRDVersion`, `#PrinterColumn`, `#CELValidation` definitions. SPEC.md gains a matching section.
- `core/src/module_release.cue`, `core/src/platform.cue`, `core/src/release.cue` *(release CRD may need a domain definition if one does not yet exist)* — add the `#CRD` instances binding each kind's metadata + version + body. Existing field shapes are reused unchanged.
- `core/SPEC.md` — new section documenting the `#CRD` envelope (co-update gate).

**opm-operator/**:

- `cmd/crdgen/` *(new)* — the Go assembler: loads published `opmodel.dev/core`, runs the openapi encoder, assembles CRD YAML, emits Go API types, invokes controller-gen `object`. Imports `cuelang.org/go/encoding/openapi`.
- `api/v1alpha1/*_types.go` — become **generated** output of `cmd/crdgen` (the hand-authored structs are deleted; the `groupversion_info.go` registration and any helper methods that aren't pure type shape — `GetConditions`/`SetConditions`, `conditions.go` — stay hand-authored or move to a separate non-generated file).
- `config/crd/bases/*.yaml` — become generated output of `cmd/crdgen` rather than controller-gen `crd`.
- `.tasks/dev.yaml` / `Taskfile.yml` — replace the controller-gen `crd` invocation with `crdgen`; keep controller-gen `object` for deepcopy; add a `crdgen:check` CI gate that fails on diff.

**cli/**:

- No source change required — it continues to import the operator's `api/v1alpha1` types (per 0006). It must build unchanged against the generated types; a build is part of the acceptance gate.

## Before / After

**Before** — the `spec.values` example from `01-problem.md`. `#ModuleRelease` in `core/` says `values` is a struct; `ModuleReleaseSpec.Values` in Go is a `*RawValues` JSON passthrough; the CRD admits `values: [1,2,3]`; the error surfaces at reconcile time as a CUE evaluation failure. Two definitions, silent disagreement.

**After** — `values: {...}` is authored once in `core/src/module_release.cue`. `cmd/crdgen` emits an `openAPIV3Schema` where `values` has `type: object`, and a Go `Values` field typed accordingly. `kubectl apply` of `values: [1,2,3]` is rejected at admission with a structural-schema error naming the field. The Go type, the CRD YAML, and the CUE contract cannot disagree, because two of the three are generated from the first — and CI fails if anyone commits a stale copy.

**Authoring workflow** — before: edit CUE in `core/`, separately edit Go in `opm-operator/`, run controller-gen, review both, hope. After: edit CUE in `core/`, publish; in `opm-operator/` run `task crdgen`, commit the regenerated artefacts; CI re-runs `crdgen` and blocks the merge if the committed output is stale.
