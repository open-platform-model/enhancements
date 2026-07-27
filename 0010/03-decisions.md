# Design Decisions — Module and Catalog Identity

This document records every significant design choice with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. The log is **append-only** — never remove or renumber existing entries. If a decision is reversed, add a new decision that supersedes it and leave the original in place as historical context.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source.

---

## Decisions

### D1: `metadata.modulePath` is the artifact's complete CUE module path, and `fqn` is that path

**Decision:** `#Module.metadata.modulePath` and `#Catalog.metadata.modulePath` carry the artifact's full CUE module path **including the major suffix** — `opmodel.dev/m/acme/jellyfin@v2`, `opmodel.dev/catalogs/opm@v1` — rather than a bare prefix that must be recombined with a name. `metadata.fqn` is that same string. `uuid: SHA1(OPMNamespace, fqn)` keeps its formula with a version-free, major-bearing input, and `instance.uuid` is unchanged.

**Alternatives considered:**

- **A bare prefix plus a separate `major` field.** The smallest change, and it does put the major back in identity. Rejected: it adds a *second* identity fragment that must be kept in step with `cue.mod` while leaving the prefix-plus-name recombination intact — paying for the major without simplifying anything else.
- **`modulePath/name` with no version component at all.** Rejected: it collapses two incompatible majors into one identity, which is the collision major suffixes exist to prevent. Go states the reasoning outright — the suffix is what lets a toolchain treat two majors as genuinely distinct modules.
- **Deriving the major inside CUE from the artifact's own `cue.mod/module.cue`.** Measured 2026-07-26 (cue v0.17.1): `@extern(embed)` plus `_raw: _ @embed(file="cue.mod/module.cue", type=text)` plus `regexp.FindSubmatch` yields `"v2"`, and it survives publishing because `cue.mod/module.cue` ships inside the artifact zip (confirmed by unzipping `opmodel.dev/modules/jellyfin@v2` tag `v2.0.2`). Rejected on user decision, and independently constrained: `@embed` resolves relative to the *embedding file's own directory* and cannot escape upward (`../cue.mod/module.cue` fails with `@embed: cannot refer to parent directory`), so `core` cannot do it on a consumer's behalf and every artifact would carry attribute-and-regex boilerplate.

**Rationale:** This is the only candidate that makes something else *simpler* rather than only paying for the major. The declared path already is the registry address, so the address becomes recoverable by reading one field; the "path leaf equals the artifact's name" constraint becomes a statement about a single field rather than a relationship between two independently-authored ones; and the value an author sees is the string CUE, the registry, and the `import` statement already agree on.

**Source:** User decision 2026-07-26.

### D2: `#Module` declares no version

**Decision:** `#Module.metadata.version` does not exist. A module's source declares `modulePath` and `name` and nothing about its version. The full version exists only as the coordinate an artifact was published at and resolved by — the OCI tag — with the major carried in the module path per D1.

**Alternatives considered:**

- **Keep the field and enforce that it equals the release tag.** Rejected as policing a problem rather than removing it: it requires a publish-side derivation, a read-side check, a version-authoring command, a migration of every already-published artifact, and a permanent invariant every future tool must respect — all to keep two values equal that need not both exist.
- **Keep `version` as a declared-but-never-authored field, injected at acquire from the resolved tag.** Genuinely viable, and it makes agreement true by construction while preserving the metadata surface. Rejected because it keeps `fqn`, `uuid`, and the shape gate depending on a value that exists only after a registry fetch — so a module read from disk has no identity — and because a declared field will eventually be written to by someone.
- **A hidden `_version` written into the artifact at publish.** Rejected on two independent grounds. It puts bytes in the artifact that do not exist in source, which is the mechanism measured producing local-versus-published divergence. And `core/SPEC.md:304` records that a field which is not a declared, permitted member of the closed `#Module` breaks re-unification into `#ModuleInstance.#module` with "field not allowed" — a failure invisible to `cue vet` on a standalone module, because a standalone module is only closed once.

**Rationale:** CUE and Go both keep the full version out of source and neither has this class of bug. Removing the field deletes the problem instead of defending against it: no drift to detect, no fleet to migrate for version reasons, no invariant for future tooling to uphold.

It also removes a latent failure that *fixing* the drift would have activated. Because `fqn` interpolates `version`, a genuinely-moving version changes `module.uuid` → `instance.uuid` → the owner label on every rendered resource, and `opm-operator/internal/apply/prune.go:107` skips any delete whose live label disagrees with `Status.InstanceUUID` — which `reconcile/moduleinstance.go:308` repopulates from each new render. Every upgrade would have silently orphaned whatever it removed.

**Source:** User decision 2026-07-26.

### D3: `#Catalog` keeps a full SemVer `metadata.version` — as a compatibility signal, never a key

**Decision:** `#Catalog.metadata.version` is a full SemVer, declared concretely in committed source, with no default. It is **not** part of any FQN (D4). Its single job is to let a consumer state and the kernel check a compatibility floor: a module records which catalog build it was authored against, and the kernel compares that against the build a platform actually materialized.

`#Module` and `#Catalog` are therefore **not symmetric**, and the asymmetry is principled. A catalog is a *vocabulary provider* whose consumers must be able to express a minimum, because a module can genuinely require a primitive that only exists from some catalog build onward. A module is a leaf artifact that nothing depends on, so no consumer needs to express a floor against it. D2 stands for `#Module` and does not extend here.

**Alternatives considered:**

- **Remove the catalog version too, for symmetry with D2.** Rejected: it leaves D4's residual failure unaddressed. With major-only keys, a module built against `1.2.0` matches a platform on `1.0.0` right up until it demands a primitive `1.0.0` never shipped — and then fails with a missing FQN that names nothing useful. The version is what turns that into a legible error.
- **Let each primitive declare its own version.** Rejected: it turns one catalog-level fact into N author-maintained ones and reintroduces per-primitive drift inside a single published artifact.

**Rationale:** D4 takes the version out of the key so compatible releases match; something still has to catch the case where they match but should not have. Splitting the two jobs — `@vN` is the key, the full SemVer is the signal — gives each one a value shaped for it.

**Source:** User decision 2026-07-26.

### D4: Every primitive FQN is major-keyed

**Decision:** `#FQNType` becomes `path/name@vN` for every primitive — resources, traits, blueprints, and transformers alike — so a primitive's FQN is stable across the entire compatible series of the catalog that ships it. The **exact** resolved catalog version is not part of any identity string; it is a coordinate the kernel holds, taken from the tag that was resolved, and used for the D3 floor, diagnostics, and reporting.

This makes the pattern platform teams actually want a supported one: a catalog publishes `v1.0.0`, `v1.1.0`, `v1.2.0` adding APIs; a platform subscribes to the `v1` series; modules written against *different minors* all install on it and match, because every FQN on both sides reads `@v1`.

**Feasibility is already met.** `library/opm/materialize/materialize.go:93` constructs `catalogBuild{Subscription, Version, Value}` where `Version` is the bare SemVer of the tag it resolved (`index.go:22`). The kernel already knows which catalog build it pulled; today that knowledge is used only in error messages.

**Alternatives considered:**

- **A semver-range-aware matcher** — teach matching that a `@1.5.0` supply satisfies a `@1.4.0` demand. Rejected as the most expensive option available: it turns an O(1) keyed lookup into constraint solving, re-implements the resolution CUE already performs for module dependencies, and still leaves every FQN string churning on each release.
- **Normalize to major at match time**, leaving SemVer FQNs in the schema. The smallest change, and rejected for that reason: it creates two notions of FQN — the string the schema declares and the key the matcher uses — which is exactly the declared-versus-effective split this entry exists to remove.
- **Demand primitives by path with no version at all.** Rejected: it gives up the ability to express a major incompatibility, which is the one version distinction that carries real meaning.

