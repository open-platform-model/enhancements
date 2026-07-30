# Enhancement 0010 — Module and Catalog Identity

An OPM artifact states its identity in more places than one — `metadata.modulePath`, `metadata.name`, `metadata.version`, the `module:` line in `cue.mod/module.cue`, the CUE package name, and the tag it was published under — and nothing binds them. This enhancement reduces that to one statement per artifact, held in the artifact's own committed bytes, and takes the full version out of identity entirely.

See [`config.yaml`](config.yaml) for the metadata contract — it is the sole source of metadata; no parallel metadata table lives in this README.

## Summary

`metadata.modulePath` becomes the artifact's **complete CUE module path including the major suffix** (`opmodel.dev/m/acme/jellyfin@v2`), and `metadata.fqn` is that string. `#Module` declares **no version at all**: the full version exists only as the coordinate an artifact was published at and resolved by, with the major — the one component CUE and Go both treat as identity-bearing — carried in the path.

Identity reaches the artifact through a **committed, visible `identity.cue`** whose tool-owned fields are located by their schema-fixed path rather than by a marker attribute (D22). A field may be left open (`Version: string`), and an open field is an *absent value* rather than a placeholder one: CUE refuses to build on it and names the file and line, where a sentinel like `0.0.0-dev` would evaluate, render, and diverge silently from the published artifact. Fixing that sentinel is what makes a catalog's declared version trustworthy — and therefore usable inside a transformer key and as the provenance every primitive carries.

**A contract is keyed by its own API version; an implementation is keyed by its build** (D24). `#Resource`, `#Trait` and `#Blueprint` FQNs read `path/name@v1`, where `v1` is that primitive's `apiVersion` — a contract major its author moves when the shape breaks, independent of the catalog's module major and of its release SemVer. `#ComponentTransformer` FQNs keep the full build SemVer (`path/name@1.2.0`). The split follows the demand direction: a module demands resources and traits and never demands a transformer, so the contract surface is the one that has to survive a catalog release and the implementation surface is the one that should name its own bytes. Every primitive additionally carries `catalogVersion` as provenance that never enters a contract key (D25) and is removed from the match comparison before unification rather than forgiven after it (D26) — by a Go-side **denylist** naming `catalogVersion` and `description`, which leaves `core`'s primitive shape alone and keeps every field it does not name in the comparison (D30).

That split is what lets a contract be **fulfilled by a catalog other than the one defining it** — a generic `backup` resource declared in `catalog_opm` with no transformer of its own, implemented by a k8up provider catalog on an unrelated release cadence. Build-keyed contracts could not express it: both sides would have to have compiled against the identical `catalog_opm` build, so every release broke the pairing until the provider re-released and every module was rebuilt. What carries compatibility instead is a promise (D27) — inside one `apiVersion` a contract may add but never remove, a new field is optional or defaulted, and an existing field's default is immutable. Publish refuses a build that breaks it (0011 D9), the matcher's unify rung catches what reaches it, and CUE's closedness makes a provider older than the contract fail loudly on the exact field a module used that it lacks. A demand nothing supplies is an error rather than a silent omission (D28).

Reproducibility then rests on the subscription rather than on the key, so the subscription stops resolving: a platform **names the catalog builds it materializes** in a required, non-empty `versions` list, and `range`, `deny` and the empty-filter default are deleted (D29). Selection becomes a projection of committed source, so a catalog release is inert until someone edits that list — and there is no resolution left to record in a lockfile.

Three suffixes are in play and two of them spell `@vN`, so the distinction is worth holding: `@v2` on a **module path** is an *address*, `@v1` on a **resource or trait FQN** is a *contract key*, and `@1.2.0` on a **transformer FQN** is a *build key*.

The result is that a patch or minor upgrade no longer changes any identity, a catalog release neither invalidates an installed module nor moves what it renders, a contract outlives the builds on either side of it, a local checkout computes the same keys as the artifact it publishes to, and a demand that cannot be met fails loudly — naming the field or the contract — instead of rendering something incomplete.

## Documents

The six split documents below are mandatory and always present.

