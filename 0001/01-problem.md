# Problem Statement — `#Platform` Redesign Umbrella

## Current State

Today's `#Platform`, defined in [`core/platform.cue`](../../core/platform.cue), is a registry of fully-imported `#Module` values. Each registry entry embeds a concrete Module; the platform's projections (`#knownResources`, `#knownTraits`, `#composedTransformers`, `#matchers`) are computed by walking every enabled entry's `#defines` block:

```cue
// core/platform.cue today
#Platform: {
  kind: "Platform"
  metadata: { name!, description?, labels?, annotations? }
  type!: string
  #registry: [Id=#NameType]: #ModuleRegistration

  #knownResources:       { for _, reg in #registry if reg.enabled
                             if reg.#module.#defines.resources != _|_
                             for fqn, v in reg.#module.#defines.resources { (fqn): v } }
  #knownTraits:          { /* same shape */ }
  #composedTransformers: #TransformerMap & { /* same shape, transformers */ }
  #matchers: {
    resources: [FQN]: [...#ComponentTransformer]    // reverse index
    traits:    [FQN]: [...#ComponentTransformer]
  }
}

#ModuleRegistration: {
  #module!: #Module
  enabled: bool | *true
  presentation?: { … }
  metadata?: { labels?, annotations? }
}
```

A platform fixture is wired up by importing a Module via CUE and assigning it to `#registry.<id>.#module`. The default Kubernetes fixture at [`library/modules/opm_platform/platform.cue`](../../library/modules/opm_platform/platform.cue) does exactly this:

```cue
import opm_package "opmodel.dev/catalogs/opm"
#registry: opm: { #module: opm_package, enabled: true }
```

(The same fixture still imports `opmodel.dev/core/v1alpha2@v1` rather than the published `opmodel.dev/core@v0` — the core repo split is mid-flight, and the library rewire is a sibling task that this enhancement depends on landing first or in parallel.)

Each catalog Module is itself a `#Module` value with its primitives published through `#defines.{resources,traits,transformers}`, a struct keyed by `#FQNType` declared on [`core/module.cue`](../../core/module.cue):

```cue
#Module: {
  metadata: { name, modulePath, version, fqn, uuid, … }
  #components: [Id=string]: #Component & { … }
  #defines?: {
    resources?:    [FQN=#FQNType]: #Resource         & { metadata: fqn: FQN }
    traits?:       [FQN=#FQNType]: #Trait            & { metadata: fqn: FQN }
    transformers?: [FQN=#FQNType]: #ComponentTransformer & { metadata: fqn: FQN }
  }
  #config:     _
  debugValues: _
}
```

Primitive FQNs are MAJOR-only. The regex in [`core/types.cue`](../../core/types.cue) pins the version suffix at `@v[0-9]+$`:

```cue
#FQNType: =~"^[a-z0-9.-]+(/[a-z0-9.-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@v[0-9]+$"
#MajorVersionType: =~"^v[0-9]+$"
```

And `metadata.version` on `#Resource`, `#Trait`, `#Blueprint`, and `#ComponentTransformer` is `#MajorVersionType`. A primitive's FQN computes to `\(modulePath)/\(name)@\(version)` — every patch of a primitive at major `v1` collapses to the same FQN string.

The kernel's `Match` (`library/opm/kernel/phases.go`) is fed a `*Platform` directly. There is no pull step, no `Materialize`. CUE imports do the only resolution that happens; whatever the library's `cue.mod/module.cue` pins is what the platform sees. The kernel's only registry-shaped state is its bare `Kernel` struct — `{ cueCtx, logger, tracer, clock }` — with no `Registry` field, no OCI client, no version-policy plumbing.

The core schema itself ships **inside** the library binary today: `library/apis/core/embed.go` carries a `//go:embed cue.mod/module.cue v1alpha2/*.cue` directive that bakes a snapshot of the OPM schema into the Go package consumed by every kernel build. Per-version `Binding` types in `library/opm/api/v1alpha2/` dispatch validation through the embedded `embed.FS`. Two coupled consequences: (a) every schema bump in the standalone `core/` repo forces a library re-publish before any consumer can use the new shape — even when no library Go code changed; (b) consumers cannot point a single kernel binary at different core schema versions (e.g. one for staging on `v0.3`, one for prod on `v0.2`) — the binary is what it is. The same root pain as the registry side: the kernel collapses *core-schema version* into the binary itself instead of treating it as a runtime input.

