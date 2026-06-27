# Risks, Drawbacks, Alternatives — Kubernetes-Native Refocus: Generated Mirror and Composed Abstractions

This document records the honest costs of the proposed design. Risks are what could go wrong; Drawbacks are what definitely costs something; Alternatives are the high-level paths not taken (per-decision detail lives in `03-decisions.md`).

## Risks and Mitigations

- **Generated strict types over-constrain real manifests.** Closed types generated from the OpenAPI may reject valid native fields (vendor extensions, newer fields the pinned schema lacks), breaking author manifests that worked under hand-written open schemas. **Mitigation:** keep `catalog_kubernetes` on the open projection; reserve strict types for `catalog_opm` construction where validation is wanted; retain the `#Objects` generic hatch for anything untyped.
- **Readiness metadata is curated and goes stale.** Readiness expressions are not in the OpenAPI; a maintained per-kind table can lag new kinds or changed status conventions, causing the operator to misreport readiness. **Mitigation:** a generic `status.conditions[Ready]` fallback for uncurated kinds; treat the curated table as data with its own review, not code (OQ4).
- **Generator drift from upstream Kubernetes.** A new k8s minor changes GVKs/fields; if regeneration lags, catalogs misrepresent the target cluster. **Mitigation:** version-align catalog releases to k8s minors (OQ3) and wire regeneration into the release flow so a minor bump is a regeneration, not hand-editing.
- **Trapdoor unification conflicts.** If projected sugar fields are concrete rather than defaulted, author overrides conflict instead of winning, defeating the trapdoor (today's `#StatelessWorkload` uses concrete assignment). **Mitigation:** resolve OQ5 before implementation — defaulted projection or an explicit `overrides` field merged last.
- **Hitting projection's limit mid-implementation.** A cross-resource-wiring case that pure-CUE projection cannot express could surface after `catalog_opm` is committed to single-pass shapes. **Mitigation:** keep the transformer-output convention multi-phase-friendly (D3) and track the trigger as OQ6 so the staged `core` follow-on can pick it up without reworking catalog APIs.

## Drawbacks

- **A new generation pipeline to own and operate.** Regeneration, pinning, and release wiring are ongoing maintenance the hand-written catalogs did not have — accepted because hand-authoring cannot reach all kinds/versions or CRDs.
- **`catalog_kubernetes` source becomes generated, not hand-edited.** Contributors patch the generator or its inputs, not the CUE directly — a workflow change for catalog authors.
- **Two projections to keep coherent.** Strict and open renderings of the same source add a consistency surface, even though both derive from one input.

## Alternatives

- **Keep hand-writing both catalogs.** Continue the status quo with no generator. **Why not:** does not scale to all kinds/versions or CRDs, and leaves the divergent-schema-source drift unfixed.
- **Force `catalog_opm` to compose `catalog_kubernetes` (the earlier "Model B mandate").** Route all rendering through the mirror's pass-through transformers. **Why not:** D1's shared type source already removes the real duplication; mandated composition adds indirection and complicates the trapdoor for no gain.
- **Deliver multi-phase lowering now.** Redesign core so transformer outputs re-enter matching. **Why not:** highest kernel risk, and unnecessary for the goals once composition and golden paths ship on projection (D3).
