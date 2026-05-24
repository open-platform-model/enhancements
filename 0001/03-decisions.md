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

**Source:** User decision 2026-05-23 (after evaluating the three reimagine options). Reinforced by experiment `enhancements/0001/experiments/07-ctx-cycle-freedom/` concluded 2026-05-23 — the comprehension's input (`#names`) cannot read its output (`#ctx.components`) without producing a hard CUE error, so the cycle-freedom claim is empirically structural.

---

### D2: `#Component.#names` is the source of truth; `#ctx.components` is a pure CUE projection

**Decision:** Each `#Component.#names` block computes `resourceName` and `dns.{short, local, fqdn}` inline from the component's own `metadata.resourceName` cascade and the injected `#release`. `#Module.#ctx.components` is a CUE comprehension over `#components` that maps each `id` to `#components[id].#names`. No builder, no separate computation, no kernel-side projection step. `metadata.resourceName: *name | #NameType` carries the override cascade — explicit override wins, otherwise falls back to `metadata.name`.

**Alternatives considered:**

- Kernel-side `#ContextBuilder` computes `#ctx.components.<id>` and unifies the per-component slice into each component's `#names`. Rejected: two computation paths for the same data invite drift; the matcher and renderer would have to defend against a `#ctx.components.<id>` that disagrees with `#components.<id>.#names`. With CUE comprehensions the projection is structurally guaranteed identical.
- `#names` carried only on `#ctx.components.<id>`, with components reading their own names via `#ctx.components.\(metadata.name)`. Rejected: requires retyping the map key inside every self-reference, defeats one of the cascade's main ergonomic wins, and couples component bodies to a sibling map.

