# Design — Module and Catalog Identity

This document answers the question: "What is the proposed solution and how does it work?" Design Goals and Non-Goals together define the boundary of the enhancement; the High-Level Approach should be understandable without deep implementation knowledge. All trade-off reasoning lives in `03-decisions.md`, not here.

## Design Goals

- **One statement of identity per artifact**, held in the artifact's own committed bytes, so CUE's own dependency resolution carries it to every consumer without OPM in the loop.
- **Identity is stable across compatible releases.** A patch or minor upgrade of a module keeps one identity; two majors are distinct identities. The owner label on deployed resources therefore survives ordinary upgrades.
- **A module built against one catalog build installs on a platform tracking that catalog's major**, without either side rebuilding — supplied by the platform materializing the major's builds rather than by the key discarding the build (D13, D14).
- **What a module renders does not change unless the module changes.** A catalog release adds a key space; it never alters the one an installed module is already matching against.
- **A local checkout and its published artifact compute identical identity and identical match keys.** Development cannot validate against a key space no consumer will see.
- **A missed demand names the gap.** "This platform materialized 1.0.0 and 1.1.0 of that primitive; you asked for 1.3.0" is an error that says what to do, not a missing key that names nothing.
- **The registry address is recoverable from a loaded artifact**, so code holding a decoded module or catalog can re-import it.
- **An unsupplied identity fails loudly and early.** Absence must never present as a plausible value that renders successfully.

## Non-Goals

- The commands that *write* identity or *push* artifacts. `opm module publish`, `opm catalog publish`, and `opm … version set` belong to enhancement 0011; this entry defines what those commands write and what readers may assume about it.
- Registry namespace policy, publishing credentials, and tag immutability — 0011.
- Version *selection*: how a consumer pins or ranges a dependency. This entry fixes what a version *means*; choosing one is a separate concern.
- Artifact discovery — search, listing, or any index over what is published.
- The catalog repackage itself (composition, subscription filters, materialization semantics). Enhancement 0001 owns those; this entry changes the identity the primitives inside a catalog carry, not how catalogs are assembled.

## High-Level Approach

Split what an artifact *is* from what was *resolved*, and put only the first in identity.

1. **`metadata.modulePath` is the artifact's complete CUE module path, major suffix included** — `opmodel.dev/m/acme/jellyfin@v2`, not the prefix `opmodel.dev/modules`. `metadata.fqn` is that same string, and `uuid: SHA1(OPMNamespace, fqn)` keeps its formula with a version-free, major-bearing input. The declared path *is* the registry address, so nothing is recombined from parts and the address is recoverable by reading one field.

2. **`#Module` declares no version.** A module's full version exists only as the coordinate an artifact was published at and resolved by. The major, which is the one version component both CUE and Go treat as identity-bearing, arrives inside the module path. With one version in the system there is no second value to drift from it.

3. **`#Catalog` keeps a full SemVer `metadata.version`** — declared concretely in committed source, and interpolated into every FQN the catalog ships. What changes versus today is not where the value goes but whether it is honest: it is committed rather than stamped into a copy of the tree at publish, so a checkout and the published artifact produce the same keys.

4. **Every primitive FQN carries the full SemVer of the build it came from** — `path/name@1.2.0` for resources, traits, blueprints, and transformers alike, which is the form `core` carries today. A key therefore names its own bytes. Note the deliberate asymmetry with point 1: a *module path* ends in `@v1` because that is CUE's spelling for an address; an *FQN* ends in `@1.2.0` because it is a key. The two are never the same string.

5. **A subscription supplies every published build in the major it names.** This is what makes a module built against `1.0.0` work on a platform that also carries `1.2.0`: the composed transformer map is the union of the materialized builds' key spaces, so both demands are present and each module matches exactly what it was authored against. `library` already does this — `materialize/filter.go` returns every survivor of a filter and `materialize.go` pulls each as its own build — but its *default* selects a single build, which is the half that changes (D14). Prereleases become an explicit opt-in rather than a property of constraint syntax (D15).

6. **Identity is supplied by a committed, visible `identity.cue`.** Tool-owned fields carry an inert `@opm()` marker so a reader can see the field is managed and tooling can locate what it owns without hardcoding names. The file is committed, diffable, and reviewable; OPM edits a file you can read rather than generating one you cannot.

7. **An identity field may be left open (`string`), and an open field is an absent value rather than a placeholder one.** An author who wants to manage the version by hand writes a concrete value and commits it; an author who wants tooling to supply it leaves the declaration open. Either way the published artifact carries a concrete value. Where a value is missing, CUE refuses to build on it and names the field — it never yields a wrong-but-plausible string.

8. **Identity is verified where artifacts are read**, not only where they are written: at module acquire, at catalog materialize, and when a platform adds a catalog subscription. A check a publisher can route around gives a consumer nothing.