**Rationale:** This is D2's identity-versus-coordinate split applied one level down. The exact version stops being part of what a primitive *is* and becomes part of what the kernel *resolved*.

It reverses a prior position deliberately, and that is worth stating plainly: `core/src/types.cue:41-44` records that FQNs were *lifted* from major-only to SemVer so that two builds of the same primitive at adjacent versions occupy distinct keys, and divergent definitions surface as structured errors rather than colliding on a major bucket. That goal is accepted; the mechanism is not. Version inequality is a *proxy* for definitional divergence, and a poor one — it charges every consumer on every release for a check that only pays out when a publisher misbehaves. Comparing definitions directly (same key, structurally different definition → error) tests the actual condition. Whether that check gets built is OQ5's question; D4 does not depend on it.

**Source:** User decision 2026-07-26.

### D5: Identity lives in a committed, visible `identity.cue` that OPM tooling writes into

**Decision:** An artifact's identity file is **committed to git and visible to developers**. OPM tooling *writes into it* — the way `npm version` writes `package.json` — rather than generating it behind the developer's back. Fields OPM owns carry an inert marker attribute:

```cue
ModulePath: "opmodel.dev/catalogs/opm@v1" @opm(identity, owner=publish)
Version:    "1.2.0"                       @opm(identity, owner=publish)
```

Placement differs by artifact type, and the difference is forced by package topology rather than chosen. A **module** keeps identity in a file in its own root package — modules are single-package, so there is no cycle to break, and CUE has no relative intra-module import to make a subpackage reachable anyway. A **catalog** keeps `identity/identity.cue` as a shared constant its `resources/` and `transformers/` leaves import, because those leaves compute their own FQNs at their own definition sites and a root-supplied constant makes root and leaves import each other (`package import cycle not allowed`, measured).

**Alternatives considered:**

- **`@tag()` injection at build time.** Rejected on measurement (2026-07-26, cue v0.17.1), and the failure is worse than predicted. Injection does not propagate into an imported package **at all**: `cue eval ./mod -t modulePath=example.com/real-module@v2` sets the module's own value and leaves the imported catalog reading its uninjected default, identical to the uninjected run. The anticipated failure was a *collision* — two artifacts declaring the same tag both receiving one string. That does not happen, because injection never reaches that far. The real failure is quieter: the transitive dependency keeps its placeholder, every FQN it derives is built from it, and nothing reports that an injection was ignored. Since a module always reaches its catalog through CUE's own resolution, the kernel can never supply a catalog's identity this way however well it knows the coordinates.
- **Gitignored generation into the artifact's own package.** Technically sound; the value resolves correctly when the file is present, and its absence fails legibly (`ModulePath: incomplete value string`). Rejected on transparency: the value lives in a file the developer never wrote and cannot see in git. It also makes a fresh clone unvettable by plain `cue` until an `opm` command has run.
- **A committed marker with a gitignored value.** Same rejection with less benefit: it makes the *field* visible without making the *value* visible.

**Rationale — and the reason is transparency, not mechanics.** A committed file is documentable, diffable, reviewable in a PR, and greppable. A developer reading an artifact can see where its identity comes from and open the file that supplies it.

The technical constraint that rules the alternatives out is separate and was measured: identity must be present in the artifact's **own bytes**, because CUE's dependency resolution is what carries it to consumers and OPM does not mediate that. A committed value resolves correctly through a transitive import under plain `cue eval` with no flags and no OPM tooling in the loop; `cue vet -c` passes; and `cue def` preserves `@opm()` attributes verbatim, so tooling can locate the fields it owns without hardcoding names.

**Source:** User decision 2026-07-26.

### D6: An identity field may be left open, and an open field is an absent value rather than a placeholder one

**Decision:** An identity field may be declared **open** (`ModulePath: string @opm(…)`) or **concrete** (`Version: "1.2.0" @opm(…)`), at the author's choice. Both forms are committed. `opm … version set <semver>` and `opm … publish --version <semver>` write a concrete value into the field either way, so the choice is a workflow preference rather than a mode the tooling must track: what matters is whether the field holds a value right now.

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

### D8: `metadata.name` is snake_case, and the module path's leaf equals it

**Decision:** `#Module.metadata.name` is authored in **snake_case** (`#SnakeNameType`). The module path's leaf equals `name` directly, with no projection in between, and that constraint is expressed over `modulePath` alone (`strings.HasSuffix(registryPath, "/" + name)`). The rest of the path is whatever CUE accepts; OPM does not narrow it.

Consequently `nameSnakeCase` and `#KebabToSnake` are removed from `core`. They exist solely to project kebab onto snake; with `name` already snake there is no projection left.

**Alternatives considered:**

- **Keep kebab `name` plus a derived `nameSnakeCase`.** Rejected: it keeps two spellings of one identity alive so that one of them can be prettier, which is the class of drift this entry exists to remove.
- **Narrow the whole module path to snake_case.** Rejected on evidence: CUE accepts hyphens in path segments (verified — `github.com/open-platform-model/my-thing@v1` evaluates and `cue mod tidy`s clean), path segments are not CUE identifiers, and narrowing would make OPM unable to express its own GitHub organisation. Only the **leaf** needs to be an identifier, because only the leaf is also the CUE package name.

**Rationale:** One identity, one spelling. The leaf must be a CUE package name and package names cannot contain hyphens, so the identity is the constrained form and there is nothing to project.

**Migration:** every hyphenated module name is renamed (`web-app` → `web_app`, `zot-registry-ttl` → `zot_registry_ttl`). `name` feeds the `module.opmodel.dev/name` label, so this is user-visible; underscores are legal in Kubernetes label values.

**Source:** User decision 2026-07-26.

### D9: The resolved-coordinate label is stamped once, by the kernel

**Decision:** `module.opmodel.dev/version` — and any future label naming a *resolved coordinate* rather than a property of the artifact's definition — is stamped by `library`'s kernel on the render path both frontends traverse. `core` stops declaring it. Its value is the version of the artifact that was actually fetched, so it says what it always appeared to say and, for the first time, says it truthfully.

**Alternatives considered:**

- **Drop the label.** Rejected: selecting deployed resources by module version is a real operational need, and removing a field is not a reason to remove a capability.
- **Have each frontend stamp its own** (`cli` and `opm-operator` separately). Rejected: it makes byte-identical rendered output a coordination agreement between two independently-released codebases, and the only thing detecting a divergence would be a digest gate failing after the fact and naming a digest rather than a label.
- **Stamp it in the apply path rather than the render path.** Rejected: the label must be present in rendered output for dry-run, diff, and digest, all of which run before anything is applied.
- **Inject the resolved version into the module value so CUE can stamp it as today.** Rejected on `core/SPEC.md:304`'s recorded closed-struct failure, and because it returns a fetch-derived value to module identity.

**Rationale:** The label describes an *acquisition*, not a definition. Core's schema states what an artifact is; the code that fetched it is the only actor that knows which one it got. The kernel is also the only layer holding both halves at once — the resolved coordinate, from the acquisition's own parameters, and the resources being stamped — and putting the write on the path both actors traverse means they cannot disagree, rather than requiring that they agree.

**Source:** User decision 2026-07-26.

### D10: A module's built-against catalog version is read from its own `cue.mod` deps