1. [01-problem.md](01-problem.md) — Identity is stated four times, drifts, and puts a moving version inside the label on every deployed resource
2. [02-design.md](02-design.md) — One identity per artifact, contract keys split from build keys, subscriptions that name their builds, and a committed identity file
3. [03-decisions.md](03-decisions.md) — Decision log + Open Questions
4. [04-graduation.md](04-graduation.md) — Per-status gates (draft → accepted → implemented)
5. [05-risks.md](05-risks.md) — Risks and Mitigations, Drawbacks, high-level Alternatives
6. [06-operational.md](06-operational.md) — Operational concerns (PRR-lite)

Pure-CUE definitions live in [`schemas/`](schemas/): [`target.cue`](schemas/target.cue) holds the contract, [`examples.cue`](schemas/examples.cue) holds worked before/after values. Both compile, so a wrong example is a build failure rather than a documentation bug.

## Scope

### In scope

- The shape of `#Module.metadata` and `#Catalog.metadata`: `modulePath` as the complete CUE module path, `fqn` as that path, no module version, a catalog version that every primitive FQN interpolates, and a snake_case `name` whose value is the module path's leaf.
- The shape of `#FQNType` and every primitive's `fqn`: **two key types split by role** (D24) — an `apiVersion` contract key for resources, traits and blueprints, a full-SemVer build key for transformers — plus the `apiVersion` and `catalogVersion` fields that feed them (D25), and how both read against `#ModulePathType`'s `@vN` address.
- What a subscription selects: exactly the builds it names, via a required, non-empty `versions` list on `#SubscriptionFilter` (D29). `range`, `deny`, the empty-filter default and D15's prerelease flag are all deleted. This is what makes a render reproducible from a commit once D24 stopped the contract key from pinning the build, so it is in scope even though `#Platform` is otherwise 0001's.
- The matcher's diagnostic: the two outcomes a missed demand produces, both computed from the demanded FQN without deriving an owning catalog.
- Where identity lives and how it gets there: a committed `identity.cue`, in the module's own root package or in a catalog's `identity/` subpackage — an asymmetry kept deliberately (D23) — with fields that may be open or concrete.
- Read-side verification of identity — at module acquire, at catalog materialize, and at platform subscription — and the typed errors it produces.
- The `module.opmodel.dev/version` label's move from the schema to the kernel.
- The identity migration: every artifact's UUID changes once, and every live instance's owner label with it.

### Out of scope

- **The commands that write identity or push artifacts.** `opm module publish`, `opm catalog publish`, and `opm … version set` belong to enhancement 0011. This entry defines what those commands write and what a reader may assume; 0011 defines the commands.
- **Registry namespace policy, publishing credentials, and tag immutability** — 0011.
- **Module version selection** — how a consumer pins or ranges a *module* dependency. This entry fixes what a version means; choosing one is separate. Catalog subscription selection is the exception and is **in** scope (D29): under D13 it was the mechanism producing cross-minor compatibility, and under D24 it became the only remaining thing that could pin the transformer build a render executes — which is why D29 replaces its resolution with an explicit list.
- **Artifact discovery** — search, listing, or any index over what is published. It rests on this entry's addressing guarantees but is its own concern.
- **The catalog repackage** — composition and materialization semantics. Enhancement 0001 owns those. The boundary is worth stating precisely: `#SubscriptionFilter`'s whole shape is in scope here, because it decides which catalog bytes a render executes (D29, OQ15); how catalogs are assembled, filtered by kind, and composed remains 0001's.
- **The single-build render rewrite** in `library`. This entry supplies the identity contract that work consumes, not the render change itself.

## Deviations from Design

