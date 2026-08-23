# Open Questions — Kubernetes-Native Refocus: Generated Mirror and Composed Abstractions

## Open Questions

Each entry carries a `Status:` line; close it with `resolved-by-D##`, `deferred-to-NNNN`, or `answered`.

- **OQ1: Strict vs open projection — one module or two, and reuse vs generate?** Status: open. Blocking: acceptance — gates the construction roadmap (projection shape). The generator must emit a strict projection (for `catalog_opm` construction + validation) and an open/`...`-leaf projection (for `catalog_kubernetes` pass-through fidelity and CRDs). Decide whether these are two modules from one generator, one module with both variants per kind, and whether the strict side reuses `cue.dev/x/k8s.io@v0` directly or is generated in-house for consistency with the open side and CRDs.

- **OQ2: Where does the generation tooling live, and in what language?** Status: open. Blocking: acceptance — gates the construction roadmap (generator home and language). Candidates: a new repo, inside `catalog_kubernetes`, or `library`. Language: Go vs CUE's native `cue import` of k8s OpenAPI/CRD YAML. Resolves the "Generation tooling (new; home TBD)" Integration Point in `02-design.md`.

- **OQ3: How is the Kubernetes version axis represented?** Status: open. Blocking: acceptance — gates the construction roadmap (version axis). Two axes exist: an object's API version (`apps/v1`) — already per-kind — and the cluster minor (1.32 vs 1.33 add/remove GVKs and fields). Likely resolution: encode the targeted k8s minor in the catalog's SemVer and let the `#Platform` subscription filter pin it (reusing existing machinery), but confirm the release cadence and how multiple minors coexist.

- **OQ4: How is per-kind readiness metadata curated and maintained?** Status: open. Readiness expressions are not in the OpenAPI (they encode k8s status conventions). Decide the curated source (a maintained table keyed by GVK), the generic fallback (`status.conditions[type=Ready]`), and who owns updates as kinds evolve.

- **OQ5: Trapdoor semantics — how does an override unify with sugar-set defaults?** Status: open. Blocking: acceptance — gates the construction roadmap (trapdoor semantics). For "override any raw field on top of the sugar" to work, the abstraction's projected fields must be defaults (`*…`) so an explicit override wins rather than conflicts (today's `#StatelessWorkload` uses concrete assignment, which would conflict). Decide whether the trapdoor is "unify a patch on top" (needs defaulted projection) or an explicit `overrides: <strict-type>` field merged into output.

- **OQ6: What concrete case would trigger the staged core (multi-phase lowering) follow-on?** Status: open. Name the first cross-resource-wiring / sequential-lowering scenario that pure-CUE projection cannot express (e.g. an abstraction whose emitted resource must reference another emitted resource's *rendered, prefixed* name). When such a case is concrete, it becomes the problem statement for the sibling `core` enhancement under D3.