**Decision:** The D3 floor's "what was this module built against" value is **not a new field and is not generated**. It is read from the module's own `cue.mod/module.cue` `deps` block, which already records the exact catalog version resolved at build time, already ships inside the published artifact, and is already staged by the registry loader.

**Evidence (2026-07-26):** `modules/jellyfin/cue.mod/module.cue` carries `deps: "opmodel.dev/catalogs/opm@v1": {v: "v1.0.0-alpha.1"}`, and `cue.mod/module.cue` was confirmed present inside the published artifact zip for `opmodel.dev/modules/jellyfin@v2` tag `v2.0.2`. `LoadModulePackageWithSource` documents that the module's own `cue.mod/module.cue` drives transitive resolution, so the data is in hand at the read point with no new plumbing. The deps block is also *semantically* a floor already, since minimal version selection records a lower bound — which is exactly the comparison D3 wants.

**Alternatives considered:**

- **Generate a record at publish** into the identity file or a new `#Module` field. Rejected as redundant and less trustworthy: it states a fact `cue.mod` already holds authoritatively, and a generated copy can drift from the deps that actually resolved.
- **Read it from the stamped `metadata.version` on the primitives a module references.** Rejected on soundness. The value is not frozen into the module — it is recomputed from whichever catalog wins dependency resolution at load. Today the module and the platform resolve in separate builds, so it happens to be the module's own pin; under a single-build render the two share one resolution, minimal version selection picks the maximum, and the module reports the *platform's* catalog version. The floor would then compare a value against itself and could never fail.

**Rationale:** The requirement is not to *record* the value but to stop discarding it. The dependency block is versioned with the module, frozen at publish, and shipped in the artifact.

**Source:** User decision 2026-07-26, refined by the finding that `cue.mod` deps already record it.

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

### D12: Every primitive carries `version`, and it is the matcher's catalog lookup

**Decision:** `metadata.version` is **required on every primitive kind** — `#Resource`, `#Trait`, `#Blueprint`, and `#ComponentTransformer` alike — and holds the full SemVer of the catalog build that primitive definition came from. It is not optional, not advisory, and not display-only.

Its job is the matcher's. When a component demands a primitive, the matcher has the demanded FQN (major-keyed, per D4) and the primitive's own `modulePath` and `version`. From those it works out **which catalog build to look for in the platform's registry**, and produces one of two specific failures instead of a bare missing key:

- **Not subscribed.** The platform's registry carries no subscription to the catalog that primitive belongs to. The error names the catalog, not just the primitive.
- **Too old.** The catalog is subscribed, but the build the platform resolved predates the build the module was authored against — so the primitive genuinely is not in it. The error names the catalog, the version the module needs, and the version the platform has.

Both replace `no matching transformer`, which names neither.

**How the owning catalog is found.** By **longest-prefix match** of the primitive's `modulePath` against the subscribed catalog paths, with majors required to agree — not by stripping a fixed number of segments. That holds for the flat convention (`…/opm/resources@v1`) and for any nested one (`…/opm/resources/workload@v1`, which `core/src/resource.cue`'s own doc example shows), so this decision does not depend on OQ3 being resolved first. OQ3 remains live for the separate question of answering "which catalog ships this FQN?" *without* a platform in hand.

**How each primitive gets the value.** Two mechanisms, and both stay:

- Every primitive reads `id.Version` from the catalog's identity package at its own definition site. This is what `catalog_opm` already does — `resources/configmap.cue:15` and `transformers/configmap_transformer.cue:14` both carry `version: id.Version`.
- `#Catalog`'s pattern constraint **also** stamps `version: M.version` onto every `#transformers` entry, exactly as `core/src/catalog.cue:70-76` does today. It is kept rather than dropped, because it is the only *structural* guarantee available: the pattern constraint owns the `#transformers` map, so a transformer cannot omit the field or disagree with the catalog. Resources, traits, and blueprints are reached only transitively through each transformer's `required`/`optional` maps, so there is no map for a constraint to attach to and they rely on the author writing the line.

The two agree by construction and unify silently. Where they could not — a transformer whose author wrote a different version — the stamp wins and the disagreement is a unification failure at the catalog's own `cue vet`.

**This supersedes D10's choice of carrier.** D10 ruled that the built-against catalog version is read from the module's own `cue.mod/module.cue` `deps` block. D12 reverses that: the value is read from the demanded primitive. D10's other holding survives untouched — no new record is generated, because the value already exists in the artifact.

**Alternatives considered:**

- **Keep D10's `cue.mod` deps as the carrier.** Rejected on fit rather than on correctness. The deps block gives one version per catalog *dependency*, so the matcher would have to join back from a demanded primitive to the catalog dependency that supplied it before it could say anything — which needs precisely the OQ3 constraint this route avoids. The primitive already carries the answer at the point the question is asked.
- **Drop `version` from primitives entirely** and let the kernel report only the missing FQN. Rejected: that is today's behaviour, and `no matching transformer` naming neither the catalog nor the version is the single worst diagnostic in the system.
- **Keep it on transformers only**, since those are the entries the matcher looks up. Rejected: the demand originates from a *resource* or *trait* in a component, so that is where the version has to be readable. A transformer-only field would be legible at the wrong end of the lookup.
- **Make it optional, defaulting to absent.** Rejected: an optional field is one the matcher cannot rely on, so every diagnostic would need a degraded path, and the degraded path is the bad message this decision exists to remove.

**Rationale:** D4 takes the exact version out of the match key so that compatible catalog builds match. That is right for *matching* and it removes information from *diagnosis* — under major-only keys, a demand that misses could mean the platform is on a different catalog, or on an older build of the right one, and the key alone cannot distinguish them. `version` on the primitive is what restores that distinction, carried on the object the matcher is already holding.

**One invariant this imposes, and it must be preserved deliberately.** The value is only meaningful if a module's primitive definitions resolve through the **module's own dependency graph**, not through a graph shared with the platform. That holds today: `library/opm/compile/module.go:137` consumes `mp.Transformers` from `materialize` as read-only input built by a separate resolver, so a module's own `cue.mod` pins supply its primitive definitions. If a future single-build render put the module and the platform in one CUE build, minimal version selection would pick the maximum and a module would report the *platform's* catalog version — the floor would compare a value against itself and could never fail. Recorded in `05-risks.md`; it is a constraint on the render path, not an open choice.

**Source:** User decision 2026-07-26. Resolves OQ6; supersedes D10's carrier choice. Lookup and both failure modes verified in `schemas/target.cue` as `#PrimitiveDemand` — an unsubscribed catalog yields `subscribed: conflicting values false and true` and an out-of-date one yields `satisfied: conflicting values false and true`, each as the only error reported.

### D13: Primitive FQNs carry the full SemVer, and cross-minor installs come from subscription breadth

**Decision:** `#FQNType` keeps the form `core/src/types.cue:37-46` carries today — `path/name@MAJOR.MINOR.PATCH`, bare SemVer, **no `v` prefix**. The `v` stays on the *module path* major (`@v1`) because that is CUE's own spelling for a module path, and the two suffixes must remain visually distinct: `…/opm@v1` is an address, `…/config-maps@1.2.0` is a key. A primitive's key therefore names the exact catalog build its definition came from.

The capability D4 existed to deliver — a module built against one minor installing on a platform that resolved another — is supplied instead by **subscription breadth**. A platform subscribed to a catalog major materializes *every* published build in that major, so the composed transformer map is the union of those builds' key spaces, and each module matches the exact key the build it was authored against shipped. Publishing `1.3.0` **adds** a key space; it does not invalidate, replace, or alter the one `1.2.0` modules are already matching against.

