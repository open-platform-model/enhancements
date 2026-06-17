# Design — Rename #ModuleRelease to #ModuleInstance

This document answers the question: "What is the proposed solution and how does it work?" The trade-off reasoning — especially the contested wire-contract questions — lives in `03-decisions.md`.

## Design Goals

- The `core` deployable-artifact definition and its supporting identity types read as *instance* vocabulary end-to-end: `#ModuleInstance`, `#ModuleInstanceMap`, `#InstanceIdentity`, `#ctx.instance`, `#Component.#instance`.
- The rename is a pure terminology change — zero behavioral change. The same UUID derivation, the same `#names`/DNS computation, the same `values` unification, the same auto-secrets discovery, just under instance-named identifiers.
- The target schema in `schemas/target.cue` compiles and captures the full renamed surface, so the implementation slice is a mechanical, reviewable substitution rather than a redesign.
- The boundary between "renamable purely within `core`" and "wire contract that forces downstream coordination" is stated explicitly, so promotion to `accepted` is an informed decision, not an accidental breaking change.

## Non-Goals

- **Renaming the operator's `Release` CRD** (`opm-operator/api/v1alpha1/release_types.go`). That CRD is the GitOps *reconciliation* resource — it fetches a Flux artifact, renders it, applies via SSA, prunes, honors `dependsOn`/`suspend`. It is the *act of releasing*, not the instance; "Release" fits it and Argo/Flux precedent supports it. Out of scope by intent (per the scoping decision recorded in D1).
- **Any change to behavior, evaluation semantics, or field shapes** beyond the identifiers themselves.
- **Renaming `#Module`, `#Platform`, `#Component`, `#Trait`, `#Resource`, `#Blueprint`** or any other core construct.
- **A compatibility-alias / deprecation window in `core`.** Whether one is offered is an open question (OQ3); the default position is a hard rename, since `core` is pre-`v1`.

## High-Level Approach

Substitute the "Release" lexeme with "Instance" across the `core` schema's deployable-artifact family, plus its `SPEC.md` and generated `INDEX.md`. Three layers are affected, and they are *not* equally containable:

1. **CUE definition identifiers** (`#ModuleRelease`, `#ReleaseIdentity`, `#ctx.release`, `#Component.#release`, `#moduleRelease`, …). These are resolved at compile time *within* the published module. Renaming them is a source-level change in `core`; downstream CUE that imports `opmodel.dev/core` and references these identifiers by name must update, but nothing matches them as opaque strings.
2. **The `kind` discriminator string** `"ModuleRelease"` (`module_release.cue:11`). This is *not* core-internal — the library kernel and the operator's `Release` reconciler match on this literal to decide whether a rendered artifact is a deployable instance (`opm-operator/.../release_types.go` rejects any kind that is not `#ModuleRelease`). Changing it is a wire-contract change that breaks downstream until they update in lockstep.
3. **The label domain** `module-release.opmodel.dev/{name,uuid}`. These keys land on rendered Kubernetes objects and may be used in selectors. Changing them is observable on the data plane and on anything that selects by them.

The clean, truly core-scoped change is layer 1. Layers 2 and 3 are where "core-only" stops being true — they are called out as decisions (D2, D3) so the scope is chosen deliberately rather than discovered during implementation.

## Schema / API Surface

The full renamed surface is in [`schemas/target.cue`](schemas/target.cue). Headline mapping:

| Today (`core/src`) | Proposed |
| --- | --- |
| `#ModuleRelease` | `#ModuleInstance` |
| `kind: "ModuleRelease"` | `kind: "ModuleInstance"` *(wire — see D2)* |
| `#ModuleReleaseMap` | `#ModuleInstanceMap` |
| `#ReleaseIdentity` | `#InstanceIdentity` |
| `#ctx.release` | `#ctx.instance` |
| `#Component.#release` | `#Component.#instance` |
| `#moduleRelease` / `#moduleReleaseMetadata` (transformer) | `#moduleInstance` / `#moduleInstanceMetadata` |
| label `module-release.opmodel.dev/{name,uuid}` | `module-instance.opmodel.dev/{name,uuid}` *(wire — see D3)* |

`#InstanceIdentity` keeps its four fields verbatim (`name`, `namespace`, `uuid`, `clusterDomain`). The `uuid` derivation is unchanged: `SHA1(OPMNamespace, "\(#moduleMetadata.uuid):\(name):\(namespace)")`.

## Integration Points

Core only (the slice; `affects: [core]`):

- `core/src/module_release.cue` → renamed file `core/src/module_instance.cue`. `#ModuleRelease` → `#ModuleInstance`, `kind`, `#ModuleReleaseMap` → `#ModuleInstanceMap`, the `#ctx: instance:` wiring block, and the label keys.
- `core/src/module_context.cue` — `#ReleaseIdentity` → `#InstanceIdentity` and its doc comment.
- `core/src/module.cue` — `#ctx.release` slot → `#ctx.instance` (`module.cue:68`), the `#release: #ctx.release` projection → `#instance: #ctx.instance` (`module.cue:47`), and the comment at `module.cue:63`.
- `core/src/component.cue` — `#release: #ReleaseIdentity` → `#instance: #InstanceIdentity` (`component.cue:39`); the `#names.dns` computation references (`component.cue:52-53`).
- `core/src/transformer.cue` — `#moduleRelease` → `#moduleInstance`, `#moduleReleaseMetadata` → `#moduleInstanceMetadata`, label key at `transformer.cue:147`.
- `core/SPEC.md` — every section naming the renamed constructs (co-update gated by the `core-schema-edit` skill + pre-commit hook).
- `core/INDEX.md` — regenerated via `task generate:index`.

Downstream coordination *required if D2/D3 land* (tracked here, executed in those repos under their own OpenSpec slices — they are why a "core-only" rename is not self-contained):

- `library/opm/...` — kind-detection and `synth/release.go` helper match the `kind` string and consume `#ReleaseIdentity`-shaped context.
- `opm-operator/api/v1alpha1/release_types.go` and reconcilers — kind-detection rejects non-`#ModuleRelease` renders.

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
// rendered label: module-instance.opmodel.dev/name: mc-prod   (only if D3 lands)
```

The component-facing identity reads the same way:

```cue
// before:  #Component.#release: #ReleaseIdentity ; dns.fqdn = "\(resourceName).\(#release.namespace).svc.\(#release.clusterDomain)"
// after:   #Component.#instance: #InstanceIdentity ; dns.fqdn = "\(resourceName).\(#instance.namespace).svc.\(#instance.clusterDomain)"
```
