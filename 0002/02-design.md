# Design — Rename #ModuleRelease to #ModuleInstance

This document answers the question: "What is the proposed solution and how does it work?" The trade-off reasoning — especially the contested wire-contract questions — lives in `03-decisions.md`.

## Design Goals

- One coherent *instance* vocabulary end-to-end across `core`, `library`, `opm-operator`, and `cli` — the same construct stops wearing four inconsistent "Release" spellings. The `core` family reads `#ModuleInstance`, `#ModuleInstanceMap`, `#InstanceIdentity`, `#ctx.instance`, `#Component.#instance`; the library, operator CRDs, and CLI follow.
- The rename is a pure terminology change — zero behavioral change. The same UUID derivation, the same `#names`/DNS computation, the same `values` unification, the same reconcile loops, just under instance-named identifiers.
- The target schema in `schemas/target.cue` compiles and captures the full renamed surface (core family + wire kinds + operator CRD shapes), so each implementation slice is a mechanical, reviewable substitution rather than a redesign.
- The wire contract (kind strings, label domain) and the operator API group move *with* the definitions, in a deliberately sequenced rollout (core → library → operator ‖ cli), rather than being left split-brained.

## Non-Goals

- **Any change to behavior, evaluation semantics, or field shapes** beyond the identifiers, kind strings, label keys, and API group.
- **Renaming `#Module`, `#Platform`, `#Component`, `#Trait`, `#Resource`, `#Blueprint`** or any other construct. The `Platform` CRD keeps its kind; it only moves to the new API group along with its siblings (D5).
- **A compatibility-alias / deprecation window in any repo.** Hard rename — `core` is pre-`v1` and the operator/CLI have no external users (D8).

Note: the previous Non-Goal "do not rename the operator's `Release` CRD" (D1) has been **reversed** by D2 — that CRD is now renamed to `ModulePackage`. See `03-decisions.md`.

## High-Level Approach

Substitute the "Release" lexeme with "Instance" across the whole stack. Three layers are affected; under the cross-cutting scope (D2) all three move together:

1. **CUE definition identifiers** (`#ModuleRelease`, `#ReleaseIdentity`, `#ctx.release`, `#Component.#release`, `#moduleRelease`, …) and the Go identifiers that mirror them in `library`/`opm-operator`/`cli`. These are resolved at compile time / link time within each module; downstream that references them by name updates in lockstep.
2. **The wire `kind` discriminator strings** — `"ModuleRelease"` → `"ModuleInstance"`, `"BundleRelease"` → `"BundleInstance"`, and the GitOps CRD kind `Release` → `ModulePackage`. The library kernel, the operator reconcilers, and the CLI kind-detection all match these literals; they move together (D3).
3. **The label domain** `module-release.opmodel.dev/{name,namespace,uuid}` → `module-instance.opmodel.dev/*`, plus **the operator API group** `releases.opmodel.dev` → `opmodel.dev` and the finalizer key. These land on / govern live Kubernetes objects — the most observable, most disruptive layer (D4, D5).

Layer 1 is the bulk of the mechanical work; layers 2 and 3 are the wire/cluster contract and are the reason the rollout must be sequenced rather than landed independently.

## Schema / API Surface

The full renamed surface is in [`schemas/target.cue`](schemas/target.cue). Headline mapping:

| Today | Proposed | Layer |
| --- | --- | --- |
| `#ModuleRelease` | `#ModuleInstance` | core CUE |
| `#ModuleReleaseMap` | `#ModuleInstanceMap` | core CUE |
| `#ReleaseIdentity` | `#InstanceIdentity` | core CUE |
| `#ctx.release` | `#ctx.instance` | core CUE |
| `#Component.#release` | `#Component.#instance` | core CUE |
| `#moduleRelease` / `#moduleReleaseMetadata` (transformer) | `#moduleInstance` / `#moduleInstanceMetadata` | core CUE |
| `kind: "ModuleRelease"` | `kind: "ModuleInstance"` | wire (D3) |
| `kind: "BundleRelease"` | `kind: "BundleInstance"` | wire (D3, D7) |
| label `module-release.opmodel.dev/{name,namespace,uuid}` | `module-instance.opmodel.dev/*` | wire (D4) |
| operator `ModuleRelease` CRD | `ModuleInstance` CRD | operator (D2) |
| operator GitOps `Release` CRD | `ModulePackage` CRD | operator (D2) |
| API group `releases.opmodel.dev` | `opmodel.dev` | operator (D5) |
| finalizer `releases.opmodel.dev/cleanup` | `opmodel.dev/cleanup` | operator (D5) |
| CLI `opm release …` (alias `rel`) | `opm instance …` (alias `inst`) | cli (D6) |