**This supersedes D4 in full**, and it retires the two decisions that existed only to repair D4's information loss. D3's compatibility floor and D12's catalog lookup both lose their job the moment a demanded key names its own build: there is no "matched but too old" state to detect, because a key from an absent build simply is not present. D3's other holding survives — a catalog declares one full concrete SemVer in committed source — but that value is a *key component* again rather than a signal sitting beside the keys. D12's required `metadata.version` on every primitive loses its load-bearing reader, which re-opens OQ6.

**Feasibility is already met, and this is the finding that changed the decision.** `library` is built for this model and documents it. `materialize/filter.go:43-100` returns **every** survivor of a subscription filter, not one; `materialize/materialize.go:87-95` pulls each survivor as its own `catalogBuild`; and `materialize/index.go:57-64` states the resulting invariant outright — two builds of one catalog "necessarily come from different paths … the same path cannot yield two builds at one FQN (distinct versions → distinct FQNs)" — calling the collapse path "largely defensive". That comment is true under SemVer keys and **false under D4**, where every survivor of a range collides on every FQN and any transformer that changed between builds becomes `transformer %q diverges across selected builds`. The multi-build machinery cross-minor installs need already exists; D4 would have broken it.

It also re-reads the evidence in `01-problem.md`. The observed failure (opm-operator e2e, fixtures at `@v1-alpha` against a platform at `@v0`) is a **subscription that did not cover the build the module was authored against**, not a keying failure — a platform whose range spans both supplies both key spaces and both match. The pain point is real; its cause is the subscription default (D14), not the presence of a version in the key.

**Alternatives considered:**

- **Keep D4's major-only keys plus D3's floor.** The design this reverses. Rejected on reproducibility (below), on the collision it introduces into `materialize` (above), and on cost: it needs a floor, a catalog-lookup matcher, a required `version` on every primitive, and a definition-comparison check (OQ5) to recover the safety SemVer keys have for free.
- **Key by `MAJOR.MINOR` (`@v1.2`).** Collapses patches, which are non-breaking by definition, so the collapse is safe. Rejected as strictly a build-count optimisation: minors are also additive under SemVer, so cross-minor matching still needs multi-build subscriptions, and the scheme buys a smaller materialized set at the price of a third version spelling nobody else uses.
- **A range-aware matcher over SemVer keys** — exact match first, then highest compatible. Rejected for the same reason D4 rejected it, and it is unnecessary here: multi-build subscription and range-aware matching are alternative routes to one capability, and the former is already implemented.

**Rationale — the argument is reproducibility, and it was not made anywhere in this entry before now.** Under D4 every installed module keys to `@v1`, so publishing catalog `1.3.0` changes the transformer bodies every already-installed module renders against. Nobody edited a module; the output moved. For a system reconciling continuously under GitOps, "cross-minor just works" and "a catalog release silently changes every render" are the same sentence. Under SemVer keys a module renders against the exact bytes it was authored against, permanently, and a catalog release is inert until a module is rebuilt.

It also degrades better under the failure OPM cannot control. A publisher who breaks compatibility inside a major poisons, under D4, **every installed module at once** — they all key to `@v1` and all pick up the bad build. Under SemVer keys they poison only modules built after the bad release. Publisher SemVer discipline remains the only lever, and the honest response is to document the contract rather than to build a key space that hides its violation.

**Two reversals on one decision, stated plainly.** `core/src/types.cue:41-44` records that FQNs were already lifted major-only → SemVer under enhancement 0001 D5, for exactly the reason cited here: so divergent definitions surface as structured errors rather than colliding on a major bucket. D4 reverted that; D13 reverts it back. The useful output is therefore a statement of which failure this project prefers — a catalog release that cannot reach an installed module (D13, loud, fixable by widening a subscription) over a catalog release that silently changes one (D4, quiet, detectable only by comparing renders) — rather than a third flip later.

**What survives from D12.** Its diagnostic goal, and it gets better rather than worse. A missed demand under SemVer keys can name the exact build demanded and enumerate the builds the platform actually materialized for that catalog — "demanded `config-maps@1.2.0`; this platform carries 1.1.0 and 1.3.0 for `opmodel.dev/catalogs/opm@v1`" — which names the subscription gap directly and needs no floor, no longest-prefix lookup, and no per-primitive version field to say it.

**Source:** User decision 2026-07-27. Supersedes D4; retires D3's floor role and D12's lookup; resolves OQ2 and OQ5 by dissolution; re-opens OQ6. Multi-build behaviour read from `library/opm/materialize/{filter,materialize,index}.go` 2026-07-27.

### D14: A subscription with no filter materializes every published build in its major

**Decision:** The default selection for a `#Subscription` carrying no filter changes from "the highest published stable version" to **every published build in the subscribed major**. `materialize/filter.go:43-47` returns `highestStable(published)` for an empty filter today; under D13 that default is the broken one, because a single build supplies a single key space and every module authored against any other build misses.

The subscription key already carries the major under D1 — `#registry: [Path=#ModulePathType]` where `#ModulePathType` ends in `@vN` — so "every build in this major" is the literal reading of a key that says `@v1`, rather than a new concept the author has to know to ask for.

**Alternatives considered:**

- **Leave the default and require every platform to author a range.** Rejected: it makes the ergonomic default the silently-wrong one, and the failure lands on whoever renders a module next rather than on the platform author who omitted the filter. The measured shape of that failure is bad — a bare subscription to `catalogs/opm` today resolves one build, and `range: ">=1.0.0 <2.0.0"` selects **zero** of its three published tags because Masterminds constraints exclude prereleases unless the constraint carries one (D15).
- **Default to a bounded window** — the N most recent builds. Rejected as an arbitrary constant that silently drops exactly the old builds a long-lived instance still demands, which is the failure D13 exists to avoid, deferred rather than removed.

**Rationale:** Under D13 the materialized set has to cover the authorship history of the fleet installed on the platform. A default that covers one build is not a conservative default, it is a default that works only for a fleet built this week. The unbounded growth this admits is real and is recorded as OQ7 rather than papered over with a window that would break correctness to bound cost.

**Source:** User decision 2026-07-27. Follows from D13; scoped in `01-problem.md`'s re-read of the e2e failure.

### D15: Prerelease inclusion is an explicit opt-in on `#SubscriptionFilter`

**Decision:** `#SubscriptionFilter` (`core/src/platform.cue:16-20`) gains an explicit prerelease opt-in — a boolean flag rather than a property inferred from constraint syntax. A subscription that wants `1.0.0-alpha.2` in its materialized set says so in a field, and D14's default-to-whole-major reads that flag when deciding what "every published build" includes.

**Measured, and it is not a tail case — it is the entire current fleet.** `catalogs/opm` publishes exactly `v1.0.0-alpha`, `v1.0.0-alpha.1`, `v1.0.0-alpha.2`; `catalogs/kubernetes` publishes `v0.1.0` and `v1.1.0-alpha` (registry read 2026-07-27). Today `filterVersions` reaches a prerelease only by an `allow` entry naming the exact version or by a `range` whose constraint itself carries a prerelease identifier (`filter.go:31-42`), and `highestStable` falls back to highest-overall only when *nothing* stable exists. So a platform subscribing to today's `catalogs/opm` gets one build by default and zero from the obvious range — and hand-listing every prerelease in `allow` is the only route that works.

**Alternatives considered:**

