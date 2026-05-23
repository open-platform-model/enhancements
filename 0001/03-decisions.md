# Design Decisions — `#Platform` Redesign Umbrella

## Summary

Decision log for the umbrella. Each architectural and design choice is numbered sequentially (D1, D2, D3, …) and recorded as it is made. The log is **append-only** — never remove or renumber existing entries. If a decision is reversed, add a new decision that supersedes it (e.g. "D9 supersedes D3") and leave D3 in place as historical context.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source. The Source field is specific — `"User decision YYYY-MM-DD"`, a URL, a file path, or an experiment outcome — so the provenance of a choice never gets lost.

This file ships intentionally **skeletal**. Decisions accrete iteratively in follow-up turns as each design choice is discussed and resolved. The Open Questions list below is the seed agenda: every OQ becomes either a decision (`resolved-by-D##`), a deferral (`deferred-to-NNNN`), or an explicit `answered` outcome.

---

## Decisions

### D1: `#ctx` collapses to `{ release, components }` — no `runtime` axis, no `module` mirror, no `#ModuleContext` wrapper

**Decision:** `#Module.#ctx` is an inline struct on `#Module` with exactly two named fields — `release: #ReleaseIdentity` and `components: { for id, c in #components { (id): c.#names } }` — plus an open top (`...`) so future enhancements can add `platform` / `environment` siblings additively. `#ModuleContext`, `#RuntimeContext`, `#ModuleIdentity`, and `#ContextBuilder` are not introduced.

**Alternatives considered:**

- Single-layer `#ctx: { runtime: #RuntimeContext }` with `runtime.{release, module, components}`. Rejected: the `runtime` axis only existed to make room for future `platform` / `environment` siblings; the open-top inline struct preserves that property with one fewer indirection. Mirroring `module` under `#ctx` duplicates `#Module.metadata` (name, version, fqn, uuid already live there) and creates a sync surface the matcher and renderer would have to keep honest.
- Remove `#ctx` entirely; expose `#release` and per-component `#names` at the top level of `#Module` and `#Component` respectively. Rejected at this stage: keeps the channel boundary clear ("anything under `#ctx` is kernel-injected") for SPEC docs and tooling, and gives a single root for the future capability extension.

**Rationale:** Two fields, no wrappers, open top. Module identity stays in `#Module.metadata` (single source of truth). The extension property promised by OQ17 is preserved by the `...` opening, not by a placeholder `runtime` axis.

**Source:** User decision 2026-05-23 (this conversation, after evaluating the three reimagine options).

---

### D2: `#Component.#names` is the source of truth; `#ctx.components` is a pure CUE projection

**Decision:** Each `#Component.#names` block computes `resourceName` and `dns.{short, local, fqdn}` inline from the component's own `metadata.resourceName` cascade and the injected `#release`. `#Module.#ctx.components` is a CUE comprehension over `#components` that maps each `id` to `#components[id].#names`. No builder, no separate computation, no kernel-side projection step. `metadata.resourceName: *name | #NameType` carries the override cascade — explicit override wins, otherwise falls back to `metadata.name`.

**Alternatives considered:**

- Kernel-side `#ContextBuilder` computes `#ctx.components.<id>` and unifies the per-component slice into each component's `#names`. Rejected: two computation paths for the same data invite drift; the matcher and renderer would have to defend against a `#ctx.components.<id>` that disagrees with `#components.<id>.#names`. With CUE comprehensions the projection is structurally guaranteed identical.
- `#names` carried only on `#ctx.components.<id>`, with components reading their own names via `#ctx.components.\(metadata.name)`. Rejected: requires retyping the map key inside every self-reference, defeats one of the cascade's main ergonomic wins, and couples component bodies to a sibling map.

**Rationale:** Single source of truth eliminates the OQ19 / OQ20 / OQ21 trap surface. The comprehension is a CUE one-liner; no Go-side helper needed. Cross-component reads use `#ctx.components.api.dns.fqdn`; self-reads use `#names.dns.fqdn`; both resolve to the same value because `#ctx.components` *is* the projection.

**Source:** User decision 2026-05-23.

---

### D3: `#Component.#release` is the per-component release injection slot; `#Module` wires it via the `#components` pattern constraint

**Decision:** `#Component` carries `#release: #ReleaseIdentity` as a hidden definition slot. `#Module` wires the module-level release into every component:

```cue
#components: [Id=#NameType]: #Component & {
    metadata: name: string | *Id
    #release: #ctx.release
}
```

Module authors never set `#release` directly; the parent pattern constraint propagates `#ctx.release` into every component, and each component's `#names` block reads it to compute DNS variants.

**Alternatives considered:**

