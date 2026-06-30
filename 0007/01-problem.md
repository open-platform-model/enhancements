# Problem Statement — Manifest Passthrough: Side-Channel Raw and Kustomize Manifests

This document answers the question: "Why does this enhancement need to exist?"

## Current State

OPM turns an application into Kubernetes resources through a strictly transformer-driven pipeline. A `#Module` carries `#Component`s; each component attaches typed `#Resource`s and `#Trait`s; a `#Platform` supplies `#ComponentTransformer`s that match components and emit output. The library kernel runs that pipeline — `compile.Match` pairs components with transformers, `compile.Execute` evaluates each transformer's `output` field, and the result is a list of `*core.Compiled` values, each an opaque CUE value the apply layer interprets as a Kubernetes object (`library/opm/compile/execute.go`, `library/opm/core/compiled.go`).

Both consumers of the kernel converge on the same final artifact — a stream of `Unstructured` Kubernetes resources — and run it through one apply path:

- The **CLI** renders a release and either prints YAML/JSON or server-side-applies it (`cli/internal/cmd/release/build.go`, `cli/internal/cmd/release/apply.go`).
- The **operator** renders, then applies via the Flux `ResourceManager.ApplyAllStaged()` (server-side apply with staging), then prunes stale resources by diffing the recorded inventory (`opm-operator/internal/apply/apply.go`, `opm-operator/internal/apply/prune.go`).

The operator stamps every applied object with ownership labels (`app.kubernetes.io/managed-by`, `module-instance.opmodel.dev/{name,namespace,uuid}`) and records each object in `status.inventory`, which is the authoritative source for drift detection and pruning (`opm-operator/pkg/core/labels.go`, `opm-operator/api/v1alpha1/common_types.go`).

Everything that reaches the cluster must therefore originate as a typed component matched by a transformer. There is no supported way to feed an arbitrary Kubernetes manifest — or a `kustomization.yaml` overlay — through the same managed apply path. The only escape hatch that exists today is `catalog_kubernetes`'s generic `#Objects` blob, which lives *inside* the CUE/transformer pipeline (the author writes the object as CUE) and is the subject of a separate redesign in enhancement 0005.

## Gap / Pain

A developer who already has Kubernetes manifests — a `kustomization.yaml` with overlays, a vendored third-party manifest set, a one-off `NetworkPolicy` or `ServiceMonitor` — has no way to ship them alongside an OPM release and have OPM own them. Their only options today are:

1. Rewrite the manifests as typed OPM components (high friction; blocks adoption for anyone with an existing manifest estate).
2. Hand-author them as CUE `#Objects` blobs (still a rewrite into CUE; no kustomize semantics).
3. Apply them out-of-band with `kubectl`/`kustomize`/Flux, outside OPM's ownership and pruning, so they leak when the release is removed and drift silently.

The consequence is an adoption cliff. OPM asks a team to convert *everything* to typed components before it can manage *anything*. Teams with a partial migration, a long tail of cluster-specific glue, or an existing Kustomize repo are pushed to "all in or stay out." A first-class side-channel — extra manifests that OPM applies, labels, inventories, and prunes just like rendered output — lowers that barrier without diluting the typed happy path.

## Concrete Example

A team runs a `jellyfin` module via the operator. They also need a `monitoring.coreos.com/v1 ServiceMonitor` for it and a small Kustomize overlay that patches resource limits per cluster. Neither is modeled in the OPM catalog yet.

Today they would apply the `ServiceMonitor` and run `kustomize build overlays/prod | kubectl apply -f -` by hand. When they later `kubectl delete modulerelease jellyfin`, OPM prunes only what it rendered — the `ServiceMonitor` and the kustomize output are orphaned, because OPM never knew about them. Inventory-based pruning (`opm-operator/internal/apply/prune.go`) can only remove what it recorded, and it recorded nothing for the side manifests.

With this enhancement, the team declares the extra manifests on the release:

```yaml
spec:
  module: { path: opmodel.dev/modules/jellyfin, version: "1.2.0" }
  extraManifests:
    - raw: { path: ./extra/servicemonitor.yaml }
    - kustomize: { path: ./overlays/prod }
```

The operator renders the kustomization, stamps OPM ownership labels on every object (its own and the side manifests alike), records them in `status.inventory`, applies them in the same staged SSA pass, and prunes them on release deletion — one ownership model, one inventory, one prune.

## User Stories

- As an **application module author**, I want to attach a few extra Kubernetes manifests to a release so that I can ship cluster glue (a `ServiceMonitor`, a `NetworkPolicy`) that isn't modeled in the catalog yet — without dropping out of OPM's lifecycle. Today: I apply them by hand and they leak when the release is removed.
- As a **platform team operator**, I want OPM to own, track, and prune side manifests the same way it owns rendered output so that I have a single inventory and no silent orphans. Today: anything applied outside OPM is invisible to its pruning and drift detection.
- As a **team adopting OPM with an existing Kustomize repo**, I want to point a release at my `kustomization.yaml` so that I can onboard incrementally instead of rewriting everything into typed components first. Today: it's convert-everything-or-nothing.

## Why Existing Workarounds Fail

- **Hand-authored `#Objects` CUE blobs** still require rewriting manifests into CUE and carry none of Kustomize's overlay/patch semantics. They solve "untyped object in the pipeline," not "I already have manifests / a kustomization." Their redesign (0005) is about *typing* the in-pipeline hatch — a different axis from this side-channel.
- **Out-of-band `kubectl`/`kustomize`/Flux apply** works mechanically but defeats the point: those objects sit outside OPM's ownership labels and `status.inventory`, so they are never pruned on release removal, never checked for drift, and never participate in staged apply ordering. The user gets two disjoint ownership models on the same cluster.
- **Rewriting to typed components** is the intended long-term path but is exactly the friction that blocks adoption; it cannot be the only on-ramp.