- **Rely on Masterminds' constraint semantics** — today's behaviour. Rejected: it makes prerelease inclusion a property of constraint *syntax* rather than of intent, so the author expresses it by writing a range they did not otherwise want, and the whole-major default (D14) has no syntax to read it from.
- **Require an `allow` list naming each prerelease.** Rejected as the current state: it is O(number of prereleases) authoring work that must be revisited on every catalog release, which is precisely the lockstep coupling this entry exists to remove.
- **A channel field** (`stable | prerelease | all`). Genuinely viable and more expressive. Not chosen now because there are two states to distinguish and a third spelling of "which builds" would have to be reconciled against `range`/`allow`/`deny`; recorded here so the option is visible if a third channel ever appears.

**Rationale:** Prereleases are the live regime for both workspace catalogs, so "prereleases require opt-in" and "the default selects everything in the major" cannot both hold without a field to reconcile them. Making the opt-in a flag keeps `range` meaning "which versions" and the flag meaning "which maturity", instead of overloading one to express the other.

**Source:** User decision 2026-07-27. Registry tag inventory measured 2026-07-27.

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

Recorded explicitly as **not** delivered: answering "which catalog ships FQN X?" with no platform in hand. That derivation needs a second convention — a fixed kind segment — beyond what this rule establishes, and the shipped catalogs already show why the segment count is not fixed: resources sit at `…/catalogs/opm/resources` while blueprints sit at `…/catalogs/opm/blueprints/workload`, one segment deeper. So `opmodel.dev/catalogs/opm/blueprints/workload/stateless-workload@1.0.0` cannot say by inspection whether its catalog is `…/catalogs/opm`, `…/catalogs/opm/blueprints`, or `…/catalogs/opm/blueprints/workload`. D12's longest-prefix match used the platform's subscribed paths as its oracle; with no platform there is none. This decision improves conformance, not derivability.

**Alternatives considered:**

- **A `core` stamping site.** Rejected on two independent grounds. `core` cannot express the rule where the primitives actually live: `#ComponentTransformer.requiredResources?: [#FQNType]: #Resource` (`core/src/transformer.cue:54`) holds a catalog's own resources and foreign ones as identical values in one map, so a constraint reached through `#transformers → requiredResources` would enforce this rule by **forbidding enhancement 0001 D16**, a decided and experiment-validated position (`0001/experiments/11-cross-catalog-import/`). Expressing it correctly would require new `#resources` / `#traits` / `#blueprints` sibling maps — an authoring surface `core/src/catalog.cue`'s own doc comment defers as "an additive extension if introspection demand surfaces later" — bought for hygiene alone, now that D13 has removed the correctness need.
- **Both a `core` constraint and a publish gate.** Rejected as the above plus a second enforcement point that cannot be made accurate.
- **Neither — document the convention and leave it convention.** Rejected: that is today's state. A third-party catalog author has no reason to copy a convention nothing checks, which is the class of drift this entry exists to remove.

**Rationale:** D13 retired D12's catalog lookup, so nothing on the match path depends on this any more — the constraint is hygiene, and hygiene belongs where it is cheapest and most accurate. Publish is the only actor that can distinguish "defined here" from "imported from catalog B", because it holds the source tree rather than the composed value; every consumer-side surface sees `#Resource` values in a map with no provenance attached. It also matches this entry's stated scope split — 0010 defines what publishing must guarantee, 0011 implements the command.

Measured 2026-07-27: the shipped catalogs follow the convention uniformly, every primitive setting `modulePath: "\(id.ModulePath)/<kind>"`; no cross-catalog reference exists yet; and transformers are *already* bound structurally, because `core/src/catalog.cue:70-76` stamps `modulePath: "\(M.modulePath)/transformers"` by unification, so a foreign transformer placed in a catalog's `#transformers` map fails today with conflicting values. The enforcement gap is exactly resources, traits, and blueprints.

**Source:** User decision 2026-07-27.

### D18: The live-instance migration is subsumed by the v0 → v1 fleet migration

**Decision:** This enhancement carries **no live-instance migration burden**. Every deployed OPM instance is on the deprecated v0 schema line, so no running instance carries an identity that this entry's changes would alter. The fleet reaches `opmodel.dev/core@v1` through a separate v0 → v1 migration, and 0010's identity shape is part of that migration's *target state* rather than a delta applied to running v1 instances. OQ4's relabel-versus-recreate choice is therefore not a runbook this entry owns.

**Fleet measured 2026-07-27.** `opm-releases/` (`gon1_nas2`, `kind_opm_dev`, `mr_spel`, `nas1`, `nas2`) and `northbyte/deployments/` (`prod`, `fleet-prod`, `test`, plus eight modules) both pin `opmodel.dev/core/v1alpha1@v1` and `opmodel.dev/opm/v1alpha1@v1` — the deprecated `catalog/` tree. Nothing is on `opmodel.dev/core@v1`. Noted in passing: those modules' `cue.mod` lines already read `module: "opmodel.dev/modules/mc_ops@v0"`, which is D1's shape verbatim — the string D1 wants in `metadata.modulePath` already exists in the fleet's own manifests.

Two holdings are recorded as **inputs** to that future migration rather than as work here:

- **Relabel in place, never recreate**, if a v1 instance ever needs its identity changed while running. `opm-operator` sets no `ownerReferences` on applied resources (verified 2026-07-27: zero occurrences of `SetControllerReference` or `OwnerReferences` in the repository) and `ModuleInstance` carries no finalizer, so deleting and re-creating the CR garbage-collects nothing — the old resources survive holding the old UUID label, the new instance applies alongside them, and every subsequent delete hits the mismatch skip at `prune.go:107`. Naive recreate produces precisely the silent-orphan state the migration exists to avoid, which inverts OQ4's original assumption that recreate was the simpler path. Relabelling is a label write with no lifecycle event, so it is uniformly safe for stateful and stateless workloads alike; its failure mode is partial coverage, which the check below detects per instance.
- **The positive check stands.** For at least one migrated instance, remove a resource from the module, re-render, and assert it is actually deleted from the cluster. An absence of errors does not satisfy it — `prune.go:112` increments `result.Skipped` and logs at Info (`moduleinstance.go:642`, `:806`), but emits no Event, no status field, and no metric.

**Alternatives considered:**

- **Relabel every live instance as part of 0010.** Rejected on measurement: there is nothing to relabel. No deployed instance is on the schema this entry changes, so the pass would be a no-op against the v0 fleet and would have to be redone by the v0 → v1 migration anyway.
- **Recreate each instance.** Rejected on the `ownerReferences` finding above: it is simultaneously the more destructive option and the one that produces silent orphans.
- **Defer OQ4 outright to the future migration entry.** Rejected as losing the analysis. The relabel-over-recreate finding and the prune-skip mechanics were measured here; recording them as inputs keeps them attached to the identity change that motivated them, rather than requiring rediscovery.

**Rationale:** OQ4 asked how live instances adopt their new identity, and the answer turned out to be that they do not adopt one — they are not on the schema whose identity changes. Resolving it as subsumed states that plainly instead of writing a runbook against a fleet that cannot execute it. What survives is the part that was genuinely learned: that the operator's resource ownership model makes in-place relabelling the safe direction, and that the failure this migration must guard against is silent rather than loud.

**Source:** User decision 2026-07-27. Fleet inventory read from `opm-releases/` and `northbyte/deployments/` 2026-07-27.

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

### D20: A primitive's `modulePath` is a package path, not a module path

**Decision:** `#Resource`, `#Trait`, `#Blueprint` and `#ComponentTransformer` type `metadata.modulePath` as a **package path** — a plain path with no `@vN` suffix, which is what `core` types it as today. Only `#Module.metadata.modulePath` and `#Catalog.metadata.modulePath` carry D1's complete module path with the major. The two get separate types rather than sharing one.

