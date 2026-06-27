# Design — Kubernetes-Native Refocus: Generated Mirror and Composed Abstractions

This document answers: "What is the proposed solution and how does it work?" Design Goals and Non-Goals define the boundary; the High-Level Approach is the shape of the solution. All trade-off reasoning lives in `03-decisions.md`.

## Design Goals

- A **single generated source of Kubernetes type truth**, derived from the Kubernetes OpenAPI, that both catalogs consume — so neither hand-maintains schemas and the two cannot drift.
- A **generated native-Kubernetes mirror** (`catalog_kubernetes`): every built-in kind becomes a typed `#Resource` + pass-through `#ComponentTransformer` produced by tooling, not hand-authored, with the generic `#Objects` hatch retained for the untyped long tail.
- The same generation pipeline produces a **typed catalog from any CRD bundle** (cert-manager, Flux, Gateway API, operators), so the CRD long tail becomes first-class without hand-writing transformers.
- Each generated resource carries **Kubernetes lifecycle metadata** (scope, apply order, readiness, prune/ownership policy) that the operator's reconcile loop consumes.
- `catalog_opm` abstractions gain a **faithful trapdoor**: sugar sets defaults that an author may override down to any native field, because the abstraction is backed by the complete generated type surface.
- **Catalog-on-catalog composition is a supported capability**, not a forced internal structure — third-party / provider "golden-path" catalogs can layer abstractions on top of `catalog_opm` or `catalog_kubernetes`.

## Non-Goals

- **No change to `opmodel.dev/core@v0`.** The transformation model stays single-pass; this enhancement is achievable entirely in the catalogs, the generation tooling, and the library/operator adapter. Multi-phase / fixpoint lowering (transformer outputs that re-enter matching) is deliberately deferred — see Open Questions and the staged follow-on in `03-decisions.md`.
- **Not forcing `catalog_opm` to compose `catalog_kubernetes`.** With Kubernetes as the lowest common denominator, both catalogs target it directly and share the generated type source; `catalog_opm` keeps its own constructing transformers.
- **No support for non-Kubernetes platforms.** Nomad / Compose / Swarm are out of scope by the project's refocus. Nothing here actively forbids them later, but no abstraction is shaped to accommodate them.
- **No runtime/reconcile engine in this enhancement.** Lifecycle *metadata* is produced here; the reconcile loop that consumes it is operator work tracked via its own slice.

## High-Level Approach

Make the **Kubernetes OpenAPI the single source of truth** and generate everything downstream from it.

A generation tool ingests a target Kubernetes minor's OpenAPI (and, separately, any CRD's `openAPIV3Schema`) and emits, per GVK: the type schema, an OPM `#Resource`, and — for the mirror — a pass-through `#ComponentTransformer` whose `apiVersion`/`kind`/scope come from the GVK. Because the pass-through transformer is uniform across kinds, it is a template; this is what makes the mirror generatable rather than hand-authored. The same tool, pointed at a CRD bundle, emits a typed catalog for that operator.

The generator emits **two projections from the one source**: a *strict* projection (closed types — what `catalog_opm` builds its constructing transformers on, or `cue.dev/x/k8s.io` used directly) and an *open* projection (leaves left `...` — what `catalog_kubernetes` uses to preserve pass-through fidelity and accept arbitrary valid native fields). Same source, two renderings, no hand-maintained drift.

Each generated resource is stamped with **lifecycle metadata** the operator consumes: scope (namespaced/cluster, from discovery), an apply-order phase (generalizing today's hardcoded `library/pkg/resourceorder` list into per-kind data), a readiness expression (curated per kind from Kubernetes status conventions, with a `status.conditions[Ready]` fallback), and prune/ownership policy (ownerReferences + server-side apply field ownership — now expressible concretely because the target is Kubernetes-only).

`catalog_opm` stays the opinionated layer with its own transformers, re-pointed at the strict generated types instead of independently-vendored ones, and gains an explicit **override field** so an author can patch any raw field on the resource the abstraction produces (the trapdoor). **Composition** is offered as a capability: a higher catalog (including third-party golden-path catalogs) composes a lower catalog's resources/blueprints and projects sugar onto them in pure CUE — the mechanism already demonstrated by `catalog_opm`'s `#StatelessWorkload` (`stateless_workload.cue:59-78`). Nothing forces the base catalogs to compose each other; composition is for layering *on top*.

## Schema / API Surface

Headline shapes only — full surface in `schemas/target.cue`.

- **Generator manifest** — declarative config naming the inputs (a k8s minor's OpenAPI endpoint or a CRD bundle), the projection (strict | open), and output targets. Drives reproducible regeneration; the catalog source becomes a generation artifact rather than hand-written.
- **Lifecycle metadata block** — the per-resource stamp (`scope`, `applyPhase`, `readiness`, `prune`/`ownership`) attached to each generated `#Resource`'s metadata, shaped so the library/operator can read it without re-deriving from the GVK.
- **Override / trapdoor field** — the convention by which a `catalog_opm` abstraction exposes the full underlying strict type for author overrides (defaults from sugar, overrides win).
- **Transformer-output convention** — kept compatible with a possible future where outputs become typed resources (the cheap "don't be hostile to multi-phase later" insurance), without adopting fixpoint lowering now.

## Integration Points

Grouped by repo. File-level targets firm up as decisions land.

- **Generation tooling (new; home TBD — Open Question).** OpenAPI/CRD ingestion → CUE emission for resources, transformers, schemas, catalog manifest, and lifecycle metadata. Both projections.
- **`catalog_kubernetes`.** Replace hand-written `src/resources`, `src/schemas`, `src/transformers`, `src/catalog.cue` with generated output (open projection). Retain `#Objects` generic hatch. Wire generation into the Taskfile / release flow.
- **`catalog_opm`.** Re-point transformers and `src/schemas/kubernetes` at the strict generated source (drop independently-vendored types). Add the override/trapdoor field to blueprints. Keep existing blueprints/traits.
- **`library`.** Generalize `pkg/resourceorder` to read the generated `applyPhase` metadata; expose readiness/prune metadata to consumers.
- **`opm-operator`.** Reconcile using the lifecycle metadata (ordering, readiness reporting, pruning via ownerReferences + SSA).
- **`opmodel.dev`.** Document the generated catalogs, the generation workflow, and the golden-path composition pattern.

## Before / After

**Trapdoor (the `topologySpreadConstraints` case from `01-problem.md`).** Before: the field is unreachable through `#StatelessWorkload`; the author abandons the blueprint for raw `catalog_kubernetes`. After: the author keeps `#StatelessWorkload` and sets the field through the abstraction's override onto the full generated Deployment type — sugar provides the defaults, the override wins.

**CRD support (the `cert-manager.io/v1 Certificate` case).** Before: only the untyped `#Objects` blob, or a hand-written transformer. After: run the generator against cert-manager's published CRDs once; a typed `Certificate` `#Resource` + pass-through transformer (with lifecycle metadata) drops out, consumable like any built-in kind.

**Provider golden path.** Before: no first-class way for a provider to ship opinionated app templates layered on OPM. After: a provider publishes `catalog_acme_goldenpaths` depending on `catalog_opm` (or `catalog_kubernetes`), projecting its templates onto those resources in pure CUE — composition on top, no core change.