- Components read release context via CUE lexical scope from the enclosing `#Module`. Rejected: CUE pattern-constraint scope rules are subtle enough that the explicit injection slot is the safer documentation surface; the slot is also the natural anchor for a future capability that wants to surface per-component context (e.g. a sidecar-specific token).
- `#ModuleRelease` walks the component map at release-evaluation time and unifies a release slice into each component. Rejected: that *is* a builder — exactly what D1 / D2 remove. CUE pattern constraints do the same work declaratively.

**Rationale:** Hidden-by-convention (`#`-prefix) keeps the slot out of author surface area; pattern-constraint wiring keeps the kernel out of the loop. The spike under `schemas/example_instance.cue` proves the propagation works end-to-end on a concrete two-component module.

**Source:** User decision 2026-05-23; validated by `cue vet ./...` on `enhancements/0001/schemas/`.

---

### D4: `clusterDomain` lives on `#ReleaseIdentity`

**Decision:** `#ReleaseIdentity` gains a `clusterDomain: string | *"cluster.local"` field. `#ModuleRelease.metadata` carries the same field and sets it through to `#ctx.release.clusterDomain`. DNS variants on `#Component.#names` derive from `#release.clusterDomain`.

**Alternatives considered:**

- Hidden `_clusterDomain` inside an obsolete `#RuntimeContext`. Rejected with `#RuntimeContext` itself (D1).
- Platform-side capability that supplies a default. Deferred to the future platform-capabilities work; cluster domain is a release-scoped fact today, and pushing it onto a capability before that work lands would block this enhancement on something out of scope.
- Hardcoded `"cluster.local"` constant on the DNS expression. Rejected: a small number of real deployments use non-default cluster domains; the override path must exist now even if the default covers most cases.

**Rationale:** Single overridable home, semantically grouped with the rest of release identity, no dependency on a future capabilities surface.

**Source:** User decision 2026-05-23.

---

## Open Questions

Seed agenda — every entry becomes a decision, a deferral, or an explicit `answered` outcome before the enhancement leaves `draft`. The validator (future) requires this block to be present from `accepted` onwards; entries should carry a `Status:` line once the enhancement reaches `implemented`.

### Registry + materialize

- **OQ1: Path-keyed `#registry` vs FQN-keyed `#registry` vs keeping the Module-valued shape.** Status: open. The umbrella scope assumes path-keyed subscriptions, but the exact key shape (kebab Id → `#Subscription`, or path → `#Subscription`, or something else) is the first decision to lock.
- **OQ2: Filter shape — `range` only, `range + allow + deny`, or allowlist-only?** Status: open. Operational escape hatches (force-include a build, force-exclude a known-bad patch) only exist if `allow` / `deny` are present. Resolution order matters too: range → allow → deny is the natural read but needs to be the explicit spec.
- **OQ3: Filter parser library.** Status: open. Masterminds/semver is the natural Go dependency for the range syntax; confirm no friction with `cuelang.org/go/mod`'s own version parsing before locking it in.
- **OQ4: Materialize trigger and cache keying.** Status: open. Explicit `Kernel.Materialize(*Platform) → *MaterializedPlatform` vs implicit-inside-Match. Cache key derives from `(path × filter × OCI tag set at fetch time)`; invalidation strategy when the registry advances (caller-driven, time-based, or an explicit "refresh" hook on a future `opm` CLI).
- **OQ5: Top-level vs nested catalog scan.** Status: open. The kernel discovers transformers by walking *top-level* values in the catalog package and unifying with `#ComponentTransformer`. Whether to also recurse into nested grouping structs (e.g. `Transformers: { … }`) is a discovery-rules question — default to top-level only unless catalog authors complain.
- **OQ6: Cross-catalog primitive references.** Status: open. A transformer in catalog A may reference a resource published by catalog B via its `requiredResources` map. With multiple catalogs subscribed, this works as long as both are pulled. Document as an explicit supported pattern or defer to a follow-up.
- **OQ7: Multi-fulfiller behaviour.** Status: open. Today's `#matchers.{resources,traits}[FQN]: [...#ComponentTransformer]` allows multiple transformers to require the same primitive FQN, disambiguated by predicate evaluation. The SemVer-FQN expansion reduces collision likelihood; confirm at implementation time whether the predicate-evaluation logic still applies unchanged or simplifies.

### Catalog identity + publish