**This amends D1.** D1 is right about what it decided — an *artifact's* declared path is its complete CUE module path including the major — but it was implemented by widening a single type, `#ModulePathType`, and every field typed with it inherited a requirement it has no use for. D1's holding stands for modules and catalogs; its type widening does not reach primitives.

**The target schema already discarded the major, which is the evidence.** `schemas/target.cue`'s pre-amendment `#PrimitiveIdentity` read `modulePath!: #ModulePathType`, built `_ref: #ArtifactRef & {modulePath}`, and then derived `fqn` from `_ref.registryPath` — stripping the major straight back off. `_ref.major` was computed and never read. Nothing on a primitive consumes it.

**It is structurally redundant, not merely unused.** A `@vN` module publishes `vN.*` tags, so a primitive carrying `version: "1.2.0"` already states that its catalog is `@v1`. The major in the path is the same fact written twice, which is the pattern D2 deleted for `#Module.version` one level up. No collision is admitted by dropping it either: a `@v1` build keys `…@1.2.0` and a `@v2` build keys `…@2.0.0`, and two majors cannot publish the same SemVer.

**And it is not a module path.** `opmodel.dev/catalogs/opm/resources@v1` is a string nothing writes: a consumer in another module imports `opmodel.dev/catalogs/opm-experimental/resources` with no suffix (`modules/metallb/components.cue:23`, `modules/cert_manager/components.cue:31`), because CUE resolves the major from the `deps` block. Typing a package path as a module path is a category error that D1's single-type widening introduced by accident.

**Alternatives considered:**

- **Keep D1's single widened type.** Rejected: it imposes a major that nothing reads, that `version` already encodes, and that makes a primitive's declared path a string no `import` statement uses.
- **Drop the major from module and catalog paths too, for uniformity.** Rejected on each artifact's own grounds. For a module, D2 removed the version field entirely, so the path is the only thing distinguishing `@v1` from `@v2`. For a catalog, the path *is* the registry address and the `#registry` subscription key that D14 reads the major from.

**Rationale:** The major belongs where it is load-bearing and nowhere else. It is load-bearing on an artifact's path because that path is an address and, for modules, the sole carrier of major identity. It is inert on a primitive because the primitive's key carries a full SemVer that already implies it.

**Consequences, all reductions.** Primitive `modulePath` values are unchanged from what ships today, so D1's migration touches two fields rather than every field sharing a type. `primitivePrefix` loses its major re-append. `#Catalog`'s `#transformers` pattern constraint splits the major out and stops, rather than splitting it out and re-appending it as `02-design.md` previously specified. D17's publish gate compares a primitive's path against the catalog's `RegistryPath` rather than its `ModulePath`, which it must do or the check compares a plain path against one ending `@v1` and never matches.

**Source:** User decision 2026-07-27.

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

Tooling still writes exactly the two fields D5 marks with `@opm()` — `ModulePath` and `Version` — and the derived pair follows from them, so the publisher gains nothing new to keep in step. The `identity` package's "import-free" invariant is preserved: `strings` is a CUE builtin, not a module import, and adds no edge to the module graph. Its doc comment should say "free of intra-module imports" to stay accurate.

**The property this buys, in the author's words:** "Both FQN and metadata.modulePath and metadata.version all are referencing identity/identity.cue this ensures consistency." All three fields have one source, and a catalog release moves all of them by one edit.

**The cost is accepted explicitly, also in the author's words:** "I know this could cause problems because it is not enforced and is visible and overridable by the catalog author. But to mitigate this we could add checks and gates that prevent fqn from being mismatched with identity/identity.cue." Enforcement therefore **moves** rather than disappearing — from `core`'s unification, where a wrong value is inexpressible, to 0011's publish gate, where it is caught before it ships. That is the same place D17 put the primitive-path rule, so the two are one mechanism rather than two.

**Alternatives considered:**

- **Keep `core`'s derivation** — `fqn: #FQNType & "\(modulePath)/\(name)@\(version)"`, as `core/src/resource.cue:18` has it. Measured 2026-07-27: because the derivation is a unification, `fqn` is effectively non-authorable, and a transformer whose author writes a disagreeing version fails at the catalog's own `cue vet` with `conflicting values "1.2.0" and "1.1.0"` naming both sites. Not chosen: the author wants the key visible at its definition site and accepts gate-based enforcement in exchange. It also forecloses a capability the authored form admits — pinning a primitive's key to the build where its bytes last changed, so an unchanged primitive need not be re-keyed by every catalog release.
- **Remove `version` and author only `fqn`** (OQ6 candidate (b)). Rejected on measurement 2026-07-27: with `version` gone there is nothing to interpolate and nothing to stamp, so a catalog on `1.2.0` shipping a transformer whose author left `fqn: "…/secret-transformer@1.1.0"` passes `cue vet -c` with **exit 0**. The key names a build the catalog is not, silently, and under D13 that key is what modules match against permanently.
- **Derive `version` from `fqn` in `core`** (OQ6 candidate (c)). Rejected on measurement 2026-07-27: it is a CUE cycle — `t.fqn: cycle with field: version` — because `fqn` is built from `version` and deriving `version` back out closes the loop.
- **A flat FQN with no kind segment** (`…/opm/config-maps@1.2.0`). Rejected: it makes primitive names globally unique across all four kinds within a catalog, and `catalog_opm` already ships a resource named `secrets`. It also breaks the correspondence between an FQN's path portion and its `modulePath`.

**Rationale:** OQ6 asked whether `version` has a reader. Under D13 it does — the FQN interpolates it — and this decision keeps that true while moving the interpolation from `core` to the leaf. The field is the key's source component, not a duplicate of the key, which is why candidate (b)'s removal fails loudly on measurement and candidate (c)'s inversion cannot be expressed at all.

**Worked shape, verified 2026-07-27 (`cue vet -c` clean):**

```
resource:    "opmodel.dev/catalogs/opm/resources/config-maps@1.2.0"
trait:       "opmodel.dev/catalogs/opm/traits/scaling@1.2.0"
transformer: "opmodel.dev/catalogs/opm/transformers/configmap-transformer@1.2.0"
catalog:     "opmodel.dev/catalogs/opm@v1"
```

A transformer's `requiredResources` key is the resource's own `metadata.fqn`, so demand and supply are the same string by construction and there is no third place to keep in step. Every existing leaf's edit is mechanical: rename `id.ModulePath` to `id.RegistryPath` in one reference, and add one `fqn` line.

**Source:** User decision 2026-07-27. Resolves OQ6. Derivation, removal and inversion each measured against cue v0.17.1 on 2026-07-27.

---

## Open Questions

- **OQ1: Does `#Catalog` gain a `name` field?** Status: resolved-by-D16. `#Catalog.metadata` has no `name` today — catalog identity is `modulePath` alone, which is why the addressing half of this design is degenerate for catalogs. Applying D8's leaf rule to catalogs therefore means *adding* a field whose only sensible value is the path leaf (`opm` in `opmodel.dev/catalogs/opm@v1`). **For:** symmetry with `#Module`, a leaf constraint catalogs currently lack, and a readable name for diagnostics that today must be parsed out of a path. **Against:** nothing consumes a catalog name — catalog FQNs carry no name segment and the matcher keys off primitive FQNs — and a field with no reader is exactly what D2 has been deleting. Note the catalog leaf is not a CUE package name the way a module's is, so D8's identifier argument does not transfer. Resolving this fixes whether `#Catalog.metadata` grows or stays at `modulePath` + `version`.

