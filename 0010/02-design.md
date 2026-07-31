# Design — Module and Catalog Identity

This document answers the question: "What is the proposed solution and how does it work?" Design Goals and Non-Goals together define the boundary of the enhancement; the High-Level Approach should be understandable without deep implementation knowledge. All trade-off reasoning lives in `03-decisions.md`, not here.

## Design Goals

- **One statement of identity per artifact**, held in the artifact's own committed bytes, so CUE's own dependency resolution carries it to every consumer without OPM in the loop.
- **Identity is stable across compatible releases.** A patch or minor upgrade of a module keeps one identity; two majors are distinct identities. The owner label on deployed resources therefore survives ordinary upgrades.
- **A module built against one catalog build installs on a platform tracking that catalog's major**, without either side rebuilding — supplied by a contract key that does not move on a catalog release, plus an additive-only promise inside that key (D4, D27). Under the build-keyed contracts D4 replaced, this came from the platform materializing every build of the major; that mechanism worked within one catalog and could not reach across two.
- **A contract may be fulfilled by a catalog other than the one that defines it**, on independent release cadences. A generic primitive whose transformer lives in a provider catalog is the case the identity model must support, not an edge of it (D4).
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

4. **A contract is keyed by its own API version; an implementation is keyed by its build** (D4). `#Resource`, `#Trait` and `#Blueprint` FQNs read `path/name@v1`, where `v1` is that primitive's `apiVersion` — a contract major the author moves when the shape breaks, independent of the catalog's module major and of its release SemVer. `#ComponentTransformer` FQNs keep the full build SemVer, `path/name@1.2.0`. The split follows the demand direction: a module demands resources and traits and never demands a transformer, so the contract surface is the one that must survive a catalog release and the implementation surface is the one that should name its own bytes. Every primitive additionally carries `catalogVersion` — the build it shipped in — as provenance that never enters a key (D25).

