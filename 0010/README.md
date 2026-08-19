# Enhancement 0010 — Module and Catalog Identity

> **Implementation status (2026-08-19).** Complete. Every slice has landed: core crossed to the v2 major, the library/cli/operator retargeted onto it, the first-party catalogs consolidated and republished through `opm catalog publish`, and the module fleet republished at unchanged coordinates. Deviations are recorded below.

An OPM artifact states its identity in more places than one — `metadata.modulePath`, `metadata.name`, `metadata.version`, the `module:` line in `cue.mod/module.cue`, the CUE package name, and the tag it was published under — and nothing binds them. This enhancement reduces that to one statement per artifact, held in the artifact's own committed bytes, and takes the full version out of identity entirely.

See [`config.yaml`](config.yaml) for the metadata contract — it is the sole source of metadata; no parallel metadata table lives in this README.

## Summary

`metadata.modulePath` becomes the artifact's **complete CUE module path including the major suffix** (`opmodel.dev/modules/postgres@v2`), and `metadata.fqn` is that string, with the major — the one component CUE and Go both treat as identity-bearing — carried in the path and no full version anywhere in a key.

A module still **declares** a version (D2), supplied by a catalog-style identity subpackage; what it no longer does is put one in an identity. The rule that makes that safe has two halves (D41), and both are needed because the value that matters operationally is not the module's:

> **Module artifact identity** — `#Module.metadata.fqn` and `.uuid` distinguish majors and nothing finer. The major reaches them through the module path; minor and patch reach them not at all.
>
> **Instance identity** — `#ModuleInstance.metadata.fqn` and `.uuid`, which carry the owner label `opm-operator`'s `prune.go:107` reads, derive from the module's major-free `registryPath`. Neither the version nor the major reaches them, so an instance survives every upgrade of the module it deploys, a major bump included.

