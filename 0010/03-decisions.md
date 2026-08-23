# Design Decisions — Module and Catalog Identity

This document records every significant design choice with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent** — never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes. The *text* under a number states what is true now: a reversal is recorded as its own `DN` while the design is in motion, then woven into the decision it changes at the next compaction pass — the merged decision keeps the lower number, and the vacated number keeps a one-line tombstone. See the `enhancement-compaction` skill.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source.

---

## Decisions

### D1: An artifact's `modulePath` is its complete CUE module path; a primitive's is a package path

**Decision:** `#Module.metadata.modulePath` and `#Catalog.metadata.modulePath` carry the artifact's full CUE module path **including the major suffix** — `opmodel.dev/m/acme/jellyfin@v2`, `opmodel.dev/catalogs/opm@v1` — rather than a bare prefix that must be recombined with a name. `metadata.fqn` is that same string. `uuid: SHA1(OPMNamespace, fqn)` keeps its formula with a version-free, major-bearing input, and `instance.uuid` is unchanged.

`#Resource`, `#Trait`, `#Blueprint` and `#ComponentTransformer` type `metadata.modulePath` as a **package path** — a plain path with no `@vN` suffix, which is what `core` types it as today. Artifacts and primitives take separate types, `#ModulePathType` and `#PackagePathType`, rather than sharing one widened type.

Three facts force that split rather than taste. A primitive's major is **structurally redundant**: a `@vN` module publishes `vN.*` tags, so a primitive carrying a build SemVer already states its catalog's major, and no collision is admitted by dropping it — a `@v1` build and a `@v2` build cannot publish the same SemVer. It is **not a module path**: `opmodel.dev/catalogs/opm/resources@v1` is a string nothing writes, because a consumer imports `opmodel.dev/catalogs/opm-experimental/resources` with no suffix (`modules/metallb/components.cue:23`, `modules/cert_manager/components.cue:31`) and CUE resolves the major from the `deps` block. And **nothing read it**: `schemas/target.cue`'s `#PrimitiveIdentity` once typed `modulePath!: #ModulePathType`, built `_ref: #ArtifactRef`, then derived `fqn` from `_ref.registryPath` — stripping the major straight back off, with `_ref.major` computed and never consumed.

**Alternatives considered:**

- **One widened `#ModulePathType` shared by artifacts and primitives — originally adopted here, then amended.** This is how the decision was first implemented, and the defect was that every field typed with it inherited a requirement it has no use for: a major nothing reads, that the build SemVer already encodes, and that makes a primitive's declared path a string no `import` statement uses. Typing a package path as a module path is a category error the single-type widening introduced by accident.
- **A bare prefix plus a separate `major` field.** The smallest change, and it does put the major back in identity. Rejected: it adds a *second* identity fragment that must be kept in step with `cue.mod` while leaving the prefix-plus-name recombination intact — paying for the major without simplifying anything else.
- **`modulePath/name` with no version component at all.** Rejected: it collapses two incompatible majors into one identity, which is the collision major suffixes exist to prevent. Go states the reasoning outright — the suffix is what lets a toolchain treat two majors as genuinely distinct modules.
- **Drop the major from artifact paths too, for uniformity with primitives.** Rejected on each artifact's own grounds. For a module, D2 removed the version field entirely, so the path is the only thing distinguishing `@v1` from `@v2`. For a catalog, the path *is* the registry address and the `#registry` subscription key the major is read from.
- **Deriving the major inside CUE from the artifact's own `cue.mod/module.cue`.** Measured 2026-07-26 (cue v0.17.1): `@extern(embed)` plus `_raw: _ @embed(file="cue.mod/module.cue", type=text)` plus `regexp.FindSubmatch` yields `"v2"`, and it survives publishing because `cue.mod/module.cue` ships inside the artifact zip (confirmed by unzipping `opmodel.dev/modules/jellyfin@v2` tag `v2.0.2`). Rejected on user decision, and independently constrained: `@embed` resolves relative to the *embedding file's own directory* and cannot escape upward (`../cue.mod/module.cue` fails with `@embed: cannot refer to parent directory`), so `core` cannot do it on a consumer's behalf and every artifact would carry attribute-and-regex boilerplate.

**Rationale:** For the artifact half, this is the only candidate that makes something else *simpler* rather than only paying for the major. The declared path already is the registry address, so the address becomes recoverable by reading one field; the "path leaf equals the artifact's name" constraint becomes a statement about a single field rather than a relationship between two independently-authored ones; and the value an author sees is the string CUE, the registry, and the `import` statement already agree on.

For the primitive half, the major belongs where it is load-bearing and nowhere else. It is load-bearing on an artifact's path, because that path is an address and, for modules, the sole carrier of major identity. It is inert on a primitive, whose key carries a version that already implies it.

**Consequences of the primitive half, all reductions.** Primitive `modulePath` values are unchanged from what ships today, so the migration touches two fields rather than every field sharing a type. `kindPrefix` loses its major re-append. `#Catalog`'s `#transformers` pattern constraint splits the major out and stops, rather than splitting it out and re-appending it. D17's publish gate compares a primitive's path against the catalog's `RegistryPath` rather than its `ModulePath`, which it must do or the check compares a plain path against one ending `@v1` and never matches.

**Source:** User decision 2026-07-26.
**Revised:** 2026-07-30 — absorbed D20 (2026-07-27), which narrowed the type widening to artifacts only.

### D2: A module declares a version, supplied by an identity subpackage

**Supersedes:** D23

**Decision:** `#Module.metadata.version` exists, required, typed `#VersionType`. **Neither `fqn` nor `uuid` reads it.** That exclusion is the whole of what makes this safe, and D41 states it precisely, split in two because a single sentence about "the version" is both imprecise and incomplete — the *major* does reach `fqn` and `uuid`, through the module path, and the value that actually protects `prune.go` is the **instance** UUID rather than the module's:

> **Module artifact identity** — `#Module.metadata.fqn` and `.uuid` distinguish majors and nothing finer. The major reaches them through the module path; minor and patch reach them not at all.
>
> **Instance identity** — `#ModuleInstance.metadata.fqn` and `.uuid`, which carry the owner label `prune.go:107` reads, derive from the module's major-free `registryPath`. Neither the version nor the major reaches them, so an instance survives every upgrade of the module it deploys, a major bump included.

Minor and patch reach neither `fqn` nor `uuid`, and a change wiring them in restores a silent orphaning — `opm-operator/internal/apply/prune.go:107` skips any delete whose live owner label disagrees with `Status.InstanceUUID`, which `reconcile/moduleinstance.go:308` repopulates from each new render.

A module gets a catalog-style identity subpackage: `identity/identity.cue`, `package identity`, exporting **both** `ModulePath` and `Version`. The module's root package consumes it — `metadata: {modulePath: id.ModulePath, version: id.Version}` — so a release moves both values by one edit, exactly as a catalog's does. Module and catalog identity files thereby share placement and shape; the asymmetry D23 held is retired.

**`core` cannot enforce the wiring, so publish does.** `#Module` has no way to reference an arbitrary module's identity package, so the derivation is established by the template `opm module init` generates. CUE then enforces it for free while the derivation is written — an author who edits the literal gets `conflicting values` at `cue vet`. An author who *replaces* `id.Version` with a literal leaves nothing to conflict with, and that case is caught by enhancement 0011 D12's publish check comparing `metadata.version` against `id.Version`.

**The read-side check extends to the version, and D9 owns it.** With a declared version present, an acquired artifact's `metadata.version` can be compared against the tag it was fetched by — a comparison that is impossible while no version is declared. This decision made the comparison available; D9 adopts it.

**Alternatives considered:**

- **No module version at all — `#Module.metadata.version` does not exist.** **Originally adopted here (2026-07-26), then reversed 2026-08-03.** A module's source declared `modulePath` and `name` and nothing about its version; the full version existed only as the OCI tag, with the major in the module path per D1. Deletion removed the drift by removing the field, and it defused the orphaning failure of its day, because `fqn` then interpolated `version`. Both reasons were later answered structurally rather than by absence — D1 took the version out of `fqn`, D41 took the module's UUID out of instance identity, and 0011 D12's publish assertion answers the drift. What deletion also removed, unintentionally: the only place a module's version could be *seen before it became permanent* (catalogs kept `version set` and a reviewable diff; modules were left with a flag on a command), and any filler for `#moduleInstanceMetadata.version` (`core/src/transformer.cue:105`, non-optional) on a module rendered **from disk**, which has no coordinate. Recorded so the case is not overstated: measured 2026-08-03, no shipped transformer reads `.version` — 117 uses of `#moduleInstanceMetadata` across the three catalogs, all `.name` or `.namespace` — so nothing broke either way; the choice was about which design leaves a declared field with no filler.
- **Keep module and catalog identity files at different placements** — root-package `identity.cue` writing `metadata:` directly per D7, no subpackage. **Originally adopted as D23 (2026-07-29), then reversed 2026-08-03.** It rested on the module half of the writer having nothing to decide, which was true only while a module declared no version, and on the self-import being authored duplication, which `opm module init` makes generated. The self-import cost D23 measured is real and unchanged: intra-module imports omit the major, so a *major* bump churns no import, but they carry the path prefix, so a namespace migration rewrites one more site in every module. The converse convergence stays structurally unavailable: a catalog cannot move to a root-package file, because leaves importing a root-supplied constant makes root and leaves import each other — `package import cycle not allowed`, measured (D5).
- **Keep the field with no subpackage and enforce that it equals the release tag.** Rejected at deletion time as policing a problem rather than removing it — a publish-side derivation, a read-side check, a version-authoring command, and a permanent invariant every future tool must respect. That machinery is exactly what enhancement 0011 built for catalogs regardless, which is what made restoring the field cheap: the enforcement (0011 D12, D9) exists whether or not a module declares a version.
- **Keep `version` as a declared-but-never-authored field, injected at acquire from the resolved tag** — equivalently, restore the field but derive it in `core` from the fetched coordinate. Rejected twice, both times for the same reason: a value that exists only after a registry fetch leaves a disk-read module with no identity — and a declared field will eventually be written to by someone.
- **A hidden `_version`,** written at publish or authored in the root package. The publish-written form puts bytes in the artifact that do not exist in source — the mechanism measured producing local-versus-published divergence — and `core/SPEC.md:304` records that an undeclared member of the closed `#Module` breaks re-unification into `#ModuleInstance.#module` with "field not allowed", invisible to `cue vet` on a standalone module. The authored form (which D7 sanctions as an indirection) delivers an authoring seam while keeping the version out of the published artifact, and the published artifact is where the instance reads it from.
- **A top-level `Version` in the module's root package,** mirroring the catalog's exported constant without a package boundary. Rejected on D7's measurement, unchanged and still the reason the subpackage is the shape: it vets clean standalone and fails only at re-unification into the closed `#ModuleInstance.#module` slot.
- **A subpackage exporting only `Version`,** leaving `modulePath` written directly per D7. Rejected as the worst of both: it pays the self-import cost without buying the consistency that justifies paying it.

**Rationale:** The field was first deleted because a module's version was drifting from its tag, and because `fqn` interpolated `version`, so a genuinely-moving version silently orphaned whatever an upgrade removed. The second reason is what made deletion urgent, and D1 removed it independently — `fqn` is the module path, with no version in it. Restoring the field with the orphaning path structurally closed keeps the property deletion wanted — the tag and the declared value cannot drift, because publish asserts them equal — while giving modules the authoring seam catalogs never lost. The consumer that decided it: an instance derives its version from the module and declares none of its own (`library/opm/module/instance.go:110`'s `ModuleVersion()`; `core/src/module_instance.cue`), and a module rendered from disk has no coordinate to fill it from — the deletion's own argument, turned around.

**Source:** User decision 2026-07-26.
**Revised:** 2026-08-10 — absorbed D38 (user decision 2026-08-03, which restored the field this decision originally deleted; instance-derives-from-module verified at `library/opm/module/instance.go:110` and `core/src/module_instance.cue`, transformer-context exposure at `core/src/transformer.cue:101-109`, catalog reader set measured across `catalog_opm`, `catalog_kubernetes` and `catalog_opm_experimental` 2026-08-03; command surface and publish check are enhancement 0011 D12) and D23's placement holding, reversed by the same decision. Both numbers tombstoned; the original no-version position survives above as a previously-adopted alternative.

### D3: `#Catalog` keeps a full SemVer `metadata.version`, declared concretely in committed source

**Decision:** `#Catalog.metadata.version` is a full SemVer, declared concretely in committed source, with no default.

**What the value is *for* changed twice; the current answer is the third.** As originally decided it was a compatibility *signal* feeding a floor — a module recorded which catalog build it was authored against and the kernel compared that against what a platform materialized. D13 removed the floor's reader and D24 removed its reason; D10 records the retirement. What the value does now is supply **build keys and provenance**: it is interpolated into every transformer FQN as D24's implementation key, and it is stamped onto every primitive as `catalogVersion` under its D25 name. That is also what makes D6's refusal to give it a default load-bearing rather than fastidious — a sentinel version would be interpolated straight into a published key.

`#Module` and `#Catalog` remain **not symmetric**, though the asymmetry is now one of *meaning* rather than of shape — both declare a version from an identity subpackage (D2). A catalog's version names bytes that other artifacts key against; a module's version keys nothing at all and is read only by the instance that derives from it.

**Alternatives considered:**

- **Remove the catalog version too, for symmetry with D2.** Rejected originally because it left the floor unfed, and the rejection survives on stronger grounds: under D4 a transformer's FQN interpolates this value, so removing it would leave implementation keys with nothing to name their own bytes.
- **Let each primitive declare its own version.** Rejected: it turns one catalog-level fact into N author-maintained ones and reintroduces per-primitive drift inside a single published artifact. Worth distinguishing from what D24 later adopted deliberately — `apiVersion` *is* authored per primitive, but it is a different value with a different job (a contract major, not a build), and `catalogVersion` stayed catalog-level exactly as decided here.

**Rationale:** A catalog's declared version is the one identity value on a catalog that a consumer can key against, so it has to be concrete, committed, and honest about the bytes it names. Whether it also served as a compatibility floor turned out to be separable from that, and the floor did not survive; the concreteness requirement did, and D24 made it load-bearing in a way the original decision did not anticipate.

**Source:** User decision 2026-07-26.
**Revised:** 2026-07-30 — the floor role this decision was originally taken for was retired by D13 and D24; restated to what the value carries under D4/D25. No content merged in; D3 survives in its own right.

### D4: A contract is keyed by its own API version; an implementation is keyed by its build

**Decision:** `#Resource`, `#Trait` and `#Blueprint` FQNs are `path/name@vN`, where `vN` is a **per-primitive API version** — that primitive's contract major, moved when its shape breaks, independent of the catalog's module major and of the catalog's release SemVer. `#ComponentTransformer` FQNs carry the full SemVer of the build they shipped in. There are therefore two FQN types, split by role rather than by taste.

The split follows the demand direction. A module demands **resources and traits** and never demands a transformer, so the contract surface is the one that has to be stable across builds; the implementation surface is the one that wants provenance and a distinct composed-map key per build. A platform's transformer map stays keyed by build; the matcher's reverse index is keyed by contract.

**The failure that forced this shape, and it is not hypothetical.** Walked 2026-07-29: `catalog_opm` defines a generic `backup` resource and trait with **no transformer of its own**, because the contract is meant to be fulfilled by whatever provider a platform installs; a `k8up` provider catalog ships the transformer that requires it. Under build-keyed contracts the demand key is `…/opm/resources/backup@1.1.0` — the exact `catalog_opm` build the *module* compiled against — and the supply key is whichever `catalog_opm` build the *provider* compiled against, fixed by the provider's own `cue.mod` because `materialize/pull.go:23` loads each catalog as its own root. They must be **equal**, not compatible. Subscription breadth cannot repair it: subscribing to every `catalogs/opm` build supplies every build's own transformers, and `backup` has none, so `catalogs/opm` contributes nothing to that bucket at any version. Coverage is instead the set of `catalog_opm` versions the provider's release history happens to have pinned — one per provider build. Every `catalog_opm` release therefore breaks backup for modules that adopt it until the provider re-releases and the module is rebuilt to match: an N×M lockstep between two independently-released catalogs.

**Alternatives considered:**

- **Catalog-major keys for every primitive, transformers included — originally adopted here, then reversed.** One `@vN` per catalog, so a catalog's whole compatible series shares one key space and cross-minor installs work by construction. Two independent defects killed it. **Reproducibility:** every installed module keys to `@v1`, so publishing catalog `1.3.0` changes the transformer bodies every already-installed module renders against — nobody edited a module and the output moved, which for a system reconciling continuously under GitOps makes "cross-minor just works" and "a catalog release silently changes every render" the same sentence. It also degrades worse under the failure OPM cannot control: a publisher who breaks compatibility inside a major poisons *every* installed module at once rather than only those built after the bad release. **Granularity:** one version namespace for every primitive in a catalog means breaking one trait's shape requires a catalog major bump — a new module path, a new import in every consumer, a whole-catalog migration — so in practice it never happens and "v1 means v1" becomes unenforceable by construction. A per-primitive API version is what gives a catalog a legitimate, cheap way to break one contract on purpose, which is the only thing that makes D27's promise keepable.
- **Full-SemVer keys on every primitive, with cross-minor installs supplied by subscription breadth — subsequently adopted, then reversed.** A primitive's key named the exact catalog build its definition came from, and a platform subscribed to a major materialized every published build in it, so each module matched the key the build it was authored against shipped. Publishing added a key space rather than altering one. Rejected on the cross-catalog coverage failure above: it works only by coincidence of release timing, and the remedy its diagnostic implies — "rebuild your module against whichever catalog build your platform's provider was compiled against" — points at the wrong party and is not an action a module author should ever be asked to take.
- **Key by `MAJOR.MINOR` (`@v1.2`).** Collapses patches, which are non-breaking by definition, so the collapse is safe. Rejected as strictly a build-count optimisation: minors are also additive under SemVer, so cross-minor matching still needs multi-build subscriptions, and the scheme buys a smaller materialized set at the price of a third version spelling nobody else uses.
- **A semver-range-aware matcher** — teach matching that a `@1.5.0` supply satisfies a `@1.4.0` demand. Rejected at every revision of this decision, and for compounding reasons: it turns an O(1) keyed lookup into constraint solving, re-implements the resolution CUE already performs for module dependencies, leaves every FQN string churning on each release, and does not address the cross-catalog case at all — the provider's key is not a range either.
- **Normalize to major at match time**, leaving SemVer FQNs in the schema. Rejected: it creates two notions of FQN — the string the schema declares and the key the matcher uses — which is exactly the declared-versus-effective split this entry exists to remove.
- **Demand primitives by path with no version at all.** Rejected: it gives up the ability to express a major incompatibility, which is the one version distinction that carries real meaning.
- **Major keys for transformers too.** Rejected on the mechanism that killed catalog-major keys generally: two builds of one catalog collide on one composed-map key and `materialize/index.go:64-70` raises `transformer %q diverges across selected builds` for any transformer whose body changed. Keeping the build in the transformer key keeps `index.go`'s stated invariant true.

**Rationale:** The two surfaces answer to different parties and should not share a key shape. What a module writes against is a *contract* — it should survive a catalog release, because a catalog release is not an act of the module author's. What a platform executes is an *implementation* — it should name its own bytes, because an operator upgrading a catalog is choosing new rendering logic.

The reproducibility argument that killed catalog-major keys survives this shape and is not discarded — it is **relocated**. Under build-keyed contracts the key did the pinning: a module's authorship pin selected the transformer build permanently. Here the key pins nothing, so the platform's subscription must, which is D14. Correctness mostly survives without it, but not unconditionally, and the asymmetry matters: under D27 a supplier build is a safe substitute when its contract surface is a **superset** of the one the module compiled against — same build or newer — while an **older** supplier is safe only while the module stays inside the fields that build already had, and fails loudly (`spec.backup.retention: field not allowed`) the moment it does not. Byte-stable renders get no such protection in either direction.

This shape also buys a capability neither predecessor could express: two API versions of one primitive shipping **side by side** in a single catalog build, the way Kubernetes serves `v1beta1` and `v1`. Providers implement the new one when ready, modules migrate when ready, both keys sit in the index at once, and the old contract retires when nothing demands it. Under SemVer keys every release breaks every key, so a deliberate break is indistinguishable from a patch.

