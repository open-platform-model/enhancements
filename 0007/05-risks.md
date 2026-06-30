# Risks, Drawbacks, Alternatives — Manifest Passthrough: Side-Channel Raw and Kustomize Manifests

This document records the honest costs of the proposed design. Risks describe what could go wrong; Drawbacks describe what definitely costs something; Alternatives describe the high-level paths not taken (per-decision detail lives in `03-decisions.md`).

## Risks and Mitigations

- **Kustomize as a footgun inside the operator.** Kustomize supports exec plugins, `helmCharts` inflation, and generators that read arbitrary files. Run unconstrained in a controller reconcile loop, a side manifest could execute code, perform I/O, or produce non-deterministic output on every reconcile — turning a declarative apply into an arbitrary-code-execution surface. **Mitigation:** embed `krusty` with exec plugins disabled and (pending OQ6) Helm inflation disabled by default; treat any opt-in to those as a separately-gated trusted mode. The embedded-library choice (D2) is what makes this hardening enforceable in code rather than dependent on a binary's defaults.

- **Pruning the wrong resource.** Side manifests now carry OPM ownership labels and enter `status.inventory`, so the prune path can delete them. A mistaken collision with an externally-owned object (same GVK+name) could let OPM adopt and later delete something it didn't create. **Mitigation:** the existing prune ownership guard already requires the OPM `managed-by` label and a matching release UUID before deleting (`opm-operator/internal/apply/prune.go`); side objects only become prunable after OPM has stamped and recorded them. OQ7's collision rule must forbid silently adopting a pre-existing foreign object.

- **Drift between CLI and operator rendering.** If the CLI and operator embed different Kustomize versions or different hardened-option sets, the same `extraManifests` could render differently in `opm instance apply` vs the controller. **Mitigation:** a single shared renderer package (D4, OQ5) with one pinned `krusty` version and one options constructor, imported by both.

- **Path traversal / source confusion.** `raw`/`kustomize` paths resolve within a source tree; a `../`-style path could read outside the release artifact. **Mitigation:** resolve and validate paths against the artifact root (the operator already extracts with a size cap and digest verification in `internal/source/fetch.go`); reject escapes.

## Drawbacks

- **A second, untyped door into the cluster.** OPM's value proposition is "everything is a typed, validated component." Passthrough is explicitly the un-typed, un-validated path. That is intentional (an adoption ramp), but it is a permanent ergonomic split that authors and reviewers must understand: objects in `extraManifests` get none of OPM's schema guarantees.
- **Apply-layer logic now reads a filesystem.** Today the CLI/operator apply path is "take rendered objects, apply." Passthrough adds filesystem reading and an external rendering engine to that path. It stays out of the kernel (D1), but the apply layer grows a real dependency (`krusty`) and a new failure mode (render errors before apply).
- **Two integration sites to keep in lockstep.** Both the CLI and operator must wire the renderer in identically; divergence is a maintenance cost mitigated but not eliminated by the shared package.
- **`ModuleInstance` may be partially supported at first.** If OQ3 resolves to "ModulePackage-only in v1," `ModuleInstance` users get an inconsistent feature surface until a later slice.

## Alternatives

- **Use Flux Kustomization alongside OPM instead of building it in.** The operator already consumes Flux sources and the demo runs Flux, which has a `Kustomization` CRD that does exactly this. **Why not:** it yields two ownership/prune models on the same cluster — the precise orphan-and-drift problem this enhancement exists to eliminate; building it in buys one inventory, one prune, one ownership story.
- **Type the manifests inside the CUE pipeline (enhancement 0005's `#Objects` redesign).** Generate a typed Kubernetes mirror so "arbitrary object" becomes a validated in-pipeline construct. **Why not:** different axis — it still requires authoring in CUE and carries no Kustomize overlay semantics; it does not serve "I already have a kustomize repo." The two are likely complementary (OQ2), not substitutes.
- **Make side manifests a core schema primitive.** A `rawObjects`/component field in `opmodel.dev/core`. **Why not:** bakes a Kubernetes-and-Kustomize-specific concept into the platform-neutral core (SPEC §4.1) and forces schema-versioning churn for a feature that needs none (D1).
