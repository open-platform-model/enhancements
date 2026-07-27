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

---

## Open Questions

- **OQ1: Does `#Catalog` gain a `name` field?** Status: open. `#Catalog.metadata` has no `name` today — catalog identity is `modulePath` alone, which is why the addressing half of this design is degenerate for catalogs. Applying D8's leaf rule to catalogs therefore means *adding* a field whose only sensible value is the path leaf (`opm` in `opmodel.dev/catalogs/opm@v1`). **For:** symmetry with `#Module`, a leaf constraint catalogs currently lack, and a readable name for diagnostics that today must be parsed out of a path. **Against:** nothing consumes a catalog name — catalog FQNs carry no name segment and the matcher keys off primitive FQNs — and a field with no reader is exactly what D2 has been deleting. Note the catalog leaf is not a CUE package name the way a module's is, so D8's identifier argument does not transfer. Resolving this fixes whether `#Catalog.metadata` grows or stays at `modulePath` + `version`.

- **OQ2: What does the D3 floor compare against when a catalog was not resolved from a tag?** Status: resolved-by-D13. Dissolved rather than answered — there is no floor to feed. D13 puts the build back in the key, so a locally-checked-out catalog supplies whatever key space its committed `identity.cue` version produces and a module either demands one of those keys or does not. Nothing has to decide what an absent tag compares against, and candidate (b) — writing a dev version through an explicit command — is moot along with it. One residue moves to OQ8: a dev checkout that has moved ahead of its declared version still supplies keys that *look* published, which is the same silent divergence under a new name. Original framing follows. A catalog materialized from a local checkout has no resolved version, and under D6 its committed `Version` is whatever was last written — typically the last published one, which understates a working tree that has moved ahead. Two candidates, and they differ in where the knowledge lives. **(a) Treat "not resolved from a tag" as a kernel-held fact and skip the floor**, since the kernel knows a build came from a directory rather than a subscription; this needs no value in source, no registry query, and stays deterministic and offline. **(b) Write a dev version into `identity.cue` via an explicit command** the developer runs and commits or reverts, making the dirty tree chosen rather than incidental; correct versions, but a developer who forgets ships a module claiming compatibility with a published build that lacks the primitives it uses — the floor passes while the FQN is missing, which is the diagnostic regression D3 exists to prevent. (a) is more consistent with D9's own principle that resolution-time facts belong to the code that resolved them. Resolving this fixes what the local build path does and whether any dev-version notation is needed at all.

- **OQ3: Is a primitive's `modulePath` required to sit under its owning catalog's?** Status: open. Narrowed by D13. D12 had made this load-bearing for correctness of a diagnostic: a primitive sitting outside its catalog's path defeated the longest-prefix lookup, so the matcher would report "this platform has no subscription to that catalog" about a catalog the platform *was* subscribed to — an actively wrong message rather than an unhelpful one. D13 deletes that lookup, so the question reverts to its original scope: the quality of "which catalog ships FQN X?" when no platform is in hand, and whether the publish gate enforces the convention. Still worth resolving, no longer able to produce a false statement. Original framing follows. The convention is followed but not enforced. `core` types `#Resource` / `#Trait` `metadata.modulePath` as a free-form path (`core/src/resource.cue:18`, `trait.cue:17`), and the doc-comment examples there show an unrelated path. The shipped catalog binds them by author discipline — every primitive sets `modulePath: "\(id.ModulePath)/resources"` from the identity package — so under D1 the reverse lookup "which catalog ships FQN X?" works by stripping the trailing `resources`/`traits`/`transformers` segment and re-appending the major. That is derivable-by-convention with nothing enforcing it, which is the shape of drift this entry exists to remove, and it will break the moment a third-party catalog is authored without reading the first-party one. Note the partial asymmetry: `#Catalog`'s pattern constraint *does* structurally stamp `modulePath` onto every `#transformers` entry, while resources and traits reach a catalog only transitively through each transformer's `required`/`optional` maps, so there is no map for the same constraint to attach to. Resolving this decides whether the constraint lands in `core` (a new stamping site), in the publish gate (0011 refuses a catalog whose primitives sit outside its own path), or both.

