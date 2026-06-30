# Design — Manifest Passthrough: Side-Channel Raw and Kustomize Manifests

This document answers the question: "What is the proposed solution and how does it work?" Design Goals and Non-Goals together define the boundary; the High-Level Approach should be understandable without deep implementation knowledge. All trade-off reasoning lives in `03-decisions.md`.

## Design Goals

- A release can declare a set of **extra manifests** — plain YAML and/or a Kustomize directory — that OPM applies alongside the rendered output.
- Side manifests participate in the **same lifecycle** as rendered resources: stamped with OPM ownership labels, recorded in `status.inventory`, applied through the same staged server-side-apply pass, drift-detected, and pruned on removal. One ownership model, one inventory, one prune.
- The feature is available in **both** the CLI (`opm instance build` / `opm instance apply`) and the operator, with identical passthrough semantics, so a release behaves the same whether driven from a laptop or a controller.
- The **core schema (`opmodel.dev/core@v0`) and the library kernel are not touched.** Passthrough is an apply-layer concern; the kernel stays pure (no I/O, no shell, no exec — `library/CONSTITUTION.md` Principle I).
- Kustomize is rendered by an **embedded library** (`sigs.k8s.io/kustomize/api/krusty`), not by shelling out to a `kustomize` binary, so behavior is deterministic and the version is pinned in the Go build.
- The operator's execution of side manifests is **safe by default**: filesystem-reading and code-executing Kustomize features (exec plugins, and likely Helm inflation) are disabled in the reconcile loop.

## Non-Goals

- **No change to `opmodel.dev/core@v0`** and no change to the library kernel's compile pipeline. Side manifests never become `#Component`s or transformer output.
- **Not a typed-manifest hatch.** Typing arbitrary Kubernetes objects inside the CUE pipeline is enhancement 0005's `#Objects` redesign; this enhancement is the *untyped, apply-layer* side-channel. The two are complementary (see D-relationship / OQ2).
- **Not a general plugin system.** The only external renderer integrated here is Kustomize (plus verbatim raw YAML). Helm, jsonnet, cdk8s, etc. are explicitly out of scope for this pass.
- **No new reconcile engine.** Side manifests flow through the operator's existing apply/prune machinery; this enhancement adds an input source, not a new controller.
- **No templating of side manifests against OPM config/values.** Passthrough means passthrough — Kustomize does its own overlaying; OPM does not interpolate release values into the YAML (kept as a possible follow-up, OQ4).

## High-Level Approach

The insight is that the CLI and operator already share a final artifact — a list of `Unstructured` Kubernetes objects — and one managed apply path. Kustomize output and raw YAML are *just more `Unstructured` objects*. So passthrough is: produce those objects from a declared source, **merge them into the existing apply set**, and let the established ownership/inventory/prune machinery treat them identically to rendered output.

Three pieces:

1. **Declaration.** A new optional `extraManifests` field on the operator's `ModuleInstance` and `ModulePackage` CRD specs, and an equivalent CLI input (instance-file field and/or `--extra-manifests` flag). Each entry is a discriminated source: `raw` (a file or glob of plain manifests) or `kustomize` (a directory to `kustomize build`). Paths resolve **within the release's source artifact** for the operator (the Flux tarball it already extracts, `opm-operator/internal/source/fetch.go`) and relative to the release file for the CLI.

2. **Rendering.** A small shared "passthrough renderer" reads each source and produces `[]Unstructured`. For `kustomize`, it invokes the embedded `krusty` API with a hardened options set (exec plugins disabled). For `raw`, it decodes the YAML stream. This renderer is the *only* new logic that touches a filesystem, and it lives in the apply layer, never in the kernel.

3. **Folding into apply.** The passthrough objects are concatenated with the kernel's rendered objects *before* the ownership-labeling, inventory-recording, staging, SSA, and prune steps. From that point on there is no distinction: every object — rendered or passed-through — carries the same `module-instance.opmodel.dev/uuid`, appears in `status.inventory`, is staged correctly (CRDs/namespaces first), and is pruned when it leaves the set. A per-object provenance marker (e.g. a `component`-style label or annotation set to `passthrough`) records that an object came from the side-channel, for observability and targeted diffing.