Components today have no schema-level home for release identity or per-component computed names. `#Component` in [`core/component.cue`](../../core/component.cue) carries `metadata.{name, labels, annotations}` and the three definition slots (`#resources`, `#traits`, `#blueprints`); it computes a flattened `spec` from those slots and stops there. Per-component values like `resourceName`, the cluster-DNS suffix, or the predictable `<component>.<namespace>.svc.cluster.local` form are not anywhere on the `#Component`. Transformers that need them (a `deployment-transformer` emitting a `Service`, for example) reach into `#TransformerContext.#componentMetadata.name` and re-derive each one inline. Identical derivation logic lives in every transformer that needs the same name; identical mistakes propagate the same way.

`#ModuleRelease`, in [`core/module_release.cue`](../../core/module_release.cue), unifies the user's `values` into `#module.#config` and assembles `components` for rendering. It does not compute a runtime context channel and does not inject anything analogous to `#ctx` into the module:

```cue
let unifiedModule = #module & {#config: values}
…
components: {
  for name, comp in unifiedModule.#components { (name): comp }
  if len(_autoSecrets) > 0 { "opm-secrets": (#OpmSecretsComponent & {#secrets: _autoSecrets}).out }
}
```

The release knows its name, its namespace, its UUID. The module knows its name, version, FQN, UUID. None of it is exposed to component bodies through a typed channel.

## Gap / Pain

The five constraints below all share one root: today's `#Platform` collapses *catalog version*, *catalog identity*, *primitive identity*, and *runtime context* into a single CUE-time data structure assembled by direct imports. Anything that needs to vary along one of those axes — multiple catalog versions on one platform, a per-component computed name visible to a module body — has to be flattened against the others.

1. **One catalog version per platform.** A CUE import pins a single MAJOR via `cue.mod/module.cue`; the imported `#module` value is one concrete Module at one tag. The registry can hold exactly one build of each catalog at a time. End-users whose Modules pin different patches of the same catalog cannot share a platform — every primitive-version drift forces a separate platform definition.

2. **MAJOR-only FQNs hide minor/patch drift.** `container@v1` covers every `1.x.x` build. Schema additions in `1.4.0` are invisible to the matcher: if the platform was built against `1.0.0` and the consumer pins `1.4.0`, the FQN matches but the schemas may diverge silently. The Go matcher has no signal to refuse the pairing — and the only places drift surfaces are render-time errors that don't name version as the cause.

3. **`#Module.#defines` conflates two roles.** `#Module` is simultaneously the *consumer artifact* (deployed via `#ModuleRelease`) and the *catalog publication channel* (`#defines` exposes primitives to platforms). Catalog authors and application authors share a type that fits neither job: catalog modules carry empty `#components` / `#config` / `debugValues`; consumer modules carry empty `#defines`. The dual role is what locks the platform to a single Module-version — there is no separable "publish primitives" axis to subscribe to.

4. **The registry is a CUE-time-only artifact with no version policy lever.** There is no path-of-truth for "which versions of this catalog does the platform accept?" — the answer is "exactly the one the platform's CUE imports happen to pin." Platform teams have no way to express version policy declaratively; the only knob is editing imports and republishing the platform CUE. A "deny this known-bad patch" workflow doesn't exist.

5. **No schema-level home for release / module identity or per-component computed names.** Module authors cannot write `#ctx.runtime.release.namespace` or `#ctx.runtime.components.api.dns.fqdn` because there is no `#ctx`. Every transformer that needs deployment identity reaches into `#TransformerContext.#moduleReleaseMetadata` directly, and every transformer that emits a per-component DNS-named resource re-derives the name from `#componentMetadata.name`. The derivation is non-trivial (cluster domain default, RFC 1035 sanitisation, namespace suffix) and the duplication grows with every new transformer.

## Concrete Example

Suppose a platform team operates the `k8s-prod` platform and supports the OPM core catalog at `opmodel.dev/catalogs/opm`. Two application teams use it:

- **App A** depends on `opmodel.dev/catalogs/opm@v1.0.4` — pinned at that build because their charts were authored before `1.1.0` shipped. Their module declares one component, `api`, with a `Container` resource and an `Expose` trait. The component spec wants to reference its own predictable DNS name (`api.app-a-prod.svc.cluster.local`) inside an environment variable so the container talks to itself by name.
- **App B** depends on `opmodel.dev/catalogs/opm@v1.4.0` — pinned because they need a `scaling` trait field added in `1.4.0`. Their module declares two components, `frontend` and `worker`, and the `frontend` needs to compute its own DNS name plus the worker's DNS name into the same environment-variable manifest.

**Today's platform CUE pins exactly one catalog build:**

```cue
import opm_package "opmodel.dev/catalogs/opm"  // resolves to one tag, say 1.4.0
#registry: opm: { #module: opm_package, enabled: true }
```

