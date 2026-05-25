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

### D12: Schema lands on `opmodel.dev/core@v0`; no `@v1` cut until `core` is signalled stable

**Decision:** The schema changes in this umbrella publish as a new minor tag on `opmodel.dev/core@v0`. `core` is pre-1.0; per its own versioning rule every break — including FQN regex change, `#Module.#defines` removal, and the `#registry` reshape — rides a minor bump within `@v0`. No automatic `@v1` cut is triggered by cumulative breakage. `@v1` is a deliberate signal that the user issues only when `core` is deemed stable enough to commit to a backwards-compatible major lineage. The umbrella's `config.yaml.semver` is therefore `minor`, not `major`.

**Alternatives considered:**

- Cut `@v1` now as the natural home for the redesign ("breaking change deserves a major bump"). Rejected: applies post-1.0 SemVer semantics to a pre-1.0 module. Forces a backwards-compatibility promise the schema is not ready to make.
- Hedge the publish target as `@v0 or @v1 depending on cumulative break` (the prior wording in 04-graduation.md / 06-operational.md). Rejected: leaves the target unfrozen at the moment slices are being drafted; future iterations could quietly resolve the hedge toward `@v1` and lock the user into a stability commitment they did not authorise.
- Pin every break to a separate `@v0` *patch* under the pre-1.0 rule. Rejected: pre-1.0 SemVer allows patches to be non-breaking only; CUE module tooling and consumer mental models both treat the `@v0 → @v0+1minor` step as the canonical break boundary.

**Rationale:** Stability of `@v0 → @v1` is a user signal, not a side effect of accumulated breakage. Locking the target at `@v0` keeps the redesign work coherent with the user's deliberate "earn `@v1` before claiming it" stance. The pre-1.0 versioning rule (`06-operational.md ## Semver Impact`) already accommodates the breaks this umbrella introduces.

**Source:** User decision 2026-05-24.

---

### D13: `#Platform.#registry` is path-keyed; one subscription per catalog path

**Decision:** `#Platform.#registry: [Path=#ModulePathType]: #Subscription`. The map key is the catalog's CUE module path (e.g. `"opmodel.dev/catalogs/opm"`). `#Subscription` carries `enable` and an optional `filter`; the `path` field is removed from `#Subscription` (the key already encodes it). CUE map semantics enforce one subscription per path — accidental duplicates fail at `cue vet`. Multi-channel-per-path (RC alongside stable on the same platform) is intentionally not expressible at this stage; if demand surfaces, a future enhancement can add a path-plus-channel key shape additively without rewriting any existing platform fixture.

**Alternatives considered:**

- Id-keyed (`[Id=#NameType]: #Subscription { path!, ... }`). Rejected: the Id is duplicated authorial work in the common single-subscription-per-catalog case (the Id carries no information beyond the path), and diagnostics have to surface both Id and path to be actionable. The schema was drifting in this direction before the decision; D13 brings it back into alignment with the design text headline ("path-keyed registry").
- Path-plus-channel composite key (`[Key=#SubscriptionKey]: #SubscriptionBody`, where `#SubscriptionKey` is `path` or `path#channel`). Rejected for this enhancement: introduces a custom string parsing surface and CUE pattern-constraint contortions for a use case that has no concrete demand today. Reserved as a future additive extension if multi-channel becomes a real need.

**Rationale:** Single source of truth for "what catalog is on this platform"; impossible-to-duplicate by construction; minimal authoring surface; aligns the schema with the design-text headline. The deferred multi-channel use case can be reintroduced additively without breaking any platform fixture.

**Source:** User decision 2026-05-24.

---

### D14: `Materialize` is explicit and caller-driven; kernel holds no cache; library ships opt-in cache helpers

**Decision:** `Kernel.Materialize(*Platform) (*MaterializedPlatform, error)` is the canonical entrypoint and the only way a `*MaterializedPlatform` is produced. The kernel itself maintains no cache: there is no `map[platformKey]*MaterializedPlatform` inside `*Kernel`, no Match-time auto-materialize, no eviction policy baked into kernel surface. A sibling helper package (`library/opm/materialize/cache/`) ships optional primitives — a `MaterializeCache` interface, a reference LRU implementation, and a spec-content-hash key derivation utility — that consumers (`opm-operator/`, `cli/`, future `fn-runtime`) wire up themselves. The kernel does not depend on this helper package.

**Alternatives considered:**

- Implicit-inside-Match with a kernel-owned cache keyed by `*Platform` content hash. Rejected: the kernel becomes stateful in a way `library/CONSTITUTION.md` explicitly excludes ("no process model, no logging output, no shell"). The cache invalidation policy becomes a kernel decision, and every choice is wrong for some caller (controller wants generation-bump invalidation; CLI wants none; future fn-runtime wants something else).
- Optional kernel-level cache interface attached to `*Kernel` (`Kernel.Cache MaterializeCache`). Considered. Rejected for this enhancement: two ways to call Match (with or without cache) inflates the kernel surface for a feature no current consumer needs at that layer. The sibling helper package gives consumers the same primitives without coupling them to `*Kernel`.

**Rationale:** Kernel stays pure; consumers own cache lifecycle with policy that matches their runtime model. Operator caches keyed on `Platform` CR `metadata.generation` (natural invalidation moment); CLI opts out; `cuelang.org/go/mod`'s on-disk module cache amortises OCI pulls regardless. Shipping cache helpers in `library/opm/materialize/cache/` means consumers don't reinvent the cache — but they do get to pick when (and whether) to use it. Future consumers that need richer invalidation (registry-state-change webhook, time-based TTL) can add their own implementations of the `MaterializeCache` interface without touching the kernel.

**Cache key (when used):** the helper's default key derivation hashes the canonical CUE form of `*Platform.#registry` (subscriptions + filters). Adding an OCI tag-set snapshot to the key is a known follow-up if "new tag isn't being picked up" becomes a real consumer complaint.

**Invalidation (when used):** consumer-driven via explicit `Invalidate(key)` plus spec-content-hash mismatch on lookup. No TTL in the reference implementation; consumers that want time-based invalidation wrap the LRU.

**Source:** User decision 2026-05-24.

---

### D15: Catalog discovery is an explicit `#Transformers` manifest in a root `catalog.cue` file; no package walk

**Decision:** Every catalog ships a single root-package `catalog.cue` file declaring two values: `Catalog: #CatalogIdentity` (the identity stamp from D7) and `#Transformers: [#FQNType]: #ComponentTransformer` (the export manifest). The kernel's `Materialize` step reads only these two values from the loaded catalog package — it does **not** walk the package tree, does not recurse into subpackages, does not unify arbitrary values against `#ComponentTransformer`. Authors compose `#Transformers` from imports of internal subpackages (`transformers/`, `transformers/kubernetes/`, etc.) and assign each entry explicitly under its stamped FQN. Resources, traits, and blueprints are not enumerated in the manifest at this stage — they surface transitively through each transformer's required/optional maps and via standard CUE imports for authoring. The `#` prefix on `#Transformers` marks it as a CUE definition (closed by default, type-constrained at the manifest level: `[#FQNType]: #ComponentTransformer`), consistent with the rest of the schema and reflecting that transformer values stay as definitions / schemas rather than fully concrete instances.

**Alternatives considered:**

