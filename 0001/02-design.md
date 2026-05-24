# Design — `#Platform` Redesign Umbrella

## Design Goals

- One platform can host multiple SemVer builds of the same catalog at once. The matcher pairs each consumer Module against transformers whose stamped FQN matches the consumer's primitive FQN, version-for-version.
- The version axis of the FQN is exact (SemVer 2.0). Two builds of the same primitive at different SemVers occupy distinct keys in `#composedTransformers` and never silently collide. Same-SemVer rebuilds with divergent content surface as a unification failure at materialize time rather than silent drift.
- Platform teams express version policy declaratively (`range` + `allow` + `deny`). Out-of-policy consumer pins surface as a structured "FQN not on platform" diagnostic, not a render-time error or a schema mismatch downstream.
- Catalogs are plain CUE packages. Catalog authoring is decoupled from `#Module` — `#Module` becomes the consumer artifact only. Authors write `#Resource` / `#Trait` / `#Blueprint` / `#ComponentTransformer` at the top of their package; the catalog's identity (`Version`, `ModulePath`) lives in a single per-package constant.
- Catalog identity is *burned in at publish time*: the OCI artifact contains concrete `metadata.version` on every primitive, sourced from the SemVer the publish task tagged. The kernel never mutates pulled CUE to inject a version; drift between OCI tag and catalog content is impossible by construction.
- The kernel's match step always unifies the consumer primitive value with the transformer's `requiredResources[FQN]` / `requiredTraits[FQN]` entry before pairing. FQN match is necessary but not sufficient — schema agreement is enforced for every paired primitive.
- Missing FQNs are hard failures, not warnings. The kernel reports one structured diagnostic per missing FQN (component name, FQN, available alternatives at adjacent SemVers). Match accumulates every miss in one pass; it does not fail-fast.
- Optional primitives stay optional. A consumer-declared trait on the optional axis of a matched transformer is allowed; a required-axis miss fails the match.
- Modules read deployment identity and per-component computed names from an inline `#ctx` channel on `#Module`. `#ctx` is two-field (`release` and `components`) and takes no platform or environment inputs at this stage.
- Per-component computed names (`resourceName`, DNS variants) are deterministic functions of release identity, component name, and component author overrides. Identical inputs yield identical names; renaming a component or moving a release between namespaces changes every derived name in one place.
- Each `#Component.#names` is the **single source of truth** for that component's computed names; it derives them inline from the component's own `metadata` plus the release context wired in by the parent `#Module`. `#ctx.components` is a pure CUE projection of every `#components.<id>.#names`. No `#ContextBuilder`, no separate compute step, no risk of `#ctx.components.<id>` drifting from `#components.<id>.#names`.
- Module identity is not mirrored under `#ctx` — `#Module.metadata` (name, version, fqn, uuid) is already the single source. `#ctx` carries only the facts that have no other home (release identity) plus the projection used for cross-component reads (`components`). Module developers do not author `#ctx`; they read from it.

## Non-Goals

- `#Claim` / `#ModuleTransformer` / module extension surface — future enhancement.
- Platform capabilities (`#Capability`, `#Platform.#provides`, `#Module.#consumes`) and the typed `#ctx.platform` extension channel — future enhancement. This design leaves `#ctx` open at the top level (the `...` opening under `#ctx`) so a future addition of `platform` / `environment` siblings is purely additive.
- `#Bundle` cross-module context — deferred.
- Content hashes for immutable ConfigMaps / Secrets surfaced through `#ctx` — revisit when a concrete module-readable use case surfaces.
- Renderer / `#transform` execution model — unchanged. Transformers still receive `#moduleRelease`, `#component`, `#context`; the `#TransformerContext` shape stays as it is for this enhancement, with `#ctx` reads happening from the module side rather than the transformer side.
- Replacing `cuelang.org/go/mod` with a custom OCI client. CUE's module proxy / OCI fetch is the substrate; the kernel wires into it via a `Registry` field on `*Kernel` that maps to `CUE_REGISTRY`.
- Signing and verification of catalog artefacts in OCI — inherits whatever guarantees `CUE_REGISTRY` provides.
- A discovery UX (`opm catalog list`, web UI) — separate concern.
- Backwards-compatibility for legacy `v1alpha2` fixtures. The repository's only consumer of the current `#Platform` shape is `library/modules/opm_platform/`, which this enhancement rewrites in lockstep with core.
- Migration of third-party catalog modules. Only the OPM core catalog at `catalog/opm/` is in scope.

## High-Level Approach

The redesign lands as three coordinated changes, designed together because each carries a constraint that one of the others has to satisfy.