- **OQ2: What does the D3 floor compare against when a catalog was not resolved from a tag?** Status: resolved-by-D13. Dissolved rather than answered — there is no floor to feed. D13 puts the build back in the key, so a locally-checked-out catalog supplies whatever key space its committed `identity.cue` version produces and a module either demands one of those keys or does not. Nothing has to decide what an absent tag compares against, and candidate (b) — writing a dev version through an explicit command — is moot along with it. One residue moves to OQ8: a dev checkout that has moved ahead of its declared version still supplies keys that *look* published, which is the same silent divergence under a new name. Original framing follows. A catalog materialized from a local checkout has no resolved version, and under D6 its committed `Version` is whatever was last written — typically the last published one, which understates a working tree that has moved ahead. Two candidates, and they differ in where the knowledge lives. **(a) Treat "not resolved from a tag" as a kernel-held fact and skip the floor**, since the kernel knows a build came from a directory rather than a subscription; this needs no value in source, no registry query, and stays deterministic and offline. **(b) Write a dev version into `identity.cue` via an explicit command** the developer runs and commits or reverts, making the dirty tree chosen rather than incidental; correct versions, but a developer who forgets ships a module claiming compatibility with a published build that lacks the primitives it uses — the floor passes while the FQN is missing, which is the diagnostic regression D3 exists to prevent. (a) is more consistent with D9's own principle that resolution-time facts belong to the code that resolved them. Resolving this fixes what the local build path does and whether any dev-version notation is needed at all.

- **OQ3: Is a primitive's `modulePath` required to sit under its owning catalog's?** Status: resolved-by-D17. Narrowed by D13. D12 had made this load-bearing for correctness of a diagnostic: a primitive sitting outside its catalog's path defeated the longest-prefix lookup, so the matcher would report "this platform has no subscription to that catalog" about a catalog the platform *was* subscribed to — an actively wrong message rather than an unhelpful one. D13 deletes that lookup, so the question reverts to its original scope: the quality of "which catalog ships FQN X?" when no platform is in hand, and whether the publish gate enforces the convention. Still worth resolving, no longer able to produce a false statement. Original framing follows. The convention is followed but not enforced. `core` types `#Resource` / `#Trait` `metadata.modulePath` as a free-form path (`core/src/resource.cue:18`, `trait.cue:17`), and the doc-comment examples there show an unrelated path. The shipped catalog binds them by author discipline — every primitive sets `modulePath: "\(id.ModulePath)/resources"` from the identity package — so under D1 the reverse lookup "which catalog ships FQN X?" works by stripping the trailing `resources`/`traits`/`transformers` segment and re-appending the major. That is derivable-by-convention with nothing enforcing it, which is the shape of drift this entry exists to remove, and it will break the moment a third-party catalog is authored without reading the first-party one. Note the partial asymmetry: `#Catalog`'s pattern constraint *does* structurally stamp `modulePath` onto every `#transformers` entry, while resources and traits reach a catalog only transitively through each transformer's `required`/`optional` maps, so there is no map for the same constraint to attach to. Resolving this decides whether the constraint lands in `core` (a new stamping site), in the publish gate (0011 refuses a catalog whose primitives sit outside its own path), or both.

- **OQ4: How do live instances adopt their new identity?** Status: resolved-by-D18. Partial in substance — the migration is manual and no operator code ships; the remaining choice is relabel-in-place versus recreate. Every module's `fqn` changes shape, so `module.uuid` changes, so `instance.uuid` changes, so the `module-instance.opmodel.dev/uuid` label on every deployed resource changes. `opm-operator/internal/apply/prune.go:107` tolerates an *empty* live label but skips a delete when the live label *disagrees* with `Status.InstanceUUID`, and it skips **without erroring**, so an un-migrated instance reports healthy while garbage collection has stopped.

  **Settled 2026-07-26 (user decision).** OPM has one operator and the deployed fleet is enumerable from the `ModuleRelease` configs in `releases/` plus the CLI's CR inventory, so the migration is a one-time manual pass over a known list. That **eliminates the operator-tolerance candidate**: no one-release tolerance for a recorded prior UUID, no transition window, no dual-identity support — all of which exist to protect consumers this migration does not have, and each of which would ship code that then has to be removed. `opm-operator` stays in `affects` for the dependency retarget in `06-operational.md`'s step 5, not for an adoption feature.

  Because the failure is silent, the migration's exit criterion is a **positive check** rather than an absence of errors: for at least one migrated instance, remove a resource from the module, re-render, and assert it is actually deleted from the cluster.

  **Still open:** whether each instance is relabelled in place or recreated. Relabelling preserves the live objects and their history but touches every resource of every instance; recreating is simpler to execute and reason about but causes a delete/apply cycle on workloads. The answer may differ per instance — stateless things can be recreated, stateful ones probably should not be. Resolving this fixes the migration runbook, not any shipped code.

- **OQ5: Do prereleases and 0.x builds of one major share a key space safely?** Status: resolved-by-D13. Dissolved rather than answered — they no longer share one. Under SemVer keys `1.0.0-alpha.1` and `1.0.0-alpha.2` occupy distinct keys, as do `0.1.0` and `0.2.0`, so a breaking change inside a prerelease or `0.x` series produces a missed key naming the exact build rather than a silent render against a definition that changed shape. This was the entry's sole blocking question and D13 removes the condition rather than answering it. What replaces it is an authoring cost, not a correctness gap: a platform tracking a prerelease series must opt into prereleases (D15) and will materialize each one. Original framing follows. Under D4, `1.0.0-alpha.1` and `1.0.0-alpha.2` produce identical keys, and so do `0.1.0` and `0.2.0`. Breaking changes in those ranges are normal and expected — SemVer grants no compatibility guarantee below `1.0.0` or across prereleases — and both workspace catalogs are on `v1.0.0-alpha.x` right now, so this is the live regime rather than a tail case. D3's floor does not catch it: `alpha.2` clears a floor of `alpha.1` while the definition may have changed shape. Under the previous SemVer-keyed FQNs this failed loudly at match time. Candidates: **(a)** build the definition-comparison check D4's rationale names and sequence it with D4 rather than after it; **(b)** keep prerelease and `0.x` builds SemVer-keyed and switch to major-keyed at the first stable major; **(c)** accept it, on the grounds that a prerelease series is a development artifact whose consumers are expected to move in lockstep. Resolving this fixes whether D4 ships alone.

- **OQ7: When may a catalog build be dropped from a platform's materialized set?** Status: deferred. By agreement, not by oversight. D14 makes a subscription materialize every published build in its major, so the set grows monotonically with the catalog's release history and never shrinks on its own. Today's cost is trivial and measured — three builds for `catalogs/opm`, two for `catalogs/kubernetes` (2026-07-27) — so this is a question about the shape after two years, not a blocker now. What makes it answerable rather than open-ended is that demand is enumerable: every live `ModuleInstance` names the module it renders, and every module's demanded FQNs name the exact builds it needs, so "no installed module demands `1.2.0`" is a computable statement rather than a guess. Candidates: **(a)** leave it unbounded and let subscription `deny` be the manual tool; **(b)** compute the demanded set from the fleet and warn on builds nobody demands, leaving the decision to the operator; **(c)** a retention policy on the subscription, which risks dropping a build a long-lived instance still needs. Resolving this fixes whether materialize grows without limit and what tells an operator it is safe to prune. Deferred deliberately — it does not gate the design, and it is cheaper to answer once the fleet has enough history to show the real growth curve.