The declared version has two readers, and they are why it exists: an instance derives its own version from it (`#moduleInstanceMetadata.version`, declared non-optionally and unfillable for a module rendered from disk), and it sources the `module.opmodel.dev/version` label (D9). The label is honest because a reader refuses an artifact whose declared version is not the tag it was fetched by, and the version's major is checked against the path's in the identity package that writes both values (D40's identity half, kept by D43 and D45) rather than left to a publish gate that never compared them.

Identity reaches the artifact through a **committed, visible `identity.cue`** whose tool-owned fields are located by their schema-fixed path rather than by a marker attribute (D5). A field may be left open (`Version: string`), and an open field is an *absent value* rather than a placeholder one: CUE refuses to build on it and names the file and line, where a sentinel like `0.0.0-dev` would evaluate, render, and diverge silently from the published artifact. Fixing that sentinel is what makes a catalog's declared version trustworthy — and therefore usable inside a transformer key and as the provenance every primitive carries.

**A contract is keyed by its own API version; an implementation is keyed by its build** (D4). `#Resource`, `#Trait` and `#Blueprint` FQNs read `path/name@v1`, where `v1` is that primitive's `apiVersion` — a contract major its author moves when the shape breaks, independent of the catalog's module major and of its release SemVer. `#ComponentTransformer` FQNs keep the full build SemVer (`path/name@1.2.0`). The split follows the demand direction: a module demands resources and traits and never demands a transformer, so the contract surface is the one that has to survive a catalog release and the implementation surface is the one that should name its own bytes. Every primitive additionally carries `catalogVersion` as provenance that never enters a contract key (D25) and is removed from the match comparison before unification rather than forgiven after it (D26) — by a Go-side **denylist** naming `catalogVersion` and `description`, which leaves `core`'s primitive shape alone and keeps every field it does not name in the comparison (D30).

That split is what lets a contract be **fulfilled by a catalog other than the one defining it** — a generic `backup` resource declared in `catalog_opm` with no transformer of its own, implemented by a k8up provider catalog on an unrelated release cadence. Build-keyed contracts could not express it: both sides would have to have compiled against the identical `catalog_opm` build, so every release broke the pairing until the provider re-released and every module was rebuilt. What carries compatibility instead is a promise (D27) — inside one `apiVersion` a contract may add but never remove, a new field is optional or defaulted, and an existing field's default is immutable. Publish refuses a build that breaks it (0011 D9), the matcher's unify rung catches what reaches it, and CUE's closedness makes a provider older than the contract fail loudly on the exact field a module used that it lacks. A demand nothing supplies is an error rather than a silent omission (D28).

Reproducibility then rests on the subscription rather than on the key, so the subscription stops resolving: a platform **names the one catalog build it materializes** in a required scalar `version`, and `range`, `deny`, `allow` and the empty-filter default are deleted along with `#SubscriptionFilter` itself (D14). Selection becomes a projection of committed source, so a catalog release is inert until someone edits that field — and there is no resolution left to record in a lockfile. Two builds of one catalog is two platforms: breadth had no use case that survived D4 (a module cannot demand a transformer, so there is no migration to stage) and D28 (a dropped transformer now fails loudly instead of being papered over).

A contract then says where its fulfilment comes from, because nothing can infer it: `#Resource` and `#Trait` carry `fulfilment: *"catalog" | "provider"` (D37). The default is today's behaviour — the declaring catalog implements it, and many transformers may consume one contract to produce different outputs. `"provider"` is the shape D4 exists to enable: a generic `backup` declared in `catalog_opm`, expressing what backup *means* and shipping no transformer of its own, fulfilled by a k8up provider catalog on an unrelated cadence. It has to be declared rather than derived, because D17 records that a primitive's owning catalog cannot be read off its FQN.

What follows is an arity guarantee rather than a tie-break: **a provider-fulfilled contract resolves to exactly one transformer, or materialize fails naming the ambiguity** (D32). Two providers is an error raised in the kernel, so the CLI and the operator inherit it, with a CLI platform walker reporting it ahead of a deploy as a convenience rather than as the guard; zero is already D28's unresolved demand. k8up or Velero, never both — switching providers replaces a subscription rather than adding one. The matcher needs no arbitration because the arity is settled before it reads. Deliberate overlap is prohibited for this iteration rather than arbitrated (OQ17, resolved by D37), with the intent to allow it later: no cross-catalog fulfilment exists in the workspace today, so an override gets designed against the first real case.

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
- The shape of `#FQNType` and every primitive's `fqn`: **two key types split by role** (D4) — an `apiVersion` contract key for resources, traits and blueprints, a full-SemVer build key for transformers — plus the `apiVersion` and `catalogVersion` fields that feed them (D25), and how both read against `#ModulePathType`'s `@vN` address.
- What a subscription selects: exactly the one build it names, via a required scalar `version` on `#Subscription` (D14). `#SubscriptionFilter` is deleted, and `range`, `deny`, `allow`, the empty-filter default and the prerelease flag go with it. This is what makes a render reproducible from a commit once D4 stopped the contract key from pinning the build, so it is in scope even though `#Platform` is otherwise 0001's.
- The arity of a contract bucket, and the materialize-time error that enforces it (D32) — including where the check lives (kernel, not CLI) and what supplies a transformer's owning catalog (materialize-time provenance, not a parsed FQN). The *override* for a deliberate overlap is explicitly not in scope; D37 resolved it by prohibition for this iteration and the override itself is deferred to a later entry.
- The matcher's diagnostic: the two outcomes a missed demand produces, both computed from the demanded FQN without deriving an owning catalog.
- Whether `#definitionName` survives on each primitive kind (D33) — in scope because D8's snake_case module name is what breaks it.
- How a contract states where its fulfilment comes from (D37): `fulfilment: *"catalog" | "provider"` on `#Resource` and `#Trait`, and the exactly-one-provider guard a `"provider"` contract carries. In scope because it is what makes D4's cross-catalog fulfilment a supported path rather than a tolerated one, and because it corrects the mechanism D32 states. The *arbitration* for a deliberate multi-provider overlap remains out of scope and is explicitly deferred to a later entry.
- Where matching labels live (D36): a dedicated `matchLabels` field on `#Resource`, `#Trait`, `#Blueprint` and `#Component`, unified upward from the attached primitives, with `metadata.labels` no longer unified and no longer carrying the matching vocabulary. In scope because OQ16 was filed against D26's label mechanism and because `core/SPEC.md` states the upward union normatively three times without any implementing code. Carries two riders: `#LabelWorkloadType` is deleted from `core` (zero readers, the D33 argument), and the key is renamed `opm.opmodel.dev/workload-type` under `catalog_opm` ownership.
- Where identity lives and how it gets there: a committed `identity/identity.cue` subpackage, the same shape for both artifact types (D2, D5), with fields that may be open or concrete.
- Read-side verification of identity — at module acquire, at catalog materialize, and at platform subscription — and the typed errors it produces.
- The `module.opmodel.dev/version` label: retained in the schema, sourced from the module's declared version, and verified by the kernel against the tag the artifact was fetched by (D9).
- The identity migration: every artifact's UUID changes once, and every live instance's owner label with it.

### Out of scope

- **The commands that write identity or push artifacts.** `opm module publish`, `opm catalog publish`, and `opm … version set` belong to enhancement 0011. This entry defines what those commands write and what a reader may assume; 0011 defines the commands.
- **Registry namespace policy, publishing credentials, and tag immutability** — 0011.
- **Module version selection** — how a consumer pins or ranges a *module* dependency. This entry fixes what a version means; choosing one is separate. Catalog subscription selection is the exception and is **in** scope (D14): under build-keyed contracts it was the mechanism producing cross-minor compatibility, and under D4's split it became the only remaining thing that could pin the transformer build a render executes — which is why its resolution was replaced by a single named build.
- **Artifact discovery** — search, listing, or any index over what is published. It rests on this entry's addressing guarantees but is its own concern.
- **The catalog repackage** — composition and materialization semantics. Enhancement 0001 owns those. The boundary is worth stating precisely: the subscription's whole shape is in scope here, because it decides which catalog bytes a render executes (D14), as is the arity of the bucket those bytes land in (D32); how catalogs are assembled, filtered by kind, and composed remains 0001's.
- **The single-build render rewrite** in `library`. This entry supplies the identity contract that work consumes, not the render change itself.

## Deviations from Design

Seven, each recorded in `config.yaml.history` where it landed.

1. **The library retarget landed twice.** The first crossing (library#51) shipped against a library-owned stand-in fixture catalog, because the original ordering put the catalogs' v2 authoring behind the library slices. It was reverted the same day (library#52) — the stand-in duplicated the real catalog's shape knowledge with no named retirement owner — and the ordering was inverted so catalogs moved first. The redo re-landed against the real consolidated catalog.

2. **The core slices shipped across four tags, not one release.** `06-operational.md` describes a single cut point that "nothing else can move until"; in practice `v2.0.0-alpha.1` through `alpha.4` each carried part of it, leaving three partial-and-resolvable tags on the line. Only `alpha.4` was ever a retarget target, and nothing in the registry distinguishes a partial tag from a complete one.

3. **The five-slice import rewrite resolved as four rewrites and two tombstones.** D47's consolidation meant `catalog_kubernetes`'s 56 files and `catalog_opm_experimental`'s 9 were never rewritten forward — each repo's v2 line ended at the `v2.0.0-alpha.1` it had already published.

4. **D11's third read point has no library home.** The design names platform-subscription time as the earliest place to verify a catalog's identity, but nothing in the library resolves subscriptions outside materialize — the platform loader deliberately does not. The check collapsed into the materialize read; the fires-earliest property is a frontend workflow concern.

5. **The operator needed feature code after all.** `02-design.md` states the operator needs none. Retiring the Platform CRD's `Subscription.Filter` for D14's scalar `version` is versioned API work, and the controller could not compile against the retargeted library while still mapping a filter the library had deleted.

6. **`modules-identity-authoring` landed the identity packages but not the metadata derivation its concern also claimed.** Every module stated its version twice — in `identity/identity.cue` and as a literal in `module.cue` — and the gate compares values, so the two agreed until something moved one. The first release-please bump desynchronised them and publish refused; fixed across all 20 modules during the republish (modules#32). This is the entry's one genuine implementation gap rather than a design change.

7. **The republished fleet carries no `x.y.0` tags.** The seeded versions were overtaken before the republish ran — release-please counted the port commits after the bootstrap SHA, then the derivation fix touched all 20 module files in one commit and patch-bumped the rest. Nothing had been published at the seeded values, so the sweep simply shipped what was declared.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `/CLAUDE.md` (workspace root) | Cross-repo routing + area vocabulary governing this multi-repo enhancement |
| `core/.claude/skills/core-schema-edit/SKILL.md` | Binding protocol for the `core/*.cue` slice; SPEC.md co-update is gated by a pre-commit hook and CI |
| `core/src/types.cue` | `#ModulePathType`, `#FQNType`, `#ModuleFQNType`, `#MajorVersionType`, `#KebabToSnake` — the type surface this entry rewrites |
| `core/src/module.cue` | `#Module.metadata` — `version` **retained and in no key** (D2), `modulePath` reshaped, `fqn` redefined, `registryPath` added (D41), **no** version-major agreement — it lives in the identity package alone (D45, transposing D43), the version label **retained**, schema-declared and kernel-verified (D9) |
| `core/src/module_instance.cue` | `#ModuleInstance.metadata` — an explicit `fqn` derived from the module's `registryPath`, and `uuid` derived from that rather than from `module.uuid` (D41). The one shape this entry touches that enhancement 0001 otherwise owns |
| `cli/internal/workflow/render/module.go` | `:99` — "a module apply always renders a local module directory"; the path with no resolved coordinate, and the reason a kernel stamp cannot cover both frontends (D9) |
| `library/opm/schema/context.go` | `:59` — `#moduleInstanceMetadata.fqn` is filled with `inst.ModuleFQN()`, the *module's* FQN under an instance-shaped name; D41 settles which one that block carries |
| `core/src/catalog.cue` | `#Catalog.metadata` + the `#transformers` pattern constraint that stamps identity onto every transformer |
| `core/src/resource.cue`, `core/src/trait.cue`, `core/src/blueprint.cue`, `core/src/transformer.cue` | Primitive identity — `apiVersion` added, `version` renamed `catalogVersion` (D25); `fqn` keys on the contract for the first three kinds and on the build for a transformer (D4) |
| `core/SPEC.md` | Normative `#Module` / `#Catalog` spec; the semver-with-colon rationale and the `SHA1(fqn)` determinism argument both change |
| `library/opm/helper/loader/registry/module.go` | Module read point — where the address check lands |
| `library/opm/helper/loader/internal/shape/shape.go` | `RequiredConcreteFields` lists `metadata.version` — unchanged under D2 |
| `core/src/transformer.cue` | `#moduleInstanceMetadata.version` (`:105`) — the consumer that made D2's restored version necessary; fed by `Instance.ModuleVersion()` |
| `library/opm/module/instance.go` | `ModuleVersion()` (`:110`) — reads the module's `metadata.version`; the instance declares none of its own |
| `library/opm/kernel/wrappers.go` | `AcquireModuleFromRegistry` — the single call the CLI and the operator both reach the registry through |
| `library/opm/materialize/materialize.go` | `catalogBuild{Subscription, Version, Value}` — the kernel already holds the resolved catalog version |
| `library/opm/materialize/filter.go` | `filterVersions` + `highestStable` — the resolution D14 deletes outright, leaving one major-agreement check on a single string |
| `library/opm/materialize/index.go` | `indexCatalogs` — the composed map and the `#matchers` reverse index. `:82-95` builds that index from **required ∪ optional** demands, which is why D32's guard keys on a contract's declared `fulfilment` (D37) rather than on bucket arity; `catalogBuild`'s subscription provenance (`:21`) supplies the owning catalog the error names, rather than parsing an FQN. |
| `library/opm/compile/match.go` | `unifyIntersection` (`:247-273`) — D26/D27's always-unify rung and D30's operand denylist; `:130` is the missed-key diagnostic (D28); `:138-157` is the candidate loop D32 leaves deliberately unchanged |
| `core/src/platform.cue` | `#SubscriptionFilter` (deleted under D14) and `#Subscription` (gains a required scalar `version`); `#registry`'s `#ModulePathType` key gains `@vN` under D1 |
| `core/src/module.cue`, `core/src/transformer.cue` | `#definitionName` — computed at `module.cue:27` and `transformer.cue:24`, read by neither, deleted under D33 |
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
| `catalog_opm/src/identity/identity.cue` | The catalog identity package this entry reshapes; `catalog_kubernetes` and `catalog_opm_experimental` carried the same file until D47 consolidated the catalogs on the v2 line |
| `catalog_opm/src/resources/configmap.cue` | A representative leaf: imports `identity`, derives its own FQN, and embeds the whole primitive into a `#Component` |
| `modules/jellyfin/module.cue`, `modules/jellyfin/cue.mod/module.cue` | The worked example in `01-problem.md`; its `deps` block pins the catalog whose primitive definitions the module carries |
| `enhancements/0011/` | The publishing half — the commands that write what this entry defines |
| `enhancements/0001/` | Catalog repackage; owns composition and materialization semantics this entry does not touch |