The relationship that results: one identity string per artifact (`modulePath`, an address ending `@vN`), one match key per primitive (`…@1.2.0`, naming the build it came from), and one subscription per catalog major that supplies every build a module might demand.

### Where the two artifact types differ

| | `#Module` | `#Catalog` |
| --- | --- | --- |
| Identity fields | `modulePath` + `name` | `modulePath` + `version` (no `name` — see OQ1) |
| Version in source | none | full SemVer, concrete |
| What the version is for | — | the key component every primitive FQN interpolates (D13) |
| `fqn` | `modulePath` | `modulePath` |
| Identity file | one file in the artifact's own root package | `identity/` subpackage, imported by the leaves |
| Why that placement | single-package; no cycle to break, and CUE has no relative intra-module import | the leaves compute their own FQNs at their own definition sites, and a root-supplied constant creates an import cycle |
| Read-side check | acquire (`kernel.AcquireModuleFromRegistry`) | materialize + platform subscription |

The identity-file asymmetry is forced by package topology, not chosen. Removing a catalog's `identity/` subpackage makes the catalog root and its transformer subpackage import each other, which CUE rejects with `package import cycle not allowed`.

### Matching, and where cross-minor compatibility actually comes from

Matching is exact-key containment: the composed transformer map either carries the demanded FQN or it does not. There is no floor to evaluate, no owning catalog to derive, and no version ordering anywhere on the match path — a demand for a build the platform did not materialize is simply absent.

Compatibility comes from the *supply* side instead. A platform subscribed to `opmodel.dev/catalogs/opm@v1` materializes every published build in that major, so its key space is the union of those builds':

```
platform supplies   …/config-maps@1.0.0   …/config-maps@1.1.0   …/config-maps@1.2.0
module A demands    …/config-maps@1.0.0                                        ✓
module B demands                          …/config-maps@1.1.0                  ✓
```

Two properties follow, and the second is the reason for the design. Modules built against different minors coexist without either being rebuilt. And publishing `1.2.0` **adds** a key space rather than replacing one, so what module A renders does not move — the catalog release is inert until module A is itself rebuilt against a newer catalog.

**Diagnosis needs no catalog lookup.** On a miss, strip the version off the demanded FQN and collect every supplied key sharing that path-and-name. That set is exactly "which builds of this primitive the platform has", which separates the two cases a user cares about:

- **Uncovered build** — the primitive exists, at other versions. The error names what was demanded, what the platform materialized, and the subscription to widen.
- **Absent primitive** — no build supplies it at all: an unsubscribed catalog, a removed primitive, or a typo. The empty set is what distinguishes it.

Both replace `no matching transformer`, which names neither, and neither depends on OQ3 — the derivation is over the demanded FQN itself rather than over a relationship between a primitive's path and its catalog's.

### What stays out of identity, and why it still exists

**The resolved module version** is stamped as `module.opmodel.dev/version` by the kernel on the render path, from the coordinate the acquisition used. Only the code that fetched an artifact knows which one it got; the schema states what a module *is*.

## Schema / API Surface

Full shapes in [`schemas/target.cue`](schemas/target.cue). The headline definitions:

- **`#ArtifactRef`** — splits a complete module path into `registryPath` + `major`, the operation that replaces every "compose an address from a prefix and a name" site.
- **`#ModuleIdentity`** / **`#CatalogIdentity`** — the metadata shapes after the change, with `fqn` bound to `modulePath` and the module-side leaf constraint expressed over one field.
- **`#PrimitiveIdentity`** — the `fqn` = `registryPath/name@version` derivation shared by resources, traits, blueprints, and transformers. Whether `version` also survives as a separate required field is OQ6; the FQN interpolates it either way.
- **`#FetchedArtifact`** — the read-side invariant: an artifact lives where its metadata says it lives. The resolved tag is recorded alongside, not checked against anything, because nothing inside the artifact claims one.
- **`#SubscriptionSelection`** — what a subscription resolves to under D14: every published build whose major matches the subscription key's, gated by D15's `includePrereleases`. The worked cases pin the default, the opt-in, and the live regime where today's default selects nothing.
- **`#PrimitiveDemand`** — the matcher's whole check for one demanded primitive, which under D13 is exact-key containment plus the diagnostic set. `availableVersions` is computed whether or not the demand matched, so a failure can name what the platform does carry; `matched` is constrained to `true` so a miss is a unification failure rather than a value someone must remember to inspect.

`schemas/examples.cue` carries worked before/after values for a module and a catalog, the cross-minor scenario as supply-side union, and the two diagnostics a miss produces. It vets, so a wrong example is a build failure rather than a documentation bug.

## Integration Points