**Rationale:** Single source of truth eliminates the OQ19 / OQ20 / OQ21 trap surface. The comprehension is a CUE one-liner; no Go-side helper needed. Cross-component reads use `#ctx.components.api.dns.fqdn`; self-reads use `#ctx.components.<self-id>.dns.fqdn` (the projection equivalent — `#names` itself is not in lexical scope from inside a component instance's spec field; see `02-design.md` authoring caveat).

**Source:** User decision 2026-05-23. Validated by experiment `enhancements/0001/experiments/01-names-cascade/` concluded 2026-05-23 — three cascade branches (default-name / explicit-name / explicit-override) resolve as designed, byte-identity between `#components.<id>.#names` and `#ctx.components.<id>` confirmed.

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

**Source:** User decision 2026-05-23. Validated by `cue vet ./...` on `enhancements/0001/schemas/example_instance.cue` (spike) and by experiment `enhancements/0001/experiments/01-names-cascade/` concluded 2026-05-23 (three-component cascade) plus `enhancements/0001/experiments/07-ctx-cycle-freedom/` concluded 2026-05-23 (mutual cross-component refs evaluate cleanly).

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

### D5: `#FQNType` regex accepts SemVer 2.0; MAJOR-only retired from primitive metadata

**Decision:** `#FQNType` regex is `^[a-z0-9.-]+(/[a-z0-9.-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@\d+\.\d+\.\d+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$`. Primitive `metadata.version` switches from `#MajorVersionType` to `#VersionType`. `#MajorVersionType` is retired from primitive metadata (survives elsewhere — `#BundleFQNType` still uses it).

**Alternatives considered:**

- Keep MAJOR-only `@v[0-9]+` + add a `version` predicate field on transformers for discrimination. Rejected: opt-in by every author; surfaces drift as generic predicate failure rather than structured diagnostic; nothing structurally prevents two `1.x.x` builds from colliding in `#composedTransformers` (the FQN strings are identical).
- Two-component SemVer (`@MAJOR.MINOR`). Rejected: patch-level catalog rebuilds are common (security backports, build-pipeline fixes) and need first-class addressability; collapsing them defeats the point of leaving MAJOR-only.

**Rationale:** Distinct FQN keys per SemVer plus always-unify (D6) makes silent same-major drift impossible by construction. Experiment confirmed the regex accepts every SemVer 2.0 shape the design relies on (release, prerelease short/dotted/numeric, build metadata, dotted identifiers, multi-digit majors) and rejects every malformed shape that would let drift slip through (MAJOR-only, partial, four-part, malformed prerelease, v-prefix, slash-separator, case violations).

**Source:** Experiment `enhancements/0001/experiments/02-semver-fqn-regex/` concluded 2026-05-23 — hypothesis held; 9/9 positive accept, 9/9 negative reject.

---

### D6: Match always unifies consumer primitive against transformer required slot; CUE catches same-FQN divergence

**Decision:** The match step performs `unify(consumer_component.#resources[FQN], transformer.requiredResources[FQN])` (and the analogous `traits` step) for every paired FQN, **before** predicate evaluation. No `--strict` mode, no FQN-identity-is-sufficient shortcut. Same-FQN rebuilds with byte-identical bodies collapse to one map entry under unification; same-FQN rebuilds with divergent bodies produce a CUE error naming the diverging field with file:line citations.

**Alternatives considered:**

- FQN-identity is sufficient (skip unification). Rejected: silent same-SemVer divergence is the exact failure mode the umbrella exists to eliminate; opting out at match time would re-open it.
- `--strict` flag for opt-in unification (defence-in-depth that only fires in dev). Rejected: production code paths must enforce the integrity the design promises; a dev-only flag is a footgun.
- Detect divergence inside Materialize, fail there. Considered: works too, but redundant — CUE's index-build unification surfaces the same error one phase earlier (already covered by `MaterializeError`); Match's unification catches the consumer/transformer schema mismatch which Materialize cannot see.

**Rationale:** Experiment 03 proved CUE's unification produces authoring-grade diagnostics already: `conflicting values "X" and "Y": ./fileA:line:col ./fileB:line:col` — the kernel surfaces the error verbatim with no Go-side formatting. Per-pair cost is bounded (a few CUE evaluations); the failure mode it eliminates (silent render-time drift) is far worse.

**Source:** Experiment `enhancements/0001/experiments/03-same-fqn-divergent-unify/` concluded 2026-05-23 — hypothesis held; matching variant collapses to one entry, divergent variant errors with field-named diagnostics.

---

### D7: Catalog identity lives in a single root-package exported `Catalog` constant

**Decision:** Every catalog declares `Catalog: { Version: #VersionType | *"0.0.0-dev", ModulePath: #ModulePathType }` at the root of its CUE package. The identifier is capitalised (exported) so subpackages can read it via standard CUE cross-package imports (`import "<modulepath>"; ... catalog.Catalog.Version`). Subpackage primitives source `metadata.modulePath` and `metadata.version` from this single constant.

**Alternatives considered:**

- Per-subpackage stamping (no cross-package imports; each subpackage has its own `Catalog` constant). Rejected: identity duplicated across every subdirectory; publish flow has to stamp N files instead of one; high drift risk.
- Underscore-prefix `_catalog` (package-private). Rejected: CUE's `_`-prefix makes the identifier unreadable from subpackages — defeats the cross-package access pattern that the whole design depends on.
- Per-primitive author-hand-written version. Rejected: every primitive carries duplicated identity, every catalog release requires N edits, no single source of truth.

**Rationale:** Experiment confirmed exported root constant works cleanly across package boundaries (subpackage `resources/container.cue` reads `catalog.Catalog.Version` via standard CUE import). One file changes per release; identity drift impossible by construction.

**Source:** Experiment `enhancements/0001/experiments/04-catalog-stamping-flow/` concluded 2026-05-23 — hypothesis held; cross-package access confirmed; one constant drives every primitive's `metadata.{version,modulePath}`.

---

### D8: Catalog source tree carries `Catalog.Version: *"0.0.0-dev"` default

**Decision:** Checked-in catalog source defines `Catalog: { Version: #VersionType | *"0.0.0-dev", ModulePath: ... }`. Dev-time `cue vet` succeeds without any pre-stamp; primitives evaluate to `…@0.0.0-dev` FQNs locally.

**Alternatives considered:**

- Gitignored generated value (source carries no Version field; a `make generate` writes it). Rejected: every fresh checkout requires the generation step before `cue vet` works; bad onboarding UX.
- Always-checked-in concrete version. Rejected: every catalog commit becomes a version bump decision; defeats incremental authoring.

**Rationale:** `0.0.0-dev` keeps dev workflow zero-friction (vet works out of the box); publish-time stamping (D9) overwrites cleanly without source-tree mutation. Experiment confirmed dev vet succeeds and `0.0.0-dev` surfaces in primitive FQNs as expected. A CI guard should reject publishes of `0.0.0-dev` artifacts to catch "forgot to stamp" mistakes.

**Source:** Experiment `enhancements/0001/experiments/04-catalog-stamping-flow/` concluded 2026-05-23 — hypothesis held.

---

### D9: Publish-time stamping = temp-build-dir + `version_override.cue` sibling file

**Decision:** The catalog publish flow:

1. `rsync` source → `.build/catalog/` (excluding `cue.mod/{pkg,gen,usr}`).
2. Write `version_override.cue` sibling file in the build dir: `package catalog; Catalog: Version: "<SemVer>"`.
3. `cue vet` from build dir (must succeed at stamped version).
4. `cue mod publish` from build dir.

Source tree is byte-clean after; only `version_override.cue` differs in `.build/`.

**Alternatives considered:**

- In-place stamping with trap-on-exit revert. Rejected: race window where source tree carries the stamped version is observable to other tooling; failure mid-flow leaves source dirty.
- Edit `catalog.cue` directly in build dir (no separate override file). Rejected: harder to diff; mixes identity definition with version override; `version_override.cue` makes the stamping action a single discrete file that's trivially auditable.

**Rationale:** Experiment confirmed end-to-end with both release (`1.0.0`) and prerelease (`1.4.0-rc.1`) SemVers: stamped FQNs propagate to every primitive; `diff -r` after each stamp shows only `Only in .build/catalog: version_override.cue`. CUE's unification means the override and the source-tree default collapse to the override value automatically — no editing required.

**Source:** Experiment `enhancements/0001/experiments/04-catalog-stamping-flow/` concluded 2026-05-23 — hypothesis held.

---

### D10: Filter resolution order — `range` → `allow` append → `deny` subtract

**Decision:** `#SubscriptionFilter` resolves as a three-step pipeline against the registry version list:

1. `range` selects the in-range subset, preserving input order.
2. `allow` appends any entries not already in step 1 (force-include out-of-range builds).
3. `deny` filters the combined list (force-exclude known-bad patches).

**Alternatives considered:**

- `range` only (no allow/deny). Rejected: no operational escape hatch for emergency pins (a critical fix in `2.0.1` when the platform is on `1.x`) or known-bad patches (a `1.3.2` with a regression that subsequent point releases fix).
- Allow-list only (no range, no deny). Rejected: subscribing to a catalog now requires enumerating every published version; defeats the "subscribe to a range" headline.
- Order: deny → range → allow (allow trumps deny). Considered: would let `allow` override an explicit `deny` of the same version. Rejected: less defensible — explicit `deny` should be the last word ("I never want this version, even if range or allow would otherwise pick it up").

**Rationale:** Experiment 06 confirmed both CUE-side abstract semantic and Go-side Masterminds/semver parsing yield the same ordered output (`[1.0.0 1.1.0 1.2.0 1.4.0 2.0.1]`) for the canonical case `{ range: ">=1.0.0 <2.0.0", allow: ["2.0.1"], deny: ["1.3.2"] }` against input `[1.0.0 1.1.0 1.2.0 1.3.2 1.4.0 2.0.0]`. Order is robust across implementations.

**Source:** Experiment `enhancements/0001/experiments/06-filter-resolution-order/` concluded 2026-05-23 — hypothesis held on both CUE and Go sides.

---

### D11: Range parsing happens Go-side via `github.com/Masterminds/semver/v3`

**Decision:** `#SubscriptionFilter.range` carries an opaque string. `Kernel.Materialize` parses it Go-side via `github.com/Masterminds/semver/v3` and computes the in-range subset before any CUE evaluation runs. The CUE-level `#SubscriptionFilter` cannot evaluate the range string natively — CUE has no SemVer constraint parser.

**Alternatives considered:**

- Custom Go parser. Rejected: duplicates well-trodden library work; Masterminds is the de facto Go SemVer library (Helm, kubectl, operator-runtime all use it).
- CUE-native range expression (e.g. encode range as a CUE struct `{min, max, exclude}`). Rejected: experiment 06 confirmed CUE cannot natively parse SemVer range strings; a struct-based encoding would force every platform fixture to translate the standard `">=1.0.0 <2.0.0"` syntax into a custom shape; ergonomic regression.
- Range parsing inside Match instead of Materialize. Rejected: range filtering scopes what gets pulled and indexed; doing it later means materializing builds that the platform's policy excludes.

**Rationale:** Experiment 06's Go side validated the canonical case against Masterminds/semver v3.3.0 with no friction (range parses, constraint check, in-range filter all work as expected). Same library powers Helm and most Go-side SemVer tooling — well-trodden dependency.

**Source:** Experiment `enhancements/0001/experiments/06-filter-resolution-order/` concluded 2026-05-23 — hypothesis held.

---

## Open Questions

Seed agenda — every entry becomes a decision, a deferral, or an explicit `answered` outcome before the enhancement leaves `draft`. The validator (future) requires this block to be present from `accepted` onwards; entries should carry a `Status:` line once the enhancement reaches `implemented`.

### Registry + materialize

- **OQ1: Path-keyed `#registry` vs FQN-keyed `#registry` vs keeping the Module-valued shape.** Status: open. The umbrella scope assumes path-keyed subscriptions, but the exact key shape (kebab Id → `#Subscription`, or path → `#Subscription`, or something else) is the first decision to lock.
- **OQ2: Filter shape — `range` only, `range + allow + deny`, or allowlist-only?** Status: resolved-by-D10. `range + allow + deny` with resolution order `range → allow append → deny subtract`. Operational escape hatches confirmed.
- **OQ3: Filter parser library.** Status: resolved-by-D11. `github.com/Masterminds/semver/v3` v3.3.0, Go-side, inside `Kernel.Materialize`. CUE cannot evaluate SemVer ranges natively.
- **OQ4: Materialize trigger and cache keying.** Status: open. Explicit `Kernel.Materialize(*Platform) → *MaterializedPlatform` vs implicit-inside-Match. Cache key derives from `(path × filter × OCI tag set at fetch time)`; invalidation strategy when the registry advances (caller-driven, time-based, or an explicit "refresh" hook on a future `opm` CLI).
- **OQ5: Top-level vs nested catalog scan.** Status: open. The kernel discovers transformers by walking *top-level* values in the catalog package and unifying with `#ComponentTransformer`. Whether to also recurse into nested grouping structs (e.g. `Transformers: { … }`) is a discovery-rules question — default to top-level only unless catalog authors complain.
- **OQ6: Cross-catalog primitive references.** Status: open. A transformer in catalog A may reference a resource published by catalog B via its `requiredResources` map. With multiple catalogs subscribed, this works as long as both are pulled. Document as an explicit supported pattern or defer to a follow-up.
- **OQ7: Multi-fulfiller behaviour.** Status: open. Today's `#matchers.{resources,traits}[FQN]: [...#ComponentTransformer]` allows multiple transformers to require the same primitive FQN, disambiguated by predicate evaluation. The SemVer-FQN expansion reduces collision likelihood; confirm at implementation time whether the predicate-evaluation logic still applies unchanged or simplifies.

### Catalog identity + publish

- **OQ8: Per-primitive SemVer vs catalog-monolithic SemVer.** Status: open. The design sketches a 1:1 coupling (every primitive in catalog at `X.Y.Z` carries `metadata.version: "X.Y.Z"`), but independent per-primitive SemVer is the alternative — higher fidelity, more authoring burden, ambiguous publish flow.
- **OQ9: Catalog identity stamping — root constant vs subpackage constants vs author-hand-written.** Status: resolved-by-D7. Single root-package exported `Catalog` constant; subpackages read it via CUE cross-package imports.
- **OQ10: Cross-package access mechanism — exported `Catalog` struct vs `_`-prefixed identifiers.** Status: resolved-by-D7. Capital-C exported `Catalog`; subpackages import the root package and read `catalog.Catalog.Version` directly. Spike confirmed in experiment 04.
- **OQ11: Source-tree default for `Catalog.Version`.** Status: resolved-by-D8. Checked-in `"0.0.0-dev"` default. Dev-time `cue vet` works zero-friction; CI guard required to reject publishes of `0.0.0-dev` artifacts.
- **OQ12: Publish stamping strategy — temp build dir vs in-place + git revert.** Status: resolved-by-D9. Temp build dir + `version_override.cue` sibling file; CUE unification collapses override + default to the override value, no source-tree edits required.

### FQNs + matching

- **OQ13: SemVer-suffixed FQNs vs MAJOR-only + version predicate.** Status: resolved-by-D5. SemVer 2.0 FQN regex; `#MajorVersionType` retired from primitive metadata.
- **OQ14: Always-unify at match vs FQN-only vs `--strict` mode.** Status: resolved-by-D6. Always-unify before predicate evaluation; CUE's diagnostic (`conflicting values …: file:line file:line`) is surfaced verbatim.
- **OQ15: Missing FQN — one error per occurrence vs aggregate vs fail-fast.** Status: informed-by-exp-05. Experiment 05 sketched `MissingFQN: { release, component, fqn, alternatives: [...] }` accumulated per `(release, component, FQN)` triple — one diagnostic per miss, with `alternatives` computed by prefix-matching `composed` keys on the same `modulePath/name`. Formal resolution (and the `release` field elevation into the kernel-side Go diagnostic type) still pending a Decision; promote when the kernel slice lands.
- **OQ16: `#Blueprint` SemVer trail.** Status: open. Blueprints share the FQN-and-metadata shape with Resource / Trait / Transformer; do they adopt the same SemVer / stamping trail in lockstep? Default yes, no extra logic — but confirm there's no platform-side projection blueprints need that this design forgets.

### `#ctx`

- **OQ17: `#ctx.platform` and `#ctx.environment` extension points.** Status: answered. D1 collapsed `#ctx` to an inline struct with open top (`...`) — `schemas/target.cue` line ~202 has `...` directly under `#ctx`. A future capabilities enhancement adds `platform` / `environment` siblings purely additively, no closure to undo.
- **OQ18: Cluster-domain handling.** Status: resolved-by-D4. `clusterDomain` lives on `#ReleaseIdentity` with a `*"cluster.local"` default; `#ModuleRelease.metadata.clusterDomain` carries the override and sets `#ctx.release.clusterDomain` directly.
- **OQ19: `#Component.#names` injection mechanism.** Status: resolved-by-D2/D3. There is no injection — each `#Component.#names` computes itself from the component's own `metadata` plus the injected `#release` (D3); `#ctx.components` is a comprehension over those. Validated end-to-end in `schemas/example_instance.cue`.
- **OQ20: `metadata.resourceName` override propagation.** Status: resolved-by-D2. Cascade lives on `metadata.resourceName: *name | #NameType`; `#names.resourceName` reads it directly; DNS variants derive from `resourceName`. Override wins when set; absence falls back to `metadata.name`, which itself defaults to the `#components` map key. Validated in `schemas/example_instance.cue`.
- **OQ21: `#ContextBuilder` ordering vs `#config` unification.** Status: resolved-by-D1/D2. No builder; no ordering question. `#ctx.release` is set by `#ModuleRelease` upfront, `#ctx.components` is a comprehension over `#components` evaluated independently of `#config`. The trap surface disappears.
- **OQ22: Bundle-level context.** Status: deferred. Cross-module `#ctx` references (one module reading another module's `#ctx.components.<id>.dns.fqdn`) are out of scope for this umbrella. Tracking here so the deferral is explicit.
- **OQ23: Content hashes for immutable ConfigMaps / Secrets via `#ctx`.** Status: deferred. Out of scope; tracked here so it does not silently slip into the design.

### Operational

- **OQ24: Cutover sequence with the core split.** Status: open. The core repo split's Part B (library rewire from `opmodel.dev/core/v1alpha2@v1` to `opmodel.dev/core@v0`) is in flight. Does 0001 land *on top of* that cutover, or does 0001 carry the import change itself? Sequencing affects whether the library fixture migration is one PR or two.
- **OQ25: Catalog repackage migration path.** Status: open. Today's `catalog/opm/v1alpha1/` already exports primitives at top level (no `#defines` wrapper), but lacks the `Catalog: { Version, ModulePath }` constant. Is the cutover a hard switch (drop v1alpha1, publish `opmodel.dev/modules/opm@1.0.0` as the first SemVer-FQN catalog) or a graceful coexistence (publish both shapes for one release)?