**One reversal is worth stating plainly, because this decision has flipped twice.** `core/src/types.cue:41-44` records that FQNs were lifted major-only → SemVer under enhancement 0001 D5, so that two builds of the same primitive at adjacent versions occupy distinct keys and divergent definitions surface as structured errors rather than colliding on a major bucket. That goal is accepted throughout; only the mechanism moved. The useful output is a statement of which failure this project prefers — a catalog release that cannot reach an installed module (loud, fixable by editing a subscription) over a catalog release that silently changes one (quiet, detectable only by comparing renders) — and D27 plus D28 are what make the first failure loud rather than merely likely.

**Source:** User decision 2026-07-26.
**Revised:** 2026-07-30 — absorbed D13 (taken 2026-07-27), which replaced catalog-major keys with full-SemVer keys and subscription breadth, and D24 (taken 2026-07-29), which split the key by role after the cross-catalog `backup` walk. Both numbers were retired in the 2026-07-30 compaction pass, which is the leading date here and the one their tombstones carry; the parenthesised dates are when each decision was taken. Cross-catalog coverage read from `materialize/pull.go`, `materialize/filter.go` and `compile/match.go` 2026-07-29; match-time mechanics measured in `experiments/02-primitive-closedness-skew/`.

### D5: Identity lives in a committed, visible `identity.cue`, located by schema path

**Decision:** An artifact's identity file is **committed to git and visible to developers**. OPM tooling *writes into it* — the way `npm version` writes `package.json` — rather than generating it behind the developer's back.

Tooling locates the fields it writes by their **schema-fixed path**, and identity fields carry no marker attribute. For both artifact types that is `identity/identity.cue`'s `ModulePath` and `Version`, which `#IdentityPackage` defines (D2 converged modules onto the catalog's subpackage shape). A field whose name or location disagrees with the schema is a `cue vet` failure, not a case for tooling to accommodate.

Placement is the same for both artifact types: `identity/identity.cue` as an importable subpackage. For a **catalog** the shape is forced by package topology — its `resources/` and `transformers/` leaves compute their own FQNs at their own definition sites, and a root-supplied constant makes root and leaves import each other (`package import cycle not allowed`, measured). For a **module** it is chosen for symmetry and for the version-authoring seam (D2); the root package wires `metadata` to the subpackage's exports.

**Alternatives considered:**

- **An inert `@opm(identity, owner=publish)` marker on every identity field — originally adopted here, then dropped.** Its stated job was that tooling could locate what it owns without hardcoding names, and that job was measured not to exist: `0011/experiments/01-version-set-write-back` found 7 of 8 cases resolving `found by name-fallback`, because the attribute says a field *is* identity and who owns it, never *which* field it is. `experiments/01-identity-marker-discovery` finding 3 established that a consumer can never see it in any case — a reference does not carry the attribute of the declaration it points at. `owner=publish` was separately contradicted by D6, which supports an author managing the version by hand, making publish *an* owner rather than *the* owner. And nothing ever depended on it: `#IdentityPackage` carried it only in comments, so no gate validated it and `task vet` could not have noticed its absence.
- **Adding a `role` argument** — `@opm(identity, role=version|modulePath, owner=publish)`, recommended as load-bearing by both entries' experiment 01. Rejected: its only advantage over a schema-path lookup is tolerating a field the author renamed, and a renamed identity field should fail `vet` rather than be found anyway. It pays a permanent attribute on every identity field to accommodate a state the schema forbids.
- **Keeping the marker as documentation only.** Rejected as an *attribute* and accepted as a *comment*. A line reading `// written by opm catalog version set` tells the reader the same thing and costs nothing to anyone else.
- **`@tag()` injection at build time.** Rejected on measurement (2026-07-26, cue v0.17.1), and the failure is worse than predicted. Injection does not propagate into an imported package **at all**: `cue eval ./mod -t modulePath=example.com/real-module@v2` sets the module's own value and leaves the imported catalog reading its uninjected default, identical to the uninjected run. The anticipated failure was a *collision* — two artifacts declaring the same tag both receiving one string. That does not happen, because injection never reaches that far. The real failure is quieter: the transitive dependency keeps its placeholder, every FQN it derives is built from it, and nothing reports that an injection was ignored. Since a module always reaches its catalog through CUE's own resolution, the kernel can never supply a catalog's identity this way however well it knows the coordinates.
- **Gitignored generation into the artifact's own package.** Technically sound; the value resolves correctly when the file is present, and its absence fails legibly (`ModulePath: incomplete value string`). Rejected on transparency: the value lives in a file the developer never wrote and cannot see in git. It also makes a fresh clone unvettable by plain `cue` until an `opm` command has run.
- **A committed marker with a gitignored value.** Same rejection with less benefit: it makes the *field* visible without making the *value* visible.

**Rationale:** The reason is transparency, not mechanics. A committed file is documentable, diffable, reviewable in a PR, and greppable. A developer reading an artifact can see where its identity comes from and open the file that supplies it.

The technical constraint that rules the alternatives out is separate and was measured: identity must be present in the artifact's **own bytes**, because CUE's dependency resolution is what carries it to consumers and OPM does not mediate that. A committed value resolves correctly through a transitive import under plain `cue eval` with no flags and no OPM tooling in the loop, and `cue vet -c` passes.

Locating a field by its schema-fixed path is not the hardcoding a marker would have avoided. The file path and the field names *are* the contract this entry defines; reading them is honouring it rather than guessing at it. `experiments/01-identity-marker-discovery`'s own closing sentence is the argument: "What a reader relies on is the schema."

**Source:** User decision 2026-07-26.
**Revised:** 2026-07-30 — absorbed D22 (2026-07-29), which dropped the `@opm()` marker. D5's committed-and-visible half is unchanged.
**Revised:** 2026-08-10 — the placement half restated: the per-type asymmetry this decision first recorded (module root-package file vs catalog subpackage, later re-affirmed as D23) was reversed by the decision now stated at D2, which converges both types on the `identity/` subpackage.

### D6: An identity field may be left open, and an open field is an absent value rather than a placeholder one

**Decision:** An identity field may be declared **open** (`ModulePath: string`) or **concrete** (`Version: "1.2.0"`), at the author's choice. Both forms are committed. `opm … version set <semver>` and `opm … publish --version <semver>` write a concrete value into the field either way, so the choice is a workflow preference rather than a mode the tooling must track: what matters is whether the field holds a value right now.

The published artifact always carries concrete values. In a working tree, an unfilled field is an **absent value**, not a placeholder one — there is no `0.0.0-dev`, no sentinel, and nothing that renders successfully while being wrong.

**Measured 2026-07-26 (cue v0.17.1).** `cue vet -c` on an unfilled tree names the field and the file:

```
Version: incomplete value string:
    ./identity/identity.cue:7:10
builtAgainst: incomplete value string:
    ./identity/identity.cue:7:10
    ./mod/mod.cue:6:15
```

Filling the field — by an in-place edit or by a sibling file in the same package — produces byte-identical consumer values either way.

**`ModulePath` and `Version` do not share a lifecycle, and the design depends on that.** `ModulePath` is *derivable* at any time from `cue.mod/module.cue`: offline, deterministic, idempotent, and unchanged except when `cue.mod` changes. `Version` is a *decision* that only an explicit command knows. So `ModulePath` is filled by any `opm` command that touches the tree and is effectively always concrete, while `Version` is the only field genuinely left open in ordinary development. That split is load-bearing: with `ModulePath` concrete, **every FQN still evaluates in an unfilled tree**, so the match key space is intact and only the compatibility signal is missing. With `ModulePath` open, `strings.SplitN` over a non-concrete string returns an empty list and the FQN derivation fails with `index out of range [0] with length 0` — a useless error pointing at the wrong thing.

**Alternatives considered:**

- **Require a concrete value in source, always.** Rejected: it forces a version decision at authoring time and gives release automation nowhere to put its answer without a second writer.
- **A sentinel default (`0.0.0-dev`) for the unfilled state.** Rejected on measurement. A sentinel is a *value*: it evaluates, it renders, it flows into FQNs and labels, and both the sentinel tree and the published tree `cue vet` clean, so only a cross-tree comparison reveals that they disagree. An open field cannot do this — CUE refuses to build on it and names the file and line.
- **A dev-version placeholder computed from the registry** — take the highest published tag in the major, bump the patch, append `-dev`. Rejected: it makes local rendering depend on live registry state, so the same tree rendered before and after someone else publishes produces different output, and that value reaches a resource label. It also puts a resolution-time fact into committed source, which is the class of value D9 exists to keep out.

**Rationale:** The failure mode is the whole point. Every mechanism that supplies a *value* for the unfilled state makes "nobody set this" indistinguishable from "somebody set this" at every point downstream. Absence propagates as absence, fails at the first operation that needs a string, and names the field responsible.

**Source:** User decision 2026-07-26.

### D7: A module's identity file writes `metadata` directly and declares no top-level field

**Decision:** A module's `identity.cue` sets `metadata: modulePath: "…"` directly. It must **not** introduce a top-level field (`ModulePath: "…"`) alongside the embedded `#Module`, and a hidden field (`_modulePath`) is acceptable if an indirection is ever wanted. Catalogs are unaffected: their identity is a separate package and is never unified into `#Catalog`.

**Measured 2026-07-26 (cue v0.17.1), and this is why the decision exists.** A top-level field in the module's own package vets clean standalone and fails only when the module is unified into the closed `#ModuleInstance.#module` slot:

```
inst.#module.ModulePath: field not allowed:
    ./mod/identity.cue:3:1
```

A hidden `_modulePath` and a direct `metadata:` write both pass both checks.

**Alternatives considered:**

- **A top-level `ModulePath` field for symmetry with the catalog's identity package.** Rejected on the measurement above. The symmetry is cosmetic and the failure is delayed: it passes every check an author runs on the module alone and surfaces only downstream, in a different repo's code path.
- **Give modules a catalog-style `identity/` subpackage.** Rejected: modules have no structural need for one — the workspace modules are single-package, so nothing computes an FQN from a module-wide constant across a package boundary and there is no cycle to break. Referencing a subpackage would also require the author to write the module's own path in an `import` statement, relocating the duplication rather than removing it.

**Rationale:** The `#Module` definition is closed, and the closure is only enforced at the point of re-unification. A design that puts a stray field in the module's own package is a design whose defect is invisible to the person who would introduce it.

**Source:** Measured 2026-07-26; recorded as a design constraint on D5's module half.
**Revised:** 2026-08-03 — **partially superseded by the decision now stated at D2** (originally recorded as D38). The *measurement* stands and is load-bearing: a top-level field beside the embedded `#Module` in the module's root package still fails at re-unification with `field not allowed`. What changes is the conclusion drawn from it — D2 gives modules a catalog-style `identity/` subpackage (the second alternative above, later adopted), which is the shape that avoids the failure, so `metadata:` is now written from an imported package rather than authored directly.

### D8: `metadata.name` is snake_case, and the module path's leaf equals it

**Decision:** `#Module.metadata.name` is authored in **snake_case** (`#SnakeNameType`). The module path's leaf equals `name` directly, with no projection in between, and that constraint is expressed over `modulePath` alone (`strings.HasSuffix(registryPath, "/" + name)`). The rest of the path is whatever CUE accepts; OPM does not narrow it.

Consequently `nameSnakeCase` and `#KebabToSnake` are removed from `core`. They exist solely to project kebab onto snake; with `name` already snake there is no projection left.

**Alternatives considered:**

- **Keep kebab `name` plus a derived `nameSnakeCase`.** Rejected: it keeps two spellings of one identity alive so that one of them can be prettier, which is the class of drift this entry exists to remove.
- **Narrow the whole module path to snake_case.** Rejected on evidence: CUE accepts hyphens in path segments (verified — `github.com/open-platform-model/my-thing@v1` evaluates and `cue mod tidy`s clean), path segments are not CUE identifiers, and narrowing would make OPM unable to express its own GitHub organisation. Only the **leaf** needs to be an identifier, because only the leaf is also the CUE package name.

**Rationale:** One identity, one spelling. The leaf must be a CUE package name and package names cannot contain hyphens, so the identity is the constrained form and there is nothing to project.

**Migration:** every hyphenated module name is renamed (`web-app` → `web_app`, `zot-registry-ttl` → `zot_registry_ttl`). `name` feeds the `module.opmodel.dev/name` label, so this is user-visible; underscores are legal in Kubernetes label values.

**Source:** User decision 2026-07-26.

### D9: The version label is declared by the schema and verified by the kernel

**Resolves:** the read-side comparison D2 left open

**Decision:** `#Module.metadata.labels` declares `"module.opmodel.dev/version": "\(version)"`, sourced from D2's `metadata.version`. The kernel is the label's *verifier* rather than its *source*: at each read point D11 names, an acquired artifact's `metadata.version` is compared against the tag it was fetched by, and a disagreement raises the same typed error D11 raises for an address mismatch.

**Alternatives considered:**

- **The kernel stamps the label from the resolved coordinate, and `core` stops declaring it — originally adopted here, then reversed.** The argument was that the label describes an *acquisition* rather than a definition, so the code that fetched an artifact is the only actor knowing which one it got, and putting the write on the path both frontends traverse means they cannot disagree rather than merely being required to agree. That held while `metadata.version` was absent or drifting. It does not survive a render path with no coordinate to stamp: `cli/internal/workflow/render/module.go:99` records that "a module apply always renders a local module directory (the main module is local), so render provenance is local (enhancement 0006 D7)" — so the CLI's primary module path has **no resolved coordinate**, and under this scheme it either omits the label or invents one while the operator's registry-acquired render stamps it. the byte-identical-render gate does not catch that, because it compares `cli` against `opm-operator` for one *instance* and both sides of that comparison acquire from a registry.
- **Drop the label.** Rejected: selecting deployed resources by module version is a real operational need, and removing a field is not a reason to remove a capability.
- **Schema-stamp it and skip the read-side comparison.** Rejected — this is the pre-0010 defect exactly. Measured and recorded in `01-problem.md`: `jellyfin` v2.0.1 and v2.0.2 both shipped `metadata.version "2.0.0"`, so three published artifacts carried one label value. 0011 D4's own scope note is that `cue mod publish` keeps working, so a producer-side assertion is not something a consumer may rely on; without a reader checking, the label can still lie for anything published outside `opm publish`.
- **Have each frontend stamp its own** (`cli` and `opm-operator` separately). Rejected: it makes byte-identical rendered output a coordination agreement between two independently-released codebases, and the only thing detecting a divergence would be a digest gate failing after the fact and naming a digest rather than a label.
- **Stamp it in the apply path rather than the render path.** Rejected: the label must be present in rendered output for dry-run, diff, and digest, all of which run before anything is applied.
- **Inject the resolved version into the module value so CUE can stamp it.** Rejected on `core/SPEC.md:304`'s recorded closed-struct failure, and because it returns a fetch-derived value to module identity.
- **Two labels under different keys — one declared, one resolved.** Rejected as two spellings of one operational question. If the two values can disagree, the right response is to refuse the artifact, not to render both and leave an operator to reconcile them at a terminal.
- **Have the kernel overwrite the schema-supplied value wherever a coordinate exists.** Rejected on mechanics: CUE cannot unify a concrete label value to a different one, so this needs either a disjunction default in `core` or a post-render Go rewrite. Both reintroduce the divergence between the two render paths that this decision removes, and the Go form puts a label's value outside the rendered CUE where the digest gates cannot see how it got there.

**Rationale:** D2 removes the drift at the producer — 0011 D12's publish check asserts `metadata.version == id.Version`, and the tag derives from the same value — and this decision removes it at the consumer. Declared and resolved become the same fact, and only the declared one is available on **both** render paths.

The division of labour is the point. The schema states what the artifact says it is; the reader refuses an artifact where that is not what it was fetched as. That is a stronger guarantee than stamping the coordinate, because a stamp makes the label true about *this render* while leaving the artifact's own claim about itself unexamined — and it is the artifact's claim that every other consumer reads. The requirement that the two frontends cannot disagree carries forward, met more strongly by both reading one committed value than by both writing the same computed one.

**Source:** User decision 2026-07-26.
**Revised:** 2026-08-04 — absorbed D39 (taken 2026-08-03), which returned the label to `core` sourced from the declared `metadata.version` (D2) and made the kernel its verifier. Local-render path read at `cli/internal/workflow/render/module.go:99` that day; the label chain confirmed at `core/src/module.cue:36`, `core/src/module_instance.cue:28` and `core/src/transformer.cue:131-137`; drift measurement from `01-problem.md`.

### D10: The built-against catalog version has no reader — the floor mechanism is retired

**Decision:** Nothing records or reads "which catalog build was this module authored against". The compatibility floor D3 was originally taken for was retired by D13 and never returned: under D24 a contract key names an API version rather than a build, and compatibility is carried instead by D27's additive-only promise plus the matcher's unify rung. There is no floor to feed, so there is no carrier to choose.

**One invariant survives the retirement, and it must be preserved deliberately.** A module's primitive definitions must resolve through the **module's own dependency graph**, not through a graph shared with the platform. That holds today — `library/opm/compile/module.go` consumes `mp.Transformers` from `materialize` as read-only input built by a separate resolver, so a module's own `cue.mod` pins supply its primitive definitions. A future single-build render putting the module and the platform in one CUE build would let minimal version selection pick the maximum, and a module would silently render against the platform's catalog rather than its own. Recorded in `05-risks.md` and gated at acceptance; it is a constraint on the render path, not an open choice.

**Alternatives considered:**

- **Read the value from the module's own `cue.mod/module.cue` `deps` block — originally adopted here.** Measured sound and still true as a *fact*: `modules/jellyfin/cue.mod/module.cue` carries `deps: "opmodel.dev/catalogs/opm@v1": {v: "v1.0.0-alpha.1"}`; `cue.mod/module.cue` was confirmed present inside the published artifact zip for `opmodel.dev/modules/jellyfin@v2` tag `v2.0.2`; and the deps block is semantically a floor already, since minimal version selection records a lower bound. Superseded as a *carrier* by the per-primitive field below, then retired along with the floor itself.
- **A required `metadata.version` on every primitive, read as the matcher's catalog lookup — subsequently adopted, then retired.** From a demanded FQN plus the primitive's own `modulePath` and `version`, the matcher would find the owning catalog by longest-prefix match over the platform's subscribed paths and report *not subscribed* or *too old* in place of a bare missing key. It was chosen over the `cue.mod` route on fit rather than correctness: the deps block gives one version per catalog *dependency*, so the matcher would have to join back from a demanded primitive to the dependency that supplied it, which needs precisely the OQ3 constraint the primitive-carried route avoids. D13 then removed its reader — once a demanded key named its own build there was no "matched but too old" state left to detect. The field itself survives under a different name and a different job: `catalogVersion`, provenance rather than lookup (D21, D25).
- **Generate a record at publish**, into the identity file or a new `#Module` field. Rejected as redundant and less trustworthy: it states a fact `cue.mod` already holds authoritatively, and a generated copy can drift from the deps that actually resolved.
- **Read it from the stamped version on the primitives a module references, with no floor.** Rejected on soundness, and the reasoning is what became the invariant above: the value is recomputed from whichever catalog wins dependency resolution at load, so under a shared build the comparison would be a value against itself and could never fail.
- **Drop the diagnostic entirely** and let the kernel report only the missing FQN. Rejected when the per-primitive lookup was adopted, on the ground that `no matching transformer` naming neither the catalog nor the version was the worst diagnostic in the system. It did not survive as the answer either: D24's contract keys let the matcher distinguish "nothing implements this contract" from "your platform implements a different API version of it", and D28 makes the miss fail loudly — without any per-primitive version field to say it.

**Rationale:** The requirement was never to *record* the value but to stop discarding it, and the design moved past needing it at all. D13 removed the floor's reader; D24 removed the floor's reason by making a contract key stable across catalog builds; D27 replaced what the floor protected with a promise both ends enforce. What is left is the render-path invariant, which is about *where definitions resolve* rather than about what version they report.

**Source:** User decision 2026-07-26, refined by the finding that `cue.mod` deps already record it.
**Revised:** 2026-07-30 — absorbed D12 (2026-07-26), which had reversed the carrier choice. Both are retired by D13's removal of the floor's reader and D24's removal of its reason; D12's render-path invariant is preserved above.

### D11: Identity is verified where artifacts are read

**Decision:** The invariant "an artifact lives where its metadata says it lives" is checked on every read path, and a mismatch is a typed error naming both values. Three read points, one rule:

- **Module acquire** — `library/opm/helper/loader/registry/module.go`, on the `kernel.AcquireModuleFromRegistry` path, so the CLI and the operator inherit one implementation.
- **Catalog materialize** — `library/opm/materialize`, where a subscription resolves and pulls a build. This is also where the D3 floor is evaluated.
- **Platform subscription** — when a catalog is added to a `#Platform`'s registry, so a broken catalog is reported to the platform author who subscribed rather than to whoever renders a module next.

**Alternatives considered:**

- **Check only at publish.** Rejected: `cue mod publish` exists, will keep working, and is what every artifact published to date used. Enforcement a publisher can route around gives a consumer nothing to rely on. Publish-side checks are still worth building — they are what makes conformance the default — but they are the ergonomic half, not the guarantee.
- **Best-effort consumption, recording the fetched reference as a fallback.** Rejected: it makes a wrong-artifact condition survivable and therefore permanently invisible, which is the failure this entry exists to eliminate.

**Rationale:** Read points are the ones every actor passes through and no publisher controls. The subscription check is worth calling out separately because it fires *earliest* — when a platform author adds a catalog, before any module is rendered against it — and because it names the catalog rather than a missing key.

Publishing an incomplete artifact is not prevented by CUE: measured 2026-07-26, `cue mod publish v1.2.0 --dry-run` succeeded on a tree whose identity fields were open. Read-side verification is therefore the only thing standing between an unfilled artifact and a consumer. It degrades safely — the consumer-side symptom is `incomplete value string` naming the field — but it is a consumer-side symptom, which is why the check belongs there rather than only in a publish task.

**Source:** User decision 2026-07-26.

### D12: (merged into D10, 2026-07-30)

Every primitive carries `version`, and it is the matcher's catalog lookup — content now in D10. Number retired.

### D13: (merged into D4, 2026-07-30)

Primitive FQNs carry the full SemVer, and cross-minor installs come from subscription breadth — content now in D4. Number retired.

### D14: A subscription names exactly one catalog build

**Decision:** `#SubscriptionFilter` does not exist. `#Subscription` carries a required **`version`**: one bare SemVer, scalar, naming the single build that subscription materializes. There is no range to solve, no `allow` or `deny` to arbitrate, no highest-stable default to fall through to, and no maturity inference — a prerelease is selected by being written down. A platform that wants two builds of one catalog cannot express it; it makes two platforms.

Catalog selection is therefore a **pure function of committed source**: `git`-identical inputs materialize identical catalog bytes on any day, from any machine, with no lockfile, because the platform file *is* the resolution. That is what keeps a render reproducible once D4 stopped the contract key from pinning the build.

The field is spelled `version`, singular, rather than a one-element list. The cost is recorded rather than discovered later: widening back to multi-build becomes a breaking rename instead of a list relaxation.

**Why breadth did not survive.** Each candidate use collapses on inspection. **Union coverage** — build `1.0.0` ships transformers A and B, build `1.2.0` ships A only, and listing both yields `A@1.2.0` + `B@1.0.0` — is the one case breadth uniquely served, and it describes a catalog that made a breaking change without saying so; under D28 the dropped transformer fails the render loudly, and the fix belongs to the catalog author. **Gradual migration** does not structurally exist: under D4 a module demands resources and traits and never a transformer, so no module can stay on the old build and there is no per-module transition to stage. **Two `apiVersion`s of one contract** ship side by side in a single build, which is what D4's contract keys are for. **Testing a new build beside the old** is two platforms — already expressible, names both behaviours, and costs nothing hidden, since Materialize is explicit and caller-driven and the kernel holds no cache (0001 D14).

**Alternatives considered:**

- **A whole-major default: a subscription with no filter materializes every published build in its major — originally adopted here, then reversed.** It existed because build-keyed contracts forced a platform to cover the *authorship history* of its installed fleet, so a default covering one build worked only for a fleet built this week. D4's contract keys removed that requirement, and with it the default's reason. Its unbounded growth was recorded as an open question rather than papered over with a retention window; the growth question dissolved with the default.
- **An explicit prerelease opt-in flag on the filter — adopted alongside the whole-major default, then deleted with it.** It existed to reconcile "the default selects every build in the major" with "prereleases need opt-in", and the measurement behind it was real and is why constraint syntax could not be left to carry the distinction: `catalogs/opm` publishes only `v1.0.0-alpha`, `v1.0.0-alpha.1`, `v1.0.0-alpha.2` and `catalogs/kubernetes` only `v0.1.0` and `v1.1.0-alpha` (registry read 2026-07-27), while `filterVersions` reached a prerelease only via an `allow` entry naming the exact version or a `range` whose constraint itself carried a prerelease identifier (`filter.go:31-42`). With no default left there is nothing to opt into — a literal `1.0.0-alpha.2` is selected by being written down.
- **A required, non-empty `versions` LIST — subsequently adopted, then reduced to a scalar.** It removed resolution while keeping breadth expressible, on the reasoning that deliberate breadth stays legitimate. Reversed once that legitimacy was examined directly and none of its uses survived (above). Keeping the list also left open what happens when two named builds ship one transformer, which the scalar dissolves.
- **Keep `versions` as a one-element list** (`[#VersionType]`), so widening later is a pure relaxation and CUE list arity rejects a second entry loudly. Considered and declined by the author: it buys a cheaper reversal at the cost of a shape that describes an intention rather than a rule, and invites a reader to try two entries and discover the constraint by failure.
- **Keep breadth with a newest-wins tie-break.** Defensible on its own terms — D27's additive-only promise makes the newer build's contract a superset, so the newer transformer cannot lose capability, and the winner is a max over a committed list so inertness survives. Rejected because it makes listing two builds *indistinguishable in effect* from listing one in every case except the dropped-transformer catalog bug: a silent arbitration bought to serve a scenario that should fail loudly.
- **Keep breadth and refuse same-catalog overlap at materialize.** Rejected as a same-catalog rule: it makes the list legal to write and illegal to use for every catalog that did not drop a transformer, a shape that exists only to be rejected. The candidate survives in D32, where the operands are two *different* catalogs and the refusal is the whole point.
- **Keep ranges and add a lockfile.** The more expressive answer and the one to reach for if manual bumps become the bottleneck. Not chosen: it is strictly more machinery for the same guarantee, and it stays available — reintroducing `range` alongside a recorded resolution takes nothing away from a platform that already names its version. The reverse is not true; an established floating default cannot be withdrawn cheaply once platforms depend on it.
- **Keep ranges and pin exactly by convention.** Rejected on evidence rather than principle. This is already what enhancement 0006's A5 did to stop the demo platform resolving whatever `-dev` tag published last, and 0006 OQ18 records the general case still open with the CLI's seeded `>=1.0.0-0 <2.0.0-0` still exposed. A convention nothing enforces is the failure shape D17 and D27 both legislate against.
- **Keep `deny` as a subtractive tool.** Rejected: `deny` exists to carve exceptions out of a range. With no range there is nothing to carve.
- **Delete `range` but keep the empty-filter default.** Rejected: the default *is* the float. `highestStable(published)` moves on the next catalog release whether or not a constraint was ever written.

**Rationale:** Ranges without a lockfile is the one combination that cannot be made reproducible, and every ecosystem shipping ranges ships a lock beside them. OPM shipped ranges and recorded its resolution in `MaterializedPlatform.Resolved` — an in-memory map whose only non-test consumer in the entire workspace was an integration harness (`cli/tests/integration/platform-materialize/main.go:95`), and whose own doc comment instructed callers that they "MUST NOT branch behavior on it". There were two exits from that state, build the lock or drop the ranges; dropping is smaller, closes more questions, and is the one that can be walked back.

Reducing further, from a list to a scalar, is the same move applied to a capability that turned out to have no surviving use. Deleting it dissolved the last question gating this entry rather than answering it.

The cost is that a catalog upgrade becomes an explicit edit on every platform that wants it. For a system whose platforms live in git and reconcile continuously, an upgrade that appears in a diff and gets reviewed is the correct interaction rather than a regression, and automating the bump is enhancement 0004's subject rather than a gap this decision leaves open.

**Source:** User decision 2026-07-27.
**Revised:** 2026-07-30 — absorbed D15 (taken 2026-07-27, the prerelease opt-in), D29 (taken 2026-07-29), which deleted `range`, `deny` and the empty-filter default, and D31 (taken 2026-07-30), which reduced the `versions` list to a scalar `version`. All three numbers were retired in the 2026-07-30 compaction pass, which is the leading date here and the one their tombstones carry; the parenthesised dates are when each decision was taken. `allow`'s original shape read from `core/src/platform.cue:16-20` and `library/opm/materialize/filter.go` 2026-07-29; `Resolved`'s consumer set verified across `library`, `cli` and `opm-operator` the same day; the prior floating-resolution failure is enhancement 0006 OQ18, analysed in `0006/research/dev-tag-range-pollution.md`.

### D15: (merged into D14, 2026-07-30)

Prerelease inclusion is an explicit opt-in on `#SubscriptionFilter` — content now in D14. Number retired.

### D16: `#Catalog` gains no `name` field

**Decision:** `#Catalog.metadata` stays `modulePath` + `version` (plus the existing optional `description` / `labels` / `annotations`). No `name` field is added. A catalog's identity and its address are the module path alone, and D8's leaf-equals-name rule is a `#Module` rule that does not transpose to catalogs.

**Alternatives considered:**

- **Add `name` constrained to the path leaf and snake-cased, transposing D8.** Rejected: it costs a published-path rename — `opmodel.dev/catalogs/opm-experimental@v1` would have to become `…/opm_experimental@v1` — and buys a field nothing reads.
- **Add `name` typed as kebab `#NameType`**, the primitive spelling, to avoid that rename. Rejected: it makes `#Catalog.name` and `#Module.name` differently constrained, which defeats the symmetry that was the only argument for adding the field at all.

**Rationale:** Measured 2026-07-27 — nothing reads a catalog name. `library/opm/schema/*.go` carries no catalog metadata reader in Go, and every diagnostic in `library/opm/materialize/{enumerate,index,pull,materialize,filter}.go` interpolates a subscription path or an FQN, never a name. D2's argument applies here unchanged: a field with no reader drifts, and is eventually written to by someone.

The catalogs do already carry the projection D8 deleted for modules — `catalog_opm_experimental` has path leaf `opm-experimental` and `package opm_experimental` — but it is invisible to every consumer, because a module imports a catalog's `resources` / `traits` subpackages (whose leaves are already identifiers, aliased at the import site) and never the catalog's root package. So the drift exists and costs nothing, and adding a constrained `name` would convert a free inconsistency into a paid migration.

If a discovery or listing surface later needs a display token, adding the field is additive. Artifact discovery is a stated non-goal of this entry.

**Source:** User decision 2026-07-27.

### D17: The primitive-under-catalog-path constraint is a publish gate, not a schema constraint

**Decision:** A primitive's `metadata.modulePath` MUST sit under the `modulePath` of the catalog whose source tree **defines** it, and that rule is enforced at publish — 0011's `opm catalog publish` refuses a catalog that violates it. `core` gains no new stamping site and no `#resources` / `#traits` / `#blueprints` sibling maps on `#Catalog`. The rule binds a catalog's own definitions only; primitives a catalog *references* from another catalog (enhancement 0001 D16) are untouched.

Recorded explicitly as **not** delivered: answering "which catalog ships FQN X?" with no platform in hand. That derivation needs a second convention — a fixed kind segment — beyond what this rule establishes, and at the time of this decision the shipped catalogs showed why the segment count was not fixed: resources sat at `…/catalogs/opm/resources` while blueprints sat at `…/catalogs/opm/blueprints/workload`, one segment deeper. So `opmodel.dev/catalogs/opm/blueprints/workload/stateless-workload@1.0.0` could not say by inspection whether its catalog was `…/catalogs/opm`, `…/catalogs/opm/blueprints`, or `…/catalogs/opm/blueprints/workload`. D12's longest-prefix match used the platform's subscribed paths as its oracle; with no platform there is none. This decision improves conformance, not derivability.

> **The evidence above no longer holds — see the Revised line.** D42 supplies exactly the fixed kind segment this paragraph says is missing, so the FQN *is* now decomposable. The conclusion (fulfilment is declared, not inferred — D37) stands on separate ground and is not reopened here.

**Alternatives considered:**

- **A `core` stamping site.** Rejected on two independent grounds. `core` cannot express the rule where the primitives actually live: `#ComponentTransformer.requiredResources?: [#FQNType]: #Resource` (`core/src/transformer.cue:54`) holds a catalog's own resources and foreign ones as identical values in one map, so a constraint reached through `#transformers → requiredResources` would enforce this rule by **forbidding enhancement 0001 D16**, a decided and experiment-validated position (`0001/experiments/11-cross-catalog-import/`). Expressing it correctly would require new `#resources` / `#traits` / `#blueprints` sibling maps — an authoring surface `core/src/catalog.cue`'s own doc comment defers as "an additive extension if introspection demand surfaces later" — bought for hygiene alone, now that D13 has removed the correctness need.
- **Both a `core` constraint and a publish gate.** Rejected as the above plus a second enforcement point that cannot be made accurate.
- **Neither — document the convention and leave it convention.** Rejected: that is today's state. A third-party catalog author has no reason to copy a convention nothing checks, which is the class of drift this entry exists to remove.

**Rationale:** D13 retired D12's catalog lookup, so nothing on the match path depends on this any more — the constraint is hygiene, and hygiene belongs where it is cheapest and most accurate. Publish is the only actor that can distinguish "defined here" from "imported from catalog B", because it holds the source tree rather than the composed value; every consumer-side surface sees `#Resource` values in a map with no provenance attached. It also matches this entry's stated scope split — 0010 defines what publishing must guarantee, 0011 implements the command.

Measured 2026-07-27: the shipped catalogs follow the convention uniformly, every primitive setting `modulePath: "\(id.ModulePath)/<kind>"`; no cross-catalog reference exists yet; and transformers are *already* bound structurally, because `core/src/catalog.cue:70-76` stamps `modulePath: "\(M.modulePath)/transformers"` by unification, so a foreign transformer placed in a catalog's `#transformers` map fails today with conflicting values. The enforcement gap is exactly resources, traits, and blueprints.

**Source:** User decision 2026-07-27.
**Revised:** 2026-08-05 — the gate this decision delegates to is specified as **enhancement 0011 D22**, which ships `#CatalogMemberFQNGate` in `core` and has `opm catalog publish` unify every catalog member against it. Until that decision existed, 0011 carried no owner for the rule — no decision, no refusal message, no slice — so this delegation pointed at nothing.
**Revised:** 2026-08-03 — **the not-delivered claim's evidence is retired by D42**, and this note exists because citing that claim as still-current is the specific error the next reader is likely to make. D42 flattens every primitive kind to exactly one path segment (`…/blueprints/<name>`, not `…/blueprints/workload/<name>`), which is the fixed kind segment this decision names as the missing convention — so with `kindPrefix` admitting one prefix per kind, the owning catalog IS recoverable from a contract FQN by stripping version, name and kind segment. What does **not** change: the decision itself (the rule is a publish gate, not a `core` constraint), and D37's requirement that `fulfilment` be authored rather than inferred, which rests independently on a catalog later adding a transformer silently changing a contract's character. D42 records the same consequence from its own side and declines to reopen either decision on it.

### D18: The live-instance migration is subsumed by the v0 → v1 fleet migration

**Decision:** This enhancement carries **no live-instance migration burden**. Every deployed OPM instance is on the deprecated v0 schema line, so no running instance carries an identity that this entry's changes would alter. The fleet reaches `opmodel.dev/core@v1` through a separate v0 → v1 migration, and 0010's identity shape is part of that migration's *target state* rather than a delta applied to running v1 instances. OQ4's relabel-versus-recreate choice is therefore not a runbook this entry owns.

**Fleet measured 2026-07-27**, across two deployment repositories covering eight environments in total; the repositories and environments are named out of band. Every one pins `opmodel.dev/core/v1alpha1@v1` and `opmodel.dev/opm/v1alpha1@v1` — the deprecated `catalog/` tree. Nothing is on `opmodel.dev/core@v1`. Re-verified 2026-08-05 for the larger of the two repositories: all 31 of its `cue.mod/module.cue` files still pin that pair, on CUE `v0.15.x`. Noted in passing: those modules' `cue.mod` lines already read `module: "opmodel.dev/modules/<name>@v0"`, which is D1's shape verbatim — the string D1 wants in `metadata.modulePath` already exists in the fleet's own manifests.