**core** — the breaking half. Load the `core-schema-edit` skill before touching any of these; the SPEC.md co-update is gated by a pre-commit hook and CI.

- `core/src/types.cue:20` — `#ModulePathType` gains the `@vN` suffix and must accept underscores. Today's `=~"^[a-z0-9.-]+(/[a-z0-9.-]+)*$"` has no underscore, which was harmless while `modulePath` was a bare prefix and is not once the path ends in the module's own snake_case name (`media_server`, `cert_manager`, `zot_registry_ttl`).
- `core/src/types.cue:26-28` — `#ModuleFQNType` (the `:semver` tail) retired or redefined as `#ModulePathType`.
- `core/src/types.cue:37-46` — `#FQNType` keeps its SemVer tail (D13); only the underscore widening on its path portion applies. The doc comment recording enhancement 0001 D5's major→SemVer lift stays true and should gain a pointer to D13, since D4 briefly reversed it.
- `core/src/types.cue:22-24` — `#MajorVersionType` is declared today and used nowhere. This is the design its doc comment describes.
- `core/src/types.cue:56-72` — `#KebabToSnake` removed; `#KebabToPascal` keeps its other callers but stops being applied to a module name.
- `core/src/module.cue:12` — `name!` retyped to `#SnakeNameType`.
- `core/src/module.cue:15-19` — `nameSnakeCase` removed.
- `core/src/module.cue:22` — `version!` deleted.
- `core/src/module.cue:23` — `fqn: modulePath`.
- `core/src/module.cue:27` — `#definitionName` currently computes `(#KebabToPascal & {in: name}).out`; with a snake `name` that yields `Media_server`. Needs a snake-aware projection or removal.
- `core/src/module.cue:36` — the `module.opmodel.dev/version` label loses its source and moves to the kernel.
- `core/src/catalog.cue:10` — `#CatalogFQNType` retired or redefined.
- `core/src/catalog.cue:63` — `version!` kept; the `*"0.0.0-dev"` default removed.
- `core/src/catalog.cue:64` — `fqn: modulePath`.
- `core/src/catalog.cue:70-76` — the pattern constraint keeps stamping **both** `modulePath` and `version` onto every `#transformers` entry. `modulePath` now splits the major out and re-appends it, since `@v1` sits mid-string; `version` is unchanged and now feeds the FQN directly.
- `core/src/{resource,trait,blueprint,transformer}.cue` — `fqn` derived from `registryPath/name@version`. Whether `version!` stays a separate required field or becomes derived from `fqn` is OQ6.
- `core/src/platform.cue:16-20` — `#SubscriptionFilter` gains D15's prerelease opt-in. This is a **new** integration point: the filter schema was untouched by the pre-D13 design.
- `core/src/platform.cue:70` — `#registry`'s key becomes a `#ModulePathType` carrying `@vN`, which is what makes "every build in the major" (D14) the literal reading of the key and lets one platform subscribe to two majors of one catalog as distinct entries.
- `core/SPEC.md` — `#Module` and `#Catalog` Shape / Constraints / Rationale, including the semver-with-colon rationale and the `SHA1(fqn)` determinism argument.

**library**

- `library/opm/helper/loader/internal/shape/shape.go:66` — drop `metadata.version` from `RequiredConcreteFields`.
- `library/opm/helper/loader/registry/module.go` — the module read-side check: the fetched artifact's `metadata.modulePath` must equal the path it was fetched by. Placing it on the `kernel.AcquireModuleFromRegistry` path means the CLI and the operator inherit one implementation.
- `library/opm/helper/synth/instance.go:152` — drop the version clause from the precondition.
- `library/opm/helper/synth/render.go:62` — stops parsing a SemVer for a major the module path states literally. A reduction.
- `library/opm/schema/metadata.go:18`, `context.go:17` — `Version` removed or repurposed to the resolved coordinate; `FQN` doc comment updated.
- `library/opm/materialize` — the catalog read-side check. `materialize.go:93` already builds `catalogBuild{Subscription, Version, Value}`; the resolved version keeps its diagnostic role, and `Resolved` becomes per-major-set rather than a single string (`materialize.go:96` records only the highest survivor today).
- `library/opm/materialize/filter.go:43-47` — **D14.** The empty-filter default changes from `highestStable(published)` to every published build in the subscription key's major. `filterVersions` already returns a list and every caller already handles N builds, so this is a change to one branch rather than to the shape.
- `library/opm/materialize/filter.go:31-42` — **D15.** Prerelease inclusion reads the new `#SubscriptionFilter` flag instead of being inferred from whether a `range` constraint happens to carry a prerelease identifier. The `highestStable` fallback ("a path that has published only pre-releases falls back to the highest of them") is superseded by the flag and should go, not be kept as a second rule.
- `library/opm/materialize/index.go:57-64` — the comment stating that distinct versions yield distinct FQNs is **correct under D13** and should be kept, promoted from a defensive aside to a stated invariant: it is what makes multi-build subscriptions safe, and D4 would have falsified it.
- `library/opm/compile/match.go` — the diagnostic. On a missed demand, split the version off the demanded FQN, collect the supplied keys sharing that path-and-name, and report either "the platform materialized these builds, not that one" or "no build supplies this primitive at all", in place of a bare `no matching transformer`. No catalog lookup and no version ordering are involved.
- `library/opm/kernel` — stamp `module.opmodel.dev/version` on the render path from the resolved coordinate.
- `library/opm/compile/module.go:137` — **must keep consuming `mp.Transformers` as read-only input from a separate resolver.** A module's primitive definitions have to resolve through the module's own dependency graph. Under D13 this stops being a precondition for a diagnostic and becomes the reproducibility guarantee itself: if a single-build render put the module and the platform in one CUE build, minimal version selection would pick the maximum, so the module's own copy of a definition would carry the *platform's* catalog version and it would demand `…@1.2.0` where it was authored against `…@1.0.0`. The platform supplies that key, so the demand would **match** — silently, against a definition the module was never built on. See `05-risks.md`.

