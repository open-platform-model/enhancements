# Open Questions — #Platform Redesign Umbrella

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