- **OQ4: How do live instances adopt their new identity?** Status: open. Partial in substance — the migration is manual and no operator code ships; the remaining choice is relabel-in-place versus recreate. Every module's `fqn` changes shape, so `module.uuid` changes, so `instance.uuid` changes, so the `module-instance.opmodel.dev/uuid` label on every deployed resource changes. `opm-operator/internal/apply/prune.go:107` tolerates an *empty* live label but skips a delete when the live label *disagrees* with `Status.InstanceUUID`, and it skips **without erroring**, so an un-migrated instance reports healthy while garbage collection has stopped.

  **Settled 2026-07-26 (user decision).** OPM has one operator and the deployed fleet is enumerable from the `ModuleRelease` configs in `releases/` plus the CLI's CR inventory, so the migration is a one-time manual pass over a known list. That **eliminates the operator-tolerance candidate**: no one-release tolerance for a recorded prior UUID, no transition window, no dual-identity support — all of which exist to protect consumers this migration does not have, and each of which would ship code that then has to be removed. `opm-operator` stays in `affects` for the dependency retarget in `06-operational.md`'s step 5, not for an adoption feature.

  Because the failure is silent, the migration's exit criterion is a **positive check** rather than an absence of errors: for at least one migrated instance, remove a resource from the module, re-render, and assert it is actually deleted from the cluster.

  **Still open:** whether each instance is relabelled in place or recreated. Relabelling preserves the live objects and their history but touches every resource of every instance; recreating is simpler to execute and reason about but causes a delete/apply cycle on workloads. The answer may differ per instance — stateless things can be recreated, stateful ones probably should not be. Resolving this fixes the migration runbook, not any shipped code.

- **OQ5: Do prereleases and 0.x builds of one major share a key space safely?** Status: resolved-by-D13. Dissolved rather than answered — they no longer share one. Under SemVer keys `1.0.0-alpha.1` and `1.0.0-alpha.2` occupy distinct keys, as do `0.1.0` and `0.2.0`, so a breaking change inside a prerelease or `0.x` series produces a missed key naming the exact build rather than a silent render against a definition that changed shape. This was the entry's sole blocking question and D13 removes the condition rather than answering it. What replaces it is an authoring cost, not a correctness gap: a platform tracking a prerelease series must opt into prereleases (D15) and will materialize each one. Original framing follows. Under D4, `1.0.0-alpha.1` and `1.0.0-alpha.2` produce identical keys, and so do `0.1.0` and `0.2.0`. Breaking changes in those ranges are normal and expected — SemVer grants no compatibility guarantee below `1.0.0` or across prereleases — and both workspace catalogs are on `v1.0.0-alpha.x` right now, so this is the live regime rather than a tail case. D3's floor does not catch it: `alpha.2` clears a floor of `alpha.1` while the definition may have changed shape. Under the previous SemVer-keyed FQNs this failed loudly at match time. Candidates: **(a)** build the definition-comparison check D4's rationale names and sequence it with D4 rather than after it; **(b)** keep prerelease and `0.x` builds SemVer-keyed and switch to major-keyed at the first stable major; **(c)** accept it, on the grounds that a prerelease series is a development artifact whose consumers are expected to move in lockstep. Resolving this fixes whether D4 ships alone.