- Top-level package scan (kernel walks every top-level field, unifies against `#ComponentTransformer`, indexes matches). Rejected: implicit discovery surface, debugging "why isn't my transformer being picked up?" requires reasoning about CUE's structural typing rules, no way for the author to declare intent. The manifest is one extra file but it's the file that says "this is what we publish for kernel consumption."
- Recursive structural walk of the package tree. Rejected: same problems as top-level scan plus FQN-collision ambiguity (two nested groupings could each define the same transformer name and the kernel would have to dedupe silently or fail with an obscure error). Cost grows with structural depth.
- `#Exports: [...#ComponentTransformer]` list (Option C in the OQ5 discussion). Rejected in favour of the keyed map form: an FQN-keyed map gets duplicate-FQN detection at `cue vet` for free (map unification fails), and the constraint shape (`[#FQNType]: #ComponentTransformer`) is more discoverable than a generic list of values.
- Include `#Resources` / `#Traits` / `#Blueprints` siblings in the manifest now. Rejected for this enhancement: the kernel only consumes `#Transformers` for matching; resources/traits surface transitively. Adding the others up front pays an authoring tax for a future-introspection use case nobody has asked for yet. Additive extension if demand surfaces.

**Rationale:** Explicit author intent + deterministic kernel discovery + zero magic. The manifest co-locates the two answers the kernel needs (catalog identity + export list) in one file. Catalog file organisation (which transformer in which subpackage) is decoupled from kernel discovery — only what's listed in `#Transformers` is visible. Drift risks are bounded: adding a transformer file without a manifest entry fails silently (the transformer ships but isn't discoverable; mitigable via a publish-task lint that greps for un-referenced transformer files), and deleting a referenced file fails loudly at evaluation time (undefined CUE reference). Both are observable and addressable.

**Source:** User decision 2026-05-24.

---

### D16: Cross-catalog primitive references are a documented supported pattern; no kernel-level `#CatalogDependencies` manifest

**Decision:** A transformer published by catalog A may reference a resource / trait / blueprint owned by catalog B by FQN, via standard CUE imports at catalog-A author time. The pattern is officially supported: when a platform subscribes to both A and B, both materialize and the cross-reference resolves. When a required catalog is *not* subscribed, the failure surfaces as `MaterializeError` (catalog B missing entirely) or `MissingFQN` / `UnifyError` at match time (catalog B subscribed but the referenced SemVer is not in the materialized set). No new kernel surface, no `#CatalogDependencies` block on the catalog manifest, no `CrossCatalogMismatch` structured diagnostic kind at this stage.

**Alternatives considered:**

- Defer / mark "unspecified behaviour." Rejected: CUE's import system already resolves cross-catalog references today; declaring the behaviour unsupported when it works just leaves real third-party catalog authors (e.g. a hypothetical `examplecorp/transformers` building on top of OPM core resources) without a sanctioned path forward.
- Add a `#CatalogDependencies: [#ModulePathType]: #VersionType | #SubscriptionFilter` block to the catalog manifest, with kernel-side cross-checking and a `CrossCatalogMismatch` diagnostic. Rejected for this enhancement: no concrete consumer demands it today (`library/modules/opm/` is the only catalog in scope). Doubling the manifest surface for a future-proofing use case is premature. Reserved as an additive extension if the author-time-vs-platform-time pin drift risk (see 05-risks.md) materialises as a real complaint.

**Rationale:** Cross-catalog references work today via CUE's import system; documenting the supported pattern + its failure modes is the honest description of current behaviour and gives third-party catalog authors a sanctioned path forward without expanding kernel surface. The same diagnostic kinds (`MaterializeError`, `MissingFQN`, `UnifyError`) cover both same-catalog and cross-catalog miss cases — no parallel diagnostic taxonomy. The author-time vs platform-time pin drift risk is real but bounded; if it bites, `#CatalogDependencies` is a clean additive follow-up.

**Source:** User decision 2026-05-24. Validated by experiment `enhancements/0001/experiments/11-cross-catalog-import/` concluded 2026-05-25 — hypothesis held. Both-catalogs-present scenario: standard CUE imports resolve; catalog A's transformer materializes catalog B's resource into its `requiredResources` map keyed by B's concrete FQN (`test.example/b/resources/bar@1.0.0`). Catalog-B-physically-absent scenario: CUE evaluation fails with `cannot find package "..."` naming both the offending import line (`foo_transformer.cue:12:2`) and the file that triggered the resolution (`catalog.cue:9:2`) — exactly the failure shape the kernel wraps as `MaterializeError` per 06-operational.md. The experiment uses physical absence to simulate "catalog B not subscribed at platform level" (pure CUE cannot express the platform subscription set without the kernel); the CUE error shape matches what the kernel would surface.

---

### D17: Multi-fulfiller matcher behaviour is unchanged; SemVer-FQN expansion narrows buckets, not algorithm

**Decision:** `#Platform.#matchers.{resources,traits}[FQN]: [...#ComponentTransformer]` keeps its current list shape. The matcher's predicate-evaluation disambiguation (labels + additional required-resources / traits beyond the keyed one) is the unchanged tie-breaker when multiple transformers declare the same primitive FQN. SemVer-FQN expansion (D5) reduces the average bucket size by separating what used to collide on MAJOR-only keys, but the matching algorithm itself is identical. The cross-catalog overlap case D16 enables (catalog A and catalog B both publishing transformers consuming the same FQN) routes through the same predicate path with no special case.

**Alternatives considered:**

- Simplify to single-fulfiller-per-FQN (`[FQN]: #ComponentTransformer`, no list). Rejected: workload-type discrimination — `stateless → Deployment`, `stateful → StatefulSet`, `job → Job`, `cronjob → CronJob` — relies on multiple transformers consuming the same `container@<semver>` primitive and disambiguating via predicate (`workload-type` label). The pattern is idiomatic in OPM; removing it would force every catalog to split shared primitives into per-workload-type FQNs (e.g. `stateless-container@...`, `stateful-container@...`), fragmenting the primitive namespace for a structural simplification that buys nothing.
- Simplify only the cross-catalog case (same-catalog list stays; cross-catalog same-FQN entries error at materialize time, requiring an explicit platform-side tie-breaker). Rejected as premature: no cross-catalog overlap exists today, and designing the tie-breaker shape against a hypothetical scenario risks getting it wrong. If cross-catalog overlap becomes a real authoring problem once a second catalog exists, a future enhancement can layer a tie-breaker on top — additive, no breakage.

**Rationale:** Zero matcher implementation change. Existing tests and fixtures pass unchanged. The cost of multi-fulfiller support is already paid in `library/opm/compile/match.go`; SemVer-FQN expansion doesn't change that cost. Confirming "unchanged" as an explicit Decision (rather than letting the implementation slice relitigate it at code-review time) is the load-bearing part of D17.

**Source:** User decision 2026-05-24.

---

### D18: Catalog-monolithic SemVer; every primitive's `metadata.version` is `Catalog.Version`

**Decision:** Every primitive in a catalog at version `X.Y.Z` carries `metadata.version: "X.Y.Z"` — sourced from the single `Catalog.Version` constant (D7) and stamped at publish time (D9). One bump per catalog publish; every primitive's FQN moves in lockstep. Per-primitive SemVer is **not** introduced now and is not on the roadmap. The catalog is the unit of versioning; primitives inherit.

**Alternatives considered:**