### 1. Registry becomes path-keyed; the kernel materializes it

`#Platform.#registry` shifts from `[Id=#NameType]: #ModuleRegistration { #module!: #Module, … }` to `[Id=#NameType]: #Subscription { path!, enable, filter? }`. A subscription stands for "every published build of this catalog that the filter selects." The CUE-level `#Platform` value is a *spec*; the kernel realises it.

The realisation is a new `Kernel.Materialize(*Platform) (*MaterializedPlatform, error)` step. It walks each subscription, **parses any `range` string Go-side via `github.com/Masterminds/semver/v3`** (D11 — CUE cannot evaluate SemVer range syntax natively), then resolves the in-range subset against the OCI registry (via `cuelang.org/go/mod`), applies `allow` and `deny` per D10's order, pulls every selected build into the local CUE module cache, loads each package, and indexes top-level `#ComponentTransformer` values by their stamped FQN. The result is a synthetic `#composedTransformers: #TransformerMap` plus a `#matchers.{resources,traits}: [FQN]: [...#ComponentTransformer]` reverse index that `Match` consults.

`Match` takes `*MaterializedPlatform` instead of `*Platform`. Materialize is an explicit step rather than implicit-inside-Match so the caller controls when pulling and indexing happen — typically once per platform spec, reused across many `Match` calls.

`#knownResources` and `#knownTraits` are removed from `#Platform`. Primitives surface only as the `requiredResources` / `optionalResources` / `requiredTraits` / `optionalTraits` of materialized transformers. Primitives that no transformer references are unreachable on the platform.

### 2. Catalogs drop `#defines`; FQNs gain SemVer; publish stamps identity

`#Module.#defines` is removed. `#Module` becomes the consumer artifact only — `#components`, `#config`, `debugValues`, plus the new `#ctx` slot. Catalogs become plain CUE packages that export `#Resource`, `#Trait`, `#Blueprint`, and `#ComponentTransformer` definitions at the top level. The kernel discovers them by walking top-level package values at materialize time.

Catalog identity lives in a single root-package constant:

```cue
Catalog: {
  Version:    #VersionType | *"0.0.0-dev"   // overwritten at publish
  ModulePath: "opmodel.dev/modules/opm"
}
```

Every primitive sources its `metadata.version` from `Catalog.Version` and its `metadata.modulePath` from `Catalog.ModulePath` (subpath suffixes appended per subdirectory). The publish task overwrites `Catalog.Version` with the concrete SemVer *in a temp build dir* before running `cue mod publish`. The source tree is never mutated; failure mid-flow leaves the build dir for inspection. Source-tree `Catalog.Version` carries a `0.0.0-dev` default so dev-time `cue vet` works without any pre-stamp; primitives evaluate to `…@0.0.0-dev` FQNs locally.

`#FQNType` changes regex from `…@v[0-9]+$` to `…@<SemVer 2.0>$`. `metadata.version` on `#Resource` / `#Trait` / `#Blueprint` / `#ComponentTransformer` changes type from `#MajorVersionType` to `#VersionType`. `#MajorVersionType` is retired from primitive metadata (it may survive elsewhere — `#BundleFQNType` keeps it for now). Two builds of the same primitive at different SemVers are distinct keys in `#composedTransformers` and unify cleanly per CUE's map semantics; same-SemVer rebuilds with identical content collapse via unification, and divergent content fails CUE evaluation at the materialize step.

Match runs against the materialized platform with FQN-keyed lookup followed by an always-on `unify(consumer_component.#resources[FQN], transformer.requiredResources[FQN])` (and the analogous traits step) before predicate evaluation. There is no `--strict` mode, no skip in production — unification cost is bounded (a few CUE evaluations per matched pair) and catches the failure mode that would otherwise propagate to render time as a confusing error. Same-SemVer rebuilds with byte-identical bodies collapse to one map entry under unification; divergent bodies produce a CUE error of the form `conflicting values "X" and "Y": ./fileA:line:col ./fileB:line:col` — the kernel surfaces this verbatim with no Go-side formatting (experiment 03 confirmed the format is authoring-grade). Missing FQNs produce one structured `MissingFQN` error per `(release, component, FQN)` triple; unification failures produce one `UnifyError` per pair. The `MatchPlan` accumulates everything in one pass.

### 3. `#ctx` lands as an inline channel; components compute their own `#names`

`#Module` gains an inline `#ctx` struct with exactly two fields and an open top so future enhancements can add `platform` / `environment` siblings additively:

```cue
#Module: {
  …
  #ctx: {
    release: #ReleaseIdentity
    components: {
      for id, c in #components { (id): c.#names }
    }
    ...
  }
}
```

`#ReleaseIdentity` carries the deployment-scoped facts that no other slot owns — release name, namespace, UUID, and the cluster-domain default — and the kernel populates it once per release via `#ModuleRelease`:

```cue
#ReleaseIdentity: {
  name!:         #NameType
  namespace!:    #NameType
  uuid!:         #UUIDType
  clusterDomain: string | *"cluster.local"
}
```

Module identity intentionally does **not** appear under `#ctx` — `#Module.metadata` (name, version, fqn, uuid) is already the canonical home; a `#ctx.module` mirror would be pure restatement and a sync surface the matcher and renderer would have to keep honest.

`#Component` gains two definition-level slots: `#release` (hidden injection target wired by the parent `#Module`) and `#names` (the per-component computed names). `metadata.resourceName` carries the author override with a default-disjunction cascade so the override wins when set and falls back to `metadata.name` when absent:

```cue
#Component: {
  metadata: {
    name!:        #NameType
    resourceName: *name | #NameType   // override wins; defaults to name
    …
  }
  #release: #ReleaseIdentity          // wired by #Module pattern constraint
  #names: {
    resourceName: metadata.resourceName
    dns: {
      short: resourceName
      local: "\(resourceName).\(#release.namespace)"
      fqdn:  "\(resourceName).\(#release.namespace).svc.\(#release.clusterDomain)"
    }
  }
  …
}
```

The parent `#Module` wires the release into every component via the `#components` pattern constraint:

```cue
#components: [Id=#NameType]: #Component & {
  metadata: name: string | *Id
  #release: #ctx.release
}
```

There is no `#ContextBuilder` and no builder unification step. `#ModuleRelease` sets `#module.#ctx.release` from its own metadata; CUE evaluates every `#Component.#names` against its injected `#release`; the `#ctx.components` comprehension projects each `#names` into a sibling map under `#ctx`. The matcher and renderer see fully concrete values.

**Authoring caveat.** `#names` lives in `#Component`'s definition body, not in the lexical scope of any concrete instance value. CUE references resolve pre-unification, so a component body that writes `spec: url: "http://\(#names.dns.fqdn)"` will see `reference "#names" not found`. The canonical access path from inside a component's `spec` (or `#resources` / `#traits`) is **the projection**:

- **Self-reference:** `#ctx.components.<self-id>.dns.fqdn` — `#ctx` is a sibling of `#components` at the `#Module` level and IS in scope.
- **Cross-component reference:** `#ctx.components.<other-id>.dns.fqdn` — same path, different id.
- **External access (from outside any component literal):** `<module-value>.#components.<id>.#names.dns.fqdn` works too — but is rarely what authors want.

Experiment 07 (`ctx-cycle-freedom`) walked into this and used the projection form throughout; the lesson belongs in the SPEC authoring guide when this lands in core.

The cluster-domain default lives on `#ReleaseIdentity` itself (`clusterDomain: string | *"cluster.local"`); operators override per release. No platform-side capability is required — that's the line between this enhancement and the future platform-capabilities work.

## Schema / API Surface

Full schema lives in [`schemas/target.cue`](schemas/target.cue) and tightens as decisions land in `03-decisions.md`. Headline shapes:

```cue
// core/types.cue
#FQNType: =~"^[a-z0-9.-]+(/[a-z0-9.-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"
// MAJOR-only `@v[0-9]+$` retired from primitive metadata.
```

```cue
// core/resource.cue, core/trait.cue, core/blueprint.cue, core/transformer.cue
metadata: {
  modulePath!: #ModulePathType
  version!:    #VersionType    // was #MajorVersionType
  name!:       #NameType
  fqn:         #FQNType & "\(modulePath)/\(name)@\(version)"
}
```

```cue
// core/module.cue — #defines REMOVED; #ctx ADDED as inline struct.
#Module: {
  metadata: { … }            // unchanged; carries module identity (name, version, fqn, uuid)
  #components: [Id=#NameType]: #Component & {
    metadata: name: string | *Id
    #release: #ctx.release   // wire release context into every component
  }
  #config:     _
  debugValues: _
  #ctx: {
    release:    #ReleaseIdentity
    components: { for id, c in #components { (id): c.#names } }
    ...                       // open for future `platform` / `environment` siblings (OQ17)
  }
}
```

