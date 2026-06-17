# Risks, Drawbacks, Alternatives — Rename #ModuleRelease to #ModuleInstance

This document records the honest costs. The benefit being weighed is modest and purely conceptual (clearer vocabulary); the costs below are what that benefit must outweigh.

## Risks and Mitigations

- **Partial rename ships an incoherent contract.** If the CUE definitions rename to `Instance` but the `kind` string and labels stay `Release` (the core-isolation path under OQ1/OQ2), every reader sees `#ModuleInstance` evaluate to `kind: "ModuleRelease"` and emit `module-release.opmodel.dev/*`. That is arguably *worse* than the status quo — it adds a second name without retiring the first. **Mitigation:** resolve OQ1+OQ2 together before `accepted`; if the wire can't move yet, prefer deferring the *whole* rename over shipping a split-brain artifact.
- **Silent downstream breakage on `kind`/label change.** The library kernel and operator match `"ModuleRelease"` literally; a render now producing `kind: "ModuleInstance"` is rejected as "unsupported kind" with no compile-time signal in those repos. Blast radius: every reconcile fails closed. **Mitigation:** if D2 lands, sequence the rollout core → library → operator with the kind-detection updated *before* the new `core` is consumed; add a kind-detection test asserting the new string.
- **Selector / external-tooling breakage on label change.** Anything selecting on `module-release.opmodel.dev/*` (dashboards, network policies, the operator's own inventory) silently selects nothing after the key changes. **Mitigation:** inventory selector usage before D3; consider emitting both label keys for one release if a window is needed (reopens OQ3 for labels specifically).
- **Churned cross-references in 0001.** Enhancement [0001](../0001/) documents the `#ctx.release` wiring (D1/D3/D4) in prose; this rename makes that prose stale. **Mitigation:** 0001 is append-only and already `accepted`/in-progress — do not rewrite its history; note the rename in this entry and let 0001's decisions stand as the historical record under their original names.

## Drawbacks

- **It is a breaking rename for purely cosmetic gain.** Every downstream that names `#ModuleRelease` / `#ReleaseIdentity` must edit, and the behavior is byte-for-byte identical afterward. The payoff is clarity, not capability.
- **"Instance" drops the version/promotion connotation that "Release" carried.** "Release to prod" implied a specific shipped version; "instance" is version-agnostic. A reader who valued that connotation loses it.
- **Two-vocabulary world if the operator CRD keeps `Release` (D1).** Authors will hold both "a `#ModuleInstance` is rendered by a `Release` CR" in their heads. Defensible (artifact vs. reconciler), but it is a concept the docs must teach explicitly.

## Alternatives

- **Do nothing; fix it with documentation.** Keep `#ModuleRelease`, explain in docs that it means "instance." **Why not:** the canonical comment already does this, which is the tell that the name is the defect; docs are a recurring tax, not a fix.
- **Rename everything including the operator `Release` CRD to `Instance`.** One word everywhere. **Why not:** erases the artifact-vs-reconciliation distinction (see D1); "Instance" fits the GitOps CR poorly.
- **Choose a different target word (`Deployment`, `Installation`, `Placement`).** **Why not:** `Deployment` collides with the Kubernetes kind; `Installation` is Flux/Helm-flavored (same problem as `Release`); `Placement` is scheduling jargon. "Instance" most directly names the multiplicity property that motivated the change.
