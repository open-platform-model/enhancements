# Problem Statement — Kubernetes-Native Refocus: Generated Mirror and Composed Abstractions

This document answers the question: "Why does this enhancement need to exist?" It leads with observable facts about the two catalogs as they stand today and the cost of keeping them on divergent foundations. It proposes no solution — that belongs in `02-design.md`.

## Current State

OPM ships two Kubernetes-facing catalogs that reach Kubernetes by independent means.

`opmodel.dev/catalogs/kubernetes@v0` (repo `catalog_kubernetes`) is a 1:1 mirror of native Kubernetes kinds. Every kind has a hand-written `#Resource` plus a pass-through `#ComponentTransformer` that accepts the native spec verbatim, prefixes the resource name (`{release}-{component}-{name}`), injects the namespace for namespaced kinds, and merges OPM labels/annotations. The schemas under `src/schemas/*.cue` are deliberately *open* (`...`) so any valid native field survives. The `apiVersion`/`kind` pair is a hardcoded constant in each transformer. There are ~27 transformers, each hand-authored, covering a curated slice of built-in kinds plus a generic `#Objects` escape hatch for arbitrary GVKs and Custom Resource instances.

`opmodel.dev/catalogs/opm@v0` (repo `catalog_opm`) is the opinionated abstraction layer: `#Blueprint`s (`StatelessWorkload`, `StatefulWorkload`, …), portable `#Trait`s (`scaling`, `expose`, route traits), and `#Resource`s (`container`, `volume`, …). It vendors *strict* Kubernetes types from `cue.dev/x/k8s.io@v0` and ships its **own** `#ComponentTransformer`s (e.g. `DeploymentTransformer`, `ServiceTransformer`) that read OPM abstractions and emit Kubernetes manifests directly, re-encoding "how to build a Deployment" independently of the pass-through mirror.

Core (`opmodel.dev/core@v0`) is a pure desired-state producer. Transformation is single-pass: a `#Component`'s `spec` is `close({_allFields})` — the CUE unification of every attached resource/trait/blueprint `spec` (`core/src/component.cue:57-80`) — and a transformer matches on the FQNs present in the component's `#resources`/`#traits` maps. There is no transformer chaining, and core carries no lifecycle: no create/update/delete/reconcile/health/ordering. The one Kubernetes-specific concession lives downstream in `library` (`pkg/resourceorder`, called out in enhancement 0001 as "the intentional K8s adapter tail").

The project has recently decided to focus exclusively on Kubernetes. Other targets (Nomad, Docker Compose, Swarm) are no longer a design constraint — they are not actively excluded, but no abstraction will be shaped to accommodate them.

## Gap / Pain

The two catalogs encode Kubernetes knowledge twice, by different mechanisms, and neither is positioned to scale.

**Divergent schema sources that drift.** The duplication that hurts is not transform *logic* — pass-through (forward a complete native spec) and construction (assemble a spec from sugar) are genuinely different jobs, not copies of each other. The duplication that hurts is the **schema foundation**: `catalog_kubernetes` hand-writes open (`...`) schemas while `catalog_opm` vendors strict `cue.dev/x/k8s.io@v0` types. The two understand "what a Kubernetes Deployment is" from different, independently-maintained sources, so a field one knows and the other does not is a silent divergence. There is no single generated source of Kubernetes type truth that both consume.

**Hand-authoring does not scale.** `catalog_kubernetes` is hand-written, one transformer at a time. It covers a curated subset of built-in kinds and punts everything else to the generic `#Objects` escape hatch, which gives no typing, no validation, and no per-kind lifecycle metadata. Supporting "every Kubernetes resource and version" — and, critically, the CRDs that real clusters run (cert-manager, Flux, Gateway API, operators) — is not reachable by continuing to hand-write transformers.

**Lifecycle is implicit and ad hoc.** Apply ordering is a hardcoded list in `library/pkg/resourceorder`. Readiness, pruning of removed resources, and ownership are handled — where they are handled — outside the catalog, with no per-kind metadata to drive them. Because the catalog had to stay platform-neutral in spirit, none of this Kubernetes-specific lifecycle knowledge was ever encoded as data the operator could consume.

**The abstraction layer cannot offer a trapdoor.** `catalog_opm`'s transformers emit only the fields they were written to emit, so a module author who outgrows a blueprint cannot reach in and override an arbitrary raw Kubernetes field — they fall off a cliff to the separate `catalog_kubernetes` and lose the abstraction entirely. This is the same failure mode that makes Helm charts brittle: the abstraction hides the resource instead of layering on it. An abstraction built on a complete, generated type surface can instead set defaults the author may freely override down to any native field.

## Concrete Example

A module author models a web service with `catalogs/opm`'s `#StatelessWorkload`. The blueprint projects sugar onto `catalog_opm`'s own `#Container`/`#Scaling` specs (`catalog_opm/src/blueprints/workload/stateless_workload.cue:59-78`), and `catalog_opm`'s `DeploymentTransformer` renders the Deployment.

The author now needs to set `spec.template.spec.topologySpreadConstraints` — a perfectly ordinary Deployment field that the `StatelessWorkload` sugar does not surface. Today there is no path to set it through the blueprint: `catalog_opm`'s transformer only emits the fields it was written to emit. The author must abandon the blueprint and re-model the whole workload with `catalogs/kubernetes`'s raw `#DeploymentResource` — discarding `scaling`, `expose`, and every other abstraction in the process.

Separately, the author needs a `cert-manager.io/v1` `Certificate`. `catalogs/kubernetes` has no typed `Certificate` resource — only the generic `#Objects` escape hatch, where the entire object is untyped `...`. There is no way to generate a typed `Certificate` resource + transformer short of hand-writing one, and no pipeline that would produce it from cert-manager's published CRD.

## User Stories

- As an application module author, I want to start from a concise workload abstraction and still override any raw Kubernetes field when I need to, so that outgrowing the sugar does not mean rewriting the workload. Today: the abstraction emits a fixed field set; the escape hatch is a different catalog with no abstractions.
- As a catalog author, I want the native-Kubernetes mirror to be generated from the Kubernetes OpenAPI (and from CRD schemas), so that new kinds, new API versions, and arbitrary CRDs become typed OPM resources without hand-writing a transformer each. Today: every kind is hand-authored, and anything uncovered degrades to an untyped `#Objects` blob.
- As a platform operator, I want each rendered resource to carry Kubernetes lifecycle metadata (scope, apply order, readiness, prune policy), so that the operator reconciles in the right order and reports readiness honestly. Today: ordering is a hardcoded list and readiness/pruning have no per-kind data to act on.

## Why Existing Workarounds Fail

The generic `#Objects` escape hatch covers "any GVK" but at the cost of all typing, validation, and lifecycle metadata — it is a pass-through blob, not a modeled resource, so it cannot back a typed abstraction or carry readiness/order data. Continuing to hand-write `catalog_kubernetes` transformers does not reach the CRD long tail and keeps two divergent encodings of Kubernetes alive. Keeping `catalog_opm` on its own manifest-emitting transformers means the abstraction layer can never offer a faithful trapdoor onto a complete mirror, because there is no complete mirror underneath it. None of these is a partial fix that buys time; each entrenches the split this enhancement exists to close.