**Scope note added 2026-08-05.** Clusters and environments are out of scope for this entry and for 0011 (author's call): these entries fix what a published artifact *is*, and moving a running deployment onto it is separate work handled afterwards. That does not change this decision, which already declined the migration burden — but it does mean the two holdings below are the entry's whole contribution to that future work, and that the delivery plan deliberately carries no live-instance slice. The `releases-repin` slice was cancelled on the same call.

Two holdings are recorded as **inputs** to that future migration rather than as work here:

- **Relabel in place, never recreate**, if a v1 instance ever needs its identity changed while running. `opm-operator` sets no `ownerReferences` on applied resources (verified 2026-07-27: zero occurrences of `SetControllerReference` or `OwnerReferences` in the repository) and `ModuleInstance` carries no finalizer, so deleting and re-creating the CR garbage-collects nothing — the old resources survive holding the old UUID label, the new instance applies alongside them, and every subsequent delete hits the mismatch skip at `prune.go:107`. Naive recreate produces precisely the silent-orphan state the migration exists to avoid, which inverts OQ4's original assumption that recreate was the simpler path. Relabelling is a label write with no lifecycle event, so it is uniformly safe for stateful and stateless workloads alike; its failure mode is partial coverage, which the check below detects per instance.
- **The positive check stands.** For at least one migrated instance, remove a resource from the module, re-render, and assert it is actually deleted from the cluster. An absence of errors does not satisfy it — `prune.go:112` increments `result.Skipped` and logs at Info (`moduleinstance.go:642`, `:806`), but emits no Event, no status field, and no metric.

**Alternatives considered:**

- **Relabel every live instance as part of 0010.** Rejected on measurement: there is nothing to relabel. No deployed instance is on the schema this entry changes, so the pass would be a no-op against the v0 fleet and would have to be redone by the v0 → v1 migration anyway.
- **Recreate each instance.** Rejected on the `ownerReferences` finding above: it is simultaneously the more destructive option and the one that produces silent orphans.
- **Defer OQ4 outright to the future migration entry.** Rejected as losing the analysis. The relabel-over-recreate finding and the prune-skip mechanics were measured here; recording them as inputs keeps them attached to the identity change that motivated them, rather than requiring rediscovery.

**Rationale:** OQ4 asked how live instances adopt their new identity, and the answer turned out to be that they do not adopt one — they are not on the schema whose identity changes. Resolving it as subsumed states that plainly instead of writing a runbook against a fleet that cannot execute it. What survives is the part that was genuinely learned: that the operator's resource ownership model makes in-place relabelling the safe direction, and that the failure this migration must guard against is silent rather than loud.

**Source:** User decision 2026-07-27. Fleet inventory read 2026-07-27 from the two deployment repositories, named out of band; re-verified 2026-08-05.

### D19: A moved-ahead dev checkout is accepted and warned about, not versioned around

**Decision:** A local catalog checkout whose bytes have moved ahead of its committed `identity.cue` `Version` is an accepted condition of local development, documented rather than prevented. No dev-version notation is introduced, and nothing in the schema changes. One check is added: **if the main module carries `cue.mod/local-module.cue`, the render path warns that demanded keys may not correspond to published bytes.** It is a file-presence test — deterministic, offline, no registry query, no new field — and it fires exactly when the false-conclusion risk exists.

**A correction to OQ8's premise, and it narrows the question.** A platform cannot materialize a catalog from a local checkout. `#Subscription` is `{enable, filter?}` keyed by a registry path (`core/src/platform.cue:30`), `enumerateVersions` lists registry tags (`materialize/enumerate.go:28`), and `pullCatalog` loads `path@version` (`pull.go:24`). There is no directory route into a platform's materialized set. A local checkout enters through the **module's** dependency graph instead, and the two sides join on the FQN: the module contributes resource and trait definitions plus the demanded keys, versioned by the local `identity.cue`; the platform contributes the transformers that actually execute, from the registry.

**The escape routes are already closed, and it is measured.** `enhancements/0011/experiments/02-publish-plan-gates` (concluded 2026-07-26, cue v0.17.1) records that publish REFUSES a catalog carrying a local override, and refuses it *even with* `--allow-local-override`, because the flag does not apply to catalogs; a module with a local override is refused by default and proceeds only under that explicitly named flag. `local-module.cue` is additionally unpublishable by construction and honored only when its module is the main module. Nothing moved-ahead reaches a registry by accident.

**And the ordinary dev loop already diverges in a different way.** `enhancements/0003/experiments/04-local-module-chain-hops` (concluded 2026-07-25) measured that a one-hop replacement — an instance replacing its module with a local checkout — yields `modOrigin: LOCAL-CHECKOUT` but `catOrigin: REGISTRY`. The inner hop is dropped, so the common case already renders local module bytes against the *published* catalog. Reconstructing the full chain requires a hand-written multi-entry `local-module.cue` (`case3` / `case4`, both verified, and `cue mod tidy` preserves them).

What remains after both findings is narrow: a developer who deliberately wires the two-entry chain, edits a catalog primitive, leaves `Version` at the last published value, renders, and concludes "it works" — while the cluster will run the registry's bytes under that same key. Nothing is published and no artifact is corrupted. The damage is a false conclusion, which is what the warning addresses.

**Alternatives considered:**

- **Have the kernel mark a directory-resolved catalog and warn when a module matches one of its keys** (OQ8 candidate (b) as originally framed). Rejected as unimplementable where it was sited: materialize never sees a directory-resolved catalog, so there is nothing to mark. The salvageable half is the module-load check adopted above.
- **Require an explicit dev version** (OQ8 candidate (c)). Rejected on two grounds: it is OQ2 candidate (b) transposed and carries the identical forget-to-set failure, and it writes a resolution-time fact into committed source, which is the class of value D9 exists to keep out.
- **Accept with no warning at all.** Rejected narrowly. The publish gates make this safe for artifacts, but they do nothing for the developer standing in front of a render that will not reproduce, and the detection costs one file-existence check.

**Rationale:** The condition cannot produce a bad artifact — 0011's gates already establish that, by measurement rather than by assertion — so the remaining exposure is a person drawing a wrong conclusion from a local render. That calls for telling them, not for adding a version notation whose own failure mode is being forgotten. It also keeps the guarantee honest in the form D13 states it: a key names its exact bytes for everything that was published, and the one place that holds only by author discipline is a dirty checkout that the tooling now points at.

**Source:** User decision 2026-07-27. Publish-gate behaviour from `enhancements/0011/experiments/02-publish-plan-gates` (2026-07-26); chain-hop resolution from `enhancements/0003/experiments/04-local-module-chain-hops` (2026-07-25).

### D20: (merged into D1, 2026-07-30)

A primitive's `modulePath` is a package path, not a module path — content now in D1. Number retired.

### D21: A primitive's `fqn` is authored from the identity package, and `version` stays required

**Decision:** `core` stops deriving `fqn`. `#FQNType` stays as the type, and each catalog **authors** the value at the primitive's own definition site, interpolating it from the catalog's `identity` package:

```
fqn: "\(id.RegistryPath)/resources/\(name)@\(id.Version)"
```

`version!` stays **required** on every primitive kind, which resolves OQ6. Kind segments are retained in the FQN (`/resources`, `/traits`, `/blueprints`, `/transformers`), so a resource and a trait sharing a name do not collide.

The `identity` package gains two derived fields so no leaf ever splits a major:

```
_p:           strings.SplitN(ModulePath, "@", 2)
RegistryPath: _p[0]   // "opmodel.dev/catalogs/opm"
Major:        _p[1]   // "v1"
```

Tooling still writes exactly the two fields D5 locates by schema path — `ModulePath` and `Version` — and the derived pair follows from them, so the publisher gains nothing new to keep in step. The `identity` package's "import-free" invariant is preserved: `strings` is a CUE builtin, not a module import, and adds no edge to the module graph. Its doc comment should say "free of intra-module imports" to stay accurate.

**The property this buys, in the author's words:** "Both FQN and metadata.modulePath and metadata.version all are referencing identity/identity.cue this ensures consistency." All three fields have one source, and a catalog release moves all of them by one edit.

**The cost is accepted explicitly, also in the author's words:** "I know this could cause problems because it is not enforced and is visible and overridable by the catalog author. But to mitigate this we could add checks and gates that prevent fqn from being mismatched with identity/identity.cue." Enforcement therefore **moves** rather than disappearing — from `core`'s unification, where a wrong value is inexpressible, to 0011's publish gate, where it is caught before it ships. That is the same place D17 put the primitive-path rule, so the two are one mechanism rather than two.

**Alternatives considered:**

- **Keep `core`'s derivation** — `fqn: #FQNType & "\(modulePath)/\(name)@\(version)"`, as `core/src/resource.cue:18` has it. Measured 2026-07-27: because the derivation is a unification, `fqn` is effectively non-authorable, and a transformer whose author writes a disagreeing version fails at the catalog's own `cue vet` with `conflicting values "1.2.0" and "1.1.0"` naming both sites. Not chosen: the author wants the key visible at its definition site and accepts gate-based enforcement in exchange. It also forecloses a capability the authored form admits — pinning a primitive's key to the build where its bytes last changed, so an unchanged primitive need not be re-keyed by every catalog release.
- **Remove `version` and author only `fqn`** (OQ6 candidate (b)). Rejected on measurement 2026-07-27: with `version` gone there is nothing to interpolate and nothing to stamp, so a catalog on `1.2.0` shipping a transformer whose author left `fqn: "…/secret-transformer@1.1.0"` passes `cue vet -c` with **exit 0**. The key names a build the catalog is not, silently, and under D13 that key is what modules match against permanently.
- **Derive `version` from `fqn` in `core`** (OQ6 candidate (c)). Rejected on measurement 2026-07-27: it is a CUE cycle — `t.fqn: cycle with field: version` — because `fqn` is built from `version` and deriving `version` back out closes the loop.
- **A flat FQN with no kind segment** (`…/opm/config-maps@1.2.0`). Rejected: it makes primitive names globally unique across all four kinds within a catalog, and `catalog_opm` already ships a resource named `secrets`. It also breaks the correspondence between an FQN's path portion and its `modulePath`.

**Rationale:** OQ6 asked whether `version` has a reader. Under the build-keyed contracts of the time it did — the FQN interpolates it — and this decision keeps that true while moving the interpolation from `core` to the leaf. The field is the key's source component, not a duplicate of the key, which is why candidate (b)'s removal fails loudly on measurement and candidate (c)'s inversion cannot be expressed at all.

**Worked shape, verified 2026-07-27 (`cue vet -c` clean):**

```
resource:    "opmodel.dev/catalogs/opm/resources/config-maps@1.2.0"
trait:       "opmodel.dev/catalogs/opm/traits/scaling@1.2.0"
transformer: "opmodel.dev/catalogs/opm/transformers/configmap-transformer@1.2.0"
catalog:     "opmodel.dev/catalogs/opm@v1"
```

A transformer's `requiredResources` key is the resource's own `metadata.fqn`, so demand and supply are the same string by construction and there is no third place to keep in step. Every existing leaf's edit is mechanical: rename `id.ModulePath` to `id.RegistryPath` in one reference, and add one `fqn` line.

**Source:** User decision 2026-07-27. Resolves OQ6. Derivation, removal and inversion each measured against cue v0.17.1 on 2026-07-27.
**Revised:** 2026-08-05 — the publish gate this decision moves enforcement to is specified as **enhancement 0011 D22** (`#CatalogMemberFQNGate`, shipped in `core`, unified against at publish). The trade recorded above — an authored `fqn` for one identity source, with a stale key caught before it ships — is only paid for once that gate exists; until 0011 D22 it had no owner in either entry.

### D22: (merged into D5, 2026-07-30)

Identity fields carry no marker attribute — content now in D5. Number retired.

### D23: (merged into D2, 2026-08-10)

Module and catalog identity files keep different placement and shape — reversed by the decision now stated at D2; the asymmetry and its measured self-import cost survive there as a previously-adopted alternative. Number retired.

### D24: (merged into D4, 2026-07-30)

A primitive's key is its own API version; a transformer's key keeps the build SemVer — content now in D4. Number retired.

### D25: `apiVersion` is authored per primitive; `version` is renamed `catalogVersion`

**Decision:** `#Resource`, `#Trait` and `#Blueprint` — the three **primitives** — gain a required `metadata.apiVersion` (`#APIVersionType`), authored per primitive, which is what a contract FQN interpolates under D4. `#ComponentTransformer` does **not**: it is an adapter rather than a primitive and its key is its build, so it carries no `apiVersion` at all. D44 states that taxonomy and the shape split that enforces it.

`metadata.version` is **renamed** `metadata.catalogVersion` on all four kinds, keeps its full SemVer and its source (`id.Version` / the `#Catalog` pattern stamp), and becomes provenance: it records the build a definition shipped in and is never part of a contract key. The rename is four-kind where the `apiVersion` addition is three — a transformer's `catalogVersion` is its own key's source component (D4) and the provenance both ends of a match read (D26).

`#CatalogMemberFQNGate` follows: a contract FQN must equal `kindPrefix[kind]/name@apiVersion`, and `catalogVersion` must equal `identity.Version`. Both still derive from one identity source plus one authored field.

**Alternatives considered:**

- **All four kinds carry `apiVersion`, `#ComponentTransformer` included — originally adopted here, then narrowed.** The cost is not tidiness. With an `apiVersion` present, 0011 D9's gate — "pull the last published build that shipped a primitive of that name at that apiVersion" — **resolves** for transformers, and the additive-only rule then refuses ordinary catalog releases: changing rendering logic, dropping an emitted field and narrowing an output type are all normal transformer edits and all D27 violations. That inverts D4, which keeps the build in a transformer's key precisely *because* a transformer is free to change. The four-kind list also contradicted a taxonomy `core/SPEC.md:38` already stated normatively. Narrowed by D44, which splits the shared shape rather than trimming the field, because the shared shape is how the field arrived.
- **Reuse `version` for both jobs.** Not available: one value keys the contract and must not move on a release, the other records the release and must. That is the conflation D24 exists to undo.
- **Derive `apiVersion` from the catalog's module major.** That is D4 under another name, rejected at D24.
- **Rename `version` to `moduleVersion`.** Rejected on collision: "module" already means three things in OPM — `#Module`, the CUE module, and the module path — so on a primitive it reads as the version of the `#Module`, which is precisely the field D2 deleted. `catalogVersion` says what the value is, and stays accurate for a primitive reached by cross-catalog reference, where it is that primitive's *own* catalog's version.
- **Drop the provenance field now that nothing keys off it.** Rejected: it is what lets the matcher say "this platform's provider was built against 1.0.0; this module needs 1.3.0" when the shapes are compatible but the provider lags. That diagnostic is the whole reason a skew is legible instead of mysterious, and D26 keeps the value readable while removing it from the comparison.

**Rationale:** `apiVersion` is the one identity value on a primitive that is **not** derivable from `identity/identity.cue` — it is a judgement about that primitive's contract, made by its author, so it needs its own field rather than an interpolation. It is also the value a compatibility gate keys its comparison on (D27): "compare this primitive against the last published build shipping this name at this apiVersion".

Measured 2026-07-29 in `experiments/02`: the transformer's `requiredResources` map materialises the **whole primitive value**, `metadata` included, so both sides of a match already carry their build. The provenance needs a name and a type, not a new plumbing route.

**Source:** User decision 2026-07-29.
**Revised:** 2026-08-04 — absorbed D44's narrowing of scope: the `apiVersion` clause binds the three **primitives** only, and the four-kind position it replaced moves into Alternatives above. **D44 stands as its own decision** for the primitive/adapter taxonomy it settles, the `#Blueprint` reclassification and `SPEC.md` co-update it requires, the `#PrimitiveIdentity` / `#TransformerIdentity` split, and the two renames — folding it wholesale would make this decision about two subjects and lose the taxonomy as a citable one, which 0011 D9 cites externally. The conflict it resolved is worth recording: D34 stated the correct scope two days after this decision without amending it, so the log asserted both readings at once and `schemas/target.cue` followed this one.

### D26: Provenance is excluded from the match comparison before unification, not tolerated after it

**Decision:** `Match`'s always-unify rung compares **contract surfaces only**. Provenance — at minimum `catalogVersion` — is removed from the operands *before* they are unified, rather than unified and then forgiven. The mechanism is deliberately left open (OQ12); the position is that the exclusion happens on the way in.

**Measured, and this is the decision's whole basis** (`experiments/02-primitive-closedness-skew/`, cue v0.17.1, 2026-07-29). With `catalogVersion` as an ordinary field of `metadata`, **every** build skew fails — cases 2, 3 and 6, all of them shape-compatible — with `metadata.catalogVersion: conflicting values "1.1.0" and "1.0.0"`. The two sides each state which build they came from, those disagree, and `match.go:243-278` unifies the whole value. MAJOR-keyed FQNs exist precisely so two builds can meet at one key; a provenance field inside the compared value stops them from ever meeting. D24 does not work without this.

**Alternatives considered:**

- **Cut the comparison at `spec`.** The obvious fix, and rejected on measurement. Cases 1 and 7 are the same skew and the same authored change, differing only in how the catalog wrote the spec body: under spec-only unification case 1 **passes** — silently dropping a field the module set — while case 7 fails. Closedness is inherited from the enclosing definition, so an inline `spec: backup: {…}` carries none of its own while a named `#BackupSetSchema` does, and `catalog_opm` ships both styles today (`resources/container.cue` inline, `resources/configmap.cue:23` via a named schema). Enforcement would depend on a catalog author's formatting choice.
- **Unify everything and filter the resulting errors by path.** Measured to produce the full predicted matrix, and it is the cheapest thing that works — but it is an error-path filter, so it forgives *any* metadata conflict, including an `apiVersion` or `fqn` disagreement that should never be tolerated. Recorded as a candidate under OQ12 rather than as this decision, because the decision is about where the exclusion happens, not which filter to write.
- **Remove provenance from the primitive entirely.** Rejected with D25: it takes the lagging-provider diagnostic with it.

**Rationale:** Correctness here depends on the **operands**, not on the errors. The closed definition has to stay in the unification — that is what makes a field the provider's build never declared a hard failure (D27) — while the values that legitimately differ between builds have to be out of it. Only an operand-side exclusion can satisfy both; an error-side filter satisfies the second by weakening the first.

The boundary is not "all of `metadata`", and OQ12 existed because of it — resolved by **D30**, which takes a denylist naming `catalogVersion` and `description` and leaves everything else in. `catalogVersion` and `description` are provenance. `name`, `modulePath`, `apiVersion` and `fqn` are identity that the map key already forces into agreement, so excluding them is harmless but not meaningful.

**Corrected 2026-07-29, because D30's rationale depends on stating it accurately.** This paragraph originally read that `labels` are neither — that "component labels are the union of the labels of its attached primitives, and transformers match on `requiredLabels`, so a label added in a later build changes the component's label set and is a **contract** change rather than provenance." The conclusion (labels stay in) survives; the mechanism was wrong, in the direction that overstates what this decision governs. There is no union. `core/src/component.cue`'s `_allFields` comprehension unions the attached primitives' **`spec`** bodies and nothing else; the "unified from all attached resources, traits, and blueprints" wording at `component.cue:18-24` is a doc comment with no implementing comprehension. What actually happens is that a catalog ships **two** declarations per primitive — the primitive itself (`#ContainerResource: c.#Resource & {…}`, carrying `metadata.labels: {"resource.opmodel.dev/category": "workload"}`) and a *component fragment* beside it (`#Container: c.#Component & {metadata: labels: {"core.opmodel.dev/workload-type"!: …}}`) — and embedding fragments is what unifies component labels. So the label a transformer selects on lives at `component.metadata.labels`, set by the fragment, on a path `unifyIntersection` never touches: it compares `#resources[fqn]` values, which carry the *primitive's* labels. A primitive's own `metadata.labels` has no reader on the match or execute path at all.

**Source:** User decision 2026-07-29 on `experiments/02-primitive-closedness-skew/`, which measured all three scopes.

### D27: Inside one API version a contract is additive-only, and both ends enforce it

**Decision:** Within a single `apiVersion`, a primitive's definition may **add, never remove** fields or options. Two riders are part of the rule rather than notes on it:

- a newly added field MUST be optional or carry a default, since a new required field breaks every component authored against an earlier build; and
- an existing field's default is **immutable** — changing it adds nothing and removes nothing, and moves rendered output for every component that left the field unset.

Removing a field, narrowing a type, or changing a default requires a **new `apiVersion`**, which may ship alongside the old one in the same catalog build.

**The rule binds per level, not uniformly.** At **alpha** (`vNalphaM`) there is no promise at all — a build may remove a field, narrow a type or change a default without bumping, and 0011 D9's publish gate is off. At **beta** (`vNbetaM`) and **GA** (`vN`) the rule above applies in full, and a break requires a level bump (`v1beta1` → `v1beta2`, or a new major) which may ship beside its predecessor in one build. The ladder those forms come from, the day-one assignment per catalog, and the comparator that orders them are D34's.

Enforcement is split across both ends, deliberately: **at publish** by a compatibility gate (enhancement 0011 D9), and **at match** by the always-unify rung that already exists. The publish gate is level-aware for the same reason the rule is.

**Measured** (`experiments/02-primitive-closedness-skew/`, 7 of 7 cases as predicted under D26's exclusion):

- provider on 1.0.0, module on 1.1.0 **using** the added field → `spec.backup.retention: field not allowed`. Loud, and precisely when it matters — the module asked for something this provider cannot honour.
- same skew, module staying inside the shared fields → passes, and renders against the older provider correctly.
- provider *ahead* of the module → passes. This is the direction the promise is for.
- a provider whose build broke the promise by narrowing `schedule` → fails, naming both arms of the disjunction.
- **default drift → passes the match**, and the probe shows why that is not acceptable: after unification `spec.backup.mode` is `"retain" | "delete"` and **not concrete**. Neither build's default survives. The render then fails on an incomplete value, far from the catalog release that caused it, naming a field rather than a build.

**Alternatives considered:**

- **Publisher discipline alone.** Rejected: this is D13's own objection to D4 and it was fair. A promise nothing checks is a convention, and D17 already records that a third-party catalog author has no reason to copy a convention nothing checks.
- **Match-time enforcement only.** Rejected on the default-drift measurement above: the one violation that unification cannot catch is also the one that silently moves output, so the match rung cannot be the only gate.
- **Publish-time enforcement only.** Not chosen as sufficient, because `cue mod publish` keeps working and is what every artifact published to date used (D11's argument). Whether the read side gets its own counterpart is OQ13.
- **Forbid all change within a major.** Rejected: additive evolution is the normal case, and forbidding it would make every new field an `apiVersion` bump — which is exactly the cost D4 was rejected for.
- **Bind the rule uniformly at every API version, alpha included.** **Originally adopted here, then narrowed by D34 (2026-07-31).** It was the simpler rule and it made the gate uniform, but it commits a catalog to compatibility on shapes still known to be wrong: both workspace catalogs were on `1.0.0-alpha.*` with primitive shapes still moving, so declaring the promise everywhere would either freeze those shapes or be routinely violated. Carving alpha out costs exactly one class — the default drift `experiments/02` measured, which no consumer-side check catches — and under D34's day-one assignment that is confined to `catalog_opm_experimental`.

**Rationale:** The promise is what replaces the version join. Under D4 the key no longer guarantees that two builds agree, so something has to, and "additive-only inside a major" is both the weakest sufficient rule and the one CUE can check from both ends. The measurement is what makes it more than an aspiration: closedness makes the lagging-provider direction fail loudly on the exact condition that matters, which is the property the whole model rests on.

**Source:** User decision 2026-07-29. Every case measured in `experiments/02-primitive-closedness-skew/` against cue v0.17.1.
**Revised:** 2026-07-31 — absorbed D34's narrowing of scope: the rule binds at beta and GA, not at alpha. D34 stands as its own decision for the API-version ladder it defines.

### D28: An unresolved primitive demand is an error; a trait's optionality is stated by its catalog and overridden by the attachment

**Decision:** Every resource a component declares is **required**. A demanded resource FQN that no transformer in the platform supplies is an immediate, hard failure of the render — not a diagnostic collected and dropped. Traits carry an explicit **posture** instead of a silent default: `#Trait` has `optional: bool`, beside `spec`, and **`core` gives it no default.** The declaring catalog states the posture and MUST state it as a *default* — `bool | *true` for an advisory trait, `bool | *false` for a load-bearing one — and a `#Component` overrides it at the attachment site:

```cue
#traits: (BackupFQN): Backup & {optional: true}   // not my data
```

`#Component` carries no optionality field of its own, and neither `core` nor this decision supplies an implicit default in either direction. An unhandled trait whose effective `optional` is `false` fails the render exactly as an unsupplied resource does; only the effectively-optional case degrades to a warning that continues.

**Why the posture is per-trait rather than one global rule.** Optionality is a property of the *(trait, component)* pair, not of the trait alone: `backup` on a throwaway cache is advisory, and on a database it is the entire point. The catalog knows the common case and the module knows its own, so both need a say — which is exactly what a default plus an attachment-site override expresses, and what a demand-side-only marker could not.

**Why a default and not a value, and why `core` states none.** A default is what makes the catalog's statement a recommendation rather than a ruling: measured against cue v0.17.1, a module narrowing a default is never a conflict, while narrowing a concrete value always is. And two defaults do not compose — a catalog restating one against a `core` default annihilates both, leaving `bool | true | false`: incomplete, with no default, and a diagnostic (`incomplete value bool`) that never says why. So `core` declares the field and no opinion, which is also the honest position: `core` does not know whether backups are optional.

**The rule the schema cannot carry, and where it went.** CUE has no way to say "this field may be given a default here but not a concrete value" — a field admits a concrete value or it does not, and this one must, because that is what a module writes at the attachment site. What separates the two cases is *who wrote it*, which the schema cannot see. `#TraitOptionalGate` ships in `core` and `opm catalog publish` unifies every published trait's `optional` against it, refusing an unstated posture and a pinned one. That is D22's mechanism in 0011 (unify against a shipped definition, surface CUE's own error) rather than a second one.

**Two properties of the gate worth carrying, both measured 2026-08-07 against cue v0.17.1.** Its two rules fail differently: a pinned posture is a conflict between concrete booleans and plain `cue vet` reports it, while an unstated posture is an *incomplete value* and plain `cue vet` does not — only `-c` does. And the gate must be unified into a **non-hidden** value, because `cue vet -c` does not check hidden fields, so a gate parked in a `_`-prefixed slot passes while checking nothing. A gate run without `-c`, or into a hidden field, enforces half of itself silently.

**Today's behaviour, measured 2026-07-29, and it is worse than "quiet".** `Match` produces three outcomes with three different volumes (`compile/match.go`):

- no bucket for the demanded FQN → an `oerrors.MissingFQN` is recorded (`:130`) — and `plan.Missing` **has no production consumer**. It is populated in `match.go`, asserted in `kernel/integration_test.go:183`, and read nowhere else; `compile/module.go:124` and `kernel/phases.go:86` carry only `Unmatched`.
- a bucket exists but every candidate is disqualified by unify or predicate → nothing is recorded against that FQN at all.
- the component paired with no transformer whatsoever → `plan.Unmatched`, which is the only outcome that stops the render.

There is also no `UnhandledResources` counterpart to `UnhandledTraits` (`:167-176` walks traits only). So a component carrying `#Container` and `#Backup`, on a platform with no backup provider, matches the deployment transformer, is not `Unmatched`, renders successfully, and has no backup. Under a provider-fulfilled contract model that is not an edge case — it is the routine failure.

**Alternatives considered:**

- **Keep the current soft treatment.** Rejected: it was survivable while every demanded primitive came from a catalog that also shipped its transformer. D4 makes an unsupplied demand a normal condition, and a silent one is indistinguishable from a fulfilled one.
- **A demand-side marker set** — `#Component.#optionalTraits`, keyed by contract FQN. **Originally adopted here as the trait opt-out's spelling, built by the implementing slice, then replaced (2026-08-07).** It wrote the FQN twice — once to attach, once to mark — and located optionality where the trait's author, who knows whether the trait is advisory, could not state it. Its one advantage was structural: a catalog cannot write a field that lives on `#Component`. The publish gate buys that back.
- **Give resources a demand-side optionality marker too.** Rejected: a component does not attach a resource it can do without. The asymmetry is real — a trait can be advisory while a resource is the thing being asked for.
- **A boolean on `#Trait` with a `core` default.** Rejected on the annihilation measured above: a catalog wanting the other posture cannot restate the default without destroying it and forcing every attaching module to answer explicitly.
- **Two fields — a catalog-side `recommendedOptional` and a demand-side `optional` defaulting to it.** Measured working, and rejected as one field too many for the same guarantee once dropping `core`'s default was found to give it directly.
- **Warn on everything and let the platform decide** — equivalently, make all traits optional by default. Rejected: the failure is silent in the cluster, not just in the log — `prune.go:112` is the existing evidence that a skipped operation with no Event and no metric reads as success. Under the per-trait posture the question does not arise as a default at all: every trait states one, and the gate refuses a catalog that does not.

**Rationale:** "Required vs optional" had no demand-side expression before this decision, which is why the prior behaviour was incoherent rather than lenient. Fixing it means naming the default: everything a component declares is a demand the platform must satisfy, and the exception is written down — per-trait by the declaring catalog, which knows the common case, and per-attachment by the module, which knows its own. Nothing defaults silently in either direction, and the gate refuses a catalog that leaves a posture unstated.

**Source:** User decision 2026-07-29. Current behaviour read from `library/opm/compile/{match,module,errors}.go` and `library/opm/kernel/phases.go` 2026-07-29.
**Revised:** 2026-08-10 — absorbed D46 (user decision 2026-08-07, during implementation of `core/core-platform-and-match`; CUE behaviour measured in `core/src` against cue v0.17.1), which replaced this decision's original demand-side-only trait opt-out with the catalog-stated posture above. Number tombstoned; the original spelling survives as a previously-adopted alternative.

### D29: (merged into D14, 2026-07-30)

A subscription names its catalog builds explicitly — content now in D14. Number retired.

---

### D30: Provenance is excluded by a Go-side operand filter over a fixed denylist

**Decision:** D26's exclusion is implemented as **candidate (a)** — `library` removes the excluded fields from both operands before unifying them, in Go. `core`'s primitive shape does not change.

The filter is a **denylist**, and that is the load-bearing half of this decision: it removes a fixed, named set and passes everything else through. The set is **`metadata.catalogVersion` and `metadata.description`**. Identity (`name`, `modulePath`, `apiVersion`, `fqn`), `labels`, and any field a future `core` release adds to a primitive all stay in the comparison by default.

Mechanically, `cue.Value` is immutable and exposes no field removal, so the filter is a syntax round-trip: `Syntax(cue.All(), cue.InlineImports(true))` → delete the named fields from every `metadata` block in the resulting AST → `BuildExpr`. `InlineImports` is required, because these values come from imported packages and an unresolved cross-package reference does not rebuild in a bare context. The strip must reach the primitive's **definition** as well as its instance: removing the instance's `catalogVersion: "1.1.0"` while leaving the definition's `catalogVersion!: #VersionType` leaves a required field nothing satisfies, which `Validate(cue.Concrete(false))` does not catch and a later concrete evaluation does.

**Alternatives considered:**

- **An allowlist over `metadata`** — keep `spec` plus a named contract surface, drop the rest. Rejected on two grounds, and the first is the reason (a) was preferred to (c) at all. D26 rejected the error-path filter because it forgives *any* metadata conflict, including an `apiVersion` or `fqn` disagreement that should never be tolerated; an allowlist reintroduces exactly that by a different route, which would make choosing (a) over (c) cosmetic. And it fails **open**: a field added to `#Resource.metadata` in some later `core` release is silently not compared, so a contract-bearing addition produces a silent wrong render — the class D27 and D28 exist to eliminate. A denylist fails **closed**; its worst case is a loud spurious match failure naming the field that needs adding to the list, and the `core`↔`library` release coupling that requires is one D29 already imposes.
- **Candidate (b), a structural split in `core`** — the contract surface becomes its own closed definition, with identity and provenance outside it. Not chosen, on measurement rather than taste: `experiments/03` finding 1 shows the round-trip **preserves closedness** in both spec-body styles, so (a) delivers the correctness (b) was wanted for without touching a published schema. (b) stays the right answer if the boundary ever needs to be visible to *catalog authors* rather than only to the matcher — naming the contract surface explicitly belongs in `core`, where it is declared and published, not asserted in Go where it drifts the first time `core` changes.
- **Candidate (c), the error-path filter.** Rejected at D26 and not reopened. `experiments/03` does record that (c) and this decision agree on all eight measured cases, and that no fixture can separate them — the identity fields that would are structurally forced into agreement, because the map key *is* `fqn` and `fqn` is computed from the rest. The argument for (a) is therefore defense in depth against a conflict arriving by a route the fixtures cannot model, not measured correctness, and the entry should not claim otherwise.
- **Stripping `catalogVersion` alone.** Measured wrong. `experiments/03` case 8 pairs two builds whose contract surfaces agree completely and which differ only in `catalogVersion` and a reworded `description`; with `description` left in, the match fails on the reworded sentence. A catalog author clarifying wording between builds is the most ordinary edit there is and must not be able to break a match.

**Rationale:** The denylist is what makes this decision different from the one D26 rejected. Both (a) and (c) let two builds meet; only a denylist keeps the tripwire on the values that must never disagree. Choosing which fields are *provenance* is a small, reviewable list; choosing which fields are *contract* is a claim about every field that will ever exist, and getting that claim wrong is silent in exactly the direction that matters.

One cost is real and worth recording rather than discovering later. The round-trip discards the value's position in its enclosing document, so a CUE-level message reads `_#def.spec.backup.retention: field not allowed` where (c) reads `components.web.#resources."…/backup@v1".spec.backup.retention: …`. The **field path survives intact**, which is the part that matters, and `oerrors.UnifyError` (`library/opm/errors/match.go:49-63`) already carries `Component` and `FQN` structurally and renders `component %q, fqn %q: %v`, so no information is lost. What is lost is that the raw CUE error no longer self-describes when read alone, and anything pattern-matching on the message path breaks.

**Source:** User decision 2026-07-29 selecting mechanism (a). Closedness survival, the field list, and the diagnostic cost all measured in `enhancements/0010/experiments/03-provenance-operand-filter/` the same day (cue v0.17.1) — 8 of 8 cases as predicted.

---

### D31: (merged into D14, 2026-07-30)

A subscription names exactly one catalog build — content now in D14. Number retired.

---

### D32: Two providers supplying one contract is a materialize-time error

**Decision:** A contract that declares `fulfilment: "provider"` (D37) must be supplied by **exactly one** transformer *requiring* it across a platform's subscribed catalogs. More than one is a **hard error at materialize**, naming both catalog paths and the contract key; zero is already D28's unresolved demand. It is raised in the kernel, so the CLI and the operator inherit one implementation. A CLI platform validation command that walks a platform's catalogs and reports the same condition before a deploy is a convenience on top, not the guard.

**No arbitration mechanism ships.** Which catalog should win when the overlap is *intended* was OQ17, resolved by D37 as a prohibition for this iteration rather than an arbitration: two providers is not a state a platform may reach, so nothing has to choose between them. The candidates for a future override survive in D37's alternatives.

The invariant is worth stating as one sentence, because it is what removes arbitration from the matcher entirely: **a provider-fulfilled contract resolves to exactly one transformer, or materialize fails naming the ambiguity.** `compile/match.go:138-157` iterates a bucket and pairs every candidate that unifies and satisfies the predicate — there is no "pick one" and under this decision there never needs to be, because the arity is guaranteed upstream.

**Alternatives considered:**

- **Bucket arity: more than one transformer in a `#matchers` bucket is the error.** **Originally adopted here, then reversed on measurement (2026-08-01).** The reasoning was that after D14 a bucket holding two transformers could only mean two different catalogs supplying one contract. It cannot: `materialize/index.go:82-95` builds the reverse index from **required ∪ optional** demands, and one contract legitimately feeds many different outputs — a container becomes a Deployment *and* a Service *and* PVCs. Measured against the shipped catalog, `catalog_opm`'s own `#ContainerResource` bucket holds **8** transformers and `#VolumesResource` **6**, all from one catalog, and 15 trait buckets hold 3–7 each. A guard on bucket arity would refuse `catalog_opm` on day one. This is why the test is keyed on the contract's *declared* fulfilment and counts **required** demands only: a provider requires what it fulfils, while optional consumption is tolerance. The conclusion the original reasoning reached — a loud materialize-time error in the kernel, with no arbitration — was right and is unchanged.
- **Detect competing providers by predicate equality** — two transformers from different catalogs whose `requiredResources`, `requiredTraits` and `requiredLabels` all agree. Measured to have no false positives today (21 transformers in `catalog_opm`, 21 distinct predicates), and rejected because it false-*negatives* on the real case: a k8up transformer requiring `backup` + `schedule` and a Velero transformer requiring `backup` alone are two providers of one contract with different predicates.
- **Weights on the catalog entry**, required, with the higher weight winning an overlap. The author's first proposal, and rejected on three grounds. A weight sits on the *catalog*, so one number arbitrates every contract two catalogs share — it cannot say "k8up wins `backup`, velero wins `restore`" without being scoped per contract, at which point it is a priority table under a misleading name. Making it *required* taxes the overwhelming majority of platforms, which have no overlap at all, with a field that is meaningless in their case; a required field that is usually inert trains authors to stop reading it, which cuts against D6's care about which fields demand a real decision. And a number records no reason: when k8up wins because 100 > 50, nothing says why that was right. If an override does ship, an explicit per-contract binding or an ordered `prefer` list expresses the same precedence as reviewable source rather than arithmetic — which is D14's principle applied to arbitration.
- **A CLI-only validation tool, with no kernel check.** Rejected on the same argument OQ13 made against D27's publish-side enforcement: a check the operator never runs is not a guarantee. The walker is worth building — telling an author before a deploy beats telling them during one — but it belongs on top of a kernel error, not instead of it.
- **Newest-wins across the whole bucket.** Rejected as incoherent rather than merely risky. Two catalogs have unrelated version namespaces, so comparing `k8up@1.5.0` against `velero@1.2.0` is arithmetic on values that share no scale. It would produce a stable, plausible-looking, meaningless choice.
- **Allow the duplicates.** The status quo, and it is the defect OQ15 was filed about: both candidates pair, both render, and one component emits two copies of the same workload. No error, no warning.

**Rationale:** Detection is cheap, loud, and available now; arbitration is a design question with no real instance to design against. Measured 2026-07-30 and re-verified 2026-08-01: no cross-catalog fulfilment exists anywhere in the workspace — 141 self-imports and **zero** foreign across `catalog_opm`, `catalog_kubernetes` and `catalog_opm_experimental`. The cross-catalog pairing D4 exists to enable is entirely prospective. So a kernel error breaks nothing today, and when the first genuine overlap arrives its shape is what an override gets designed against instead of a guess frozen into `core`.

This also keeps the entry's failure model consistent with itself. D28 made an unresolved demand an error rather than a silent omission; D30 chose a denylist over an allowlist precisely because it fails closed. A silent tie-break would have been the one quiet arbitration in a design that argues everywhere else that quiet is the enemy.

**Source:** User decision 2026-07-30. Bucket-iteration behaviour read from `library/opm/compile/match.go:138-157` and the reverse-index construction from `library/opm/materialize/index.go:76-90` on 2026-07-29. Cross-catalog import closure measured across `catalog_opm`, `catalog_kubernetes` and `catalog_opm_experimental` on 2026-07-30.
**Revised:** 2026-08-01 — mechanism corrected per D37. Bucket arity was measured to be undetectable-by-arity and is folded into the alternatives above; the guard now keys on a contract's declared `fulfilment` and counts required demands only. The conclusion is unchanged.

---

### D33: `#definitionName` is removed from `#Module` and `#ComponentTransformer`

**Decision:** `core/src/module.cue:27` and `core/src/transformer.cue:24` both compute `#definitionName: (#KebabToPascal & {"in": name}).out`, and **nothing reads either one**. Both are deleted. `#definitionName` stays on `#Resource` (`resource.cue:14`), `#Trait` (`trait.cue:13`) and `#Blueprint` (`blueprint.cue:15`), where it has a reader: each builds its `spec!` field key from it via `strings.ToCamel` (`resource.cue:35`, `trait.cue:34`, `blueprint.cue:42`).

**No snake-aware projection is needed anywhere.** D8 retypes only `#Module.name` to `#SnakeNameType`; primitive names stay kebab-case under `#NameType` (`schemas/target.cue:65-67`, `:135`, `:241`, `:264`). So `#KebabToPascal` keeps working unchanged at all three sites that consume its output, and the `Media_server` failure this entry surfaced exists only at the one site where the result is discarded.

**Alternatives considered:**

- **Add a snake-aware projection to `core`.** This is the option the acceptance criteria named first, and it was written before the reader set had been checked. Rejected: it builds a type-level transformation to feed a field nothing consumes.
- **Keep `#definitionName` on `#Module` and accept `Media_server`.** Rejected. A wrong value that nothing reads is still a wrong value, and a computed field sitting in a published schema is an invitation for something to start reading it — at which point the defect acquires a consumer and stops being free.
- **Delete it from `#Module` only, leaving `#ComponentTransformer`.** Rejected as arbitrary. The transformer's copy is equally unread and equally unreachable; leaving it means the next name-shape change re-opens exactly this question at exactly this site.

**Rationale:** This resolves a `draft → accepted` gate by deletion rather than by design, which is the cheapest available outcome and the one the evidence supports. It is also consistent with D2's treatment of `#Module.version` and D16's refusal to add `#Catalog.name`: a field with no reader is removed rather than maintained.

**Source:** User decision 2026-07-30. Reader set measured the same day — `grep` for `definitionName` across `core/`, `library/`, `cli/`, `catalog_opm/`, `catalog_kubernetes/`, `modules/` and `opm-operator/` returns the three primitive consumers named above plus the two `#definitionName` declarations being deleted; the only other hits in the workspace are schema copies inside two frozen `library/enhancements/006-*` experiments.

---

### D34: Contract API versions follow the Kubernetes ladder, and the promise is keyed to the level

**Decision:** `#APIVersionType` admits the three Kubernetes forms — `vNalphaM`, `vNbetaM`, `vN` — and D27's additive-only rule binds **per level** rather than uniformly. `core/src/types.cue:22-24`'s `#MajorVersionType` (`^v[0-9]+$`) is untouched and keeps naming module majors; `#APIVersionType` is the widened sibling D4's contract keys read.

- **alpha (`vNalphaM`)** — no compatibility promise. A build may remove a field, narrow a type or change a default without bumping. 0011 D9's publish gate is **off** at this level.
- **beta (`vNbetaM`)** — D27 applies in full. A break requires a beta bump (`v1beta1` → `v1beta2`), which may ship beside its predecessor in one build.
- **GA (`vN`)** — D27 applies in full. A break requires a major bump, likewise shippable side by side.

The level-keyed scope now lives in **D27** itself, so the rule reads correctly where it is stated; what remains here is the ladder, its day-one assignment, and the ordering it requires.

**Day one, per catalog.** Every contract-bearing primitive in a catalog takes that catalog's level, so the judgement is per catalog rather than per primitive:

| Catalog | Contracts | `apiVersion` |
| --- | --- | --- |
| `catalog_opm` | 38 (7 resources, 26 traits, 5 blueprints) | `v1beta1` |
| `catalog_kubernetes` | 27 resources | `v1beta1` |
| `catalog_opm_experimental` | 3 resources | `v1alpha1` |

Transformers take no `apiVersion` — they keep the build SemVer (D4), so the ~50 of them are unaffected.

**The level is not the catalog's release prerelease, and conflating the two is the likely misreading.** A catalog's release version (`1.0.0-alpha.2`) and a contract's pre-stable level (`v1beta1`) are independent axes, and only the second decides whether D27 binds. A beta contract shipped inside an alpha catalog build is gated in full; an alpha contract inside a stable catalog build is not gated at all. Both spell "alpha", and the day-one table above assigns `v1beta1` to two catalogs that publish only `1.0.0-alpha.*` today — so the two values disagree in the live regime rather than in a constructed example.

**Ordering is not required for correctness and is required for diagnostics.** The match path is exact-key (`bucketTransformers`, `library/opm/compile/match.go:128`), so no comparator ever decides what matches. The one reader is `sortFQNsBySemVer` (`match.go:322-336`), which orders the alternatives in a `MissingFQN`. It gets a kube-aware comparator for contract keys while build keys keep SemVer — a split along a line D4 already draws.

**Not imported from Kubernetes, each for a stated reason.** Conversion and storage versions: Kubernetes needs them because it persists objects; OPM renders, so two `apiVersions` are two independent contracts and a module names one. Feature gates: OPM has no per-primitive opt-out, and the nearest analogue is coarser and already exists — `catalog_opm_experimental` is a separate subscription a platform takes or declines. Deprecation windows: Kubernetes's exist because cluster upgrades force version moves on a support lifecycle, and under D14 a platform moves only when someone edits `version:` in its own source, so any window would be arbitrary.

**Alternatives considered:**

- **A uniform gate at every level, with the ladder spelled but alpha still gated.** This was the recommendation offered and it was rejected on coherence: gating alpha enforces additivity on the one level whose definition is *no additivity promise*, which empties the label. Alpha's whole value is that it is honest about what it does not guarantee.
- **`v1` from the start with the gate on immediately.** Rejected: it commits to compatibility on catalogs that are all still pre-1.0 at the build level (`1.0.0-alpha.*`, `1.1.0-alpha`, `1.2.0-alpha.*`), and it leaves no honest label for a contract that genuinely is experimental — which `catalog_opm_experimental` exists to hold.
- **`v1alpha1` across the board on day one.** Rejected on measurement: `catalog_opm`'s entire contract history is 715 field-declaration additions against 30 removals (2815 lines added, 118 deleted), and inspection shows most of the 30 are the blueprint propagation-guard hoist (`81641e0`) rather than contract surface. These catalogs have behaved like beta or better since bootstrap; alpha would be a label their own history contradicts.
- **Enforcing "alpha contracts only in the experimental catalog" as a publish rule.** Rejected as unenforceable in general: it cannot bind a third-party provider catalog, and 0011 OQ7 is open on exactly that first-party/third-party boundary. It stays a first-party convention, and the real contract is the ordinary one — do not depend on alpha, and a platform's only lever is declining the subscription.
- **Keeping `#APIVersionType` narrow at `^v[0-9]+$`** (the "resolves the other way" branch `schemas/target.cue`'s comment anticipated). Rejected: it forces every pre-stable break to present as a GA-looking bump, so the string carries no stability signal at exactly the point in the project's life where one is most useful.

**Rationale:** The ladder is what the author asked for — alpha and beta handled the way Kubernetes handles them — and the measurements say the expensive parts of that model are the parts OPM does not need. Coexistence is already in D4. Ordering never reaches the matcher. What remains is a string form and a per-level promise, both cheap.

The level-keyed promise is also the more internally consistent reading of D27. D27 exists because D4's contract key no longer guarantees that two builds agree, so something has to; but "something has to" is a claim about levels that make a promise. Alpha makes none, and saying so plainly is better than enforcing a rule the label denies.

The day-one assignment follows the evidence rather than caution: `v1beta1` for `catalog_opm` and `catalog_kubernetes`, whose measured history is overwhelmingly additive, and `v1alpha1` for `catalog_opm_experimental`, which is the catalog whose name already says what its promise is.

One consequence is recorded rather than left to be discovered: **0011 D9's publish gate becomes level-aware.** It defers to D27 by name, so the carve-out propagates by reference rather than by amendment, but its own wording says *every primitive in the tree* and an implementer would check all of them — the gate must classify each primitive's `apiVersion` and run the pull-and-compare only at beta and GA. What that gives up at alpha is narrow and specific: closedness still fails a removed field loudly at match time, so the only class that goes unguarded is the default drift `experiments/02` measured, which surfaces as a deferred render failure. Under this decision's day-one assignment that is confined to `catalog_opm_experimental`'s three contracts. With both mainline catalogs at beta the gate is load-bearing from day one rather than deferred to `v1`, which raises the priority of the unmeasured `cue.Value.Subsume` question `02-design.md:86` records. The same carve-out would apply to OQ13's candidate (c) if a read-side check ever ships.

A second, smaller consequence: admitting the alpha/beta forms exposes a defect already in the tree. `sortFQNsBySemVer` switches comparison rule per pair — SemVer when both sides parse, lexical otherwise — which is not transitive. Measured against Masterminds v3: `v1alpha1 < v2`, `v2 < v10` and `v10 < v1alpha1` all return true, and the same three FQNs sort to `[v2, v10, v1alpha1]` or `[v1alpha1, v2, v10]` depending on input order. The kube-aware comparator this decision requires is also the fix.

**Source:** User decision 2026-07-31. `#APIVersionType` spelling measured against Masterminds v3 in `library/opm/compile` on 2026-07-31 (throwaway probe, removed after the run): `v1`/`v2` parse as `1.0.0`/`2.0.0`, `v1alpha1`/`v1alpha2`/`v1beta1` fail with `invalid semantic version`, and the resulting lexical fallback orders `v1` ahead of its own pre-releases. Contract counts and churn measured the same day across `catalog_opm`, `catalog_kubernetes` and `catalog_opm_experimental`.

---

### D35: Compatibility enforcement is publish-side only; a catalog check command is an aid, not a guarantee

**Decision:** D27's additive-only promise is enforced at **publish** (0011 D9) and at the **match rung**, and nothing else is a guarantee. There is no compatibility check on the render path, none at materialize, and none required before a platform's subscription moves.

A catalog check command ships alongside — 0011 D7's `opm catalog registry check` gains a compatibility mode — and it is explicitly an **aid**. It can be run deliberately against a published catalog by someone who did not publish it, and nothing requires it to have been run. It does not convert publish-side enforcement into a guarantee, and this entry does not claim it does.

**The exposure, stated plainly because the acceptance criteria ask for exactly this:** a catalog published outside `opm catalog publish` carries no compatibility promise OPM can verify on a consumer's behalf. `cue mod publish` keeps working (D11), so the chain 0011 D9's induction rests on is breakable by any publisher who declines the tool, and OPM reports nothing when it is broken. Under D34 that exposure exists at beta and GA only — alpha promises nothing, so it has nothing to break.

**Alternatives considered:**

- **The subscription-bump check — deferred, not rejected.** Under D14 the only moment a platform's catalog bytes change is an edit to `version:`, which makes that edit a determinate trigger with both builds nameable and no I/O on the render path. Recorded as future work rather than adopted now, and filed as [`open-platform-model/opm-operator#63`](https://github.com/open-platform-model/opm-operator/issues/63), because the operator is the actor that holds both the previous applied state and the incoming one without needing to read git.
- **A read-side check on every render or materialize.** Rejected: it puts a registry round-trip on the path D14 exists to keep offline and deterministic, and it reports to whoever renders next rather than to whoever caused it.
- **Treating the check command as the guarantee.** Rejected on D11's own reasoning: a check nobody is required to run is not something a consumer can rely on. Shipping it as an aid and saying so is honest; shipping it and calling it enforcement is not.
- **Materialize compares a newly-pulled build against another build of the same catalog it already holds.** Eliminated by D14 rather than argued: a subscription names one build, so materialize never holds two and this check could never fire. This was the free option when the question was filed, which is what raised the price of every remaining answer.

**Rationale:** The actor a read-side check protects against is prospective. All four catalog repositories in [`research/migration-inventory.md`](research/migration-inventory.md) are first-party, and D32's measurement found cross-catalog fulfilment entirely prospective — so the third-party publisher who declines `opm catalog publish` does not exist yet. The cost of being wrong is also bounded and legible: `experiments/02` measured that the removal class fails loudly at match (`spec.backup.retention: field not allowed`), leaving only default drift deferred, and that surfaces as an incomplete-value render error rather than as wrong output. Against a prospective actor and a bounded failure, a permanent read-side mechanism is not yet earned.

The check command is worth shipping anyway because it is nearly free: the `catalog` command group is being created for D7 and D9 regardless — measured 2026-07-31, `cli/internal/cmd/` today carries only `module`, `instance`, `config` and `operator` — and the comparator is D9's.

**One exposure this accepts that is not about third parties.** D14's reproducibility rests on a named tag meaning fixed bytes, and 0011 OQ3 records that OCI registries make immutability opt-in configuration. If a tag is overwritten, a named build's bytes change under a platform that edited nothing, and with no read-side check nothing in OPM notices. The deferred subscription-bump check is the mechanism that would; until it exists, tag immutability is a deployment constraint OPM **states** rather than a property it verifies.

**Source:** User decision 2026-07-31.

---

### D36: Matching labels live in their own field, unified upward from primitives

**Decision:** Matching moves out of `metadata.labels` into a dedicated `matchLabels` field carried by `#Resource`, `#Trait`, `#Blueprint` and `#Component`. A component's `matchLabels` is the **wholesale unification** of its attached primitives' — no filter, no key list — while `metadata.labels` is left alone and never unified upward. Component fragments become pure wrappers that attach primitives and declare nothing of their own. `#ComponentTransformer.requiredLabels` selects on `matchLabels`.

`core` deletes `#LabelWorkloadType`, and the key it names is renamed `opm.opmodel.dev/workload-type` and owned by `catalog_opm`. `matchLabels` is **not rendered** — it does not reach `#TransformerContext.componentLabels` and therefore does not appear on any rendered object.

**Alternatives considered:**

- **Extend D27's wording to cover component fragments (OQ16 candidate (a)).** Rejected. Fragments are addressable by CUE definition path, so a publish gate could compare them without inventing identity — but D34 keys the promise's strength to a primitive's `apiVersion`, and a fragment has none of its own. Measured 2026-08-01, the label-setting fragments attach 6–8 independently-versioned primitives (`stateful_workload` attaches 8), so no principled rule says which level governs. It also leaves the `SPEC.md` union claim wrong and gives no match-time coverage.
- **Leave the fragment outside the promise deliberately and say so (candidate (b)).** Rejected once the label proved movable. It was the cheapest option and conceded a permanent exposure; this decision removes the exposure instead of documenting it.
- **Union `metadata.labels` unfiltered, as `SPEC.md` describes (candidate (c) as filed).** Refuted by measurement rather than judgement. `experiments/04`'s `v_full` fails on `resource.opmodel.dev/category`, which takes `workload` on Container, `storage` on Volumes and `config` on ConfigMaps; the real `catalog_opm` fails at `#StatefulWorkload` before reaching a module at all, and real `modules/jellyfin` additionally collides on `trait.opmodel.dev/category`. The spec's own sentence — *conflicts MUST fail at unification* — is what makes this a build break rather than latent safety.
- **Union `metadata.labels` behind a filter**, in three forms: keys under a `core.opmodel.dev/` prefix, every key except a named categorisation denylist, or one key named by `core` and read by index. All three were measured working and rejected together. Every filtered union must **iterate**, and CUE refuses to iterate a struct holding an unset required field (`missing required field in for comprehension`), so each one forces dropping `!` from the container's workload-type — degrading "the author must pick" from a required field to an incomplete value. The prefix form additionally keeps the vocabulary in `core` at namespace granularity and silently drops a catalog-owned key; the index form needs a `core` release per new matching label.
- **Rendering `matchLabels` behind an opt-in flag defaulting off.** Demonstrated working in `experiments/04`'s `v_render` and deliberately not taken, for now. The fold is a four-line guard at struct level and can be added later without disturbing anything this decision fixes; shipping it now would mean deciding where the flag lives, and a runtime-only flag is ruled out by the byte-identical-render gate.

**Rationale:** Every problem the filter designs solved traces to a single cause — `metadata.labels` conflates categorisation with matching. Separating the two removes the filter and its three costs at once: the structs unify wholesale so the `!` marker survives, the categorisation labels never meet structurally rather than by a filter agreeing not to look at them, and a genuine disagreement between two primitives becomes a meaningful conflict (`conflicting values "daemon" and "stateful"`) rather than an artifact of unrelated labels sharing a namespace.

It also removes an asymmetry that already existed rather than introducing a new concept. `#ComponentTransformer` declares its matching *demand* in a dedicated field (`transformer.cue:46`), separate from its own `metadata.labels`; only the component side declared matching *supply* in `metadata.labels`. This makes the two sides agree.

Because `core` no longer names the key, the vocabulary is catalog-owned **by construction** rather than by a filter's cooperation — which is what turns the `opm.opmodel.dev` rename from a follow-on migration into a consequence of the design. `#LabelWorkloadType` costs nothing to delete: measured 2026-08-01 it has **zero readers** across `catalog_opm`, `catalog_kubernetes`, `library`, `cli`, `opm-operator` and `modules`, which all write the literal string; every other occurrence in `core/src` is a comment example. That is the same reader-set argument D33 used.

Not rendering is the author's call and is recorded as provisional. It has a fleet-visible consequence worth stating: rendered objects carry `core.opmodel.dev/workload-type` **today**, via the `componentLabels` fold at `transformer.cue:147-157`, and they will stop. That is a label removal on every live workload, landing in the same window as the identity migration rather than adding a new one.

**Source:** User decision 2026-08-01, on [`experiments/04-component-label-union/`](experiments/04-component-label-union/) — outcome 2026-08-01.

---

### D37: A contract declares where its fulfilment comes from, and a provider-fulfilled contract admits exactly one provider

**Decision:** `#Resource` and `#Trait` gain `fulfilment: *"catalog" | "provider"`.

- `"catalog"` — the declaring catalog implements it. Today's behaviour and the default, so every existing primitive is unchanged and nothing opts in by accident.
- `"provider"` — fulfilment is expected from a transformer in **another** catalog. The declaring catalog ships no transformer for it, deliberately.

For a `"provider"` contract a platform must carry **exactly one** transformer *requiring* it. Two is refused at materialize, naming both catalog paths and the contract key; zero is already D28's unresolved demand. A platform whose backup contract is fulfilled by k8up cannot add Velero alongside it — switching providers is a **replacement** of a subscription, not an addition.

`#Blueprint` does **not** get the field. A blueprint composes resources and traits, and a transformer can never demand one — `core/src/transformer.cue:54-64` has `requiredResources` and `requiredTraits` and no blueprint equivalent — so the field would be unreachable. A blueprint's fulfilment is that of the contracts it composes.

**This corrects D32's mechanism**, and D32 now carries the corrected test directly. In short: bucket arity cannot detect a two-provider overlap, because `materialize/index.go:82-95` indexes required ∪ optional demands and one contract legitimately feeds many outputs. The guard therefore keys on the contract's declared `fulfilment` and counts **required** demands only. D32's conclusion — a loud materialize-time error in the kernel, no arbitration, CLI walker as convenience — is unchanged; see D32's alternatives for the measurement that reversed the test.

**Alternatives considered:**

- **Derive it: a contract whose declaring catalog ships no transformer for it is provider-fulfilled.** Costs no schema and is **not computable**. D17 records as explicitly not delivered that "which catalog ships FQN X?" can be answered with no platform in hand — the kind-segment count is not fixed (`…/opm/resources` against `…/opm/blueprints/workload`), so the owning catalog cannot be read off an FQN. It is also fragile in principle: a catalog later adding a transformer would silently change the contract's character.
- **Detect competing providers by predicate equality** — two transformers from different catalogs whose `requiredResources`, `requiredTraits` and `requiredLabels` all agree. Measured to have no false positives today (21 transformers in `catalog_opm`, 21 distinct predicates), and rejected anyway because it false-*negatives* on the real case: a k8up transformer requiring `backup` + `schedule` and a Velero transformer requiring `backup` alone are still two providers of one contract, and their predicates differ.
- **Ship an arbitration mechanism now** — per-contract binding, ordered `prefer` list, catalog weights, or a replaceable-default marker on the transformer (OQ17's candidates (a)–(d)). Deferred rather than rejected. Re-measured 2026-08-01, cross-catalog fulfilment still does not exist anywhere in the workspace — 141 self-imports, **zero** foreign, across all three catalogs — so there is nothing to design against, and every candidate is purely additive to this decision later.
- **A boolean `providedExternally`.** Rejected for a closed enum, which leaves room for a third fulfilment mode without a breaking rename.

**Rationale:** This is what D4 exists to enable, stated positively. A generic `backup` contract declared in `catalog_opm` — the author's opinion of what backup means and how it behaves — with no transformer of its own, fulfilled by a k8up provider catalog on an unrelated release cadence, is the supported path rather than a tolerated one. Anyone may publish a competing *contract* under their own path; that is a different FQN and no conflict arises.

The declaration has to be explicit because it cannot be inferred, and the contract author is the one who knows: choosing not to implement a contract is a design intent, not an omission a tool can detect. Making `"catalog"` the default means the field is invisible to everyone who is not doing this.

The single-provider guard is the other half of the same intent. Two providers for one contract both unify, both satisfy the predicate and both render, so the failure without a guard is duplicate output rather than an error — the class OQ15 was filed about and D28 refused to tolerate elsewhere. Bounding it to exactly one keeps the arity `compile/match.go` already assumes, without arbitration and without the matcher learning to choose.

**Source:** User decision 2026-08-01. Bucket arity and transformer predicates measured across `catalog_opm`, and cross-catalog import closure re-verified, the same day; index construction read at `library/opm/materialize/index.go:76-95`, candidate loop at `library/opm/compile/match.go:138-157`, transformer demand surface at `core/src/transformer.cue:54-64`.

---

### D38: (merged into D2, 2026-08-10)

A module declares a version again, supplied by an identity subpackage — content now in D2. Number retired.

---

### D39: (merged into D9, 2026-08-04)

The version label returns to the schema and the kernel verifies it — content now in D9. Number retired.

---

### D40: A declared version's major must agree with its path's major, checked in the identity package and in `core`

**Decision:** An identity package exports `VersionMajor`, **derived** from `Version` and never authored, and asserts it equal to the major the path declares:

```cue
VersionMajor: "v" + strings.SplitN(Version, ".", 2)[0]
VersionMajor: Major
```

`core` asserts the same relation independently, on `#Module.metadata` and `#Catalog.metadata`, between `version`'s major and `modulePath`'s. Both are kept: the identity-package check names the file the author is editing, and the `core` check holds for an artifact whose identity package is absent, hand-written, or non-conformant.

**Alternatives considered:**

- **Feed `VersionMajor` into `fqn` or `uuid`,** which is where the field was first proposed. Rejected on measurement: the major is **already** in both. `fqn` *is* the module path, the path carries `@vN`, and `uuid` is `SHA1(OPMNamespace, fqn)` — measured 2026-08-03, `@v2` yields `b762d291-…` and `@v3` yields `6dc33f7b-…`. A second route to a value that already has one is not redundant-and-harmless here: measured the same day, `ModulePath: ".../jellyfin@v2"` with `Version: "3.0.0"` **vets clean**, so a version typo that today changes nothing would, under that wiring, move every instance UUID and every owner label — reporting success while `prune.go:107` stopped deleting. That is D2's failure through a different door, and this decision is what makes the wiring provably redundant rather than merely discouraged.
- **Leave the check to publish.** Rejected as too late and incomplete. 0011's `#TagRef` compares the *tag's* major against the *path's*, which CUE's own publish already enforces (measured 2026-07-26: `publish version "v9.1.0" does not match the major version "v3"`). Nothing compares the **declared version** against either. Without this decision the disagreement surfaces only when a platform names the build — `_majorAgrees: conflicting values "1" and "2"` — which reports one publisher's mistake to a different party, about an artifact they cannot fix.
- **Put the check only in `core`.** Genuinely available and weaker in one respect: the two values are *written* in the identity package, so a failure there names the file the author has open, while a `core`-side failure names a metadata field two hops away.
- **Put the check only in the identity package.** Rejected while identity packages remain hand-written with no schema validating their shape — `#IdentityPackage` is defined in this entry's `schemas/target.cue` and nowhere in shipped code, so a package that simply omits `VersionMajor` omits the check with it.

**Rationale:** This is the field the "`VersionMajor` in the FQN" proposal was reaching for, used for the job it can actually do. Deriving the major rather than declaring it removes an authored value; asserting it against the path closes the one gap between `Version` and `ModulePath` that no other check covers. Once it holds, the major in `fqn` is provably the major `version` names — which is what turns "do not wire the version into the key" from a rule someone must remember into a statement that is true either way.

**Source:** User decision 2026-08-03. Major-already-present and version/path-skew both measured against `cue v0.17.1` the same day, on a worked tree carrying this entry's target shapes; publish-side tag check measured 2026-07-26 and recorded in 0011 `schemas/target.cue`'s `#TagRef`.
**Revised:** 2026-08-03 — **amended by D43** for `#Catalog`: the `core`-side assertion is dropped and the identity package's is the only one, on the ground that both values are written there and 0011 D8 validates the file's shape at publish. The relation itself is unchanged, as is the identity-package half of this decision. What D43 gives up is consumer-side verification for a non-conformant artifact, which D43 records rather than this one. The **`#Module` half of this decision stands** — D43 leaves it deliberately undecided.

---

### D41: Instance identity derives from the module's registry path, not from its FQN

**Decision:** `#ModuleInstance.metadata` gains an explicit `fqn`, and `uuid` derives from it:

```cue
fqn:  "\(#moduleMetadata.registryPath):\(name):\(namespace)"
uuid: #UUIDType & cue_uuid.SHA1(OPMNamespace, fqn)
```

`#Module.metadata` exposes `registryPath` — the module path with the major stripped, already computed as `_ref.registryPath` under D1. **Neither the module's version nor its major reaches instance identity.**

`#Module.metadata.fqn` and `.uuid` are **unchanged** and keep the major.

The two values answer different questions, and deriving one from the other forced them to agree when they should not:

- `module.uuid` is **artifact** identity — *which module is this*. `@v2` and `@v3` are genuinely distinct modules under both CUE and Go semantics (D1), so it must move across a major.
- `instance.uuid` is **ownership** identity — *which live resources does this manage*. It is the `module-instance.opmodel.dev/uuid` label `opm-operator/internal/apply/prune.go:107` reads, so it must survive every upgrade of the same deployment, a major bump included.

Both labels already ship on every rendered resource. The names promised they were different facts; this makes them so.

**Alternatives considered:**

- **Keep deriving `instance.uuid` from `module.uuid`** — today's shape, and this entry's as accepted. Rejected: it makes a `@v2 → @v3` upgrade orphan every resource the new major no longer renders, silently. D1 already reduced the blast radius from *every release* to *every major*, which is why this was not visible while D2 held; it does not remove it.
- **Take the major out of `#Module.metadata.fqn`,** so the existing derivation becomes major-free without touching `#ModuleInstance`. Rejected: it breaks artifact identity to fix ownership identity. D1 rejected dropping the major from artifact paths on its own grounds — for a module the path is the only thing distinguishing `@v1` from `@v2` — and that argument is unchanged.
- **Derive instance identity from the module's `name`** rather than its path. Rejected on collision: `opmodel.dev/modules/jellyfin` and `example.com/jellyfin` both carry `name: "jellyfin"`, so two unrelated modules deployed under one instance name in one namespace would fight over the same resources. A full module path is unique **by construction**, so `registryPath` distinguishes them structurally — measured 2026-08-03 against the owner-scoped spelling then in force: two such paths yield `a0be73cc-…` and `ebc35491-…`. *(Citation corrected 2026-08-04: this originally read "`registryPath` is owner-scoped under 0011 D5". 0011 D13 removed owner-scoping under `opmodel.dev` in favour of domain ownership, so the uniqueness now comes from the domain rather than from an owner segment. The property this alternative depends on is unchanged.)*
- **Add a second, major-free UUID to `#Module.metadata`** and derive the instance from that. Available, and rejected as a spare identity value: `registryPath` is already computed under D1 and has independent callers (it is the OCI repository every address-composition site in `cli` and `library` collapses into), whereas a second UUID would exist only to be hashed again.
- **Defer to a later entry.** Rejected on migration timing, which is the strongest argument for doing it now. This entry already moves every instance UUID once, and D18 settles that adoption is a one-time manual pass over an enumerable fleet. Landing this in the same window costs nothing extra and makes it the **last** time an instance UUID ever moves. Landed later it is a second fleet-wide relabelling, carrying the same silent-orphaning exposure through a second cutover.

**Consequences, each measured:**

- **`#TransformerContext.#moduleInstanceMetadata.fqn` has to pick a meaning.** It is filled today with `inst.ModuleFQN()` (`library/opm/schema/context.go:59`) — the *module's* FQN, under an instance-shaped name. With an instance FQN defined, the block exposes the **instance's**, and the module's takes its own key if a reader appears. Free today: measured 2026-08-03, no shipped transformer reads `.fqn` from that block — the same 117-use survey that found no reader for `.version`, all `.name` or `.namespace`.
- **Two majors of one module, deployed under the same instance name in the same namespace, now collide on `instance.uuid`.** Not a new constraint: rendered resource names are instance-scoped, so that pair already collides on names.
- **`#Module.metadata.uuid` keeps a reader** after losing this one — the `module.opmodel.dev/uuid` label. It does not become the reader-less field D33 and D16 delete.

**Rationale:** The owner label exists to answer "does this controller own this object", and the answer must not change because a module author made a breaking schema change. A major bump is a new *module* and the same *deployment*; the previous derivation could not express that, because it had only one identity to spend.

Stating the derivation as an explicit `fqn` rather than an inline interpolation inside `uuid` is what makes the "custom set of fields" reviewable in one place, and it mirrors `#Module`'s own `fqn → uuid` shape.

**Source:** User decision 2026-08-03, on a worked tree carrying this entry's target shapes; the invariance matrix (version bump, major bump, owner change, namespace change) measured against `cue v0.17.1` the same day. Prune behaviour at `opm-operator/internal/apply/prune.go:107`; `Status.InstanceUUID` repopulation at `opm-operator/internal/reconcile/moduleinstance.go:308`; context fill at `library/opm/schema/context.go:59`. **Restates the identity invariant now stated at D2**, and touches `#ModuleInstance`, whose shape is otherwise enhancement 0001's.

---

### D42: Every primitive kind is flat, and `catalog_opm`'s blueprints move up one segment

**Decision:** A catalog's primitives sit **directly** under exactly one path per kind — `…/resources`, `…/traits`, `…/blueprints`, `…/transformers` — with no grouping subdirectory beneath any of them. `#IdentityPackage.kindPrefix` is therefore a complete statement of a catalog's key space rather than a convenience for the common case.

`catalog_opm`'s five blueprints move accordingly: source files from `src/blueprints/workload/` to `src/blueprints/`, `package workload` → `package blueprints`, `modulePath` from `"\(id.ModulePath)/blueprints/workload"` to `id.kindPrefix.blueprints`, and every FQN re-keyed — `…/blueprints/workload/stateless-workload@1.0.0` becomes `…/blueprints/stateless-workload@v1beta1`. `#CatalogMemberFQNGate` needs no change.

**Read from the shipped tree 2026-08-03, and it is why this is a decision rather than a cleanup.** `#CatalogMemberFQNGate` asserts `declaredModulePath: identity.kindPrefix[kind]` and builds the key as `kindPrefix[kind] + "/" + name + "@" + _keyVersion` — both exact equality by unification. `kindPrefix.blueprints` is `RegistryPath + "/blueprints"`, while `stateless_workload.cue:24`, `stateful_workload.cue:22`, `daemon_workload.cue:20`, `task_workload.cue:20` and `scheduled_task_workload.cue:20` every one declare `"\(id.ModulePath)/blueprints/workload"`. So the gate as specified **refuses `catalog_opm` on day one**, and the key it computes is not the key the leaf authors.

D17 already recorded the fact that makes it fail — *"resources sit at `…/catalogs/opm/resources` while blueprints sit at `…/catalogs/opm/blueprints/workload`, one segment deeper"* — as its reason for not delivering catalog-derivability. The gate then encoded the assumption D17 refuted, and this decision removes the discrepancy from the side that is cheaper to move.

**Alternatives considered:**

- **Prefix rather than equality** — `strings.HasPrefix(declaredModulePath, kindPrefix[kind])`, with the FQN derived from the *declared* `modulePath` instead of from the prefix. Cheapest to implement and rejected on what it costs the gate: `kindPrefix` stops predicting where a primitive lives, so it becomes a constant that has to be re-checked against reality at every use, which is the shape `identity/identity.cue` exists to remove. It also weakens `#CatalogMemberFQNGate` back to D17's rule — "somewhere under this catalog" — which is not enough to catch a primitive placed under the wrong *kind*.
- **A per-primitive prefix supplied to the gate**, asserting only that the declared path sits under `RegistryPath`. The same weakening with more plumbing.
- **Keep `kindPrefix` exact and special-case blueprints** with a second, deeper entry. Rejected: it makes the map a description of `catalog_opm`'s current layout rather than a rule, and the next grouping segment anyone adds re-opens the question.
- **Leave the blueprints where they are and drop the FQN half of the gate**, checking only `catalogVersion`. Rejected — the FQN half is what catches the stale-literal failure D21 accepted when it moved `fqn` out of `core`, so removing it leaves that failure with no gate at all.

**Rationale:** `#CatalogMemberFQNGate` can only be a gate if the four prefixes are a complete statement of where a catalog's primitives may live. Once they are, the rule is checkable, the FQN is derivable from identity plus name plus one authored `apiVersion`, and a primitive placed under the wrong kind fails at publish rather than producing a key nobody demands. The alternative direction — making the prefix tolerant — buys back one grouping directory in one catalog at the price of the property the gate exists for.

Moving the files rather than only the declared string keeps a primitive's `modulePath` equal to the package that defines it, which is the correspondence D21 relies on when it argues for retaining kind segments.

**Consequences, each measured 2026-08-03:**

- **Blueprint names become globally unique within a catalog**, since the grouping segment that could have disambiguated them is gone. The five in `catalog_opm` are already distinct (`stateless-workload`, `stateful-workload`, `daemon-workload`, `task-workload`, `scheduled-task-workload`). This is the same trade D21 made in the other direction when it kept kind segments so a resource and a trait named `secrets` do not collide.
- **Seven import sites change**, all inside the migration's existing blast radius: `modules/metallb/components.cue:20`, `modules/istio_ambient/components_control_plane.cue:4` and `components_dataplane.cue:4`, `library/testdata/modules/web_app/components.cue:5`, `cli/tests/fixtures/modules/podinfo/components.cue:6`, `cli/tests/integration/module-apply/testdata/components.cue:7`, and `library/opm/helper/synth/instance_integration_test.go:154`, which writes the import as a string. The modules are being republished and the testdata regenerated regardless.
- **`core`'s own doc-comment examples move** — `core/src/blueprint.cue:17` and `:19`, and `core/src/types.cue:45`, all use the deep path.
- **D17's "explicitly not delivered" claim weakens, and D37's justification partly rests on it.** With exactly one segment per kind, the owning catalog *is* recoverable from a contract FQN: strip `@version`, strip the name, strip the kind segment. D17's stated blocker was that the kind-segment count is not fixed, and this decision fixes it. **Not reopened here** — D37's other argument stands unaffected (a catalog later adding a transformer would silently change a contract's character, so `fulfilment` must be declared rather than inferred), and reworking D17 and D37 on the back of this is a separate pass. Recorded so the next reader does not cite D17's blocker as still-current.

**Source:** User decision 2026-08-03. Gate shape read from `schemas/target.cue`'s `#CatalogMemberFQNGate` and `#IdentityPackage`; blueprint paths, package clauses and the import-site inventory read across `catalog_opm/src/blueprints/workload/`, `modules/`, `cli/tests/`, `library/testdata/` and `library/opm/helper/synth/` the same day.

---

### D43: The version-major agreement is asserted in the identity package alone, for `#Catalog`

**Decision:** D40 asserts the version/path major agreement twice — once in the identity package (`VersionMajor: Major`) and once in `core`, on `#Catalog.metadata` and `#Module.metadata`. For **`#Catalog`** the `core` copy is dropped. `identity/identity.cue` is the sole assertion, and it reaches `metadata` through the wiring that already exists (`modulePath: id.ModulePath`, `version: id.Version`).

For a conformant catalog the `core` copy is provably redundant, which is the whole argument: both values are *written* in `identity.cue`, `identity.cue` asserts the relation between them, so any value that reaches `#Catalog.metadata` has already passed it. Re-deriving in `core` checks the same relation on the same two values one hop downstream.

**One mechanical constraint bounds what "assert it in the identity package" can mean.** `core` cannot import a consumer's identity package — the impossibility D2 and 0011 D12 both record for `metadata.version`, since `#Module` and `#Catalog` have no way to name an arbitrary artifact's identity package. So there is no shape in which `#Catalog.metadata` reads `id.VersionMajor` directly; the reference is the authored wiring in `catalog.cue`, exactly as `modulePath` and `version` already are.

**Alternatives considered:**

- **Keep both, as D40 decided.** Rejected as the redundancy it is for every conformant artifact, at the cost of a derivation in `core` that has no reader beyond itself.
- **Keep only the `core` copy and drop the identity-package assertion.** Rejected on D40's own ground, unchanged: the two values are *written* in `identity.cue`, so a failure there names the file the author has open, while a `core`-side failure names a metadata field two hops away.
- **Wire `versionMajor` as a third authored field on `#Catalog.metadata`**, sourced from `id.VersionMajor`, with `core` asserting it equals the path's major. Available, and rejected: it adds a visible metadata field whose only reader is its own check, and it puts a third value in the wiring `0011` D12's publish check has to verify.

**Rationale:** D40's stated reason for keeping both was that "identity packages remain hand-written with no schema validating their shape — a package that simply omits `VersionMajor` omits the check with it." That is answered by 0011 D8, which already requires publish to refuse an identity file that does not match `#IdentityPackage`. With the shape validated at publish, the second assertion is defence against a case the first already covers.

**The exposure this accepts, stated so it is a choice rather than a discovery.** The `core` constraint is **consumer-verifiable**: `library/opm/materialize/pull.go:23` builds the catalog value, which unifies against `#Catalog`, so the check fires on the consumer's side at materialize. `identity/identity.cue` is never evaluated as a package by any consumer — it reaches them only through the values it produced. So after this decision, a catalog whose identity package is absent, hand-written or non-conformant carries **no major-agreement check any consumer can run**, and D11 records that `cue mod publish` keeps working, so that artifact class is not hypothetical. The residual failure then surfaces at `#SubscriptionSelection`'s `_majorAgrees` as `conflicting values "1" and "2"` in the *platform author's* file, about a *catalog publisher's* mistake — which is the outcome D40 added the `core` check to avoid.

**The follow-on that removes the exposure, recommended and not required by this decision:** have `core` **export** `#IdentityPackage`, and have each `identity/identity.cue` embed it. `VersionMajor` is then supplied by the definition rather than by the author remembering to write it, and the D40 objection above stops applying at authoring time rather than at publish time. This is permitted: the identity package's import-free invariant is scoped to **intra-module** imports (D21 — "free of intra-module imports"), `strings` is a builtin, and `core` imports no catalog, so no cycle exists. It would also let `identity.cue` drop the `#VersionType` it duplicates today for exactly that reason, and give `#IdentityPackage` one home instead of a definition in this entry's `schemas/target.cue` mirrored by hand in four repos.

**Deliberately not decided here: the `#Module` half.** D40 asserts the same relation on `#Module.metadata`, and D2 gives modules an identity subpackage, so the argument transposes without change. It is left open because the two artifact types having different answers to "where is the major checked" is the asymmetry D2 and 0011 D12 have just spent two decisions removing — so the module half should be settled deliberately rather than inherited. Recommendation on the record: symmetry, and it is free if the `#IdentityPackage` export above lands.

**Source:** User decision 2026-08-03. Consumer-side evaluation point read at `library/opm/materialize/pull.go:23`; the `core`-cannot-import-identity constraint from D2 and 0011 D12; publish-side identity-shape validation from 0011 D8. **Amends D40.**
**Revised:** 2026-08-05 — the `#Module` half this decision left open is **settled by D45**, which transposes this holding rather than diverging from it. The recommendation recorded here (symmetry, and free if the `#IdentityPackage` export lands) is what D45 takes.

**Revised:** 2026-08-08 — the decision stands; one fact in the exposure paragraph above needs reading in the present tense rather than the future. Both replacements it names are **still unbuilt**. The publish-side one is 0011 D21's unification, which needs `cli-publish-pipeline` (`status: planned`); the consumer-side residual — "surfaces at `#SubscriptionSelection`'s `_majorAgrees`" — is library-side, carried by this entry's own `library-acquire-and-subscription` slice (formerly `library-subscription-collapse`; "one major-agreement check survives beside the subscription"), also `planned`. Measured 2026-08-08 against `core/src`: `_majorAgrees` has never existed in `core` at any commit, and `core-platform-and-match` correctly never claimed it, since `schemas/target.cue`'s preamble puts subscription selection's production implementation in Go. So between 0011's `core-identity-package` landing (2026-08-08) and the first of those two slices, **nothing in shipped code checks the relation at all** — `#IdentityPackage.VersionMajor` is its only statement and no tool runs it. The `recommended follow-on` above (identity files embedding the shipped definition) is now available for the first time, since the definition exists, and would make the assertion live under a plain `cue vet` of the artifact's own tree rather than waiting on either slice.

---

### D44: A transformer is an adapter, not a primitive; `apiVersion` is primitive-only

**Decision:** `metadata.apiVersion` is carried by `#Resource`, `#Trait` and `#Blueprint` and **not** by `#ComponentTransformer`. The scope itself now lives in **D25**, so the rule reads correctly where the field is defined; what remains here is the taxonomy that decides it, the shape split that enforces it, and the reclassification and renames that follow. D25's rename of `version` to `catalogVersion` stays correct for all four kinds, because a transformer's `catalogVersion` is its key's source component (D4) and its provenance at match (D25, D26).

The shared shape is split rather than trimmed, because the shape is how the field arrived. `#PrimitiveIdentity` now covers the three primitives and narrows `fqn` to `#ContractFQNType`; a new `#TransformerIdentity` carries `name` + `modulePath` + `catalogVersion` + `#ImplFQNType` and no `apiVersion`. There is **no shared parent**. `#ContractIdentity` and `#ImplIdentity` are retired — they were the parent plus an `fqn` narrowing, which existed only because the parent straddled the split.

**`#Blueprint` is a primitive.** It composes resources and traits rather than introducing vocabulary, and it is still a fundamental building block an author reaches for; it keeps its `apiVersion` and its contract key. `core/SPEC.md:29` and `:38` currently list it under **Constructs**, so those two category lines move it to Primitives — a `SPEC.md` co-update gated by the `core-schema-edit` skill. Nothing else follows: D37's exclusion of `#Blueprint` from `fulfilment` stands on its own structural ground (`core/src/transformer.cue:54-64` has `requiredResources` and `requiredTraits` and no blueprint equivalent, so a transformer can never demand one), which makes a blueprint a primitive that nothing demands rather than a non-primitive.

Two shapes legitimately keep their four-kind scope and are **renamed** to stop implying otherwise: `#PrimitiveFQNGate` → `#CatalogMemberFQNGate`, and `#IdentityPackage.primitivePrefix` → `kindPrefix`. Both genuinely cover transformers — the gate checks a transformer's package path (D17's rule binds it) and its build-keyed FQN — so the correction is to their names, not their arms. D42's "exactly one prefix per kind, no grouping segment" constrains the renamed field unchanged. The rename is free today: neither shape exists in shipped code, and `identity/identity.cue` carries only `ModulePath` and `Version`, so `kindPrefix` is the name catalog authors type from day one rather than one they migrate to.

**Enhancement 0011 D9 gains one clause:** the compatibility gate runs over primitives only.

**Alternatives considered:**

- **Delete the field from `#ComponentTransformer` and leave the shared shape named `#PrimitiveIdentity` with four members.** The minimal edit, and rejected as treating the symptom. The shape is the mechanism: name a struct after three things, admit a fourth, and every field added to it lands on the fourth for free. `apiVersion` is the one that has bitten so far; D37's `fulfilment` and D36's `matchLabels` were each kept off transformers by hand. The next field gets the same manual exclusion or the same defect.
- **Keep an inert `apiVersion` on transformers and exclude them in 0011 D9.** Rejected on two grounds. It is a required field with no reader — the argument D33 used to delete `#definitionName` and D16 used to refuse `#Catalog.name` — and there is no value to assign it, since a transformer's inputs are other people's contracts and its output is platform objects, so "this transformer's contract major" has no referent. Worse, the exclusion becomes load-bearing in a *different entry*: 0011 D9 reads "for every primitive in the tree being published, pull the last published build that shipped a primitive of that `name` at that `apiVersion`", which under D25's four-kind reading covers transformers and **resolves**, because the lookup key would exist. The additive-only rule then refuses ordinary catalog releases — changing rendering logic, dropping an emitted field and narrowing an output type are all normal transformer edits and all D27 violations. That inverts D4, which keeps the build in the transformer key precisely because a transformer is free to change.
- **Keep a shared parent under a kind-neutral name** (`#CatalogMemberIdentity`), with both shapes extending it. Genuinely available and rejected narrowly: it saves repeating three field lines and reintroduces the straddle. A parent spanning a category split `core/SPEC.md` draws deliberately is where the next field lands ambiguously.
- **Treat this as a documentation fix** — correct D25's prose and leave the schema. Rejected: `schemas/target.cue` is what an implementer builds `core/src/transformer.cue` from, and it said `apiVersion!`.
- **Follow `core/SPEC.md` and class `#Blueprint` a construct**, dropping its `apiVersion` and its contract key. Rejected by the author: a blueprint is a fundamental building block a module attaches, and its `spec` is a surface modules write against, so it earns D27's promise. `SPEC.md` moves rather than the schema.

**Rationale:** The taxonomy is not this entry's to invent — `core/SPEC.md` already carries it normatively. `:38` enumerates "the primitives `#Resource` and `#Trait`, the constructs … and the **adapter** `#ComponentTransformer`", and `:34` states why the adapter category exists: "Forcing transformers into the composition graph would mean every primitive needs a target-specific arm — an explosion that doesn't compose. Adapters sit beside the model, not inside it." D25 enumerated four kinds under one word and contradicted that; D34 stated the correct scope two days later without amending D25, so the log asserted both and the schema followed the earlier one.

Fixing it as a category rather than as a field is what makes the correction durable. The primitives are the vocabulary a module writes against, so they are the surface that needs a contract key, an additive promise and a publish gate. The adapter is the implementation, so it needs a build key and nothing else — which is D4's split, stated in the type system instead of maintained by hand at each new field.

**Consequences, measured 2026-08-03 against cue v0.17.1:**

- **`apiVersion` on a transformer becomes inexpressible, not merely unread.** `#TransformerIdentity` is a closed definition, so the pinned MUST-FAIL case yields `_transformerWithAPIVersion.apiVersion: field not allowed`.
- **`#CatalogMemberFQNGate` needs no restructuring.** `declaredAPIVersion` becomes optional with a conditional requirement (`if kind != "transformers"`), and `_keyVersion` is unchanged: its transformer branch selects `identity.Version` before `declaredAPIVersion` is reached, and CUE's laziness spares the absent optional. Measured — a transformer with the field absent yields the build with no error, a contract supplying it yields the apiVersion, and a contract omitting it fails `declaredAPIVersion: field is required but not present`.
- **`core/src/transformer.cue` gains `catalogVersion!` and not `apiVersion!`**, which is what D34's "the ~50 of them are unaffected" already assumed.
- **`core/SPEC.md:29` and `:38` move `#Blueprint` from Constructs to Primitives.** Gated by the `core-schema-edit` skill like every other SPEC change in this entry.
- **Three wording-only sites**, substantively correct and loose in the same way: D1 (`#PackagePathType` on four kinds — right, a transformer does declare a package path), D21 (`version!` required on "every primitive kind" — right for all four under its `catalogVersion` name), and D17 (whose rule binds primitives *and* transformers). None changes meaning; each says "primitive" where it means "catalog member".

**Source:** User decision 2026-08-03, stating the taxonomy directly — "A primitive is the fundamental building block, so Resource, Trait, Blueprint. A transformer is not a primitive" — and placing `#Blueprint` with the primitives explicitly. Category vocabulary read from `core/SPEC.md:29`, `:34` and `:38` the same day; the D25/D34 conflict from `03-decisions.md:452` against `:644`, with D25 carrying no revision note; closedness refusal and gate laziness both measured against cue v0.17.1. **Amends D25's `apiVersion` clause.**

---

### D45: The version-major agreement is asserted in the identity package alone for `#Module` too

**Decision:** D43's holding transposes to `#Module`. `core` asserts no relation between `#Module.metadata.version`'s major and `modulePath`'s; `identity/identity.cue`'s `VersionMajor: Major` is the only assertion, reaching `metadata` through the wiring D2 establishes (`modulePath: id.ModulePath`, `version: id.Version`). **D40's `#Module` half is superseded**; its identity-package half is untouched, as it was for `#Catalog`.

This settles what D43 left explicitly undecided, and it settles it the way D43 recommended on the record. The two artifact types now answer "where is the major checked" identically, which is the asymmetry D2 and 0011 D12 spent two decisions removing.

**Alternatives considered:**

- **Keep the `core` assertion on `#Module` while `#Catalog` has none — the state D43 leaves behind.** Rejected: nothing distinguishes the two cases. Both write `ModulePath` and `Version` in an identity package that asserts the relation between them; both reach `metadata` by authored wiring; both have that wiring checked at publish by 0011 D12. A rule that binds one artifact type and not the other is a rule the next reader has to look up rather than know.
- **Drop both assertions.** Rejected on D40's measurement, which is unchanged and is why the identity-package half survives: `ModulePath: ".../jellyfin@v2"` with `Version: "3.0.0"` **vets clean**, and the disagreement then surfaces at `#SubscriptionSelection`'s `_majorAgrees` in a platform author's file, about a publisher's mistake they cannot fix.
- **Keep both `core` copies and reverse D43 instead.** Genuinely available, and rejected for D43's reason rather than by preference: for a conformant artifact the `core` copy re-derives the same relation over the same two values one hop downstream, and 0011 D8 plus D21 already refuse an identity file that does not match `#IdentityPackage`.

**Rationale:** The exposure this accepts is identical to D43's and is worth restating rather than inheriting silently: a module whose identity package is absent, hand-written or non-conformant carries **no major-agreement check any consumer can run**, because `identity/identity.cue` is never evaluated as a package by a consumer — it reaches them only through the values it produced. `cue mod publish` keeps working (D11), so that artifact class is not hypothetical.

Two things bound it. The residual failure is loud rather than silent — a version whose major disagrees with its path is caught at publish by 0011 D12's `metadata.version == id.Version` check for any artifact that goes through the tool. And D43's recommended follow-on removes the exposure for both artifact types at once: have `core` **export** `#IdentityPackage` and have each `identity/identity.cue` embed it, so `VersionMajor` comes from the definition rather than from an author remembering to write it. That is now cheaper than when D43 recorded it, because 0011 D21 already requires `#IdentityPackage` to ship in `core` and 0011 D22 puts `#CatalogMemberFQNGate` beside it.

**Source:** User decision 2026-08-05, taking D43's recorded recommendation. Measurements are D40's and D43's, unchanged; publish-side wiring check from 0011 D12; identity-file shape validation from 0011 D8 and D21. **Supersedes D40's `#Module` half; completes D43.**

**Revised:** 2026-08-08 — the decision stands. Its exposure paragraph inherits D43's, and so does D43's 2026-08-08 note: both named replacements are still unbuilt, so the relation this decision moved out of `core` is currently checked by nothing that runs. 0011's `core-identity-package` landed the schema on 2026-08-08 and nothing unifies against it yet. See D43.

---


### D46: (merged into D28, 2026-08-10)

A trait's optionality is stated by its catalog and overridden by the attachment — content now in D28. Number retired.

---

### D47: The first-party catalogs consolidate into one — `catalog_opm` absorbs `catalog_kubernetes` and `catalog_opm_experimental` on the v2 line

**Decision:** On the v2 line there is **one first-party catalog**. `catalog_kubernetes`'s 27 resources and 27 transformers move into `catalog_opm` as a **raw passthrough family** — native Kubernetes APIs implemented as-is, positioned as the last resort for what the abstractions do not model — with every member's name prefixed `k8s-` (`k8s-deployment`, `k8s-object`), files `k8s_*.cue`, definitions `#K8s*`. `catalog_opm_experimental`'s 3 resources and 4 transformers move in as **abstraction-family members at `v1alpha1`**, their D34 level. Each absorbed repo's v2 line **ends at the `v2.0.0-alpha.1` it has already published** (tags read 2026-08-10): the tag stays resolvable permanently, but the line is abandoned with no promise broken — an alpha promises nothing (D34's own semantics at the build level) and no consumer pins either one. Each repo keeps its protected `v1` branch serving the live v1 fleet unchanged, gains a tombstone README on `main`, and is archived once the fleet migrates.

Two rules make the two-family structure hold rather than blur:

- **The abstraction family never depends downward on the raw family.** No blueprint, trait, or abstraction transformer requires a `k8s-*` contract; abstraction transformers keep emitting Kubernetes types directly through the shared `schemas/` tree. This holds today for free — D32's measurement found zero cross-catalog imports — and a repo-local vet check keeps it from regressing. The raw family is a leaf: modules may demand it, nothing inside the catalog builds on it.
- **The group stays out of the name; collisions are curated.** A raw member takes its bare upstream kind name. On an actual same-name collision across API groups (core/v1 `Event` vs events.k8s.io/v1 `Event` is the live example; none exists among the 27 moved members), the non-core group's member gets a group prefix. A standing rule, not day-one work.

**One stated loss.** D34's rationale used "`catalog_opm_experimental` is a separate subscription a platform takes or declines" as OPM's coarse feature-gate analogue, and D14 deleted `#SubscriptionFilter`, so a subscription names one build with no filtering. After the merge a platform subscribing to `catalog_opm` materializes the alpha transformers too. The remaining protections are the contract key's visible level (`@v1alpha1` in every demand string) and D34's convention against depending on alpha. A platform-level level-gate is deliberately **not** designed here — no platform has asked to decline alpha, and per the D32/D37 pattern the mechanism gets designed against the first real case.

**Alternatives considered:**

- **Keep the three repos (status quo).** Rejected: D34's per-primitive `apiVersion` already carries the stability signal the experimental catalog existed to quarantine at repo granularity, making the repo a duplicate of the mechanism; and the `catalog_opm`/`catalog_kubernetes` split implies a platform separation that does not exist — measured 2026-08-10, `catalog_opm` vendors its own Kubernetes schema tree under `src/schemas/kubernetes/` and its 23 transformers emit Deployments, HPAs, and PDBs directly, so what the split actually maintained was two Kubernetes-emitting catalogs with duplicated vendored schemas and three subscription pins for one surface.
- **Keep `catalog_kubernetes` separate as a provider catalog.** Rejected: it fulfils no `catalog_opm` contract (D32: 141 self-imports, zero foreign) — it declares its own. D37's provider story is for third-party catalogs on unrelated cadences (the k8up shape), and does not need the raw surface to live in its own repo.
- **Delete the raw passthrough surface outright.** Rejected: it is the escape hatch for exactly the modules the abstractions cannot yet model — the live fleet's `cert_manager`, `metallb`, and `istio_ambient` are that class — and `k8s-object` is the last resort's last resort.
- **A `k8s/` FQN path segment instead of a name prefix** (`…/catalogs/opm/k8s/resources/deployment@v1`). Rejected: D42's `kindPrefix` is a complete, flat statement of the key space and the shipped `#CatalogMemberFQNGate` refuses a member filed under an extra segment; a family segment is exactly the arbitrary grouping D42 banned, since nothing in the key derives it. The name prefix costs nothing in `core` and is equally legible.

**Rationale:** The consolidation is what D4 and D25 made cheap and D14 made safe: contract keys no longer pin builds, so merging catalogs moves no module-facing identity, and a subscription names one build, so the merged catalog's release cadence is inert until a platform edits its pin. What remains distinct about the raw family is its *meaning* — as-is passthrough versus intentional abstraction — and that distinction lives in the name prefix, the no-downward-dependency rule, and D48's upstream-mirrored versioning rather than in repo topology. Reversibility is also better than it was: under the contract/build key split, re-extracting the raw family later would move no contract key.

**One consequence discovered at implementation (2026-08-10):** the `k8s-` prefix reaches the module author's spec keys, because `core`'s `#Resource` derives the spec's single field key from the member's name (`spec!: (strings.ToCamel(metadata.#definitionName)): _`). A component using a raw contract writes `spec: k8sDeployment: …` where the old catalog took `spec: deployment: …`. Accepted rather than worked around: the key is one more place the escape hatch announces itself, and exempting raw members would mean loosening a core constraint for exactly the family least entitled to special casing.

**Source:** User decision 2026-08-10. Catalog contents, the duplicated schema trees, and the consumer inventory (modules `metallb`, `cert_manager`, `istio_ambient` pin `opmodel.dev/catalogs/opm_experimental@v1`; `cli/internal/config/templates.go` and `cli/hack/platform.cue` reference `opmodel.dev/catalogs/kubernetes`) measured 2026-08-10. Cross-family import closure re-cited from D32's 2026-07-30 measurement.

---

### D48: A raw-family contract's `apiVersion` mirrors the upstream Kubernetes API version, assigned at adoption

**Decision:** A `k8s-*` contract's `apiVersion` is the version of the upstream API it passes through: apps/v1 → `k8s-deployment@v1`, autoscaling/v2 → `k8s-hpa@v2`, an upstream beta arrives as `@vNbetaM`. The raw family's ladder is thereby **upstream-owned**: a contract graduates when upstream graduates, and a new upstream version is a new contract — which is D27's semantics by construction, since two upstream versions of one kind are two independent shapes. D34's day-one per-catalog table is superseded for the two absorbed catalogs: the per-catalog assignment survives only for the abstraction family (`v1beta1`; the ex-experimental members `v1alpha1`), and the raw family is assigned per member.

The default is **one version per kind per catalog build** — the version the vendored schema tree carries. Coexistence of two versions of one kind in one build is supported (the matcher keys on the full contract FQN and `availableApiVersions` already diagnoses a level mismatch by name) and reserved for genuine transition windows, such as an upstream deprecation overlap a single platform must straddle; the ordinary skew case — clusters on different Kubernetes versions — is served by different platforms pinning different catalog builds under D14. When two versions do ship, the current version's transformer keeps the bare name and the other suffixes its level (`k8s-hpa-v2beta2`), because a transformer carries no `apiVersion` (D44) and its name is its key.

`#APIVersionType` admits every form this produces unchanged, and `#APIVersionGated` prices the levels correctly without modification: upstream GA and beta carry D27's additive-only promise — which at those levels is precisely upstream's own API guarantee — and an upstream alpha, should one ever be worth vendoring, promises nothing.

**Alternatives considered:**

- **Blanket `v1beta1`, D34's original assignment for `catalog_kubernetes`.** Rejected: it launches GA-mirrored APIs at a level below the promise upstream already makes, and the eventual graduation moves the contract key — every module demanding `k8s-deployment@v1beta1` migrates for a change that changed no shape. Starting where upstream is avoids a scheduled pointless migration.
- **An OPM-owned per-member stability judgement.** Rejected: it invents a second opinion on a surface whose entire contract is "as upstream". The moment OPM's level and upstream's diverge, the label misleads in one direction or the other.
- **Mirroring the full upstream coordinate, group included, into the key.** Rejected: the group disambiguates rarely and would be paid for on every demand string (`k8s-apps-deployment`); D47's curation rule covers the rare collision.

**Rationale:** The raw family's one promise is fidelity to upstream, and a version key that mirrors upstream is that promise made structural. It also settles who moves the key: nobody at OPM — upstream does, and the catalog follows at adoption. The corner this backs into — several members at different majors within one kind space, versions coexisting during transitions — is priced by D49's filing scheme rather than left to accumulate as identifier suffixes.

**Source:** User decision 2026-08-10. Matcher coexistence support read from `schemas/target.cue` `#PrimitiveDemand.availableApiVersions`; `#APIVersionType` form coverage checked against `core/src/types.cue` the same day.

---

### D49: Contract kinds file under a version segment — `<kind>/<apiVersion>/` — derived from the key

**Amends:** D42

**Decision:** The three contract kinds file one segment deeper, under their own `apiVersion`: `resources/v1/k8s_deployment.cue`, `resources/v1beta1/container.cue`, `resources/v1alpha1/namespace.cue`, and likewise `traits/v1beta1/`, `blueprints/v1beta1/`. The rule is **uniform across both families** — abstraction members file by their level exactly as raw members do. Transformers stay flat under `…/transformers`: they carry no `apiVersion` (D44), so there is no segment to derive.

The **FQN does not change**: `…/resources/k8s-hpa@v2`, exactly as D4 keys it. The directory segment is *derived from* the key's own `apiVersion` and never authored independently — which is what makes this an amendment to D42 rather than a reversal. D42 banned grouping segments because an arbitrary segment lets filing location and key drift apart. A version segment cannot drift: `#CatalogMemberFQNGate` checks it against the `declaredAPIVersion` it already holds. D42's "no arbitrary grouping" survives in full; "exactly one prefix per kind" becomes "one prefix per kind × apiVersion, derived".

Mechanically, in `core`: `#IdentityPackage.kindPrefix` stays the enumerated per-kind map (the base prefixes are unchanged), and the gate's equality becomes, for the three contract kinds, `declaredModulePath: kindPrefix[kind] + "/" + declaredAPIVersion`, with `kindPrefix.transformers` compared as today. The must-fail pin in `identity_package_pins.cue` splits in two: a member under an *arbitrary* extra segment is still refused; a contract member **without** its apiVersion segment is now refused too. The FQN construction (`kindPrefix[kind] + "/" + name + "@" + _keyVersion`) is untouched — the segment never enters the key.

What the layout buys, stated as the failure it prevents: under flat filing, the first coexistence of two versions of one kind (D48's transition window) forces the version into the CUE identifier — `#K8sHpa` mutates to `#K8sHpaV2` in the shipped package, rippling to every importer for a change that changed no shape. Under versioned filing, a second version is a new file in a new package, the identifier is stable in both (`#K8sHpa` in `resources/v2/` and `resources/v2beta2/`), and an import site names the level it consumes (`k8sv1 "opmodel.dev/catalogs/opm/resources/v1"`) — the same honesty at the import line that the `k8s-` prefix provides at the name.

**Alternatives considered:**

- **Flat filing, version-suffixed identifiers on coexistence** (the zero-amendment option). Rejected for the asymmetry above: the cost lands as an identifier mutation on the already-shipped member at the worst moment, and only multi-version members pay it, so the layout lies about the rule until the rule matters.
- **The version segment in the FQN as well** (`…/resources/v2/k8s-hpa@v2`, or dropping the `@` suffix for the segment). Rejected: redundant with the key's own `@vN`, and it reshapes `#ContractFQNType`, every demand string, and the matcher's key space for zero information.
- **`k8s/<group>/<version>/` filing, the full upstream mirror.** Rejected: the group is not in the key, so filing is no longer derivable from it — precisely the drift D42 exists to prevent (also rejected as a name scheme at D47).
- **Versioned filing for the raw family only.** Rejected: two filing rules and a conditional gate, to save moving ~15 abstraction files on a line nothing has published. Graduation already changes the demand string (a new contract under D27, opted into deliberately), so the import path moving with it adds no migration that was not already happening.

**Rationale:** D42's own rationale is that `kindPrefix` can only gate if it completely predicts where a member lives. Per-member `apiVersion` (D48) is what broke the flat map's completeness — when every member of a kind shared the catalog's level, the segment was redundant; once levels vary per member, the segment is derived content. Extending the derivation by one checkable component preserves exactly the property D42 bought — a member in the wrong place fails at publish — while giving coexisting versions disjoint packages instead of colliding identifiers.

**Consequences:**

- `core/src/identity_package.cue` (gate equality) and `identity_package_pins.cue` (the split must-fail pins) change under the `core-schema-edit` protocol with the SPEC.md co-update; the shipped `#IdentityPackage` field shapes are otherwise untouched.
- 0011's publish-gate member walk iterates version subdirectories per contract kind; `opm catalog version set` is unaffected — it writes the identity file, which knows nothing of member filing.
- D42's blueprint flattening composes with this rather than being redone: `src/blueprints/workload/` moves to `src/blueprints/v1beta1/` in one step, since the `catalogs-identity-authoring` slice carrying D42 is still in progress.
- Import sites change shape once (`…/resources` → `…/resources/<level>`), inside the same blast radius as the D42 import moves already counted.

**Source:** User decision 2026-08-10. Gate shape and `kindPrefix` enumeration read from `core/src/identity_package.cue:94-115` and `identity_package_pins.cue:94-124` the same day.

Open Questions live in [`07-questions.md`](07-questions.md) — the entry's question register.
