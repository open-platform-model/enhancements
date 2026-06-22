# Problem Statement — Rename #ModuleRelease to #ModuleInstance

This document answers the question: "Why does this enhancement need to exist?" It leads with the names as they exist in `core/src` today and the meaning they fail to convey. It does not propose the rename mechanics — that belongs in `02-design.md`.

## Current State

`core` models the deployable artifact as `#ModuleRelease` (`core/src/module_release.cue:10`, `kind: "ModuleRelease"`). Its own doc comment describes it as *"The concrete deployment instance"* — a reference to a `#Module`, a set of concrete `values`, and a target `namespace`. The same root carries a small family of supporting names:

- `#ModuleReleaseMap` (`module_release.cue:79`) — `[string]: #ModuleRelease`.
- `#ReleaseIdentity` (`module_context.cue:11`) — the deployment-scoped facts (`name`, `namespace`, `uuid`, `clusterDomain`) that drive per-component naming and DNS.
- `#ctx.release` (`module.cue:68`) — the runtime context slot the `#ModuleRelease` fills from its own metadata (`module_release.cue:44`).
- `#Component.#release` (`component.cue:39`) — the per-component projection of that identity; component DNS (`#names.dns.local`, `#names.dns.fqdn`) is computed from `#release.namespace` and `#release.clusterDomain` (`component.cue:52-53`).
- `#moduleRelease` / `#moduleReleaseMetadata` in the transformer context (`transformer.cue:85,99`).
- Label keys `module-release.opmodel.dev/name` and `module-release.opmodel.dev/uuid` (`module_release.cue:29-30`, `transformer.cue:147`).

This naming originates with enhancement [0001](../0001/) (the `#Platform` redesign), which introduced the `#ctx.release` wiring (D1, D3, D4).

The same "Release" vocabulary does not stop at `core` — it is spelled four different ways down the stack, and an author meets all of them:

- **`library` (Go kernel).** A `Release` type with `ReleaseName`/`ReleaseUUID` methods (`opm/module/release.go`), `ReleaseMetadata`/`ReleaseView` (`opm/schema/`), `synth.Release`/`ReleaseInput` (`opm/helper/synth/`), kernel entry points `ProcessModuleRelease`/`SynthesizeRelease`/`compileModuleRelease`, the kind-detection literal `ReleaseSpec.ExpectedKind = "ModuleRelease"` (`opm/helper/loader/internal/shape/shape.go`), and the `module-release.opmodel.dev/*` label literals.
- **`opm-operator` (controller).** *Two* CRDs carry the word: a `ModuleRelease` CRD (the in-cluster deployable, the operator-side mirror of core's `#ModuleRelease`) **and** a separate GitOps `Release` CRD (`api/v1alpha1/release_types.go`) that fetches a Flux artifact and renders it. Both live under the API group `releases.opmodel.dev`, with reconcilers (`ModuleReleaseReconciler`, `ReleaseReconciler`), the render constant `KindModuleRelease = "ModuleRelease"`, label constants `LabelModuleRelease*`, and the finalizer `releases.opmodel.dev/cleanup`.
- **`cli`.** A user-facing `opm release …` command group (alias `rel`) with nine subcommands, a parallel `BundleRelease` kind alongside `ModuleRelease` in `DetectReleaseKind`, and the same `LabelModuleRelease*` constants.

So the construct an author thinks of as "one deployed instance of a module" wears at least four inconsistent spellings — a CUE definition, a Go type, two Kubernetes CRDs, and a CLI verb — every one of them built on the word the model is trying to move away from.

## Gap / Pain

The chosen word is **Release**, and it carries baggage that works against OPM's mental model:

1. **It is Helm's word for the same thing.** In Helm, a *release* is an installed instance of a chart (`helm install <name> <chart>` → a release; `helm list` enumerates them). OPM deliberately invites comparison with Helm, but reusing Helm's exact vocabulary blurs the line OPM wants to draw rather than sharpen it.
2. **It under-describes what the construct actually is.** The construct's defining property is *multiplicity*: one `#Module` can be stamped out as many concrete deployments, each with its own name, namespace, values, and stable UUID (`uuid: SHA1(... "name:namespace")` — `module_release.cue:23`). "Instance" names that property directly. "Release" foregrounds a *shipping event* (a version going out the door) and says nothing about there being many of them coexisting.

The cost is conceptual, not functional — the schema works. But the schema *is* the published contract (`opmodel.dev/core@v0`), and the words in a contract teach every downstream author what the model means. A name that says "instance" teaches "you can make many of these from one module"; a name that says "release" teaches "this is how Helm ships a chart."

## Concrete Example

A platform team runs three environments of the same module:

```cue
// today — the word "Release" appears for one module deployed three times
dev:  #ModuleRelease & {#module: minecraft, metadata: {name: "mc-dev",  namespace: "games-dev"},  values: {...}}
qa:   #ModuleRelease & {#module: minecraft, metadata: {name: "mc-qa",   namespace: "games-qa"},   values: {...}}
prod: #ModuleRelease & {#module: minecraft, metadata: {name: "mc-prod", namespace: "games-prod"}, values: {...}}
```

Nothing here is a "release" in the version-shipping sense — it is the *same* module materialized three times. The reader has to translate "release" into "instance" mentally on every line, and the rendered objects carry `module-release.opmodel.dev/name: mc-prod`, reinforcing the mistranslation downstream.

## User Stories

- As an **application module author** reading `core` for the first time, I want the deployable artifact's name to tell me I can create many of them from one module, so that I model multi-environment deployment correctly without first un-learning Helm's "release == one shipment" framing. Today: the name says "release," so I reach for Helm's mental model.
- As a **platform team operator**, I want the identity carried on rendered objects (labels, `#ReleaseIdentity`) to read as "instance X of module Y," so that fleet inventory reads naturally. Today: `#ReleaseIdentity` / `module-release.opmodel.dev/*` reads as a Helm-style release ledger.

## Why Existing Workarounds Fail

The only "workaround" is documentation that repeatedly explains "a ModuleRelease is really an instance" — a standing tax on every doc and every reader, and an admission that the name is wrong. The canonical comment in `core` already does exactly this (`module_release.cue:7` calls it "The concrete deployment instance"). When the canonical comment has to redefine the canonical name, the name is the defect.