```cue
// core/platform.cue
#Platform: {
  kind: "Platform"
  metadata: { … }
  type!:     string
  #registry: [Id=#NameType]: #Subscription
  // #knownResources / #knownTraits REMOVED.
  // #composedTransformers and #matchers become kernel-filled optional slots:
  #composedTransformers?: #TransformerMap
  #matchers?: {
    resources: [#FQNType]: [...#ComponentTransformer]
    traits:    [#FQNType]: [...#ComponentTransformer]
  }
}

#Subscription: {
  path!:   #ModulePathType   // e.g. "opmodel.dev/modules/opm"
  enable:  bool | *true
  filter?: #SubscriptionFilter
}

#SubscriptionFilter: {
  range?: string             // SemVer constraint, e.g. ">=1.0.0 <2.0.0"
  allow?: [...#VersionType]  // force-include
  deny?:  [...#VersionType]  // force-exclude
}
```

```cue
// core/module_context.cue (new file) — identities only, no wrappers.
#ReleaseIdentity: {
  name!:         #NameType
  namespace!:    #NameType
  uuid!:         #UUIDType
  clusterDomain: string | *"cluster.local"
}
#ComponentNames: {
  resourceName!: #NameType
  dns: { short!: string, local!: string, fqdn!: string }
}
// #ModuleContext / #RuntimeContext / #ModuleIdentity / #ContextBuilder are NOT introduced.
// #ctx is inline on #Module; components compute their own #names.
```

Go surface:

```go
// library/opm/kernel/kernel.go
type Kernel struct {
    Registry string          // default "ghcr.io/open-platform-model"; threads to CUE_REGISTRY for OCI ops
    cueCtx   *cue.Context
    // ... existing fields (logger, tracer, clock)
}

// library/opm/platform/ (or new library/opm/materialize/)
type MaterializedPlatform struct {
    Platform *Platform
    Package  cue.Value   // synthetic value with #composedTransformers + #matchers filled
}

func (k *Kernel) Materialize(p *Platform) (*MaterializedPlatform, error)
```

```go
// library/opm/compile/match.go — Match takes a MaterializedPlatform.
func Match(components cue.Value, plat *MaterializedPlatform, b api.Binding) (*MatchPlan, error)
// Inside, for each (component, FQN):
//   1. composed[FQN] → if absent, append MissingFQN error
//   2. unify(consumer_primitive, tf.requiredResources[FQN]) — failure → UnifyError
//   3. predicate eval (labels, requiredResources, requiredTraits)
```

## Integration Points

- `core/types.cue` — `#FQNType` regex change; `#MajorVersionType` kept (still used by `#BundleFQNType`); `#VersionType` becomes the primitive-metadata version type.
- `core/resource.cue`, `core/trait.cue`, `core/blueprint.cue` — `metadata.version: #MajorVersionType` → `#VersionType`.
- `core/transformer.cue` — same change to `metadata.version`; transformer `requiredResources` / `requiredTraits` shapes unchanged.
- `core/module.cue` — delete `#defines`; add inline `#ctx { release, components, ... }` channel; wire `#release` into every component via the `#components` pattern constraint.
- `core/component.cue` — add `metadata.resourceName: *name | #NameType` cascade; add hidden `#release: #ReleaseIdentity` injection slot; add `#names` block that computes `resourceName` + DNS variants inline.
- `core/module_release.cue` — assemble release identity; set `#module.#ctx.release` from release metadata; that's it. No builder, no per-component injection — CUE evaluates the rest.
- `core/platform.cue` — replace `#ModuleRegistration` with `#Subscription`; remove `#knownResources` / `#knownTraits`; downgrade `#composedTransformers` and `#matchers` to optional kernel-filled slots.
- `core/module_context.cue` *(new)* — home of `#ReleaseIdentity` and `#ComponentNames` only. `#ModuleContext`, `#RuntimeContext`, `#ModuleIdentity`, `#ContextBuilder` are deliberately not introduced.
- `core/INDEX.md` — regenerated via `task generate:index` once schema lands.
- `core/SPEC.md` — co-update per the core editing protocol: new sections for `#Subscription`, `#SubscriptionFilter`, `#ReleaseIdentity`, `#ComponentNames`; updated sections for `#Platform`, `#Module` (now carries inline `#ctx`), `#Component` (now carries `#release` + `#names`), `#FQNType`, `#Resource` / `#Trait` / `#Blueprint` / `#ComponentTransformer` metadata.
- `library/opm/kernel/kernel.go` — add `Registry` field; default to `"ghcr.io/open-platform-model"`.
- `library/opm/kernel/phases.go` — `Match` signature change.
- `library/opm/compile/match.go` — algorithm rewrite (lookup → unify → predicate); structured diagnostics (`MissingFQN`, `UnifyError`).
- `library/opm/materialize/` *(new package)* — `Materialize` step, OCI pull via `cuelang.org/go/mod`, top-level package scan, FQN indexing.
- `library/modules/opm_platform/platform.cue` — rewrite to use `#Subscription`-shaped registry; switch import from `opmodel.dev/core/v1alpha2@v1` to `opmodel.dev/core@v0`.
- `catalog/opm/v1alpha1/` (and any future `v2alpha1/`) — repackage: drop any `#Module.#defines` wrapper; export primitives at top level; introduce root `Catalog: { Version, ModulePath }` constant; rewire every primitive's `metadata.version` and `metadata.modulePath` to source from the constant.
- `modules/Taskfile.yml` — extend the publish task: `rsync` to `.build/catalog/`; overwrite `Catalog.Version` with the requested SemVer; `cue vet` from build dir; `cue mod publish` from build dir.

