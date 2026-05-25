# Enhancement 0001 — `#Platform` Redesign Umbrella

See [`config.yaml`](config.yaml) for metadata. This README is the index of the
six split documents and the Cross-References table; everything else lives in
the split files.

## Summary

Reshapes `#Platform` from an Id-keyed registry of fully-imported `#Module` values into a path-keyed map of registry **subscriptions** that the kernel resolves against OCI at materialize time. Drops `#Module.#defines` so catalogs become plain CUE packages that export `#Resource` / `#Trait` / `#Blueprint` / `#ComponentTransformer` at the top level; their identity (`Version`, `ModulePath`) is stamped into a per-package `Catalog` constant at publish time. Lifts primitive FQNs from MAJOR-only (`@v1`) to exact SemVer (`@1.4.0`) so two builds of the same primitive at adjacent versions occupy distinct keys and never silently collide. Adds an always-on unification step at match time so a same-FQN pair with divergent schemas surfaces as a structured error instead of a render-time surprise. Lands an inline `#ctx` channel on `#Module` carrying release identity and a projection of per-component names — each `#Component.#names` computes itself from the component's own metadata plus a release context the parent module wires in, so modules read deployment identity and DNS variants from a single schema-level home rather than re-encoding them across transformers.

## Documents

1. [01-problem.md](01-problem.md) — Why today's Module-valued `#registry`, MAJOR-only FQNs, dual-role `#Module.#defines`, and missing `#ctx` together close doors that real multi-tenant platforms need open
2. [02-design.md](02-design.md) — Path-keyed `#registry`, kernel `Materialize` step, SemVer FQNs, plain-CUE catalogs with publish-time `Catalog` stamping, always-unify match, inline `#ctx { release, components }` channel with per-component `#names` as the source of truth
3. [03-decisions.md](03-decisions.md) — Append-only decision log (filled iteratively) and Open Questions
4. [04-graduation.md](04-graduation.md) — draft → accepted, accepted → implemented gates
5. [05-risks.md](05-risks.md) — Risks and Mitigations, Drawbacks, high-level Alternatives not taken
6. [06-operational.md](06-operational.md) — Observability, semver impact, deprecation, rollback, cross-repo coordination

Pure-CUE schema sketches live under [`schemas/`](schemas/) and mature alongside `03-decisions.md`.

## Scope

### In scope