The core/kernel boundary is the load-bearing decision: because Kustomize reads a filesystem and can execute code, it categorically cannot live in the kernel. Placing the whole feature at the apply layer keeps the kernel pure and means **zero schema churn** — the cost is that the CLI and operator each need to wire the same renderer into their apply paths (mitigated by sharing the renderer package).

## Schema / API Surface

The full target shape is in [`schemas/target.cue`](schemas/target.cue). It models the **operator CRD spec addition** (the source of truth for the declared shape) plus a `#PassthroughObject` provenance shape — not core schema. Headline:

```cue
#ExtraManifestSource: {
    // exactly one of raw | kustomize (discriminated union)
    raw?:       { path: string }            // file or glob of plain YAML
    kustomize?: { path: string }            // dir containing kustomization.yaml
}
// spec.extraManifests: [...#ExtraManifestSource]
```

- `#ExtraManifestSource` — one declared side-channel source. The `raw` vs `kustomize` split is the scope axis OQ1 resolves; the schema currently models both and a decision may narrow it.
- Ownership/inventory shapes are **not** new — side objects reuse the operator's existing `pkg/core/labels.go` label set and `api/v1alpha1/common_types.go` inventory entry. The schema file documents which existing fields carry the passthrough provenance marker rather than redefining them.

There is intentionally **no CUE definition under `opmodel.dev/core`** here. `schemas/target.cue` is repo-internal modeling of the CRD/CLI surface, consistent with this being an apply-layer feature.

## Integration Points

### opm-operator (primary)

- `api/v1alpha1/modulerelease_types.go`, `api/v1alpha1/release_types.go` — **new field** `spec.extraManifests []ExtraManifestSource`; regenerate CRDs (`config/crd`).
- `internal/render/` — after the kernel produces rendered resources, invoke the shared passthrough renderer and append its `[]Unstructured`. Resolve source paths within the already-extracted artifact for `ModulePackage`; for `ModuleInstance` decide the path root (OQ3).
- `pkg/core/labels.go` — extend label stamping to mark passthrough provenance on side objects.
- `internal/apply/apply.go`, `internal/apply/prune.go` — no logic change expected; side objects flow through unchanged once they are in the resource list and inventory. Verify staging classifies passed-through CRDs/namespaces correctly.
- `internal/inventory/` — confirm passthrough objects record and diff like rendered ones.

### cli

- `internal/cmd/release/build.go`, `internal/cmd/release/apply.go` — accept the same `extraManifests` declaration (instance-file field and/or flag); fold renderer output into the manifest set before write/apply.
- `internal/cmdutil/manifest_output.go` — ensure passthrough objects serialize alongside rendered ones for `build`.

### shared (new package)

- A **passthrough renderer** package (home repo TBD — `library/` is ruled out by purity, so likely a small package vendored by both `cli` and `opm-operator`, or duplicated deliberately; OQ5). Embeds `sigs.k8s.io/kustomize/api/krusty`; exposes `Render(sources, fsRoot) ([]Unstructured, error)` with hardened options.

### core, library

- **None.** Explicit non-goal; the kernel and `opmodel.dev/core@v0` are untouched.

## Before / After

**Before** — the team applies side manifests out-of-band; OPM never sees them:

```bash
kubectl apply -f extra/servicemonitor.yaml
kustomize build overlays/prod | kubectl apply -f -
# kubectl delete modulerelease jellyfin  → ServiceMonitor + overlay output orphaned
```

**After** — declared on the release; OPM owns the whole set:

```yaml
spec:
  module: { path: opmodel.dev/modules/jellyfin, version: "1.2.0" }
  extraManifests:
    - raw:       { path: ./extra/servicemonitor.yaml }
    - kustomize: { path: ./overlays/prod }
```

```
render(module) ──┐
                 ├─► [Unstructured…] ─► label+inventory ─► staged SSA ─► prune
passthrough() ───┘   (rendered + side manifests, one set, one uuid)
```

`kubectl delete modulerelease jellyfin` now prunes the `ServiceMonitor` and the overlay output along with the rendered workload, because all three are in `status.inventory` under the release UUID.