- **OQ8: Per-primitive SemVer vs catalog-monolithic SemVer.** Status: open. The design sketches a 1:1 coupling (every primitive in catalog at `X.Y.Z` carries `metadata.version: "X.Y.Z"`), but independent per-primitive SemVer is the alternative — higher fidelity, more authoring burden, ambiguous publish flow.
- **OQ9: Catalog identity stamping — root constant vs subpackage constants vs author-hand-written.** Status: open. The design sketches a single root-package constant (`Catalog: { Version, ModulePath }`), but per-subpackage stamping (no cross-package imports) is the alternative.
- **OQ10: Cross-package access mechanism — exported `Catalog` struct vs `_`-prefixed identifiers.** Status: open. CUE's `_`-prefix makes identifiers package-private; if subpackages need to read the constant, the name must be exported (`Catalog` capital-C). Confirm via a CUE spike.
- **OQ11: Source-tree default for `Catalog.Version`.** Status: open. Checked-in `"0.0.0-dev"` default vs gitignored generated value vs always-checked-in concrete version. The dev-time `cue vet` experience and the publish-time drift risk are the trade-offs.
- **OQ12: Publish stamping strategy — temp build dir vs in-place + git revert.** Status: open. Temp build dir keeps the source tree pure; in-place stamping with a trap-on-exit revert is the alternative.

### FQNs + matching

- **OQ13: SemVer-suffixed FQNs vs MAJOR-only + version predicate.** Status: open. The umbrella scope assumes SemVer FQNs (`@1.4.0`), but keeping MAJOR FQNs and adding a `version` predicate field on transformers is the alternative that opts out of the regex change.
- **OQ14: Always-unify at match vs FQN-only vs `--strict` mode.** Status: open. The design sketches always-unify before predicate evaluation; the alternatives are FQN-identity-is-sufficient (silent same-SemVer divergence) and a `--strict` flag (defence-in-depth that only fires in dev).
- **OQ15: Missing FQN — one error per occurrence vs aggregate vs fail-fast.** Status: open. The design sketches one structured error per `(component, FQN)` pair, accumulated; the alternatives are a single aggregate diagnostic or fail-fast on first miss.
- **OQ16: `#Blueprint` SemVer trail.** Status: open. Blueprints share the FQN-and-metadata shape with Resource / Trait / Transformer; do they adopt the same SemVer / stamping trail in lockstep? Default yes, no extra logic — but confirm there's no platform-side projection blueprints need that this design forgets.

### `#ctx.runtime`

- **OQ17: `#ctx.platform` and `#ctx.environment` extension points.** Status: open. The design ships `#ModuleContext: { runtime: #RuntimeContext }` with no other top-level fields, leaving room for a future capabilities enhancement to add `platform` and/or `environment` siblings. Confirm the shape stays additive (no closed `#ModuleContext` at this stage).
- **OQ18: Cluster-domain handling.** Status: resolved-by-D4. `clusterDomain` lives on `#ReleaseIdentity` with a `*"cluster.local"` default; `#ModuleRelease.metadata.clusterDomain` carries the override and sets `#ctx.release.clusterDomain` directly.
- **OQ19: `#Component.#names` injection mechanism.** Status: resolved-by-D2/D3. There is no injection — each `#Component.#names` computes itself from the component's own `metadata` plus the injected `#release` (D3); `#ctx.components` is a comprehension over those. Validated end-to-end in `schemas/example_instance.cue`.
- **OQ20: `metadata.resourceName` override propagation.** Status: resolved-by-D2. Cascade lives on `metadata.resourceName: *name | #NameType`; `#names.resourceName` reads it directly; DNS variants derive from `resourceName`. Override wins when set; absence falls back to `metadata.name`, which itself defaults to the `#components` map key. Validated in `schemas/example_instance.cue`.
- **OQ21: `#ContextBuilder` ordering vs `#config` unification.** Status: resolved-by-D1/D2. No builder; no ordering question. `#ctx.release` is set by `#ModuleRelease` upfront, `#ctx.components` is a comprehension over `#components` evaluated independently of `#config`. The trap surface disappears.
- **OQ22: Bundle-level context.** Status: deferred. Cross-module `#ctx` references (one module reading another module's `#ctx.runtime.components.<id>.dns.fqdn`) are out of scope for this umbrella. Tracking here so the deferral is explicit.
- **OQ23: Content hashes for immutable ConfigMaps / Secrets via `#ctx`.** Status: deferred. Out of scope; tracked here so it does not silently slip into the design.

### Operational

- **OQ24: Cutover sequence with the core split.** Status: open. The core repo split's Part B (library rewire from `opmodel.dev/core/v1alpha2@v1` to `opmodel.dev/core@v0`) is in flight. Does 0001 land *on top of* that cutover, or does 0001 carry the import change itself? Sequencing affects whether the library fixture migration is one PR or two.
- **OQ25: Catalog repackage migration path.** Status: open. Today's `catalog/opm/v1alpha1/` already exports primitives at top level (no `#defines` wrapper), but lacks the `Catalog: { Version, ModulePath }` constant. Is the cutover a hard switch (drop v1alpha1, publish `opmodel.dev/modules/opm@1.0.0` as the first SemVer-FQN catalog) or a graceful coexistence (publish both shapes for one release)?