- New `#Platform.#registry` shape: `[Path=#ModulePathType]: #Subscription`, where the map key is the catalog's CUE module path (one subscription per path enforced by CUE map semantics — D13) and `#Subscription` carries `enable` and an optional `filter` (SemVer `range` plus `allow` / `deny` overrides). Multi-channel-per-path is intentionally not expressible at this stage.
- Removal of `#Module.#defines`. `#Module` becomes the consumer artifact only (`#components`, `#config`, `debugValues`, and the new `#ctx` slot).
- Removal of `#knownResources` and `#knownTraits` from `#Platform`. Primitives surface only as the `requiredResources` / `optionalResources` / `requiredTraits` / `optionalTraits` of materialized transformers.
- `#FQNType` regex change: SemVer suffix (`@1.2.3`, `@1.2.3-rc.1`) replaces MAJOR-only (`@v[0-9]+$`). `metadata.version` on `#Resource` / `#Trait` / `#Blueprint` / `#ComponentTransformer` changes type from `#MajorVersionType` to `#VersionType`.
- Catalog-side `catalog.cue` root file embeds `c.#Catalog` modules-pattern style (D19, supersedes D7's `#CatalogIdentity` + D15's loose `#Transformers` manifest): bare type at file root, fields written at the package level, no `Catalog:` wrapper. Catalog identity (`metadata.{modulePath, version}`) lives in a sibling `identity/` subpackage so transformer subpackages can source it without circular import. The kernel reads only `#Catalog.metadata` + `#Catalog.#transformers` at materialize time — no recursive package walk, no auto-discovery. The `#transformers` pattern constraint schema-stamps each entry's `metadata.modulePath` to `<catalog-root>/transformers` and `metadata.version` to the catalog's version (D18's lockstep enforced structurally, not by author discipline). Source-tree default `id.Version: string | *"0.0.0-dev"` keeps `cue vet` cheap during development; the publish task overwrites `identity/version_override.cue` in a temp build dir before `cue mod publish`. OCI artifacts ship fully concrete; the kernel never injects a version at load time.
- Kernel `Materialize(*Platform) (*MaterializedPlatform, error)` step. Resolves each subscription's filter against the OCI registry (via `cuelang.org/go/mod`, default GHCR), pulls every selected build into local cache, loads each package, indexes top-level `#ComponentTransformer` values by stamped FQN into `#composedTransformers` and a `#matchers.{resources,traits}` reverse index. `Match` takes `*MaterializedPlatform`.
- Match algorithm rewrite: FQN-keyed lookup followed by an always-on `unify(consumer_component.#resources[FQN], transformer.requiredResources[FQN])` (and the analogous traits step) before predicate evaluation. Missing FQN produces one structured error per `(component, FQN)` pair; unification failure produces one `UnifyError` per pair.
- Inline `#ctx` channel on `#Module` with two fields and an open top: `#ctx: { release: #ReleaseIdentity, components: { for id, c in #components { (id): c.#names } }, ... }`. Module identity stays in `#Module.metadata` (no `#ctx.module` mirror); the open top reserves room for future `platform` / `environment` siblings.
- `#ReleaseIdentity` carrying release name, namespace, UUID, and the cluster-domain default. `#ModuleRelease` sets `#module.#ctx.release` from its own metadata — no builder, no helper.
- `#Component.#release: #ReleaseIdentity` hidden injection slot, wired by the parent `#Module` via the `#components` pattern constraint.
- `#Component.#names` block that computes `resourceName` + `dns.{short,local,fqdn}` inline from the component's `metadata.resourceName` cascade and the injected `#release`. Each component is the single source of truth for its own names; `#ctx.components` is a pure CUE projection of every `#Component.#names`.
- `#Component.metadata.resourceName: *name | #NameType` cascade — override wins when set, falls back to `metadata.name` when absent.

### Out of scope

- `#Claim` / `#ModuleTransformer` / module extension surface — future enhancement.
- Platform capabilities (`#Capability`, `#Platform.#provides`, `#Module.#consumes`) and the `#ctx.platform` typed extension channel — future enhancement.
- Renderer / `#transform` execution model — unchanged.
- Replacing `cuelang.org/go/mod` with a custom OCI client. CUE's module proxy / OCI fetch is the substrate; the kernel wires into it via a `Registry` field on `*Kernel` that maps to `CUE_REGISTRY`.
- Signing and verification of catalog artefacts — inherits whatever guarantees `CUE_REGISTRY` provides.
- Self-service catalog discovery UX (`opm catalog list`, web UI) — separate concern.
- Migration of third-party catalog modules. Only the OPM core catalog at `catalog/opm/` is in scope.
- Bundle-level context (cross-module references via a future `#Bundle` construct) — deferred.
- Content hashes for immutable ConfigMaps / Secrets surfaced through `#ctx` — revisit when a concrete module-readable use case surfaces.

## Deviations from Design

None at this stage. Updated when implementation lands and any deliberate divergences from the design need to be documented.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `/CLAUDE.md` (workspace root) | Workspace map; identifies the directory ownership the `area` / `affects` fields validate against. |
| `core/CLAUDE.md` | Core repo guide. Schema editing protocol (`SPEC.md` co-update, pre-commit hook) governs every CUE change this enhancement lands. |
| `core/SPEC.md` | Normative schema specification. Every construct touched by this enhancement (`#Platform`, `#Module`, `#FQNType`, …) has a SPEC section that must be co-updated when the CUE lands. |
| `core/src/platform.cue` | Target of the `#Platform` / `#registry` rewrite (`#ModuleRegistration` retired; `#Subscription` / `#SubscriptionFilter` introduced; `#knownResources` / `#knownTraits` removed; `#composedTransformers` + `#matchers` become kernel-filled optional slots). |
| `core/src/module.cue` | Target of the `#Module.#defines` removal and inline `#ctx { release, components, ... }` addition (including the `#components: [Id]: #Component & { #release: #ctx.release }` pattern constraint). |
| `core/src/transformer.cue` | Target of the `#ComponentTransformer` SemVer-FQN change. |
| `core/src/types.cue` | Target of the `#FQNType` regex change and `#MajorVersionType` retirement from primitive metadata. |
| `core/src/resource.cue`, `core/src/trait.cue`, `core/src/blueprint.cue` | Each carries `metadata.version: #MajorVersionType` today; switches to `#VersionType`. |
| `core/src/component.cue` | Gains `metadata.resourceName: *name \| #NameType` cascade, a hidden `#release: #ReleaseIdentity` injection slot, and a `#names` block that computes `resourceName` + DNS variants inline from the component's metadata and injected release. |
| `core/src/module_release.cue` | Sets `#module.#ctx.release` from release metadata. No builder, no per-component injection — CUE evaluates `#names` and the `#ctx.components` projection automatically. |
| `core/src/module_context.cue` *(new)* | Home of `#ReleaseIdentity` and `#ComponentNames` only. |
| `core/src/catalog.cue` *(new)* | Home of `#Catalog` and `#CatalogFQNType` (D19, supersedes D7 + D15). |
| `core/INDEX.md` | Generated definition index — regenerated via `task generate:index` once the schema changes land. |
| `library/opm/kernel/` | Target of the new `Materialize` step and `Kernel.Registry` field. |
| `library/opm/compile/match.go` | Target of the matcher rewrite (FQN-lookup + always-unify + predicate evaluation). |
| `library/modules/opm_platform/platform.cue` | Current Module-valued fixture; rewritten to use the path-subscription model and to import `opmodel.dev/core@v0` (replacing the legacy `opmodel.dev/core/v1alpha2@v1` import). |
| `library/modules/opm/` (CUE module `opmodel.dev/catalogs/opm@v0`) | Catalog source — repackaged to the D19 shape: drop any `#Module.#defines` wrapper, embed `c.#Catalog` at the root via `catalog.cue`, source `metadata.modulePath` + `metadata.version` from the sibling `identity/` subpackage. First post-D19 OCI tag is `0.1.0` per D23. |
| `library/modules/opm/catalog.cue` *(new)* | Root catalog file. Embeds `c.#Catalog` modules-pattern style (D19, supersedes D7 + D15) and assembles `#transformers` from imports of the transformer subpackages. The only file the kernel reads at materialize time to discover transformers. |
| `library/modules/opm/identity/` *(new subpackage)* | Sibling identity package — exports `ModulePath: string` + `Version: #VersionType \| *"0.0.0-dev"`. Imported by `catalog.cue` and every primitive subpackage; publish task writes `identity/version_override.cue` (D9 amended by D19). |
| `library/modules/opm/cue.mod/module.cue` | Module identifier pinned at `opmodel.dev/catalogs/opm@v0` (D12 — stay on `@v0` until `core` is signalled stable; the catalog rides the same versioning rule). |
| `modules/Taskfile.yml` | Publish flow — gains the temp-build-dir stamping step that writes `identity/version_override.cue` before `cue mod publish` (D9 amended by D19). |