None at this stage. This entry is `draft`; deviations are recorded here when implementation lands.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `/CLAUDE.md` (workspace root) | Cross-repo routing + area vocabulary governing this multi-repo enhancement |
| `core/.claude/skills/core-schema-edit/SKILL.md` | Binding protocol for the `core/*.cue` slice; SPEC.md co-update is gated by a pre-commit hook and CI |
| `core/src/types.cue` | `#ModulePathType`, `#FQNType`, `#ModuleFQNType`, `#MajorVersionType`, `#KebabToSnake` — the type surface this entry rewrites |
| `core/src/module.cue` | `#Module.metadata` — `version` deleted, `modulePath` reshaped, `fqn` redefined, the version label removed |
| `core/src/catalog.cue` | `#Catalog.metadata` + the `#transformers` pattern constraint that stamps identity onto every transformer |
| `core/src/resource.cue`, `core/src/trait.cue`, `core/src/blueprint.cue`, `core/src/transformer.cue` | Primitive identity — `apiVersion` added, `version` renamed `catalogVersion` (D25); `fqn` keys on the contract for the first three kinds and on the build for a transformer (D24) |
| `core/SPEC.md` | Normative `#Module` / `#Catalog` spec; the semver-with-colon rationale and the `SHA1(fqn)` determinism argument both change |
| `library/opm/helper/loader/registry/module.go` | Module read point — where the address check lands |
| `library/opm/helper/loader/internal/shape/shape.go` | `RequiredConcreteFields` still lists `metadata.version` |
| `library/opm/kernel/wrappers.go` | `AcquireModuleFromRegistry` — the single call the CLI and the operator both reach the registry through |
| `library/opm/materialize/materialize.go` | `catalogBuild{Subscription, Version, Value}` — the kernel already holds the resolved catalog version |
| `library/opm/materialize/filter.go` | `filterVersions` + `highestStable` — the resolution D29 deletes, leaving a validation pass over the platform's named `versions` |
| `library/opm/materialize/index.go` | `indexCatalogs` — the composed map; its "distinct versions → distinct FQNs" invariant is what multi-build subscription rests on |
| `core/src/platform.cue` | `#SubscriptionFilter` (collapses to a required `versions` list under D29) and `#registry`'s `#ModulePathType` key (gains `@vN` under D1) |
| `library/opm/helper/synth/render.go` | Derives the synthesized import's major by parsing a SemVer; becomes a read of the module path |
| `library/opm/compile/execute.go` | Where a demanded FQN meets the composed transformer map — the matcher this entry re-keys |
| `library/opm/compile/match.go` | `unifyIntersection` (`:247-273`) — the always-unify rung D26/D27 make load-bearing and D30's operand denylist lands in; `:130` is the missed-key diagnostic (D28) |
| `library/opm/errors/match.go` | `UnifyError` (`:49-63`) — carries `Component` and `FQN` structurally, which is what absorbs the error-path rewrite D30's syntax round-trip causes |
| `library/opm/schema/metadata.go`, `context.go` | Go-side `ModuleMetadata.Version` / `FQN` |
| `cli/pkg/module/module.go` | `CanonicalModuleRef()`, `majorVersionTag()`, `ensureVPrefix()` — address composition that disappears |
| `cli/internal/workflow/apply/apply.go` | Writes `spec.module.{path,version}`; where the silent-downgrade defect is fixed |
| `opm-operator/api/v1alpha1/common_types.go` | `ModuleReference` — already `{Path with major, Version tag}`; verified to need no change |
| `opm-operator/internal/apply/prune.go` | Skips deletes whose live owner label disagrees with `Status.InstanceUUID` — the constraint behind the migration's adoption path |
| `opm-operator/internal/reconcile/moduleinstance.go` | Repopulates `Status.InstanceUUID` from each render |
| `catalog_opm/src/identity/identity.cue` | The catalog identity package this entry reshapes; `catalog_kubernetes` and `catalog_opm_experimental` carry the same file |
| `catalog_opm/src/resources/configmap.cue` | A representative leaf: imports `identity`, derives its own FQN, and embeds the whole primitive into a `#Component` |
| `modules/jellyfin/module.cue`, `modules/jellyfin/cue.mod/module.cue` | The worked example in `01-problem.md`; its `deps` block pins the catalog whose primitive definitions the module carries |
| `enhancements/0011/` | The publishing half — the commands that write what this entry defines |
| `enhancements/0001/` | Catalog repackage; owns composition and materialization semantics this entry does not touch |