**Failure mode 1 — version collapse.** App A's release goes through the matcher. Its components declare `container@v1` (MAJOR-only FQN), and the platform has a transformer keyed on `container@v1`. The FQN matches. The platform's `1.4.0` Container schema requires a field the App A `1.0.4` Container value doesn't supply — but neither the FQN check nor the predicate check sees this. The render proceeds with the platform's `1.4.0` view of the resource and the consumer's `1.0.4` value, and the Kubernetes object that comes out is either silently wrong (field defaulted to platform-1.4.0 behavior) or fails at `kubectl apply` with a diagnostic that doesn't trace back to the version mismatch. If the platform team flips the import to `1.0.4` to fix App A, App B breaks the same way.

**Failure mode 2 — identity duplication.** App A's component body wants to set:

```cue
#components: api: {
  #resources: container: {
    spec: container: {
      env: SELF_URL: "http://api.app-a-prod.svc.cluster.local"   // hand-written
    }
  }
}
```

The string is hand-written because there is no `#ctx.runtime.components.api.dns.fqdn` to reference. When the release moves to a different namespace (`app-a-staging`), the string has to be updated by hand — or, worse, the value is computed inside the `deployment-transformer`'s Go-side `#transform` and never exposed back to the consumer's environment variables at all. App B has the same problem twice: its `frontend` needs `worker.app-b-prod.svc.cluster.local` and the equivalent for itself; both strings are hand-coded and brittle.

**The escape hatch — stand up two platforms, `k8s-prod-old` and `k8s-prod-new`** — duplicates every other piece of platform policy (labels, type, the future `#ctx.platform` channel that arrives with capabilities) and defeats the point of having one platform serving the cluster. And it doesn't help with failure mode 2 at all.

## User Stories

- **As a platform team operator**, I want to subscribe my platform to a *range* of catalog builds (e.g. "all of `opmodel.dev/catalogs/opm` from `1.0.0` up to but not including `2.0.0`, minus the known-bad `1.3.2`") so that multiple application teams can pin different patches of the same catalog without me forking the platform. Today: a single CUE import pins one tag and the platform definition is rebuilt every time policy changes.
- **As an application module author**, I want to read my deployment identity and my components' computed names from a typed `#ctx` channel so I can reference `#ctx.runtime.release.namespace` and `#ctx.runtime.components.api.dns.fqdn` in my component spec without hand-coding strings. Today: there is no `#ctx`; identity-shaped values are hand-typed and break on namespace moves.
- **As a catalog author**, I want to publish my catalog as a plain CUE package that exports `#Resource` / `#Trait` / `#Blueprint` / `#ComponentTransformer` at the top level — with one shared `Catalog: { Version, ModulePath }` constant stamped into the artifact at publish time — so the OCI tag and the primitive `metadata.version` strings are identical by construction. Today: every primitive carries hand-written `version: "v1"` strings and the only way to "publish primitives" is to wrap them in `#Module.#defines`, which forces my catalog to be a `#Module` value with empty `#components` / `#config` / `debugValues` slots.

## Why Existing Workarounds Fail

**Pinning everyone to the same catalog version.** Forces lockstep upgrades across every application targeting the platform. The catalog is supposed to be a library; libraries don't impose lockstep on consumers.

**Splitting the platform per supported version.** Multiplies platform definitions by the cardinality of versions the cluster needs to support. Every cross-cutting platform change (a new trait, a label change, the upcoming `#ctx.platform` capabilities channel) propagates to *N* forks. The hand-coded-identity problem is unchanged.

**Bumping MAJOR on every schema change.** Makes MAJOR FQNs useful for matching again, at the cost of marking every patch-grade catalog change as a breaking version bump. The catalog evolves like `v1 → v2 → v3` inside a week. SemVer loses its semantic value, every consumer must republish on every patch, and the platform fork explosion gets worse rather than better.

**Manual schema-version assertions in transformer predicates.** A transformer's `requiredLabels` could carry a `catalog.version=1.4.0` label that consumer Modules also stamp. Catches mismatch — but requires every author to opt in, surfaces version drift as a generic predicate failure rather than a structured diagnostic, and does nothing for the identity-duplication problem.

**Re-deriving per-component names inside every transformer.** Today's actual workaround. Each transformer that produces a DNS-named resource has its own copy of `<sanitise(component.name)>.<release.namespace>.svc.cluster.local` logic. New transformers paste the snippet from the previous one; bugs (a missed sanitisation case, a default cluster domain assumed) propagate by copy. The module author never sees the computed string and cannot reference it from their component spec.

None of these address the underlying shape. A platform should be able to *subscribe* to a catalog (a range of its versions), the matcher should refuse pairings where the consumer's primitive FQN — including its SemVer — is not part of the subscribed set *and* refuse pairings where the FQN matches but the primitive schemas diverge, and modules should read deployment identity and per-component names from a typed `#ctx` channel that the kernel populates once per release.