- **OQ8: What stops a moved-ahead dev checkout from supplying keys that look published?** Status: resolved-by-D19. Inherited from OQ2's residue. Under D13 a catalog materialized from a local checkout supplies FQNs interpolating whatever its committed `identity.cue` version says — typically the last published one. A developer who edits a primitive without changing that version supplies `…/config-maps@1.2.0` from bytes that are not what `1.2.0` published, and a module demanding that key matches it. This is narrower than the sentinel problem D5/D6 removed — it needs a dirty checkout wired in through `local-module.cue`, and it never reaches a published artifact — but it is the one place where D13's "a key names its exact bytes" guarantee is only as good as the author's discipline. Candidates: **(a)** accept it as inherent to local development, documented; **(b)** have the kernel mark a directory-resolved catalog and warn when a module matches one of its keys; **(c)** require an explicit dev version, which is OQ2 candidate (b) transposed and carries the same forget-to-set failure. Resolving this fixes what the local-development path guarantees.

- **OQ6: Does a primitive's `metadata.version` have a reader?** Status: resolved-by-D21. Re-opened by D13 — D12's answer was the matcher's catalog lookup, and D13 deletes that lookup. The field is now *derivable from the primitive's own `fqn`*, which carries the full SemVer again, so keeping it required means a catalog states one fact twice and the two can be made to disagree. The structural stamp `#Catalog`'s pattern constraint applies to `#transformers` still works and still costs nothing. Candidates, unchanged in shape from the original framing but with the load-bearing option now gone: **(a)** keep it required as displayed provenance and accept the duplication, since the pattern constraint makes it free for transformers and habitual for the rest; **(b)** remove it from `#PrimitiveIdentity` and let a reader parse the version out of the FQN it already holds; **(c)** keep it and *derive* it from the FQN in `core` so the two cannot disagree. Resolving this fixes whether `#Resource` / `#Trait` / `#Blueprint` / `#ComponentTransformer` keep a required `version`. Previous status follows. **resolved-by-D12** — yes, and it is the matcher. Every primitive kind keeps a required `version`; the matcher derives the owning catalog from the demanded primitive's own `modulePath` and looks that build up in the platform's registry, so a failed demand reports either "this platform has no subscription to that catalog" or "the build it resolved is older than this module needs" instead of a bare missing key. The reader named here is candidate (c) of the original framing; D12 supersedes D10's choice of carrier. Original framing follows. D3 keeps a catalog's full version and stamps it onto the primitives it ships. D10 then reads the compatibility floor from the module's `cue.mod` deps instead, and D4 takes the version out of every key — so it is not obvious what still consumes the stamped value. `library` reads `metadata.version` only for `#Module` today (`shape.go:66`, `instance.go:110`), never for a primitive. The value is structurally reachable (a component embeds the whole primitive definition, so `#components.X.#resources[fqn].metadata.version` exists) but D10 records why reading it there is unsound. Candidates: **(a)** keep it as displayed provenance, documented as informational and explicitly not a compatibility input; **(b)** remove it from `#PrimitiveIdentity` and let the catalog's version live only on `#Catalog.metadata`, which is what the read-side check compares against the resolved tag; **(c)** find a genuine reader and record it.

- **OQ9: What supplies the auto-secrets resource identity, now that `core` cannot?** Status: answered. Nothing does, because `core` no longer names one. `core/src/helpers_autosecrets.cue` was deleted and the `opm-secrets` injection removed from `#ModuleInstance` (core `a77a12d`, 2026-07-27), so no `core` construct names a catalog primitive and there is no identity left to supply. The *discovery* half stays — `#AutoSecrets`, `#DiscoverSecrets` and `#GroupSecrets` remain in `core/src/schemas.cue` and catalogs re-export them — while a module carrying secrets now declares a secrets component against its own catalog's `#Secrets` resource, so the FQN comes from the catalog that owns it, as every other primitive's does. `core/src/module_instance.cue:59-65` records the reasoning in this question's own terms ("a catalog's FQN embeds that catalog's version — a value core cannot know and must not hardcode") and settles one thing this question left open: the mismatch was live rather than latent, because the injected component "matched no transformer on the v1 line and failed the render outright". Original framing follows. Surfaced 2026-07-27 while resolving OQ3. `core/src/helpers_autosecrets.cue:5` hardcodes `#SecretsResourceFQN: "opmodel.dev/opm/resources/config/secrets@1.0.0"` and `:31` a matching `modulePath: "opmodel.dev/opm/resources/config"`. These are **live values, not doc examples**: `core/src/module_instance.cue:72` synthesizes an `opm-secrets` component keyed by that FQN whenever a module's resolved config contains `#Secret` fields. The shipped catalog ships the same primitive at `opmodel.dev/catalogs/opm/resources/secrets@<id.Version>` (`catalog_opm/src/resources/secret.cue:20-22`), and `catalog_opm/src/transformers/secret_transformer.cue:35` requires *that* FQN. The two differ in both path and version, so the synthesized component cannot match the transformer meant to handle it. The stale comment above the constant ("must stay in sync with `resources/config/secret.cue`") names the deprecated `catalog/` tree's layout, so this is fallout from the catalog split. One fleet module reaches the code path (`modules/metallb`).

  This belongs to 0010 because D13 makes the version half permanent: a literal `@1.0.0` written into `core` can never equal a catalog build's key, and no subscription breadth fixes it — the key names a build of a catalog that does not exist. The deeper problem is that `core` names a *catalog primitive* at all, which is a layering inversion this entry's identity model has no way to express: `core` is the schema every catalog depends on, so it cannot depend on one. Candidates: **(a)** move the whole auto-secrets synthesis out of `core` and into the catalog that owns the secrets resource, so the FQN is computed from `id` at its own definition site like every other primitive; **(b)** keep the synthesis in `core` but have it take the secrets FQN as an input supplied by the platform's materialized catalogs rather than as a literal; **(c)** keep the literal and accept that auto-secrets only works for a catalog that agrees to ship that exact path and version, documenting the coupling. Resolving this fixes whether `core` may name a primitive, and whether auto-secrets survives in its current form.

- **OQ10: What owns a `ModuleInstance`'s resources through deletion?** Status: open. Surfaced 2026-07-27 while resolving OQ4. `opm-operator` sets no `ownerReferences` on applied resources and `ModuleInstance` has no finalizer — `ModulePackage` has one (`modulepackage.go:90`), `ModuleInstance` does not. So deleting a `ModuleInstance` leaves every deployed resource running with no cleanup path, and the identity-mismatch skip at `prune.go:107` is the only interaction between a changed identity and a live resource.

  The two candidate mechanisms are not equally available, and the asymmetry is forced rather than chosen. `ownerReferences` cannot cover OPM's output: modules render cluster-scoped resources (`catalog_opm/src/resources/crd.cue:56` types `scope!: "Namespaced" | "Cluster"`, `role.cue:47` covers ClusterRole, `catalog_kubernetes` ships `namespace.cue`), and a namespaced `ModuleInstance` cannot legally own a cluster-scoped or cross-namespace object — Kubernetes treats cross-scope ownership as invalid and the dependent is GC'd or orphaned depending on version. Label-plus-inventory-plus-finalizer is what Flux, Helm and Argo converged on for exactly this reason, and OPM already has two of those three. Candidates: **(a)** add a `ModuleInstance` finalizer that prunes the recorded inventory on delete, leaving `ownerReferences` out entirely; **(b)** (a) plus `ownerReferences` for the same-namespace namespaced subset, as an additive fast path that never replaces the inventory; **(c)** finalizer plus an explicit orphan-on-delete policy field, so an operator can choose to leave resources running. Resolving this fixes deletion semantics for every instance, and it is a prerequisite for the v0 → v1 fleet migration D18 defers to. Owned by `opm-operator`; recorded here because 0010 is where the gap surfaced.
