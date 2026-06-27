# Operational Concerns — Rename #ModuleRelease to #ModuleInstance

PRR-lite. The cross-cutting scope (D2) and wire/group decisions (D3–D5) are now locked; the answers below reflect the full rename, not a conditional core-only path.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

Observability-neutral by intent — terminology rename, no behavioral change. Indirect signals during a botched rollout: a consumer not updated in lockstep with the new `kind` string surfaces the existing "unsupported kind" rejection (`kind: "ModuleInstance"` refused); CRs left under the old API group simply aren't watched by the new controller (no error — they go unreconciled). No new error kinds; existing ones fire for new reasons. Rendered-object labels change key but not cardinality.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

Breaking on every layer (`semver: major`, D8):

- **CUE identifiers** — breaks downstream CUE that imports `opmodel.dev/core` and names `#ModuleRelease`/`#ReleaseIdentity`/`#ctx.release`.
- **Go identifiers** — breaks any code calling the renamed `library` kernel/helper symbols.
- **`kind` strings** (D3) — breaks library/operator/cli kind-detection at runtime until updated.
- **label domain** (D4) — breaks selectors keyed on `module-release.opmodel.dev/*`.
- **API group + CRDs** (D2, D5) — breaks every CR, RBAC rule, and manifest scoped to `releases.opmodel.dev`; requires a CRD reinstall.

Release mechanics (D13, revising D8): every affected artifact ships as a **v1 prerelease** — `v1.0.0-alpha.N` (`v1.x.x-alpha.x`) — including the `opm-operator` artifact that bundles the CRDs. For `core` this advances the CUE module from `opmodel.dev/core@v0` to `opmodel.dev/core@v1` (the `@v0→@v1` break the earlier D8 mechanics had avoided): an additional import-path break for every downstream that imports `opmodel.dev/core`, and core's release-please `bump-minor-pre-major: true` no longer governs the v1-alpha line. The Kubernetes CRD served apiVersion (`v1alpha1`) is a separate K8s axis and is unchanged. Design-impact field stays `major`. Plan: hard rename, no alias (D8); sequence core → library → (opm-operator ‖ cli), each repo advancing to its v1-prerelease tag in that order.

## Deprecation

**What gets removed and when? What replaces it?**

Removed and replaced 1:1 by `Instance`-named equivalents (mapping table in `02-design.md`): the core identifiers; the Go `Release` symbols across `library`/`cli`; the `kind` strings `"ModuleRelease"`/`"BundleRelease"`; the `module-release.opmodel.dev/*` labels; the operator `ModuleRelease` CRD (→ `ModuleInstance`) and GitOps `Release` CRD (→ `ModulePackage`); the `releases.opmodel.dev` API group and finalizer (→ `opmodel.dev`); the `opm release` command group (→ `opm instance`). Timeline: each repo's slice removes its names in the same change that introduces the replacements — no transition window (D8).

## Rollback

**If this lands and proves bad, what's the rollback story?**

No data-plane state migration — the change is naming only — but rollback is now multi-repo and touches cluster identity:

- **Code/schema:** revert each repo's slice; downstream re-pins the prior `core`/`library` tags. Order is the reverse of rollout (cli/operator first, then library, then core).
- **Cluster:** the API-group/CRD rename (D5) means rollback is a reinstall, mirroring the forward path — remove new CRDs (clearing `opmodel.dev/cleanup` finalizers first so resources don't hang), reinstall old-group CRDs, re-apply CRs under `releases.opmodel.dev`. Labels revert with the re-apply; SSA reconvergence is clean. Any object selected only by the new key during the window is briefly orphaned from selectors — roll labels and consumers back together.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

1. **core** — publish the renamed schema (new OCI tag of `opmodel.dev/core`); co-update `SPEC.md`, regenerate `INDEX.md`.
2. **library** — rename Go identifiers + the `"ModuleInstance"` kind literal + `module-instance.opmodel.dev/*` labels; pin the new `core` tag; tests green.
3. **opm-operator** and **cli** (parallel) — each pins the new `core`+`library`. opm-operator renames both CRDs, moves the API group, regenerates manifests/RBAC/`PROJECT`; cli renames the command surface, `BundleInstance`, kind-detection, labels, examples/docs.
4. Root `task update-deps` propagates CUE pins. A follow-up sweep of `modules/` + `releases/` fixtures that name `#ModuleRelease`/`kind`/labels is required (outside the four named repos — flag, don't silently skip).

The hand-off artifact at each step is the published upstream tag the downstream pins.