`#InstanceIdentity` keeps its four fields verbatim (`name`, `namespace`, `uuid`, `clusterDomain`). The `uuid` derivation is unchanged: `SHA1(OPMNamespace, "\(#moduleMetadata.uuid):\(name):\(namespace)")`.

## Integration Points

The full per-repo touch-list lives in the README Cross-References table; the representative surface per slice:

**`core`** (publish first):

- `core/src/module_release.cue` → renamed file `core/src/module_instance.cue`. `#ModuleRelease` → `#ModuleInstance`, `kind`, `#ModuleReleaseMap` → `#ModuleInstanceMap`, the `#ctx: instance:` wiring block, and the label keys.
- `core/src/module_context.cue` — `#ReleaseIdentity` → `#InstanceIdentity`.
- `core/src/module.cue` — `#ctx.release` → `#ctx.instance`; `#release` projection → `#instance`.
- `core/src/component.cue` — `#release` → `#instance`; `#names.dns` references.
- `core/src/transformer.cue` — `#moduleRelease*` → `#moduleInstance*`; label key.
- `core/SPEC.md` (co-update gated by `core-schema-edit`) + `core/INDEX.md` (regenerated).

**`library`** (consume new `core`):

- `opm/module/release.go`, `opm/schema/{metadata,decode,context,paths}.go`, `opm/helper/synth/{release,render}.go`, `opm/helper/loader/file/release.go` + `internal/shape/shape.go`, `opm/kernel/{process,compile,synth,wrappers,phases,inputs,validate_typed}.go`, `opm/core/{compiled,resource}.go` — `Release`→`Instance` Go identifiers, the `"ModuleRelease"` kind literal, and `module-release.opmodel.dev/*` label literals; ~24 test fixtures.

**`opm-operator`** (consume new `core`+`library`):

- `api/v1alpha1/modulerelease_types.go` → `ModuleInstance`, `api/v1alpha1/release_types.go` → `ModulePackage`, API-group markers → `opmodel.dev` (D5); reconcilers/reconcile/render/labels under `internal/` and `pkg/core/labels.go`; regenerated CRDs/RBAC/`PROJECT` and `config/samples` + `test/fixtures`.

**`cli`** (consume new `core`+`library`):

- `internal/cmd/release/` → `internal/cmd/instance/` (command surface, D6), `pkg/bundle/release.go` → `BundleInstance` (D7), kind-detection (`get_release_file.go`, `release_kind.go`), `pkg/core/labels.go`, examples/docs.

## Before / After

```cue
// before
prod: #ModuleRelease & {
	#module: minecraft
	metadata: {name: "mc-prod", namespace: "games-prod"}
	values: {...}
}
// rendered label: module-release.opmodel.dev/name: mc-prod

// after
prod: #ModuleInstance & {
	#module: minecraft
	metadata: {name: "mc-prod", namespace: "games-prod"}
	values: {...}
}
// rendered label: module-instance.opmodel.dev/name: mc-prod   (D4)
// applied as kind ModuleInstance under apiVersion opmodel.dev/v1alpha1 (D2, D5)
// deployed via:  opm instance apply prod   (D6)
```

The component-facing identity reads the same way:

```cue
// before:  #Component.#release: #ReleaseIdentity ; dns.fqdn = "\(resourceName).\(#release.namespace).svc.\(#release.clusterDomain)"
// after:   #Component.#instance: #InstanceIdentity ; dns.fqdn = "\(resourceName).\(#instance.namespace).svc.\(#instance.clusterDomain)"
```