5. **Inside one API version a contract is additive-only, and both ends enforce it** (D27). A build may add fields and options, never remove them; a new field is optional or defaulted; an existing field's default is immutable. Removal means a new `apiVersion`, which may ship beside the old one in the same catalog build — the migration path SemVer keys could not express. Publish checks the promise against the previous build (0011 D9); the matcher's always-unify rung checks it against the module actually in hand, and CUE's closedness makes a field the provider's build never declared a hard failure rather than a silent drop (measured, `experiments/02`). The promise is directional: a supplier at or above the build a module compiled against is unconditionally safe, while an older one is safe only until the module uses a field it predates — at which point it fails loudly. Those two rungs are **the whole of the enforcement** (D35): there is no read-side compatibility check, so a catalog published outside `opm catalog publish` carries a promise OPM cannot verify for a consumer. The catalog check command is an aid a publisher may decline to run, and the subscription-bump check that would close the gap is deferred to [`opm-operator#63`](https://github.com/open-platform-model/opm-operator/issues/63).

6. **A subscription names one catalog build, and nothing resolves it** (D14). `#SubscriptionFilter` is deleted and `#Subscription` carries a required scalar `version`; `range`, `deny`, `allow`, the empty-filter default and the prerelease flag all go with it, because a prerelease is selected by being written down. This is what keeps a render reproducible from a commit once D4 stopped the key from pinning the build — with no range there is no resolution to record, so the platform file is the lockfile. The list D14 briefly carried is gone too: breadth had no surviving use case, and deleting it dissolved OQ15 rather than answering it. Two builds of one catalog is two platforms.

7. **A contract bucket resolves to exactly one transformer, or materialize fails** (D32). With same-catalog breadth gone, a `#matchers` bucket holding two transformers means two *different* catalogs supply one contract — a hard error naming both, raised in the kernel so the CLI and the operator inherit it. The matcher needs no arbitration because the arity is guaranteed upstream. Which catalog should win when the overlap is deliberate is OQ17, deliberately unanswered: no cross-catalog fulfilment exists in the workspace yet, so the override gets designed against a real case rather than a guessed one.

8. **Identity is supplied by a committed, visible `identity.cue`.** Tooling locates the fields it writes by their schema-fixed path — `#IdentityPackage`'s `ModulePath` and `Version` for a catalog, `#Module`'s `metadata.modulePath` for a module — and carries no marker attribute to find them by (D5). The file is committed, diffable, and reviewable; OPM edits a file you can read rather than generating one you cannot.

9. **An identity field may be left open (`string`), and an open field is an absent value rather than a placeholder one.** An author who wants to manage the version by hand writes a concrete value and commits it; an author who wants tooling to supply it leaves the declaration open. Either way the published artifact carries a concrete value. Where a value is missing, CUE refuses to build on it and names the field — it never yields a wrong-but-plausible string.

10. **Identity is verified where artifacts are read**, not only where they are written: at module acquire, at catalog materialize, and when a platform adds a catalog subscription. A check a publisher can route around gives a consumer nothing.

The relationship that results: one identity string per artifact (`modulePath`, an address ending `@vN`), one contract key per primitive (`…@v1`, naming what it promises), one implementation key per transformer (`…@1.2.0`, naming the bytes that run), and a provenance value on both sides that says which build each came from without either side having to agree on it.

### Where the two artifact types differ

| | `#Module` | `#Catalog` |
| --- | --- | --- |
| Identity fields | `modulePath` + `name` | `modulePath` + `version` (no `name` — D16) |
| Version in source | none | full SemVer, concrete |
| What the version is for | — | the `catalogVersion` every primitive stamps as provenance (D25); no key interpolates it |
| `fqn` | `modulePath` | `modulePath` |
| Identity file | one file in the artifact's own root package | `identity/` subpackage, imported by the leaves |
| Why that placement | single-package; no cycle to break, and CUE has no relative intra-module import | the leaves compute their own FQNs at their own definition sites, and a root-supplied constant creates an import cycle |
| Read-side check | acquire (`kernel.AcquireModuleFromRegistry`) | materialize + platform subscription |

The identity-file asymmetry is forced by package topology, not chosen. Removing a catalog's `identity/` subpackage makes the catalog root and its transformer subpackage import each other, which CUE rejects with `package import cycle not allowed`.

### Matching, and where compatibility actually comes from

Matching stays exact-key containment: the `#matchers` reverse index either carries the demanded contract key or it does not. There is no floor, no ordering, no range, and no owning-catalog derivation on the match path. What changes under D4 is that the key names a *contract* rather than a build, so a demand and a supply compiled against different builds arrive at the same key and the comparison of their **bodies** is what decides compatibility.

That comparison is the always-unify rung `library` already runs (`compile/match.go:247-273`), and D26 fixes what it may compare: contract surfaces only, with provenance excluded from the operands before unification. D30 fixes how — a Go-side filter over a **denylist** naming `metadata.catalogVersion` and `metadata.description`, leaving `core` untouched and everything it does not name in the comparison. Measured in `experiments/02-primitive-closedness-skew/` and `experiments/03-provenance-operand-filter/`, that combination produces exactly the behaviour the model needs:

```
contract key      …/opm/resources/backup@v1
module built on   catalog_opm 1.3.0        provider built on   catalog_opm 1.0.0
module sets only fields both builds share                      → unify PASSES, renders
module sets a field 1.1.0 added                                → field not allowed, named
provider's build narrowed a type inside v1                     → conflict, both arms named
```

Two properties follow. A provider catalog and the catalog defining the contract release on **independent cadences** — the case a provider-fulfilled primitive requires and the one D4's keys could not express. And a lagging provider fails **exactly when it matters**: loudly when the module uses something the provider cannot honour, silently-and-correctly when it does not.

**Diagnosis without a catalog lookup, and it gets sharper.** A demanded contract key that no transformer supplies now means one of two things, and the version noise that used to obscure them is gone. If the index carries no key at all for that path-and-name, nothing on this platform implements the contract — the platform is missing a provider, which is a statement about the platform rather than the module. If it carries the same path-and-name at a different `apiVersion`, the module is on `v1` and the platform's provider implements `v2`. Distinguishing "unimplemented contract on a subscribed catalog" from "unknown path entirely" still wants the prefix match against subscribed catalog paths that OQ3 left on the table; that is now the one diagnostic worth the derivation.

**A demand nothing supplies is an error** (D28). Every resource a component declares is required; traits carry an explicit opt-out. Today the structured `MissingFQN` diagnostic is produced and dropped — `plan.Missing` has no reader outside tests, there is no `UnhandledResources` counterpart to `UnhandledTraits`, and only a component matching *nothing at all* stops a render. Under a model where contracts are routinely fulfilled by someone else, that silence is the failure mode, not an edge of it.

### What stays out of identity, and why it still exists

**The resolved module version** is stamped as `module.opmodel.dev/version` by the kernel on the render path, from the coordinate the acquisition used. Only the code that fetched an artifact knows which one it got; the schema states what a module *is*.

## Schema / API Surface

Full shapes in [`schemas/target.cue`](schemas/target.cue). The headline definitions:

- **`#ArtifactRef`** — splits a complete module path into `registryPath` + `major`, the operation that replaces every "compose an address from a prefix and a name" site.
- **`#ModuleIdentity`** / **`#CatalogIdentity`** — the metadata shapes after the change, with `fqn` bound to `modulePath` and the module-side leaf constraint expressed over one field.
- **`#IdentityPackage`** — the catalog's committed `identity/identity.cue`. Two fields the tooling writes (`ModulePath`, `Version`), located by name against this schema rather than by a marker (D5), plus `RegistryPath`, `Major` and `primitivePrefix` derived from them, so the major is split once here rather than at every definition site (D1, D21).
- **`#PrimitiveIdentity`** — `name` + `modulePath` + `apiVersion` + `catalogVersion` + `fqn`, shared by resources, traits, blueprints, and transformers. `modulePath` is a **package path** with no `@vN` (D1); `apiVersion` is the contract major an author decides and the only identity value not derivable from the identity package (D25); `catalogVersion` is the build it shipped in, provenance only; `fqn` is **authored** at the leaf (D21) and interpolates `apiVersion` for a contract, `catalogVersion` for a transformer (D4).
- **`#PrimitiveFQNGate`** — what 0011's publish gate asserts, kept deliberately outside `#PrimitiveIdentity` because expressing it there would re-derive the value and undo D21. This is where the FQN-versus-identity agreement is enforced: a contract key must read `primitivePrefix[kind]/name@apiVersion`, a transformer key `…@catalogVersion`, and `catalogVersion` must equal `identity.Version` in both cases (D25).
- **`#FetchedArtifact`** — the read-side invariant: an artifact lives where its metadata says it lives. The resolved tag is recorded alongside, not checked against anything, because nothing inside the artifact claims one.
- **`#SubscriptionSelection`** — what a subscription resolves to under D14: the one build it names. `version` is required and scalar, and the one remaining rule is that the named build sits in the subscription key's major. D4 removed the shape's original job — breadth as the compatibility mechanism — and D14 then removed both the resolution step and the list; what survives is a field that *is* its own answer. There is no `selected`, because with a scalar the projection is the value itself.
- **`#PrimitiveDemand`** — the matcher's whole check for one demanded contract, which under D4 is exact-key containment on a contract key. `matched` is constrained to `true` so a miss is a unification failure rather than a value someone must remember to inspect (and under D28 a miss is a hard error, not a collected diagnostic). `availableApiVersions` is computed whether or not the demand matched, so a failure can distinguish "nothing implements this contract" from "your platform implements a different API version of it".
- **`#ContractCompatibility`** — the additive-only promise (D27) stated as the relation a publish gate asserts between two builds of one primitive at one `apiVersion`, and the boundary condition the match rung enforces. Under D34 the relation is **keyed to the API version's level**: its clauses assert at beta and GA and are left unasserted at alpha, which is what "no promise" means expressed as a schema rather than as a hole in one.
- **`#APIVersionGated`** — the one place the Kubernetes ladder is *interpreted* rather than matched (D34). It reads a level off an `apiVersion` string and reports whether D27 binds there. Still no ordering: a level is read, never compared against another level.

`schemas/examples.cue` carries worked before/after values for a module and a catalog, and the diagnostics a miss produces. It vets, so a wrong example is a build failure rather than a documentation bug.

## Integration Points

**core** — the breaking half. Load the `core-schema-edit` skill before touching any of these; the SPEC.md co-update is gated by a pre-commit hook and CI.

- `core/src/types.cue:20` — `#ModulePathType` gains the `@vN` suffix and must accept underscores. Today's `=~"^[a-z0-9.-]+(/[a-z0-9.-]+)*$"` has no underscore, which was harmless while `modulePath` was a bare prefix and is not once the path ends in the module's own snake_case name (`media_server`, `cert_manager`, `zot_registry_ttl`). **Only `#Module` and `#Catalog` use the widened type** — a new `#PackagePathType`, which is today's regex unchanged, is what primitives declare (D1). Widening one shared type was what dragged the major onto primitives that have no use for it.
- `core/src/types.cue:26-28` — `#ModuleFQNType` (the `:semver` tail) retired or redefined as `#ModulePathType`.
- `core/src/types.cue:37-46` — **`#FQNType` splits in two (D4).** A `#ContractFQNType` ends `@vN` and types resource / trait / blueprint FQNs; an `#ImplFQNType` keeps today's SemVer tail and types transformer FQNs. The doc comment recording enhancement 0001 D5's major→SemVer lift needs rewriting rather than annotating: the lift is now correct for implementations and wrong for contracts, and the entry should say which failure each choice prefers rather than reading as a straight reversal.
- `core/src/types.cue:22-24` — `#MajorVersionType` is declared today and used nowhere. This is the design its doc comment describes, and D4 gives it a second caller: an `#APIVersionType` for contract keys, which under D34 is this regex widened to admit the Kubernetes pre-stable forms — `^v[0-9]+((alpha|beta)[0-9]+)?$`. `#MajorVersionType` itself is untouched and keeps naming module majors.
- `core/src/types.cue:56-72` — `#KebabToSnake` removed; `#KebabToPascal` keeps its other callers but stops being applied to a module name.
- `core/src/module.cue:12` — `name!` retyped to `#SnakeNameType`.
- `core/src/module.cue:15-19` — `nameSnakeCase` removed.
- `core/src/module.cue:22` — `version!` deleted.
- `core/src/module.cue:23` — `fqn: modulePath`.
- `core/src/module.cue:27` — **`#definitionName` is deleted (D33).** It computes `(#KebabToPascal & {in: name}).out`, which under a snake `name` yields `Media_server` — and nothing reads it. No snake-aware projection is needed anywhere, because the three kinds that *do* consume `#definitionName` (`resource.cue:35`, `trait.cue:34`, `blueprint.cue:42`) keep kebab-case names under `#NameType`.
- `core/src/module.cue:36` — the `module.opmodel.dev/version` label loses its source and moves to the kernel.
- `core/src/catalog.cue:10` — `#CatalogFQNType` retired or redefined.
- `core/src/catalog.cue:63` — `version!` kept; the `*"0.0.0-dev"` default removed.
- `core/src/catalog.cue:64` — `fqn: modulePath`.
- `core/src/catalog.cue:70-76` — the pattern constraint keeps stamping **both** `modulePath` and the build version onto every `#transformers` entry, the latter under its new name `catalogVersion` (D25). `modulePath` splits the major out and **stops** — it is not re-appended, because a primitive declares a package path (D1). This stays the only *structural* guarantee in the system: it is what makes a transformer's provenance unforgeable, while resources and traits reach a catalog only transitively and rely on the publish gate.
- `core/src/{resource,trait,blueprint,transformer}.cue` — `modulePath` retyped to `#PackagePathType`, which leaves the values every catalog ships today unchanged (D1). **`version!` is renamed `catalogVersion!` and a required `apiVersion!` is added** (D25); the rename touches every leaf in every catalog and is mechanical. **`fqn` stops being derived** and becomes an authored value the catalog writes from its identity package — `#ContractFQNType` interpolating `apiVersion` for the first three kinds, `#ImplFQNType` interpolating `catalogVersion` for a transformer — with the agreement re-established at publish (`#PrimitiveFQNGate`, D21, D4).
- `core/src/transformer.cue:24` — **`#definitionName` is deleted (D33).** Same unread computation as `module.cue:27`. It stays on `resource.cue:14`, `trait.cue:13` and `blueprint.cue:15`, where each kind's `spec!` key is built from it.
- `core/src/platform.cue:16-20` — **D14: `#SubscriptionFilter` is deleted outright.** Selection is a scalar, so there is no filter left to wrap. `range`, `deny`, `allow`, the empty-filter default and the prerelease flag all go. This is a **new** integration point: the filter schema was untouched by the pre-D4 design.
- `core/src/platform.cue:31-34` — **D14.** `#Subscription` gains a required scalar `version!: #VersionType` in place of `filter?: #SubscriptionFilter`. `enable` is unchanged. The doc comment's note that "multi-channel-per-path is not expressible at this stage" becomes the permanent rule rather than a staging limitation — two builds of one catalog is two platforms.
- `core/src/platform.cue:70` — `#registry`'s key becomes a `#ModulePathType` carrying `@vN`, which lets one platform subscribe to two majors of one catalog as distinct entries. Under D14 the major it names is what the subscription's single `version` is checked against.
**core/SPEC.md** — every affected section, by line. `SPEC.md` is normative and its co-update is gated by a pre-commit hook and CI, so this list is the work item rather than a reading aid. Line numbers are against `core/SPEC.md` at 668 lines (read 2026-07-30); the whole file is 15 sections, and 9 of them move.

- `:60-62` (§2.1 `#Resource` Shape) — `version!` → `catalogVersion!`, `apiVersion!` added, `fqn` stops being computed as `"\(modulePath)/\(name)@\(version)"` and becomes an authored `#ContractFQNType` (D21, D4, D25).
- `:70` (§2.1 Shape) — the `spec!: (strings.ToCamel(metadata.#definitionName)): _` line **stays**; `#definitionName` survives on the three primitive kinds under D33.
- `:79-81` (§2.1 Constraints) — `:80`'s "`metadata.version` MUST be a SemVer 2.0 string, not a MAJOR-only prefix" is **reversed for contracts** by D4; `:81`'s "consumers MUST NOT supply `fqn` directly" is **reversed** by D21, which makes `fqn` authored.
- `:87-88` (§2.1 Rationale) — "Why `fqn` is computed, not stored" and "Why `version` is exact SemVer, not a MAJOR-only prefix" are the two arguments D21 and D4 overturn. Both need rewriting to state which failure the new choice prefers, not deleting: the old reasoning was correct for the problem it was solving.
- `:116-118`, `:126`, `:138`, `:146` (§2.2 `#Trait`) — same changes as §2.1; `:138` and `:146` cross-reference `#Resource`'s shape and must move with it.
- `:216`, `:222` (§3.1 `#Component` Constraints + Rationale) — **"`metadata.labels` and `metadata.annotations` unify from every attached primitive. Conflicts MUST fail at unification."** This is the union claim D26's correction found has **no implementing code**: `component.cue`'s `_allFields` comprehension unions primitive `spec` bodies only. `:222` restates it as rationale. Either the code grows the union or the spec stops claiming it — this is OQ16's decision surface, and it is normative text today.
- `:252-256` (§3.2 `#Module` Shape) — `nameSnakeCase` and `#KebabToSnake` deleted (D8), `version!` deleted (D2), `modulePath!` regains the major suffix (D1), `fqn` becomes `modulePath` and `#ModuleFQNType`'s semver-with-colon form retires (D1), `uuid`'s `SHA1(OPMNamespace, fqn)` formula is unchanged but its **input changes**, so every module's UUID moves once.
- `:290-293` (§3.2 Constraints) — the `nameSnakeCase` derivation, the author-supplied `version`, the semver-with-colon `fqn`, and the `uuid` determinism statement. Three of the four go; the `uuid` statement stays true and its example changes.
- `:304-307` (§3.2 Rationale) — four arguments, three overturned. `:304` "Why `modulePath` / `version` are author-supplied" (records the closed-struct failure that rules out self-reference — **keep**, D5's alternatives depend on it); `:305` "Why `nameSnakeCase` exists as a derived field" (deleted with the field); `:306` "Why `fqn` uses semver-with-colon while `#Resource` uses `@vN`" (the entry's central reversal — three suffixes now, and this is where they get distinguished); `:307` "Why `uuid` is computed via `SHA1(OPMNamespace, fqn)`" (holds, with a new input).
- `:339-341`, `:352`, `:361`, `:368` (§3.3 `#Blueprint`) — same as §2.1.
- `:405`, `:417-425` (§3.4 `#Platform` Shape) — `#registry`'s key gains `@vN` (D1); `#Subscription.filter?` becomes a required scalar `version!`; **`#SubscriptionFilter` (`:422-425`) is deleted entire** (D14).
- `:436-440` (§3.4 Constraints) — `:438` (`range` MUST be a parseable SemVer constraint) and `:439` (filter resolution order: range → allow → deny) are both **deleted**; `:436`'s one-subscription-per-path rule stays and becomes stronger.
- `:444` (§3.4 Rationale) — the subscriptions-over-inline-registrations argument survives; a new entry is needed for why selection neither resolves nor admits more than one build (D14).
- `:478`, `:491`, `:510`, `:520` (§3.5 `#ModuleInstance`) — `instance.uuid` derives from `module.uuid`, so the formula text is unchanged and the **worked values all move**. `:510` and `:520` are determinism claims that stay true.
- `:539`, `:548-550` (§3.6 `#Catalog` Shape) — `version!`'s `| *"0.0.0-dev"` default deleted (D6), `fqn` redefined (D1), `#CatalogFQNType` retired.
- `:556-563` (§3.6) — the `#transformers` pattern-constraint comment and body: `version` renamed `catalogVersion` in both the prose and the stamp (D25).
- `:574-578` (§3.6 Constraints) — `:575` documents the `0.0.0-dev` default that D6 deletes and `01-problem.md` cites as a mechanism that does not exist; `:577` requires every `#transformers` key to be a SemVer-suffixed `#FQNType`, which stays true for transformers and is what D4 makes *false* for contract keys.
- `:584-587` (§3.6 Rationale) — the `M=metadata` alias argument survives; "why the pattern stamps `modulePath` + `version` but not `fqn`" changes name and meaning under D21/D25; `#CatalogFQNType`'s existence argument goes with the type.
- `:605`, `:615-617`, `:650` (§4.1 `#ComponentTransformer`) — `:605` "Transformers are catalog-versioned. The match algorithm is FQN-keyed" is **half-reversed**: transformers stay build-keyed (D4) while the FQNs they *demand* become contract keys. `:650` cross-references the primitive-metadata shape.
- `:657` (§4.1 Rationale) — "Why match is FQN-keyed and always unifies" cites enhancement 0001 D5/D6 and argues from *distinct SemVers being distinct keys*. Under D4 that premise no longer holds for contracts, and this is where D27's additive-only promise and D30's operand denylist get stated normatively.
- `:658` (§4.1 Rationale) — **the third statement of the false union claim**, and the one that matters most because it is the justification for label-based matching: "Component labels are not authored on the Component itself — they unify upward from every attached `#Resource`, `#Trait`, and `#Blueprint` (§3.1)." Must be reconciled with `:216`/`:222` and with whatever OQ16 decides.

**library**

- `library/opm/helper/loader/internal/shape/shape.go:66` — drop `metadata.version` from `RequiredConcreteFields`.
- `library/opm/helper/loader/registry/module.go` — the module read-side check: the fetched artifact's `metadata.modulePath` must equal the path it was fetched by. Placing it on the `kernel.AcquireModuleFromRegistry` path means the CLI and the operator inherit one implementation.
- `library/opm/helper/synth/instance.go:152` — drop the version clause from the precondition.
- `library/opm/helper/synth/render.go:62` — stops parsing a SemVer for a major the module path states literally. A reduction.
- `library/opm/schema/metadata.go:18`, `context.go:17` — `Version` removed or repurposed to the resolved coordinate; `FQN` doc comment updated.
- `library/opm/materialize` — the catalog read-side check. `materialize.go:93` already builds `catalogBuild{Subscription, Version, Value}`; the resolved version keeps its diagnostic role, and `Resolved` becomes per-major-set rather than a single string (`materialize.go:96` records only the highest survivor today).
- `library/opm/materialize/filter.go` — **D14 deletes the file.** `filterVersions` stops resolving: no `highestStable` default (`:43-47`), no Masterminds constraint parsing, no prerelease inference from constraint syntax (`:31-42`), no allow/deny arbitration. What is left is a single major-agreement check on one string, which belongs beside the subscription rather than in a file of its own.
- `library/opm/materialize/index.go:76-90` — **D32.** The reverse index gains the check: a `{resources,traits}` bucket that ends up holding more than one transformer is a `MaterializeError` naming both catalog paths and the contract key. The provenance needed is already in hand — `indexCatalogs` loops over `catalogBuild{Subscription, Version, Value}` (`:21`), so the owning catalog is structural and never has to be parsed back out of a transformer FQN. That matters because D17 makes "a primitive sits under its owning catalog's path" a publish gate rather than a schema constraint, so FQN-derived provenance is not guaranteed.
- `library/opm/compile/match.go:138-157` — **D32, by omission.** The candidate loop pairs *every* transformer in a bucket that unifies and satisfies the predicate; `matched` is keyed by transformer FQN, so two build-keyed transformers are two keys and both render. No arbitration is added here. The loop is left as written because D14 and D32 together guarantee the bucket holds at most one entry before it is ever read.
- `library/opm/materialize/types.go:58` — `MaterializedPlatform.Resolved` keeps its diagnostic-only contract and loses its remaining ambiguity: it now records what the platform *said*, not what the kernel *chose*, because those are the same value. Its doc comment's "when a filter selects several versions … this is the highest survivor" is no longer reachable.
- `library/opm/materialize/index.go:57-64` — the comment stating that distinct versions yield distinct FQNs stays **true for transformers under D4**, which is why transformer keys keep the build: it is what stops two builds of one catalog colliding in the composed map, and it is the mechanism that made catalog-major transformer keys unworkable. Under D14 the collapse branch it guards becomes unreachable for two builds of *one* catalog, since a subscription materializes one — it stays as written for the case its comment already calls defensive, two different catalogs stamping one `modulePath`, which D17 prevents at publish and not in the schema.
- `library/opm/compile/match.go:247-273` — **the always-unify rung becomes load-bearing (D26, D27, D30).** It must exclude provenance from both operands before unifying, and it must keep the closed definition in the comparison; `experiments/02` measures that cutting at `spec` instead silently drops a field the module set whenever the catalog wrote its spec body inline. Under D30 the exclusion is a denylist (`catalogVersion`, `description`) applied by rendering each operand to syntax, deleting those fields from every `metadata` block, and rebuilding — `experiments/03` measures that the round-trip preserves closedness in both spec-body styles, and that the leading segment of a CUE error path becomes `_#def.` while the field path survives.
- `library/opm/compile/match.go:130` — the diagnostic. A missed contract key reports either "nothing on this platform implements this contract" or "this platform implements it at a different apiVersion", in place of a bare `no matching transformer`. `alternativesFor` (`:275`) keeps its shape and changes what it enumerates.
- `library/opm/compile/match.go:130`, `module.go:124` — **D28.** `plan.Missing` gains its first production consumer and a miss fails the render; resources gain the `UnhandledResources` counterpart that `UnhandledTraits` has had all along, with the trait opt-out as the only path back to a warning.
- `library/opm/kernel` — stamp `module.opmodel.dev/version` on the render path from the resolved coordinate.
- `library/opm/compile/module.go:137` — **must keep consuming `mp.Transformers` as read-only input from a separate resolver.** A module's primitive definitions have to resolve through the module's own dependency graph. Under D4 the failure this prevents changes shape but not severity: a single-build render would put the module and the platform in one CUE build, minimal version selection would pick the maximum, and the module's own copy of every contract definition would silently become the platform's — so the always-unify rung, which under D26/D27 is the only thing checking that the two agree, would be comparing a value against itself and could never fail. See `05-risks.md`.

**cli**

- `cli/pkg/module/module.go:69-108` — `CanonicalModuleRef()` reads `ModulePath` directly; `majorVersionTag()` / `ensureVPrefix()` lose their caller.
- `cli/internal/workflow/apply/apply.go:273`, `thineditor.go:112` — write the coordinate actually fetched into `spec.module.{path,version}`. This is where the silent-downgrade defect is fixed.
- `cli/internal/workflow/render/log_output.go:40` — logs the resolved coordinate.

**catalog repos** (`catalog_opm`, `catalog_kubernetes`, `catalog_opm_experimental`)

- `src/identity/identity.cue` — `ModulePath` gains `@vN`; `Version` becomes a committed concrete SemVer or an open field; neither carries a marker attribute (D5). The `version_override.cue` stamping generator and the `0.0.0-dev` sentinel are retired. The package also gains `RegistryPath` and `Major`, derived from `ModulePath` via `strings.SplitN`, so no leaf splits a major (D21). Its "import-free" doc comment becomes "free of intra-module imports" — `strings` is a CUE builtin and adds no edge to the module graph.
- `src/catalog.cue` — `metadata: modulePath: id.ModulePath` and `metadata: version: id.Version`. `#Catalog.metadata.version` keeps its name: it is the catalog's own release version, and it is `catalogVersion`'s source rather than a second spelling of it.
- Leaf files change three lines (D21, D4, D25): `modulePath` reads `id.RegistryPath` instead of `id.ModulePath` — a one-token edit forced by `ModulePath` now carrying `@v1`; `version: id.Version` becomes `catalogVersion: id.Version`; and each primitive authors its own `apiVersion` plus an `fqn` interpolating it, `fqn: "\(id.RegistryPath)/<kind>/\(name)@\(apiVersion)"` for a contract and `…@\(id.Version)` for a transformer. `apiVersion` is the one value that is **not** derived from the identity package, but D34 makes it mechanical anyway by settling it per catalog rather than per primitive: `v1beta1` for every contract in `catalog_opm` (38) and `catalog_kubernetes` (27), `v1alpha1` for `catalog_opm_experimental`'s 3. Transformers take none. Import statements are untouched: intra-module imports omit the major suffix (verified — `catalog_opm/cue.mod/module.cue` is `opmodel.dev/catalogs/opm@v1` while every leaf imports `opmodel.dev/catalogs/opm/identity` with no suffix), so a major bump churns no import.

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
// written by opm module publish
metadata: modulePath: "opmodel.dev/m/acme/jellyfin@v2"
```

`module.cue` declares `name: "jellyfin"` and nothing else about identity. `fqn` is that path; the UUID is stable across every 2.x release and distinct from any v3. The tag is the only version in the system, and it is what the CLI records in `spec.module.version`.

**Catalog.** Before, `catalog_opm`'s committed tree resolves `Version` to `0.0.0-dev` and publish writes a real value into a copy, so a local render demands `…/transformers/deployment@0.0.0-dev` while the registry supplies `…/transformers/deployment@1.0.0`.

After, `src/identity/identity.cue` holds:

```cue
// written by opm catalog publish / opm catalog version set
ModulePath: "opmodel.dev/catalogs/opm@v1"
Version:    "1.2.0"
```

Every value it ships is computed from those two lines, identically from a checkout and from the registry — which is the divergence D5/D6 remove. Its transformers key on the build (`…/transformers/deployment@1.2.0`); its resources, traits and blueprints key on their own contract majors (`…/resources/config-maps@v1`), which do not move when `1.2.0` is published.

**Contract.** Before, a generic `backup` resource in `catalog_opm` and a `k8up` provider catalog implementing it can only meet if both were compiled against the *same* `catalog_opm` build — so every `catalog_opm` release breaks backups until the provider re-releases and every module is rebuilt to match.

After, the module demands `opmodel.dev/catalogs/opm/resources/backup@v1` and the provider requires that same string, whichever `catalog_opm` build either was compiled against. The two catalogs release independently. If the provider is older than the contract the module uses, the render fails naming the field the provider cannot honour; if the module stays inside what both builds share, it renders (D27, measured in `experiments/02`). If no subscribed catalog implements the contract at all, the render fails naming the platform's missing provider rather than silently producing no backup (D28).
