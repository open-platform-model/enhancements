# Design Decisions — Kubernetes-Native Refocus: Generated Mirror and Composed Abstractions

This document records every significant design choice with its reasoning and the alternatives ruled out. The log is **append-only** — never remove or renumber. A reversed decision gets a new `DN` that supersedes the old one; the original stays.

Each decision uses the four-field shape: Decision, Alternatives considered, Rationale, Source.

---

## Decisions

### D1: Kubernetes is the first-class lowest common denominator; one generated type source feeds both catalogs

**Decision:** The Kubernetes OpenAPI is the single source of Kubernetes type truth. Generation tooling derives all downstream type schemas from it, and both `catalog_kubernetes` and `catalog_opm` consume the generated output rather than independently-maintained schemas. The project targets Kubernetes only.

**Alternatives considered:**

- Keep hand-written schemas in `catalog_kubernetes` and independently-vendored `cue.dev/x/k8s.io` in `catalog_opm` (status quo) — rejected: two sources drift silently, and hand-authoring does not scale to all kinds/versions or to CRDs.
- Keep a platform-neutral abstraction spanning Kubernetes and other runtimes — rejected: the project has refocused on Kubernetes; a neutral abstraction pays generality cost for runtimes no longer in scope.

**Rationale:** With Kubernetes as the permanent lowest common denominator, both catalogs target it anyway. A single generated source removes the only duplication that actually hurts (divergent schema foundations) without forcing structural coupling between the catalogs.

**Source:** User decision 2026-06-20.

### D2: Catalog-on-catalog composition is supported, not forced

**Decision:** Composition between catalogs is an available capability for layering abstractions *on top* of a lower catalog (notably third-party / provider golden-path catalogs). The base catalogs are not required to compose each other: `catalog_opm` keeps its own constructing transformers, re-pointed at the strict generated types, and does not flow through `catalog_kubernetes`.

**Alternatives considered:**

- Force `catalog_opm` to project onto `catalog_kubernetes` resources so the pass-through mirror does all rendering (the earlier "Model B as mandate") — rejected: pass-through and construction are different jobs, so routing one through the other adds indirection without removing real duplication, which D1's shared type source already handles.

**Rationale:** Composition's value is open-ended extensibility (golden paths), which happens *above* the base catalogs. Mandating internal composition buys nothing once types are shared and costs indirection and a harder trapdoor.

**Source:** User decision 2026-06-20.

### D3: No core change in this enhancement; multi-phase lowering is a staged, evidence-gated follow-on

**Decision:** This enhancement makes no change to `opmodel.dev/core@v0`; the transformation model stays single-pass. A separate `core` enhancement for multi-phase / fixpoint lowering (transformer outputs that re-enter matching) is opened only when a concrete case demonstrates that pure-CUE schema projection cannot express it. As cheap insurance, the transformer-output convention is kept compatible with typed outputs later, without adopting fixpoint lowering now.

**Alternatives considered:**

- Widen this umbrella to deliver multi-phase lowering now — rejected: largest risk to the kernel, and D1/D2 removed most of the pressure for it (composition and golden paths ship on projection).
- Design a sibling `core` enhancement in parallel from the start — deferred, not rejected: revisit if a sequential-lowering / cross-resource-wiring case emerges (tracked as OQ6).

**Rationale:** The fixpoint model earns its risk only for genuinely sequential lowering, of which no concrete instance exists yet. Gating on evidence keeps the riskiest change off the critical path and makes its eventual design sharper.

**Source:** User decision 2026-06-20.

---

## Open Questions

Each entry carries a `Status:` line; close it with `resolved-by-D##`, `deferred-to-NNNN`, or `answered`.

- **OQ1: Strict vs open projection — one module or two, and reuse vs generate?** Status: open. The generator must emit a strict projection (for `catalog_opm` construction + validation) and an open/`...`-leaf projection (for `catalog_kubernetes` pass-through fidelity and CRDs). Decide whether these are two modules from one generator, one module with both variants per kind, and whether the strict side reuses `cue.dev/x/k8s.io@v0` directly or is generated in-house for consistency with the open side and CRDs.

- **OQ2: Where does the generation tooling live, and in what language?** Status: open. Candidates: a new repo, inside `catalog_kubernetes`, or `library`. Language: Go vs CUE's native `cue import` of k8s OpenAPI/CRD YAML. Resolves the "Generation tooling (new; home TBD)" Integration Point in `02-design.md`.

- **OQ3: How is the Kubernetes version axis represented?** Status: open. Two axes exist: an object's API version (`apps/v1`) — already per-kind — and the cluster minor (1.32 vs 1.33 add/remove GVKs and fields). Likely resolution: encode the targeted k8s minor in the catalog's SemVer and let the `#Platform` subscription filter pin it (reusing existing machinery), but confirm the release cadence and how multiple minors coexist.

- **OQ4: How is per-kind readiness metadata curated and maintained?** Status: open. Readiness expressions are not in the OpenAPI (they encode k8s status conventions). Decide the curated source (a maintained table keyed by GVK), the generic fallback (`status.conditions[type=Ready]`), and who owns updates as kinds evolve.

- **OQ5: Trapdoor semantics — how does an override unify with sugar-set defaults?** Status: open. For "override any raw field on top of the sugar" to work, the abstraction's projected fields must be defaults (`*…`) so an explicit override wins rather than conflicts (today's `#StatelessWorkload` uses concrete assignment, which would conflict). Decide whether the trapdoor is "unify a patch on top" (needs defaulted projection) or an explicit `overrides: <strict-type>` field merged into output.

- **OQ6: What concrete case would trigger the staged core (multi-phase lowering) follow-on?** Status: open. Name the first cross-resource-wiring / sequential-lowering scenario that pure-CUE projection cannot express (e.g. an abstraction whose emitted resource must reference another emitted resource's *rendered, prefixed* name). When such a case is concrete, it becomes the problem statement for the sibling `core` enhancement under D3.