- **OQ7: When may a catalog build be dropped from a platform's materialized set?** Status: deferred. By agreement, not by oversight. D14 makes a subscription materialize every published build in its major, so the set grows monotonically with the catalog's release history and never shrinks on its own. Today's cost is trivial and measured — three builds for `catalogs/opm`, two for `catalogs/kubernetes` (2026-07-27) — so this is a question about the shape after two years, not a blocker now. What makes it answerable rather than open-ended is that demand is enumerable: every live `ModuleInstance` names the module it renders, and every module's demanded FQNs name the exact builds it needs, so "no installed module demands `1.2.0`" is a computable statement rather than a guess. Candidates: **(a)** leave it unbounded and let subscription `deny` be the manual tool; **(b)** compute the demanded set from the fleet and warn on builds nobody demands, leaving the decision to the operator; **(c)** a retention policy on the subscription, which risks dropping a build a long-lived instance still needs. Resolving this fixes whether materialize grows without limit and what tells an operator it is safe to prune. Deferred deliberately — it does not gate the design, and it is cheaper to answer once the fleet has enough history to show the real growth curve.

- **OQ8: What stops a moved-ahead dev checkout from supplying keys that look published?** Status: open. Inherited from OQ2's residue. Under D13 a catalog materialized from a local checkout supplies FQNs interpolating whatever its committed `identity.cue` version says — typically the last published one. A developer who edits a primitive without changing that version supplies `…/config-maps@1.2.0` from bytes that are not what `1.2.0` published, and a module demanding that key matches it. This is narrower than the sentinel problem D5/D6 removed — it needs a dirty checkout wired in through `local-module.cue`, and it never reaches a published artifact — but it is the one place where D13's "a key names its exact bytes" guarantee is only as good as the author's discipline. Candidates: **(a)** accept it as inherent to local development, documented; **(b)** have the kernel mark a directory-resolved catalog and warn when a module matches one of its keys; **(c)** require an explicit dev version, which is OQ2 candidate (b) transposed and carries the same forget-to-set failure. Resolving this fixes what the local-development path guarantees.

- **OQ6: Does a primitive's `metadata.version` have a reader?** Status: open. Re-opened by D13 — D12's answer was the matcher's catalog lookup, and D13 deletes that lookup. The field is now *derivable from the primitive's own `fqn`*, which carries the full SemVer again, so keeping it required means a catalog states one fact twice and the two can be made to disagree. The structural stamp `#Catalog`'s pattern constraint applies to `#transformers` still works and still costs nothing. Candidates, unchanged in shape from the original framing but with the load-bearing option now gone: **(a)** keep it required as displayed provenance and accept the duplication, since the pattern constraint makes it free for transformers and habitual for the rest; **(b)** remove it from `#PrimitiveIdentity` and let a reader parse the version out of the FQN it already holds; **(c)** keep it and *derive* it from the FQN in `core` so the two cannot disagree. Resolving this fixes whether `#Resource` / `#Trait` / `#Blueprint` / `#ComponentTransformer` keep a required `version`. Previous status follows. **resolved-by-D12** — yes, and it is the matcher. Every primitive kind keeps a required `version`; the matcher derives the owning catalog from the demanded primitive's own `modulePath` and looks that build up in the platform's registry, so a failed demand reports either "this platform has no subscription to that catalog" or "the build it resolved is older than this module needs" instead of a bare missing key. The reader named here is candidate (c) of the original framing; D12 supersedes D10's choice of carrier. Original framing follows. D3 keeps a catalog's full version and stamps it onto the primitives it ships. D10 then reads the compatibility floor from the module's `cue.mod` deps instead, and D4 takes the version out of every key — so it is not obvious what still consumes the stamped value. `library` reads `metadata.version` only for `#Module` today (`shape.go:66`, `instance.go:110`), never for a primitive. The value is structurally reachable (a component embeds the whole primitive definition, so `#components.X.#resources[fqn].metadata.version` exists) but D10 records why reading it there is unsound. Candidates: **(a)** keep it as displayed provenance, documented as informational and explicitly not a compatibility input; **(b)** remove it from `#PrimitiveIdentity` and let the catalog's version live only on `#Catalog.metadata`, which is what the read-side check compares against the resolved tag; **(c)** find a genuine reader and record it.
