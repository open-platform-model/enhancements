# 0008: CUE-Native CRD Schemas as Single Source of Truth

OPM describes each custom resource three times: as CUE in core, as Go structs in the operator, and as the CRD YAML generated from those structs. Nothing keeps the three in agreement. This entry makes the CUE the only hand-written one and generates the other two from it.

## Why

A field added or tightened in core does not reach the operator's types or the CRD until someone edits the Go by hand. The API server then admits an object that the kernel rejects at render time. The error surfaces deep in a reconcile instead of at `kubectl apply`. The CLI now imports the operator's types, so one drift hurts two repos.

## What Changes

- Each custom resource has one authored definition, in the published core module.
- The CRD manifest and the Go API types are generated from it and never edited by hand.
- Scope, short names, the status subresource, printer columns and validation rules become data on that definition, not Go comments.
- A rule written in CEL passes through as text. No translation happens in either direction.
- CI regenerates and fails on any difference, so a stale copy cannot merge.

## What this is not

- Not a CEL to CUE translator, in either direction.
- Not a replacement for controller-gen: it keeps the deepcopy methods.
- Not generation of controllers, RBAC or webhooks.
- Not a field change or an API version bump. Resources serialise the same before and after.
- Not a change to Go types that are not custom resources.

## Example

```cue
// core, once: Platform is a cluster singleton named "cluster"
#PlatformCRD: #CRD & {scope: "Cluster", ...}
```

An object with `values: [1, 2, 3]` is rejected at admission, naming the field, not at reconcile time.

## Capabilities

- **New:** `crd-source`, `crd-facets`, `crd-validation-rules`

## Impact

- **Core authors** edit CUE once. The operator and the CLI follow by regeneration.
- **Contributors** learn the CRD envelope in place of kubebuilder markers.
- **Three repos** change: core, opm-operator and cli. The change is not breaking: resources serialise identically.

## Open questions

- Not blocking: Does the generator stay in the operator, or move to a shared tool? The answer depends on whether the CLI ever regenerates on its own.
- Blocking: Does core define the full status shape of a resource, or only the part with domain meaning, with the operator-owned rest in operator CUE? Map each status field to an owner to settle it.
- Not blocking: Are the generated files committed, or built on demand only? Committing is assumed, so the diff is reviewable and consumers build without the generator.
- Blocking: Does `ModulePackage` have a core domain definition to anchor its CRD, or is it operator-only? Either add a minimal core definition or leave it out of the first slice.
- Blocking: Does anchoring the CRDs force a change to the existing `ModuleInstance` or `Platform` field shapes? A spike of the core slice shows the diff. If yes, that part is breaking and `breaking` changes.