- Per-primitive SemVer — each primitive carries its own author-maintained `metadata.version` independent of the catalog publish version. Rejected: reintroduces the per-primitive authorial burden D7/D8/D9 explicitly eliminated; authors would have to remember to bump per-file on schema changes, with silent drift on misses; the publish flow would either need per-primitive delta detection against the previous OCI artefact (hard) or per-file literals validated by `cue vet` (high authoring tax). With one catalog in scope (`library/modules/opm/`) and pre-1.0 status, every primitive is changing frequently — per-primitive versioning would still bump nearly everything per publish.
- Catalog-monolithic now, per-primitive as an additive follow-up. Considered. Not chosen: keeping the door open invites a future inconsistency where some primitives have author-maintained versions and others inherit from `Catalog.Version`, making the catalog harder to reason about. Closing the question is preferable to indefinitely deferring it. If primitive-level versioning becomes a real authoring need years down the line, that's a separate enhancement to argue from concrete evidence — not a hedge in this umbrella.

**Rationale:** The catalog is the unit of versioning; the primitive is the unit of evolution within it. One `Catalog.Version` constant, one publish-task overwrite, every FQN in lockstep — matches how most CUE module ecosystems work today (module versioned; contents ship at the module's version). The consumer-pin-churn cost (bumping the catalog bumps every primitive's FQN; consumers pinned to `container@1.4.0` see the same primitive at `1.4.1`, `1.5.0`, etc. on subsequent publishes) is mitigated by D6's always-unify (byte-identical bodies across SemVers unify; D6 doesn't error) and by the `#SubscriptionFilter.range` covering multiple SemVers at materialize time (the platform keeps `1.4.0`, `1.4.1`, `1.5.0` all pulled, so the consumer's pin keeps matching until the range moves past it). Consumers re-pin on their own cadence; nothing breaks.

**Source:** User decision 2026-05-24.

---

### D19: `#Catalog` is a top-level definition with schema-enforced subpath stamping; supersedes D7 + D15; amends D9

**Decision:** Introduce `#Catalog` in `core/`. Each catalog's CUE package root embeds `c.#Catalog` (modules-pattern style: bare type at file root, fields written at package level — no `Catalog:` wrapper, matching how `m.#Module` is embedded in `modules/jellyfin/module.cue` today). Catalog identity (`metadata.{modulePath, version, fqn, description, labels, annotations}`) and the `#transformers` manifest live in one typed value. A pattern constraint on `#transformers` stamps every entry's `metadata.modulePath` to `"\(M.modulePath)/transformers"` and `metadata.version` to the catalog's `metadata.version`, replacing D15's author-discipline guarantee with structural enforcement of D18's lockstep promise. The constraint does **not** stamp `metadata.fqn` — `fqn` derives in `#PrimitiveMetadata` from `modulePath/name/version`, and the map key `(t.#X.metadata.fqn): t.#X` already uses the transformer's own fqn, so a second stamping source would add redundant conflict potential with no extra safety. Catalog FQN shape is `<modulePath>@<version>` (no `name` segment) — a new `#CatalogFQNType` regex covers it without disturbing the primitive `#FQNType`. Shared identity lives in a sibling `identity/` subpackage (e.g. `opmodel.dev/catalogs/opm/identity` for the OPM core catalog) so transformer subpackages can source `modulePath` + `version` without circular import. Publish-time stamping (D9) targets `identity/version_override.cue` instead of the catalog-root file — same mechanism (rsync to temp build dir, write override file, `cue vet`, `cue mod publish`), one-line path edit. `#TransformerMap` survives as the underlying value-type shape used inside `#Catalog.#transformers`.

**Alternatives considered:**

- Keep D7 + D15 as locked: two loose top-level declarations (`Catalog: #CatalogIdentity` + `#Transformers: #TransformerMap`) plus author-maintained transformer metadata. Rejected: D18's lockstep promise relies on author discipline; the only catch was a publish-task lint that does not exist. `#Catalog` makes D18 structural — typos in transformer metadata fail `cue vet` instead of shipping wrong FQNs.
- `#Catalog` with author-written subpath suffix (no schema stamping of `/transformers`). Rejected: same drift surface as D15 — author can typo the suffix silently and the FQN ships wrong without `cue vet` noticing. Schema-stamping the subpath convention forces the OPM-canonical layout into the schema.
- Per-subpackage identity constant (transformer files reference `id.TransformersPath`, no schema-level subpath enforcement). Considered. Reduced footgun vs. raw author discipline but still allows the typo to land at the identity declaration. Rejected in favour of schema enforcement.
- Pattern constraint that also stamps `fqn: FQN` from the map key. Rejected: `fqn` is already derived in `#PrimitiveMetadata` from `modulePath/name/version`; the map key uses the transformer's own fqn by construction; stamping a second source adds redundant conflict potential with no extra safety.
- Catalog identity embedded directly in the catalog root file (no sibling `identity/` subpackage). Rejected: would force subpackage transformers to either hardcode their own modulePath+version (defeating D18 lockstep) or import the catalog root package, which creates a circular import (`catalog → transformers → catalog`). The sibling identity package is a leaf module both can depend on without cycle.
- Keep `name` as a segment in the catalog FQN (e.g. `opmodel.dev/catalogs/opm/opm@1.0.0`). Rejected: the catalog is addressed by its CUE module path; appending a redundant name segment duplicates the trailing path component and adds no information. `<modulePath>@<version>` is the natural shape for a value addressed by module path.

**Rationale:** D18 promised every primitive's `metadata.version` equals the catalog's version in lockstep; D15 left enforcement to author discipline (mitigable only via a publish-task lint that doesn't exist). `#Catalog`'s pattern constraint makes the promise structural — typos in transformer metadata fail `cue vet` instead of shipping wrong FQNs. Schema-enforced subpath stamping (`<catalog-root>/transformers`) lifts the file-layout convention from folklore into the schema, eliminating a class of typos the loose-manifest form couldn't catch. The map-key idiom `(t.#X.metadata.fqn): t.#X` (already used in `library/modules/opm/transformers/configmap_transformer.cue` for `requiredResources`) keeps working because the identity subpackage makes each transformer's `metadata.fqn` concrete from the subpackage's own scope — no circular import, no value-stamping from the catalog manifest. Catalog FQN drops the `name` segment because catalogs are addressed by their CUE module path; a separate `#CatalogFQNType` regex captures the `<modulePath>@<version>` shape. A hidden mirror field `_md: metadata` on `#Catalog` lets the `#transformers` pattern constraint reach the outer metadata without shadowing — alias labels (`metadata: M={...}`) don't carry across the nested struct boundary inside the constraint, but a hidden top-level field reference does (confirmed via `cue vet` on the schema).

**Source:** User decision 2026-05-25. Catalog FQN shape (sub-decision 3) validated by experiment `enhancements/0001/experiments/08-catalog-fqn-regex/` concluded 2026-05-25 — hypothesis held; 8/8 positive accept, 9/9 negative reject; regex accepts `<modulePath>@<SemVer 2.0>` and rejects MAJOR-only, partial, four-part, missing-path, missing-version, uppercase, trailing-dash, and v-prefix shapes. `_md: metadata` mirror rationale validated by experiment `enhancements/0001/experiments/09-catalog-mirror-pattern/` concluded 2026-05-25 — hypothesis held with three refinements. (1) **Two sound forms, not one:** the `_md: metadata` hidden-mirror AND `M=metadata: {...}` field-label-alias both work; D19's choice of the mirror is stylistic, not structural. (2) **Mechanism is closest-parent-field-walk, not "shadowing":** inside the inner `metadata: { ... }` block, a bare `metadata.X` reference walks up to the closest parent field named `metadata` — which is the inner field being constructed — and self-embeds into a non-concrete interpolation; calling this "shadowing" is imprecise. The value-alias form `metadata: M={...}` fails at vet with "reference M not found" because value aliases don't carry across the nested struct boundary. (3) **The silent-pass production trap is real:** with `#transformers` hidden and no public reader (the real `core/catalog.cue` shape), plain `cue vet` AND `cue vet -c` BOTH pass silently on a bare-direct broken pattern; bug visible only via `cue eval --all` or at kernel-time materialize. Operational implication: CI for `core/catalog.cue` cannot rely on `cue vet` alone to catch a bad `#transformers` pattern constraint; a dedicated probe (kernel-time materialize test in `library/`, or a concrete-catalog fixture that asserts on `cue eval --all` output) is required. Schema-enforced transformer stamping validated by experiment `enhancements/0001/experiments/10-catalog-stamping-asymmetry/` concluded 2026-05-25 — hypothesis held; transformer typo-subpath and wrong-version variants fail at plain `cue vet` with "conflicting values" + file:line citations (drift caught loudly with structural diagnostic).

---

### D20: `MissingFQN` is one structured diagnostic per `(release, component, FQN)` triple; Match accumulates in one pass

**Decision:** When a consumer Module declares a primitive FQN absent from the materialized `#composedTransformers`, `Match` emits exactly one `MissingFQN` diagnostic per `(release, component, FQN)` triple — not aggregated across misses, not fail-fast. `Match` accumulates every miss in one pass and returns them on the `MatchPlan`; the release fails at match time with the full set surfaced together. The diagnostic shape is `{release, component, fqn, alternatives}`, validated in pure CUE by experiment 05 and already specified in `06-operational.md`:

- `release`: the offending `ModuleRelease` name. First-class field on the Go diagnostic type, not derived from caller context — keeps the diagnostic self-contained when surfaced through `errors.As`.
- `component`: the component id within the module that declared the missing FQN.
- `fqn`: the missing FQN, verbatim from the consumer declaration.
- `alternatives`: every key in `#composedTransformers` whose `modulePath/name` prefix matches the missing FQN — every other SemVer of the same primitive that IS on the materialized platform. Computed as `strings.HasPrefix(composedKey, modulePath+"/"+name+"@")`.

**Alternatives considered:**

- **Aggregate** — one diagnostic per release listing all misses (or one per component). Rejected: operator has to parse a nested list to find the offending reference; structured-error consumers (`errors.As`, controller status conditions) can't address a single miss without parsing the aggregate. Per-triple keeps each miss independently addressable.
- **Fail-fast** — stop on the first miss. Rejected: forces N round-trips when M misses exist; the worst possible operator UX for a class of error that is straightforward to enumerate exhaustively. Match's cost is dominated by materialize, not by accumulating diagnostics; collecting every miss is free.
- **Drop `release` from the diagnostic struct** (derive from caller context). Rejected: the experiment's CUE shape carries `release` first-class, and the Go diagnostic must round-trip the same fact so a single `MissingFQN` surfaced through a logger or status condition is self-explanatory without the caller having to attach the release identity downstream.
- **Compute `alternatives` from a wider set** (e.g. fuzzy-match on name, or include `modulePath` prefix matches across primitive kinds). Rejected: prefix-match on `modulePath/name` returns exactly "other SemVers of the same primitive on this platform" — the actionable set. A wider set adds noise (a misspelled name surfaces unrelated primitives) and slows the diagnostic build. The narrow set is what experiment 05 validated.

**Rationale:** Per-triple accumulation is the load-bearing operator-UX guarantee: fix all misses in one round-trip rather than N. Experiment 05 validated the exact shape in pure CUE — App C's out-of-range `container@2.0.0` produced exactly one `MissingFQN` with all three in-range versions listed as alternatives. `06-operational.md` already documents the shape; `02-design.md` already commits to per-triple + one-pass twice. This D block exists to give the kernel slice an authority to cite (instead of scattered design-text + experiment outcome) and to pin two implementation details: `release` is a first-class struct field on the Go side, and `alternatives` uses prefix-match on `modulePath/name` rather than a wider candidate set.

**Source:** Experiment `enhancements/0001/experiments/05-multi-version-match/` concluded 2026-05-23 — hypothesis held, shape validated in pure CUE. Locked as decision by user 2026-05-25.

---

### D21: `#Blueprint` follows the same SemVer / stamping trail as `#Resource` / `#Trait` / `#ComponentTransformer`; no platform-side projection

**Decision:** `#Blueprint` adopts the same metadata shape, FQN regex, and publish-time stamping flow as the other primitives in lockstep. `metadata: #PrimitiveMetadata` (already the case in `schemas/target.cue`) — same `modulePath` / `version` / `name` / `fqn` cascade, same SemVer 2.0 regex via `#FQNType` (D5), same `id.ModulePath` + `id.Version` sourcing from the catalog's identity subpackage (D19), same `Catalog.Version` lockstep at publish time (D18 + D9 as amended by D19). Blueprint files in catalog subpackages live under `<catalog-root>/blueprints/` and source their metadata from the identity package identically to how transformer files source theirs from `<catalog-root>/transformers/`. No platform-side projection — blueprints are consumer-side composition primitives (a blueprint composes resources + traits at module-author time), not kernel-matched values, so they do not surface in `#Platform.#matchers` or in the catalog's `#transformers` manifest, and no platform-time field on `#Blueprint` is required by this umbrella.

**Alternatives considered:**

- **Per-blueprint SemVer independent of `Catalog.Version`.** Rejected: same reasoning as D18 for the other primitives — reintroduces per-file authorial burden, drift surface, and inconsistency with the rest of the catalog. The catalog is the unit of versioning; blueprints inherit.
- **Add `#blueprints: [#FQNType]: #Blueprint` sibling map to `#Catalog` for schema-enforced stamping (parallel to `#transformers`).** Rejected at this stage per D19: resources / traits / blueprints are surfaced transitively via transformer required/optional maps + standard CUE imports; the catalog's `#transformers` manifest is the kernel's sole discovery surface. Adding sibling maps is an additive extension if introspection demand surfaces. The asymmetry is deliberate — schema enforcement for transformers (the kernel-consumed shape) and convention-plus-author-discipline for the other primitives. Blueprints accept the same author-discipline tradeoff resources and traits already have.
- **Platform-side blueprint projection** (e.g. `#Platform.#blueprintsByFQN` exposed to module bodies). Rejected: blueprints compose other primitives at module-author time via standard CUE imports; module bodies do not read a kernel-projected blueprint registry. No platform-side surface is required.

**Rationale:** Uniform versioning trail across primitive kinds preserves the catalog-monolithic mental model: one `Catalog.Version` stamp moves every primitive's FQN — resource, trait, blueprint, transformer — in lockstep. The schema cost is zero (the existing `#Blueprint` definition already uses `#PrimitiveMetadata`). The "no platform projection needed" half of OQ16 is the load-bearing confirmation — blueprints differ semantically from the other primitives (composition vs. resource declaration vs. kernel matching), but this design forgets nothing platform-side for them.

**Source:** User decision 2026-05-25. Deliberate asymmetry — blueprint metadata (like resource and trait metadata) is NOT schema-stamped the way transformer metadata is by `#Catalog.#transformers` — validated by experiment `enhancements/0001/experiments/10-catalog-stamping-asymmetry/` concluded 2026-05-25 — hypothesis held; the `blueprint_typo_subpath/` variant vets clean despite a typo in `metadata.modulePath` subpath, identically to `resource_typo_subpath/` and `trait_typo_subpath/`. Residual surface acknowledged; mitigations (publish-task lint, future `#blueprints` sibling map on `#Catalog`, concrete-catalog CI fixture) are additive follow-ups outside 0001's scope.

---

### D22: 0001 lands on top of the core split's Part B; library + modules slices gated on `remove-api-binding-dispatch` shipping first

**Decision:** Enhancement 0001 sequences after the library's in-flight `remove-api-binding-dispatch` OpenSpec change (the "core split Part B" — re-syncs `library/apis/core/` from the standalone `core/` repo, drops the `apiVersion` field, deletes `opm/api` + `opm/apiversion` packages, rewires library imports from `opmodel.dev/core/v1alpha2@v1` to `opmodel.dev/core@v0`). The schema rewire is treated as a prerequisite that ships independently; 0001 does **not** carry the import-path change inside its own library slice. Parallelism is allowed where the dependency does not bite:

- **0001's `core/` slice** (schema edits — `#Catalog`, `#ctx` collapse, `#FQNType` SemVer regex, `#Subscription` reshape, etc.) lands directly in the standalone `core/` repo against `opmodel.dev/core@v0`. No dependency on Part B; can proceed in parallel.
- **0001's `library/` slice** (kernel changes for `Materialize`, the rewritten `Match`, `#ctx` wiring, removal of `#knownResources` / `#knownTraits`) waits for Part B to ship before merging. The library otherwise would carry two reasons in one PR (dead-code deletion vs. design implementation), defeating reviewability.
- **0001's `modules/` slice** (catalog repackage — `library/modules/opm/` migrating to the `#Catalog` shape, identity subpackage, transformer files sourcing from `id.ModulePath` / `id.Version`) also waits for Part B because the catalog has to import `opmodel.dev/core@v0` and its schema. Sequencing is identical to the library slice.

**Alternatives considered:**

- **0001 carries the import change itself (fold Part B into 0001's library slice).** Rejected: the two changes serve different reasons. Part B is "delete the binding-dispatch tax we no longer need now that the schema moved out-of-tree." 0001's library slice is "implement the redesigned matcher / materialize / ctx wiring." Folding them produces one PR that's twice the size and mixes mechanical deletion with intentional design implementation — the reviewer loses track of which deletion is rote and which is load-bearing. Wall-clock cost of waiting is one PR cycle for Part B; the reviewability win is permanent.
- **Block all of 0001 (including the core/ slice) until Part B ships.** Rejected: the core/ slice has zero coupling to Part B — those edits land in the standalone `core/` repo against `opmodel.dev/core@v0`, where the repo is already accepting changes today. Blocking core/ work would waste the parallelizable window.
- **Ship Part B and 0001 in a single coordinated multi-repo release.** Rejected: Part B has independent value (clears ~1k LoC of dead binding-dispatch structure) and should be release-able on its own merits. Coupling its release cadence to 0001's implementation timeline delays a clean win for no benefit.

**Rationale:** Separation of concerns survives intact. Part B = mechanical cleanup enabled by the schema move; 0001 library slice = new behaviour. Reviewing each independently is cheaper than reviewing the union. Parallelism on the core/ slice keeps total wall-clock cost minimal — only the library and modules slices pay the sequencing dependency, and they were the slow path anyway (they depend on materialize + the matcher rewrite, which takes longer than Part B's rote deletion). The 0001 enhancement's `affects:` list already names `core`, `library`, and `modules` — D22 just pins which order they ship in.

**Source:** User decision 2026-05-25.

---

### D23: Catalog repackage is a hard switch; first new-shape tag is `opmodel.dev/catalogs/opm@0.1.0`; no graceful coexistence with the legacy `@v1` shape

**Decision:** `library/modules/opm/` republishes once with the post-D19 shape: `c.#Catalog` embedded at the package root, sibling `identity/` subpackage (`opmodel.dev/catalogs/opm/identity`) holding `ModulePath` + `Version`, every primitive (`#Resource` / `#Trait` / `#Blueprint` / `#ComponentTransformer`) sourcing `metadata.modulePath` and `metadata.version` from `id`, and the publish task's `version_override.cue` writing into `identity/`. The first new-shape tag is `opmodel.dev/catalogs/opm@0.1.0` — bare SemVer per D5, no `@v` prefix, pre-1.0 in lockstep with `core@v0`'s pre-1.0 discipline (D12: stable-tag commitment is a separate user signal, not a side effect of accumulated breakage). The legacy `opmodel.dev/catalogs/opm@v1` tag (currently `v1.0.6`) is not republished; it remains in the registry for retrieval but is frozen. In-repo consumers (`library/modules/opm_platform/`, `library/testdata/`) get rewritten in the same coordinated PR set that publishes `0.1.0`. Workspace `modules/*` modules (jellyfin, garage, …) — currently importing the legacy `opmodel.dev/opm/v1alpha1/schemas@v1` path — get rewired as a follow-on wave once the new tag exists in the registry; they do not block the catalog publish. The whole sequence gates on D22 (Part B ships first; library imports `opmodel.dev/core@v0`; catalog can then import the new core schema).

**Alternatives considered:**

- **Graceful coexistence (publish both `@v1.x` and `@0.1.0` for one release window).** Rejected: no external consumers exist that the graceful path would serve — workspace `modules/*` live in the same workspace as the catalog and get rewritten in lockstep; `library/MIGRATIONS.md` already notes "no external consumers yet, no deprecation shim." Dual-shape source tree would force every catalog change into two places (or a generator), and the pre-1.0 status of every primitive makes the "old API frozen, new API evolving" framing wrong — both shapes would be moving targets. 02-design.md Non-Goals already commit to this: "Backwards-compatibility for legacy v1alpha2 fixtures … Migration of third-party catalog modules. Only the OPM core catalog … is in scope."
- **First new-shape tag at `1.0.0`.** Rejected at this stage: would signal stable-shape commitment before `core@v0` itself is signalled stable. D12's principle ("stability is a deliberate user signal, not a side effect of cumulative breakage") applies to the catalog as well — the catalog inherits core's pre-1.0 discipline and earns `1.0.0` later when the user issues that signal. Tagging `0.1.0` keeps the catalog free to break additively within the `@0.x.x` range without a stability promise it cannot yet make.
- **Per-primitive first-tag (some primitives at `0.1.0`, others at higher versions reflecting their authoring maturity).** Rejected by D18 — catalog-monolithic SemVer; every primitive's `metadata.version` is `Catalog.Version` in lockstep. Per-primitive first-tag would reintroduce the variance D18 explicitly rejected.
- **Keep the `@v` prefix (`@v0.1.0`).** Rejected: D5's `#FQNType` regex accepts bare SemVer 2.0; the `@v` prefix is the legacy MAJOR-only convention being retired. The CUE module path itself drops the prefix consistent with how `opmodel.dev/core@v0` was tagged on its first stable shape.

**Rationale:** Three forces converge on hard-switch + `0.1.0`. (1) No external consumers means graceful coexistence buys nothing real. (2) The Non-Goals already exclude legacy-fixture compatibility — coexistence would contradict the design's own scope. (3) `0.1.0` keeps the catalog's stability commitment in lockstep with `core@v0` per D12, with `1.0.0` reserved as a future user signal. The migration cost concentrates into one coordinated PR set (catalog repackage + in-repo consumer rewires) instead of being smeared across a multi-release deprecation window. Workspace-module rewires (jellyfin et al.) trail as a follow-on wave with no blocking dependency on the catalog publish itself — they consume the new tag once it exists.

**Source:** User decision 2026-05-25.

---

### D24: Library kernel pulls core schema from OCI registry; `//go:embed` of `apis/core/` deleted; binding-dispatch logic deleted

**Decision:** The library kernel carries **no** embedded copy of the OPM core schema. `library/apis/core/` is deleted entirely (`embed.go`, the embedded CUE files, and the `embed.FS` it produces). The kernel pulls `opmodel.dev/core@v0` (or a pinned version) from a CUE OCI registry via `cuelang.org/go/mod` — the same substrate `Kernel.Materialize` already uses for catalogs (D14). `Kernel.Registry` (introduced for catalogs by 0001) becomes the single discovery surface for **both** the core schema and the catalogs subscribed by a `Platform`. The `opm/api` and `opm/apiversion` packages are deleted — Part B's existing scope per `library/openspec/changes/remove-api-binding-dispatch/`, reaffirmed here so the principle is captured in 0001's authoritative decision log. D22 stands: 0001's library slice still sequences after Part B; D24 extends that slice's scope to include the embed deletion + registry-pull wiring as a post-Part-B layer (Part B itself remains scoped to binding-dispatch deletion + the legacy embed re-sync that this decision then supersedes).

**Operational stance (defaults; not new OQs):**

- **Pull timing.** Lazy at first use (first `Validate` / `Match` / `Compile` call on a `Kernel`), not eager at `Kernel` construction. Cold-start cost paid once; `cuelang.org/go/mod`'s on-disk cache amortises subsequent calls. Eager-at-construction was considered and rejected for the standard reason — `Kernel` construction should not perform network I/O before the caller has decided what they want done.
- **Version pinning.** `Kernel.CoreVersion string` field, default `"v0"` per D12 (pre-1.0 lockstep with the standalone `core/` repo). Consumers that need to pin a specific minor (`"v0.3.0"`) or a future major (`"v1"`) set it explicitly. The field is a kernel-construction-time choice, not per-call; mixing core versions in one process is out of scope at this stage.
- **Offline / air-gapped.** Not supported at this stage. Sealed environments use `cuelang.org/go/mod`'s pre-pull mechanism or a registry mirror — same answer as the catalog story. An air-gapped-friendly fallback (e.g. an opt-in embedded snapshot at a pinned version) is a known follow-up if the operator community asks for it; it does not gate 0001.
- **Pull diagnostics.** A core-schema pull failure surfaces as a structured diagnostic carrying the registry consulted, the requested core version, and the underlying `cuelang.org/go/mod` error. Folded into the existing `MaterializeError` shape with a `kind: "core-schema"` discriminator rather than introducing a new diagnostic type at this stage — keeps the operator's mental model on "one OCI failure mode, two source axes."

**Alternatives considered:**

- **Keep the `//go:embed` of `apis/core/` (current behaviour, re-synced from the standalone `core/` repo per Part B).** Rejected: violates the principle that the kernel never ships a snapshot of a schema it does not own; means every core schema bump requires a library re-publish even when no library Go code changed; means consumers cannot pin a different core version than the one the library was built against; perpetuates a manual re-sync workflow that has no value once OCI pull works. The single argument for keeping it — offline operation out of the box — is the air-gapped concern handled by `cuelang.org/go/mod`'s pre-pull mechanism, not by burying a schema snapshot in the binary.
- **Eager pull at `Kernel` construction.** Rejected: `Kernel` construction is the wrong place for network I/O. Callers that want fail-fast registry validation can invoke a no-op `Validate` immediately after construction; callers that want lazy startup (CLI, test harnesses with offline fixtures) keep that option.
- **Custom Go OCI client for core-schema pulls (distinct from `cuelang.org/go/mod`).** Rejected for the same reason 02-design.md Non-Goals reject it for catalogs: duplicates work CUE's module proxy already does; the kernel needs nothing today that the standard substrate doesn't provide; signing / policy belong to a separate enhancement.
- **Opt-in embed fallback (build tag selects between embedded snapshot and registry pull).** Considered. Rejected at this stage: introduces two code paths the kernel has to maintain coherently; the snapshot drifts from the live schema between builds; "which mode is this binary?" becomes a support question. If air-gapped support becomes a real consumer demand, that's a separate enhancement with its own design surface.
- **`Kernel.CoreVersion` derived implicitly from the latest tag at pull time.** Rejected: removes reproducibility — two kernels constructed at different times against the same registry could load different schemas. Explicit pinning keeps the "given identical inputs, get identical outputs" property core to `library/CONSTITUTION.md`'s Principle I.

**Rationale:** The kernel is consumed by `cli/`, `opm-operator/`, future Crossplane fn, and any third party. Every one of them benefits from "the kernel reads the schema the user pointed at, not the schema this library was built with." The substrate is already there — D14 puts `Kernel.Registry` + `cuelang.org/go/mod` into the kernel for catalogs; reusing both for the core schema is additive, not architectural. `library/CONSTITUTION.md` Principle I (kernel neutrality, no I/O at edges except via caller-supplied config) survives intact: the registry URL arrives via `Kernel.Registry`, the version via `Kernel.CoreVersion`, and the pull is async I/O at a kernel edge — the same shape as `Materialize`. Part B's "re-sync the embedded copy" step becomes obsolete the moment D24's library slice merges — the standalone `core/` repo becomes the only home for the schema; the library never carries a snapshot. The cost concentrates in three operational deltas — cold-start I/O, no-offline default, an explicit `CoreVersion` field — all of which trade transparently against the brittleness of an embedded snapshot.

**Source:** User decision 2026-05-25.

---

## Open Questions

Seed agenda — every entry becomes a decision, a deferral, or an explicit `answered` outcome before the enhancement leaves `draft`. The validator (future) requires this block to be present from `accepted` onwards; entries should carry a `Status:` line once the enhancement reaches `implemented`.

### Registry + materialize

- **OQ1: Path-keyed `#registry` vs FQN-keyed `#registry` vs keeping the Module-valued shape.** Status: resolved-by-D13. Path-keyed (`[Path=#ModulePathType]: #Subscription`); one subscription per catalog path enforced by CUE map semantics; multi-channel-per-path deferred as a future additive extension.
- **OQ2: Filter shape — `range` only, `range + allow + deny`, or allowlist-only?** Status: resolved-by-D10. `range + allow + deny` with resolution order `range → allow append → deny subtract`. Operational escape hatches confirmed.
- **OQ3: Filter parser library.** Status: resolved-by-D11. `github.com/Masterminds/semver/v3` v3.3.0, Go-side, inside `Kernel.Materialize`. CUE cannot evaluate SemVer ranges natively.
- **OQ4: Materialize trigger and cache keying.** Status: resolved-by-D14. Explicit `Kernel.Materialize(*Platform)` is the only entrypoint; kernel holds no cache; sibling `library/opm/materialize/cache/` helper package ships an opt-in `MaterializeCache` interface, reference LRU, and spec-content-hash key derivation that operator / CLI consumers wire up. OCI tag-set snapshot in the cache key is a tracked follow-up (revisit if "new tag isn't being picked up" becomes a real consumer complaint).
- **OQ5: Top-level vs nested catalog scan.** Status: resolved-by-D15. Neither — the kernel reads an explicit `#Transformers` manifest from a root `catalog.cue` file in each catalog package. No scan, no recursion. Resources/traits/blueprints surface transitively via transformer required/optional maps.
- **OQ6: Cross-catalog primitive references.** Status: resolved-by-D16. Documented supported pattern; no kernel-level `#CatalogDependencies` manifest in this enhancement. Cross-catalog misses surface through the existing `MaterializeError` / `MissingFQN` / `UnifyError` diagnostic kinds.
- **OQ7: Multi-fulfiller behaviour.** Status: resolved-by-D17. Unchanged. `#matchers.{resources,traits}[FQN]: [...#ComponentTransformer]` keeps its list shape; predicate-evaluation disambiguation stays. SemVer-FQN expansion narrows bucket size but doesn't change the algorithm. Cross-catalog overlap (post-D16) routes through the same predicate path with no special case.

### Catalog identity + publish

- **OQ8: Per-primitive SemVer vs catalog-monolithic SemVer.** Status: resolved-by-D18. Catalog-monolithic. Every primitive carries `metadata.version: Catalog.Version`; one stamp per publish, every FQN in lockstep. Per-primitive SemVer rejected outright (not deferred) — the catalog is the unit of versioning. Consumer-pin-churn mitigated by D6's always-unify (byte-identical bodies unify across SemVers) and by `#SubscriptionFilter.range` covering multiple SemVers at materialize time.
- **OQ9: Catalog identity stamping — root constant vs subpackage constants vs author-hand-written.** Status: resolved-by-D7. Single root-package exported `Catalog` constant; subpackages read it via CUE cross-package imports.
- **OQ10: Cross-package access mechanism — exported `Catalog` struct vs `_`-prefixed identifiers.** Status: resolved-by-D7. Capital-C exported `Catalog`; subpackages import the root package and read `catalog.Catalog.Version` directly. Spike confirmed in experiment 04.
- **OQ11: Source-tree default for `Catalog.Version`.** Status: resolved-by-D8. Checked-in `"0.0.0-dev"` default. Dev-time `cue vet` works zero-friction; CI guard required to reject publishes of `0.0.0-dev` artifacts.
- **OQ12: Publish stamping strategy — temp build dir vs in-place + git revert.** Status: resolved-by-D9. Temp build dir + `version_override.cue` sibling file; CUE unification collapses override + default to the override value, no source-tree edits required.
- **OQ26: `#Catalog` as a top-level definition collapsing `#CatalogIdentity` (D7) + `#Transformers` manifest (D15) into one typed value.** Status: resolved-by-D19. Accepted as proposed below, with schema-enforced subpath stamping (`<catalog-root>/transformers`), `name` dropped from catalog FQN (new `#CatalogFQNType` covers `<modulePath>@<version>`), identity moved to a sibling `identity/` subpackage to keep transformer-subpackage FQNs concrete without circular import, and D9 stamping target adjusted to `identity/version_override.cue`. The pattern constraint does not stamp `metadata.fqn` — fqn derives in `#PrimitiveMetadata` and the map-key idiom already uses the transformer's own fqn. **Proposal:** introduce a `#Catalog` definition (`kind: "Catalog"`, typed `metadata`, hidden FQN-keyed `#transformers` with a pattern constraint that stamps every transformer's `metadata.{modulePath,version,fqn}` from the catalog's own identity). Each catalog package declares one root value `Catalog: core.#Catalog & { ... }` in its `catalog.cue` file, replacing the two loose top-level declarations (`Catalog: #CatalogIdentity` + `#Transformers: [#FQNType]: #ComponentTransformer`) that D7/D15 lock in today.

  **Primary win:** schema-enforced transformer metadata stamping. Today D15's manifest pattern relies on author discipline to keep every transformer's `metadata.{modulePath,version}` consistent with `Catalog.{ModulePath,Version}`; with `#Catalog`, the pattern constraint on `#transformers` makes the schema enforce it — authors cannot forget, drift is impossible by construction.

  **Secondary wins:**
  - One kernel discovery surface instead of two (load `Catalog`, read `Catalog.metadata` + walk `Catalog.#transformers`).
  - `kind: "Catalog"` makes catalog packages self-describing from CUE alone, not just from `cue.mod/module.cue`.
  - Future fields (deprecation notices, capability hints, signature blocks, the D16-follow-up `#CatalogDependencies`) get a typed home under `Catalog.metadata` or as siblings.

  **Cost:** amends D7 + D15 (append-only — new D## supersedes both; originals remain as historical context). Reopens text in `02-design.md` §2 and the cross-references table in `README.md`. Triggers a `library/CONSTITUTION.md` wording update (see sub-question 2 below).

  **Open sub-decisions if accepted:**

  1. **Hidden vs exported manifest field.** `#transformers` (hidden — matches `#Module.#components` / `#Component.#resources` "kernel-facing channel" convention) vs `Transformers` (exported). Initial recommendation: hidden, for consistency with the rest of OPM's hidden-channel discipline.
  2. **Fourth artifact kind?** Adding `kind: "Catalog"` puts a fourth artifact type next to `Module` / `ModuleRelease` / `Platform`, conflicting with `library/CONSTITUTION.md`'s "exactly 3 artifact types" rule. Distinction: `Catalog` is *consumed* by the kernel (loaded via `Materialize` from OCI), not *submitted* by users — different category from authored artifacts. Constitution needs a sentence acknowledging the consumed-vs-authored split.
  3. **Catalog FQN shape.** Options: `<modulePath>/<name>@<version>` symmetric with primitives (e.g. `opmodel.dev/catalogs/opm/opm@1.0.0` — repetitive when the path already ends in `/opm`), or `<modulePath>@<version>` (catalog addressed by module path, no name). Initial recommendation: drop `name` from catalog identity; use `<modulePath>@<version>` as the catalog FQN. Decide before locking the schema.
  4. **Publish-time stamping path.** D9 stamps via `version_override.cue` writing `Catalog: Version: "<SemVer>"`. With `#Catalog`, the override file writes `Catalog: metadata: version: "<SemVer>"`. Deeper path, same mechanism — CUE unification still collapses override and default cleanly. No experiment re-run needed; D9 keeps its substance with a one-line path edit.

  **Schema sketch (target.cue addition; replaces `#CatalogIdentity`):**

  ```cue
  #Catalog: {
      kind: "Catalog"
      metadata: {
          name!:        #NameType
          modulePath!:  #ModulePathType
          version!:     #VersionType | *"0.0.0-dev"
          fqn:          #FQNType & "\(modulePath)/\(name)@\(version)"
          description?: string
          labels?:      #LabelsAnnotationsType
          annotations?: #LabelsAnnotationsType
      }
      // Pattern constraint enforces D18's catalog-monolithic SemVer:
      // every transformer's metadata.{modulePath,version,fqn} is stamped
      // from Catalog.metadata — author discipline replaced by schema.
      #transformers: [FQN=#FQNType]: #ComponentTransformer & {
          metadata: {
              modulePath: Catalog.metadata.modulePath
              version:    Catalog.metadata.version
              fqn:        FQN
          }
      }
  }
  ```

  **Catalog authoring shape if accepted:**

  ```cue
  // library/modules/opm/catalog.cue
  package opm

  import "opmodel.dev/core@v0"
  import stateless "opmodel.dev/catalogs/opm/transformers/stateless"

  Catalog: core.#Catalog & {
      metadata: {
          name:       "opm"
          modulePath: "opmodel.dev/catalogs/opm"
          // version stamped at publish time per D8/D9
      }
      #transformers: {
          "opmodel.dev/catalogs/opm/stateless@\(Catalog.metadata.version)": stateless.Transformer
      }
  }
  ```

  **What it touches if accepted:**
  - New D## that supersedes D7 + D15 (originals retained per append-only rule).
  - `schemas/target.cue`: delete `#CatalogIdentity`; add `#Catalog`; `#TransformerMap` survives as the value-type used inside `#Catalog.#transformers`.
  - `02-design.md` §2: rewrite catalog-discovery wording; explicitly call out the pattern-enforced stamping risk reduction.
  - `05-risks.md`: soften / drop the "author forgets to stamp a transformer" implicit risk in D15's drift-bounds discussion — mitigation becomes structural instead of lint-based.
  - `06-operational.md`: `MaterializeError` / `MissingFQN` / `UnifyError` gain a natural `catalog: <fqn>` field — catalog is first-class addressable.
  - `library/CONSTITUTION.md`: sentence acknowledging `Catalog` as a kernel-consumed artifact kind distinct from the three user-authored kinds.
  - `core/SPEC.md`: new `#Catalog` section, co-committed via the `core-schema-edit` skill when the change lands.
  - `README.md` Cross-References: new `core/catalog.cue` *(new)* row; `library/modules/opm/catalog.cue` row reframes from "declares `Catalog` + `#Transformers`" to "declares `Catalog: core.#Catalog`".

  **Experiments unaffected:** 02 (regex), 03 (always-unify), 04 (stamping flow), 05 (missing-FQN diagnostic), 06 (filter resolution), 07 (ctx cycle freedom) all still hold. Experiment 04 specifically: only the stamped-field path changes (`Catalog.Version` → `Catalog.metadata.version`); mechanism (temp build dir + override file + CUE unification collapsing override and default) is unchanged.

  **Resume context:** original discussion characterised this as "additive refinement, not a redirect" — the umbrella's semantics (path-keyed registry, `Materialize` step, SemVer FQNs, plain-CUE catalogs, publish-time stamping, monolithic catalog version) are unchanged. The real decision is whether catalog identity + manifest are two loose top-level declarations (D7 + D15 as locked) or one typed `#Catalog` value with pattern-enforced transformer stamping. The strongest argument for `#Catalog` is schema-enforced stamping (replaces author discipline with structural guarantee); the weakest is aesthetic symmetry with `#Module` (worth noting but not load-bearing on its own).

### FQNs + matching

- **OQ13: SemVer-suffixed FQNs vs MAJOR-only + version predicate.** Status: resolved-by-D5. SemVer 2.0 FQN regex; `#MajorVersionType` retired from primitive metadata.
- **OQ14: Always-unify at match vs FQN-only vs `--strict` mode.** Status: resolved-by-D6. Always-unify before predicate evaluation; CUE's diagnostic (`conflicting values …: file:line file:line`) is surfaced verbatim.
- **OQ15: Missing FQN — one error per occurrence vs aggregate vs fail-fast.** Status: resolved-by-D20. One structured `MissingFQN` per `(release, component, FQN)` triple; `Match` accumulates in one pass; shape `{release, component, fqn, alternatives}` per experiment 05; `release` is a first-class field on the Go diagnostic type; `alternatives` uses prefix-match on `modulePath/name`. Experiment 05 sketched `MissingFQN: { release, component, fqn, alternatives: [...] }` accumulated per `(release, component, FQN)` triple — one diagnostic per miss, with `alternatives` computed by prefix-matching `composed` keys on the same `modulePath/name`. Formal resolution (and the `release` field elevation into the kernel-side Go diagnostic type) still pending a Decision; promote when the kernel slice lands.
- **OQ16: `#Blueprint` SemVer trail.** Status: resolved-by-D21. Yes — `#Blueprint` follows the same SemVer / stamping trail as `#Resource` / `#Trait` / `#ComponentTransformer` in lockstep (same `#PrimitiveMetadata` shape, same `#FQNType` regex, same `id.ModulePath` + `id.Version` sourcing, same `Catalog.Version` stamping). No platform-side projection — blueprints are consumer-side composition primitives, not kernel-matched. No `#blueprints` sibling map on `#Catalog` at this stage (deferred per D19 as an additive extension).

### `#ctx`

- **OQ17: `#ctx.platform` and `#ctx.environment` extension points.** Status: answered. D1 collapsed `#ctx` to an inline struct with open top (`...`) — `schemas/target.cue` line ~202 has `...` directly under `#ctx`. A future capabilities enhancement adds `platform` / `environment` siblings purely additively, no closure to undo.
- **OQ18: Cluster-domain handling.** Status: resolved-by-D4. `clusterDomain` lives on `#ReleaseIdentity` with a `*"cluster.local"` default; `#ModuleRelease.metadata.clusterDomain` carries the override and sets `#ctx.release.clusterDomain` directly.
- **OQ19: `#Component.#names` injection mechanism.** Status: resolved-by-D2/D3. There is no injection — each `#Component.#names` computes itself from the component's own `metadata` plus the injected `#release` (D3); `#ctx.components` is a comprehension over those. Validated end-to-end in `schemas/example_instance.cue`.
- **OQ20: `metadata.resourceName` override propagation.** Status: resolved-by-D2. Cascade lives on `metadata.resourceName: *name | #NameType`; `#names.resourceName` reads it directly; DNS variants derive from `resourceName`. Override wins when set; absence falls back to `metadata.name`, which itself defaults to the `#components` map key. Validated in `schemas/example_instance.cue`.
- **OQ21: `#ContextBuilder` ordering vs `#config` unification.** Status: resolved-by-D1/D2. No builder; no ordering question. `#ctx.release` is set by `#ModuleRelease` upfront, `#ctx.components` is a comprehension over `#components` evaluated independently of `#config`. The trap surface disappears.
- **OQ22: Bundle-level context.** Status: deferred. Cross-module `#ctx` references (one module reading another module's `#ctx.components.<id>.dns.fqdn`) are out of scope for this umbrella. Tracking here so the deferral is explicit.
- **OQ23: Content hashes for immutable ConfigMaps / Secrets via `#ctx`.** Status: deferred. Out of scope; tracked here so it does not silently slip into the design.

### Operational

- **OQ24: Cutover sequence with the core split.** Status: resolved-by-D22. 0001 lands on top of Part B (`library/openspec/changes/remove-api-binding-dispatch`). The core/ slice of 0001 parallelizes with Part B (zero coupling — edits land in the standalone `core/` repo at `opmodel.dev/core@v0`); the library/ and modules/ slices wait for Part B to ship before merging. The import-path rewire stays out of 0001 to preserve PR reviewability — Part B is mechanical dead-code deletion; 0001's library slice is intentional design implementation; folding them mixes the two.
- **OQ25: Catalog repackage migration path.** Status: resolved-by-D23. Hard switch — republish `library/modules/opm/` once with the post-D19 shape (c.#Catalog embedding + sibling identity/ subpackage + SemVer-FQN stamping). First new-shape tag is `opmodel.dev/catalogs/opm@0.1.0` (pre-1.0 in lockstep with `core@v0` per D12). Legacy `@v1.x` not republished. Workspace `modules/*` rewires follow as a non-blocking wave. Gated on D22 (Part B ships first). Note: the OQ's original reference to `catalog/opm/v1alpha1/` predates the catalog's move to `library/modules/opm/`; the active catalog today publishes as `opmodel.dev/catalogs/opm@v1` (currently `v1.0.6`).