## Before / After

### Platform fixture — `library/modules/opm_platform/platform.cue`

```diff
  package opm_platform

- import (
-   p          "opmodel.dev/core/v1alpha2@v1"
-   opm_package "opmodel.dev/modules/opm"
- )
+ import p "opmodel.dev/core@v0"

  p.#Platform
  metadata: { name: "k8s-default", description: "Default Kubernetes Platform" }
  type: "kubernetes"

  #registry: {
    opm: {
-     #module: opm_package
-     enabled: true
+     path:   "opmodel.dev/modules/opm"
+     enable: true
+     filter: { range: ">=1.0.0 <2.0.0" }
    }
  }
```

### Module / component author — App A's `api` component

```diff
  #components: api: {
    #resources: container: {
      spec: container: {
        env: {
-         SELF_URL: "http://api.app-a-prod.svc.cluster.local"
+         SELF_URL: "http://\(#names.dns.fqdn)"
        }
      }
    }
  }
```

When the release moves from `app-a-prod` to `app-a-staging`, the string updates automatically. The component computes `#names` itself from its `metadata` + the `#release` wired in by the parent `#Module`; the override flows from `metadata.resourceName` (or defaults to `metadata.name`, which itself defaults to the `#components` map key). The renderer never invokes a builder — CUE unification does the work.

### Catalog source layout — `catalog/opm/v1alpha1/` → repackaged

```diff
  opmodel.dev/modules/opm/
    cue.mod/module.cue
-   module.cue                            # #Module with #defines.{resources,traits,transformers}
+   catalog.cue                           # Catalog: { Version, ModulePath }
    resources/container.cue
    traits/scaling.cue
    transformers/deployment_transformer.cue
```

```diff
  // resources/container.cue (excerpt)
  #ContainerResource: c.#Resource & {
    metadata: {
-     modulePath: "opmodel.dev/opm/resources/workload"
-     version:    "v1"
+     modulePath: "\(opm.Catalog.ModulePath)/resources/workload"
+     version:    opm.Catalog.Version
      name:       "container"
    }
    spec: container: #ContainerSchema
  }
```

### Matching at the kernel — App A vs App B against one platform

App A pins `1.0.4`, App B pins `1.4.0`. Subscription filter: `range: ">=1.0.0 <2.0.0"`. `Materialize` pulls every published build in the range, say `1.0.4`, `1.1.0`, `1.2.0`, `1.4.0`. Synthetic `#composedTransformers` contains:

```
"opmodel.dev/modules/opm/transformers/kubernetes/deployment-transformer@1.0.4": { … }
"opmodel.dev/modules/opm/transformers/kubernetes/deployment-transformer@1.1.0": { … }
"opmodel.dev/modules/opm/transformers/kubernetes/deployment-transformer@1.2.0": { … }
"opmodel.dev/modules/opm/transformers/kubernetes/deployment-transformer@1.4.0": { … }
"opmodel.dev/modules/opm/resources/workload/container@1.0.4":  { … }  (carried inside each transformer's requiredResources)
…
```

App A's release: components declare `container@1.0.4`. Matcher looks up `container@1.0.4` in `#matchers.resources` → finds `deployment-transformer@1.0.4` → unifies App A's container value with the 1.0.4 schema → pairs → renders against the 1.0.4 transformer body. App B's release: same flow, different keys; pairs against `deployment-transformer@1.4.0` and its 1.4.0 schema. App C pins `2.0.0`: filter excludes the major; matcher emits one `MissingFQN` per consumer-declared `container@2.0.0` reference; release fails at match time with the structured error pointing at the adjacent `…@1.4.0` SemVers that *are* on the platform.