**cli**

- `cli/pkg/module/module.go:69-108` — `CanonicalModuleRef()` reads `ModulePath` directly; `majorVersionTag()` / `ensureVPrefix()` lose their caller.
- `cli/internal/workflow/apply/apply.go:273`, `thineditor.go:112` — write the coordinate actually fetched into `spec.module.{path,version}`. This is where the silent-downgrade defect is fixed.
- `cli/internal/workflow/render/log_output.go:40` — logs the resolved coordinate.

**catalog repos** (`catalog_opm`, `catalog_kubernetes`, `catalog_opm_experimental`)

- `src/identity/identity.cue` — `ModulePath` gains `@vN`; `Version` becomes a committed concrete SemVer or an open field; both gain `@opm()` markers. The `version_override.cue` stamping generator and the `0.0.0-dev` sentinel are retired.
- `src/catalog.cue` — `metadata: modulePath: id.ModulePath` and `metadata: version: id.Version`.
- Leaf files are **unchanged**. Intra-module imports omit the major suffix (verified: `catalog_opm/cue.mod/module.cue` is `opmodel.dev/catalogs/opm@v1` while every leaf imports `opmodel.dev/catalogs/opm/identity` with no suffix), so a major bump churns no import statement.

**modules**

- Each module gains an `identity.cue` setting `metadata: modulePath:`, and loses its authored `modulePath` and `version` lines.
- Hyphenated names are renamed (`web-app` → `web_app`, `zot-registry-ttl` → `zot_registry_ttl`).

**opm-operator**

- No feature code. `api/v1alpha1/common_types.go:36-45` already types `ModuleReference` as `{Path with major, Version tag}` and reconcile reads only spec fields. What it needs is an adoption path for live instances whose owner label changes — see OQ4.

**testdata** — `library/testdata/modules/`, `cli/tests/e2e/testdata/` regenerated.

## Before / After

**Module.** Before, `jellyfin` states its identity across four files that disagree; its `fqn` is `opmodel.dev/modules/jellyfin:2.0.0`, computed from a version last touched two releases ago, so three published artifacts share one UUID.

After, `modules/jellyfin/identity.cue` holds one line:

```cue
metadata: modulePath: "opmodel.dev/m/acme/jellyfin@v2" @opm(identity, owner=publish)
```

`module.cue` declares `name: "jellyfin"` and nothing else about identity. `fqn` is that path; the UUID is stable across every 2.x release and distinct from any v3. The tag is the only version in the system, and it is what the CLI records in `spec.module.version`.

**Catalog.** Before, `catalog_opm`'s committed tree resolves `Version` to `0.0.0-dev` and publish writes a real value into a copy, so a local render demands `…/transformers/deployment@0.0.0-dev` while the registry supplies `…/transformers/deployment@1.0.0`.

After, `src/identity/identity.cue` holds:

```cue
ModulePath: "opmodel.dev/catalogs/opm@v1" @opm(identity, owner=publish)
Version:    "1.2.0"                       @opm(identity, owner=publish)
```

Every FQN it ships reads `…@1.2.0`, identically from a checkout and from the registry — which is the divergence D5/D6 remove, and it is what makes a SemVer key trustworthy enough to keep. A module built against `1.0.0` installs on a platform subscribed to `opmodel.dev/catalogs/opm@v1`, because that subscription materializes `1.0.0` alongside `1.2.0` and the module's exact key is present (D14). Publishing `1.2.0` does not change what that module renders. A module demanding a build the subscription does not cover fails with an error naming the demanded version and the versions the platform actually has, instead of a missing key naming nothing.
