# Risks, Drawbacks, Alternatives — Rename #ModuleRelease to #ModuleInstance

This document records the honest costs. The benefit being weighed is modest and purely conceptual (clearer vocabulary); the costs below are what that benefit must outweigh.

## Risks and Mitigations

- **Split-brain partial rename — resolved by going all-in.** The original worst case was renaming the CUE definitions while the `kind` string and labels stayed `Release`. D3/D4 close this off: the wire moves with the definitions. The residual obligation is *sequencing* (below), not split-brain.
- **API-group rename orphans existing in-cluster CRs (largest blast radius).** Moving from `releases.opmodel.dev` to `opmodel.dev` (D5) means every existing `ModuleRelease`/`Release`/`Platform` CR, every RBAC rule scoped to the old group, every kustomize base, and the finalizer key change identity. Old-group CRs are not seen by the new controller; finalizers under the old key are not cleared by the new code. **Mitigation:** treat as a clean reinstall, not an in-place upgrade — uninstall old CRDs/controller, install new CRDs/RBAC, re-apply CRs under the new group; ensure any old-key finalizers are removed before deleting old CRDs so resources don't get stuck terminating. Because the change is naming-only with no data-plane state, re-applying converges. Document the reinstall in `06-operational.md`.
- **Silent breakage on `kind`/label change without lockstep.** The library kernel, operator, and CLI match `"ModuleRelease"` literally; a render producing `kind: "ModuleInstance"` is rejected as "unsupported kind" with no compile-time signal. **Mitigation:** sequence core → library → (operator ‖ cli) with kind-detection updated before the new `core` is consumed; add kind-detection tests asserting the new strings in each repo.
- **Selector / external-tooling breakage on label change.** Anything selecting on `module-release.opmodel.dev/*` (dashboards, network policies, the operator's own inventory/prune) selects nothing after the key changes (D4). **Mitigation:** inventory selector usage before the operator/cli slices land; since hard rename is chosen (D8), update all in-tree selectors in the same slice and call out any external selectors in release notes.
- **Churned cross-references in 0001.** Enhancement [0001](../0001/) documents the `#ctx.release` wiring (D1/D3/D4) in prose; this rename makes that prose stale. **Mitigation:** 0001 is append-only and already `accepted`/in-progress — do not rewrite its history; let its decisions stand as the historical record under their original names.

## Drawbacks

- **It is a breaking rename for largely cosmetic gain.** Every downstream that names the old identifiers/kinds/labels/group/commands must edit, and the behavior is byte-for-byte identical afterward. The payoff is clarity, not capability — and the blast radius is now four repos plus live clusters, not one schema.
- **"Instance" drops the version/promotion connotation that "Release" carried.** "Release to prod" implied a specific shipped version; "instance" is version-agnostic. A reader who valued that connotation loses it.
- **`ModulePackage` is a newly coined noun.** Reversing D1 trades a familiar word (`Release`, with Argo/Flux precedent) for `ModulePackage`, which authors must learn. It keeps the artifact-vs-reconciler distinction but at the cost of a less-conventional name.

## Alternatives

- **Do nothing; fix it with documentation.** Keep `#ModuleRelease`, explain in docs that it means "instance." **Why not:** the canonical comment already does this, which is the tell that the name is the defect; docs are a recurring tax, not a fix.
- **Rename everything including the operator `Release` CRD to `Instance`.** One word everywhere. **Why not:** erases the artifact-vs-reconciliation distinction (see D1); "Instance" fits the GitOps CR poorly.
- **Choose a different target word (`Deployment`, `Installation`, `Placement`).** **Why not:** `Deployment` collides with the Kubernetes kind; `Installation` is Flux/Helm-flavored (same problem as `Release`); `Placement` is scheduling jargon. "Instance" most directly names the multiplicity property that motivated the change.
