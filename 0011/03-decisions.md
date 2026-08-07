# Design Decisions — Module and Catalog Publishing

This document records every significant design choice with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent** — never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes. The *text* under a number states what is true now: a reversal is recorded as its own `DN` while the design is in motion, then woven into the decision it changes at the next compaction pass — the merged decision keeps the lower number, and the vacated number keeps a one-line tombstone. See the `enhancement-compaction` skill.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source.

---

## Decisions

### D1: One publish pipeline serves both artifact types

**Decision:** `opm module publish` and `opm catalog publish` are one implementation with two entry points. They share the artifact-shape gate, the coordinate derivation, the identity-completeness check, the local-override detector, and the push. They differ in which artifact is decoded, which registry namespace applies, whether a package-name rule is checked, and whether the local-override gate offers an override.

**Alternatives considered:**

- **Two independent commands.** Rejected: the two would drift, and the drift would be invisible until a consumer hit the half that had not kept up. Publishing is one operation with a parameterised artifact type, not two operations that resemble each other.
- **One command with an artifact-type flag** (`opm publish --kind catalog`). Rejected as worse ergonomics for no structural gain: the caller always knows which kind they have, and the two commands carry different flags — only the module form takes an override.

**Rationale:** Splitting one code path across two commands reproduces exactly the failure this design exists to remove: a rule that holds in one place and quietly does not in another.

**Source:** User decision 2026-07-25.

### D2: Publish derives coordinates from the artifact and never rewrites the artifact to fit them

**Decision:** Publish reads an artifact's identity and uses it to determine where the artifact goes. It does not edit the artifact to match a coordinate supplied on the command line, and it does not generate files into the pushed bytes that do not exist in the committed tree. What is published is what is committed.

The one write publish may perform is filling an identity field the author deliberately left open — see D3 and OQ1.

**Alternatives considered:**

- **Stamp values into a copy of the tree at publish** — copy, inject, push the copy, leave source untouched. This is the current catalog mechanism, and it is a coherent pattern for artifacts that are *build outputs*. Rejected because a CUE module's artifact **is** its source: the published bytes stop equalling the committed bytes, so the same tree evaluates differently depending on whether it was resolved from disk or from the registry. Measured 2026-07-25 against a live registry — a catalog published this way resolves to `…/transformers/foo@0.0.0-dev` locally and `…/transformers/foo@1.0.0` from the registry, with both trees vetting clean.
- **Take the coordinates from a side file** (`versions.yml`, today's module mechanism). Rejected: it is a third source of truth that nothing reconciles with the other two, and the fleet it produced is the evidence.

**Rationale:** Deriving keeps exactly one authoritative statement of where an artifact lives and what it is, and keeps published bytes reproducible from a commit. An artifact that cannot be rebuilt from its source is one whose behaviour cannot be explained from its source.

**Source:** User decision 2026-07-20.

### D3: Version authoring is a separate command; `--version` on publish is the only other writer

**Decision:** Writing a version and publishing an artifact are different operations.

`opm catalog version set <semver>` writes `identity.cue`'s `Version` field in place, in committed source, idempotently — setting the version it already has is a no-op. The intended sequence is `version set` → review the diff → commit → `publish`, which puts the commit *between* deciding a version and pushing an artifact.

`opm … publish --version <semver>` is the other writer, for flows where a release process supplies the version rather than a human. Against an **open** identity field it fills it; against a **concrete** field it asserts equality and refuses on mismatch. It never invents a value and never silently overwrites a considered one.

For modules there is no version in source, so `--version` supplies the tag directly and there is nothing for it to agree or disagree with.

**Revised:** 2026-08-03 — **the module clause above is superseded by D12**, which gives modules an identity subpackage carrying `Version`. `--version` now means one thing on both artifact types — fill an open field, assert a concrete one, refuse on mismatch — and `opm module version set` exists alongside `opm catalog version set`. Everything else in this decision stands unchanged; D12 removes the asymmetry rather than the separation.

**Alternatives considered:**

- **Publish decides the version itself** — read the highest published tag and bump. Rejected: a tool cannot know whether a change is a patch, a minor, or a major, and a checksum cannot either. That is what today's module flow attempts, and it produced a fleet of artifacts whose declared version names an earlier release.
- **`--version` as a pure assertion, never a writer.** Clean, and rejected as insufficient rather than wrong: it leaves release automation with nowhere to put its answer except a second mechanism that writes the file, and a second writer is what this design exists to avoid.
- **Fuse authoring into publishing** — one command that writes the version and pushes. Rejected: fusing removes the seam the commit goes in, and an artifact whose version exists in no commit cannot be traced to the source that produced it.

**Rationale:** The two operations have different failure modes and different audiences. Writing a version is a decision a human or a release process makes and reviews; pushing an artifact is a mechanical consequence of that decision. Keeping them separate is what lets the review happen.

**Source:** User decision 2026-07-26.

### D4: Publish refuses an artifact whose identity is not concrete

**Decision:** Before pushing, publish evaluates the artifact's identity fields and refuses if any is not concrete, naming the field and the file that declares it. This is a producer-side gate on the same condition a consumer would otherwise discover.

**Measured 2026-07-26 (cue v0.17.1), and this is why the gate is necessary.** Neither CUE's own publish nor a default vet blocks the condition:

- `cue mod publish v1.2.0 --dry-run` **succeeded** on a tree whose identity fields were declared but unfilled, reporting `dry-run published example.com/catproto@v1.2.0`.
- `cue vet` without `-c` reports `some instances are incomplete; use the -c flag to show errors` and **exits 0**. Only `cue vet -c` fails, and it names the field and line.

**Alternatives considered:**

- **Rely on consumer-side failure alone.** The degradation is genuinely safe — a consumer gets `incomplete value string` naming the field, not a wrong value that renders. Rejected as insufficient rather than unsafe: it moves a producer's mistake onto every consumer, and the consumer cannot fix it.
- **Fill the missing value automatically at publish.** Rejected: it makes publish a version-inventing command, which D3 exists to prevent, and it puts a value in the artifact that nobody decided.

**Rationale:** The condition is cheap to detect at exactly one point — the moment someone deliberately pushes — and expensive to diagnose anywhere else. Every OPM vet path should also pass `-c`, so the condition surfaces during development rather than at the push.

**Source:** User decision 2026-07-26, on the measurement recorded above.

### D5: The central registry hosts rather than indexes, and module paths are owner-scoped beneath it

**Decision:** OPM operates a central registry that **hosts** published artifacts, rather than an index pointing at artifacts hosted elsewhere. A module's registry path is owner-scoped under the central domain — `opmodel.dev/m/<owner>/<name>` — with the reserved `m` segment separating module space from catalog space (`opmodel.dev/catalogs/<name>`) and schema space (`opmodel.dev/core`). Owner-scoping supplies uniqueness structurally, so no registry-side ownership table is required for it.

**Alternatives considered:**

- **Index only** — authors publish under their own domains, Go-style, and the central registry records what exists. Rejected on how CUE resolves: a module path maps to a host through the prefix→host mapping in `CUE_REGISTRY`, with no per-domain autodiscovery. A module at `example.com/modules/foo` is unresolvable for every consumer who has not first edited their own registry configuration. "Publish anywhere" and "resolves for everyone with no setup" are not simultaneously available under that model, and the second is what this project optimises for.
- **A flat namespace under the central domain** (`opmodel.dev/modules/<name>`, today's shape). Rejected: a flat global namespace has no owner. The first publisher of a common name holds it permanently, and nothing distinguishes a vendor's module from a third party's fork.
- **A longer owner segment** (`opmodel.dev/modules/<owner>/<name>`). Not chosen, but the difference is cosmetic — a segment is reserved either way. Recorded so the cost of reversing this particular spelling is known to be small, unlike the cost of reversing owner-scoping itself.

**Rationale:** Hosting is what makes consumption zero-setup, because the CLI ships the central mapping as its default `CUE_REGISTRY` and every canonical path resolves out of the box. The reserved segments matter beyond aesthetics: they make the namespace *partitionable*, so tooling can answer "which of this module's dependencies are catalogs?" by reading a path instead of fetching and decoding each one.

**Scope limit, recorded 2026-07-31: this decision partitions three artifact classes and the registry holds more than three.** `m`, `catalogs` and `core` cover modules, catalogs and schema. They do not cover Platform artifacts or instance artifacts, both of which exist today — measured against the workspace registry, `opmodel.dev/modules/opm-platform` was a `#Platform` published into *module* space, and `opmodel.dev/releases/*` carried four repositories of `ModuleRelease`/`ModuleInstance` artifacts under a segment this decision never reserved. Test fixtures are a fourth case and are already solved differently, by a separate domain rather than a segment: `testing.opmodel.dev` is mapped in every registry configuration in the workspace and now carries the library's `web_app` fixture. So the partition is real but incomplete, and the gap is **OQ9**.

Promoting or mirroring an artifact between registries is unaffected. CUE maps path prefixes to hosts through `CUE_REGISTRY` rather than through anything embedded in the path, so copying `opmodel.dev/m/<owner>/<name>` from a staging registry to production changes the host while the path and the tag stay put.

**Source:** User decision 2026-07-25.
**Revised:** 2026-08-04 — **amended by D13**, which reverses the namespace half while leaving the hosting half untouched. Three things above no longer hold: first-party modules are **not** owner-scoped and stay at `opmodel.dev/modules/<name>`; the `m` segment is not adopted for first-party space, surviving only in community space as `community.opmodel.dev/m/<owner>/<name>`; and the partitionability claim in the Rationale is narrowed to a first-party layout convention, because D13 permits third parties arbitrary paths and tooling must handle them regardless. What survives intact is the hosts-rather-than-indexes holding and the CUE-resolution argument behind it — D13 turns on the separate finding that a bare host in `CUE_REGISTRY` is a catch-all, so a path's domain need not match the host serving it. One consequence worth naming, since this decision claims it as a benefit: "no registry-side ownership table is required" is now true only of first-party space, which has a single publisher. D13's community space assigns `<owner>` at registration, which is such a table.

### D6: Publish never honours `cue.mod/local-module.cue`; modules may override explicitly, catalogs may not

**Decision:** Publish always resolves dependencies as published. `replaceWith` entries are **ignored** — never honoured, never baked into the artifact. When the tree being published carries any replacement, publish reports each one alongside the registry version that will be resolved in its place, and refuses.

For `opm module publish`, an explicit flag overrides the refusal. For `opm catalog publish` there is **no override**: presence of the file is an unconditional refusal, and the check is on presence rather than on whether the replacements currently resolve.

**The flag is `--skip-override-check` (named 2026-08-04).** This decision originally left it unnamed, and the name matters more than it looks: a drafted refusal message used `--allow-local-overrides`, which the author read — correctly, from the words — as permission for the overrides to take effect. **They never do.** The replacements are ignored unconditionally and CUE strips the file when building the artifact, so nothing local is ever published or resolved; what the flag waives is the *gate*, not the ignoring. A name that can be read as "honour the overrides" describes the one behaviour this decision rules out.

**Alternatives considered:**

- **Publish silently, as today.** Rejected: CUE strips the file at publish, so the author validated against a local checkout while the artifact resolves against something else, and the divergence is invisible at precisely the moment it becomes permanent.
- **Warn and proceed.** Rejected: a warning in a CI log is not a gate.
- **Honour the replacements.** Rejected as unimplementable: a local directory path is not resolvable by any consumer.
- **Uniform treatment — the allow flag on both commands.** Rejected: the blast radius differs in kind, not degree. A module's divergence is scoped to one artifact and its direct consumers, which a publisher can reason about at flag-press time. A catalog's divergence propagates into the key space of everything built against it, which they cannot.
- **Refuse only when a replacement is unresolvable, or only for catalog-typed dependencies.** Rejected: it makes publishability depend on the state of a developer's working tree, so the same commit publishes or refuses depending on what happens to be checked out beside it. Presence is the only condition stable across machines.

**Rationale:** This is D2 applied to the dependency graph rather than to the version. Published bytes must resolve to what a consumer will resolve, and the publish is the one moment at which an author can be told that their tested resolution and their published resolution differ. Ignoring rather than honouring keeps the artifact honest; refusing rather than warning keeps the author informed.

The dev loop makes the catalog asymmetry sharper. Measured (cue v0.17.1, live registry, a three-link `instance → module → catalog` chain with origin markers): CUE honours `local-module.cue` only for the **main** module, so replacing only the module yields local module bytes resolved against the **published** catalog, and nothing in the output names the discarded replacement. A catalog developed against local replacements has been validated against a key space no consumer will ever see.

**Source:** User decision 2026-07-25.

### D7: A published catalog can be verified out of band

**Decision:** `opm catalog registry check` pulls a published catalog, decodes it, and confirms that its identity is concrete and agrees with the coordinates it was fetched by — the same check a consumer performs, run deliberately against the registry rather than incidentally during a render.

The same verification also runs when a catalog is added to a `#Platform`'s registry, so a broken catalog is reported to the platform author who subscribed to it rather than to whoever next renders a module against that platform.

**A compatibility mode is added (2026-07-31, following enhancement 0010 D35).** `opm catalog registry check --compat` compares a published catalog against its predecessor under D9's rule, so the additive-only promise can be checked by someone who did not publish the catalog. 0010 D35 accepts publish-side enforcement as the *whole* of the guarantee and ships this as an **aid** — the distinction is load-bearing and belongs in the command's own help text, not only in a design document. Nothing requires it to have been run, so it does not make an unchecked catalog trustworthy; it makes an unchecked catalog *checkable*. It reuses the comparator D9 needs, so the marginal cost is plumbing, and it is level-aware for the same reason D9 is.

**Alternatives considered:**

- **Rely on the producer-side gate alone (D4).** Rejected: D4 only protects artifacts pushed through OPM tooling, and `cue mod publish` will keep working. A published artifact needs to be checkable after the fact, by someone who did not publish it.
- **Check only during render.** Rejected: it reports the problem to the wrong person at the wrong time. A platform author adding a subscription is the earliest actor in a position to act on it, and their fix is a one-line configuration change rather than a debugging session.

**Rationale:** The subscription check fires earliest and names the catalog; the standalone command makes the same verification available without needing a platform to hand. Together they close the gap D4 cannot: artifacts that never went through OPM's publish.

**Source:** User decision 2026-07-26.

### D8: The version writer locates its field by the schema-fixed path, not by a marker

**Decision:** `opm catalog version set` and `publish --version` write the field at `identity/identity.cue`'s `Version` — the location and name enhancement 0010's `#IdentityPackage` fixes. There is no marker attribute to match on (0010 D22 drops it) and no `role=` argument. An identity file that does not match `#IdentityPackage` is refused as a schema failure, not searched heuristically.

Everything `experiments/01-version-set-write-back` established about the *edit itself* stands unchanged: a surgical AST rewrite that preserves comments and alignment, rebuilds the `&` chain so a `#VersionType` assertion survives the write, and does not touch the file at all when the value already matches. Only the locator changes — and the experiment's recorded `name == "Version"` fallback becomes the specified behaviour rather than a fallback.

**Alternatives considered:**

- **Adopt the role-marked form** — `@opm(identity, role=version, owner=publish)`, which `experiments/01-version-set-write-back` recorded as its load-bearing finding. Rejected with 0010 D22: the only thing a role buys over the schema path is finding a field the author renamed, and that case is now measured — `experiments/02-publish-plan-gates`' `renamed-catalog` variant vets clean on its own and is refused by the schema-path lookup naming the path it failed to find. The condition the role argument would have accommodated is caught without it, by the publisher, against a contract.
- **Keep refusing an unmarked field**, as experiment 01's `catalog_unmarked` case does. Rejected as a consequence rather than on its own merits: with no marker, the write-permission bit that case exercised has nothing to read. The schema replaces it — the writer touches the field `#IdentityPackage` names in the file it names, and refuses everything else.

**Rationale:** The writer and the schema should not disagree about where a version lives, and with the marker gone there is only one statement of that. The refusal that matters is unchanged in force and better sited: it now fires on "this tree is not a conformant catalog" rather than on "this field lacks an attribute", which is a condition an author can act on.

**Source:** User decision 2026-07-29. Consequence of 0010 D22; supersedes the `role`-argument recommendation recorded in `experiments/01-version-set-write-back`. Validated by `experiments/02-publish-plan-gates/` — outcome re-run 2026-07-29, all thirteen prior verdicts unchanged under the schema-path lookup, plus a new `renamed-catalog` case.

### D9: `opm catalog publish` refuses a build that breaks a contract it already published

**Decision:** Publish gains a **compatibility gate**. For every gated primitive in the tree being published — `#Resource`, `#Trait` and `#Blueprint` only, and only at beta and GA, per the two scope clauses below — it pulls the last published build that shipped a primitive of that `name` at that `apiVersion`, and refuses if the new definition is not backwards-compatible with it under enhancement 0010 D27's rule: fields and options may be added, never removed; a newly added field must be optional or defaulted; and an existing field's default may not change.

**The gate is level-aware (rider added 2026-07-31, following enhancement 0010 D34).** D34 keys D27's promise to the API version's level, so the rule this decision defers to no longer reaches alpha: the gate reads each primitive's `apiVersion`, and runs the pull-and-compare **only at beta and GA**. An `alpha` contract may remove a field, narrow a type or change a default without refusal, because that is what its level promises. This is inherited rather than an amendment — this decision names D27 rather than restating it, so narrowing D27 narrows the gate automatically — but it is recorded because the sentence above says *every primitive in the tree*, and an implementer working from that sentence would gate all of them. Two properties are unchanged by the rider: the `apiVersion` bump remains the escape hatch, since the lookup is keyed on `name` + `apiVersion` and a bumped contract finds no predecessor and passes trivially; and the match-side rung does **not** skip alpha, so a module using a field a later alpha build removed still fails loudly. What alpha gives up is exactly one class — the default drift `0010/experiments/02` measured, which no consumer-side check catches — and under D34's day-one assignment that is confined to `catalog_opm_experimental`.

A primitive at an `apiVersion` that has never been published has nothing to compare against and passes. Removing a field, narrowing a type, or changing a default is not blocked — it is redirected: the author bumps `apiVersion`, and both versions may ship in the same build.

**The gate runs over primitives only — `#Resource`, `#Trait`, `#Blueprint` — and never over `#ComponentTransformer` (clause added 2026-08-03, following enhancement 0010 D44).** This decision's own wording says *every primitive in the tree*, which under 0010 D25's original four-kind reading covered transformers and would have **resolved**, because a transformer carried an `apiVersion` and the lookup key `name` + `apiVersion` therefore existed. Applying the additive-only rule to transformer bodies refuses ordinary catalog releases: changing rendering logic, dropping an emitted field and narrowing an output type are all normal transformer edits and all D27 violations. That inverts 0010 D4, which keeps the build in a transformer's key precisely *because* a transformer is free to change. 0010 D44 removes `apiVersion` from `#ComponentTransformer`, so the gate now has nothing to key a transformer lookup on and the exclusion is structural rather than a rule an implementer must remember — but it is stated here because this sentence is what an implementer reads.

**Rationale:** 0010 D24 makes a contract key stable across catalog releases, which is what lets a module and a provider catalog meet without being compiled against the same build. That only works while the definition behind the key stays compatible, and 0010 D27 states the rule. This is the end that can enforce it *before* the damage is distributable: `experiments/02-primitive-closedness-skew` in 0010 measured that the match rung catches a removed field and a narrowed type, but **not** a changed default — two builds disagreeing on a default unify to a non-concrete value, so the match passes and the render fails later on an incomplete value naming a field rather than a build. The one violation the consumer side cannot catch is the one that silently moves output, so a publish-side gate is not redundant with it.

Sequencing follows the same split as D17 in 0010 and the `#CatalogMemberFQNGate`: 0010 defines the rule, this entry implements the command that enforces it. The machinery already exists here — D7's `opm catalog registry check` pulls and decodes a published catalog, which is the same operation this gate needs.

**Two properties worth stating, because they bound what the gate is worth.**

Subsumption is **transitive**, so comparing against the immediate predecessor secures the whole published history by induction — the gate never needs more than one prior build. But that induction holds only while every build passes through it, and 0010 D11 records that `cue mod publish` keeps working and is what every artifact published to date used. A catalog published outside `opm catalog publish` breaks the chain with nothing reporting it. Whether that gap gets a read-side counterpart is 0010 OQ13; this decision does not assume one.

**Alternatives considered:**

- **Leave it to the publisher.** Rejected on 0010 D13's own argument against D4 — a promise nothing checks is a convention, and 0010 D17 already records that a third-party catalog author has no reason to copy a convention nothing checks. It is also the argument this entry's D4 already made about incomplete identity: a producer's mistake should not be discovered by every consumer.
- **Enforce only at match time.** Rejected on the default-drift measurement above.
- **Refuse any change to a published primitive, compatible or not.** Rejected: additive evolution is the normal case, and forbidding it would make every new field an `apiVersion` bump — the cost 0010 rejected D4 for.
- **Warn rather than refuse.** Rejected for the reason D6 rejected it for local overrides: a warning in a CI log is not a gate, and the artifact it warns about is immutable once pushed.

**The implementation is now measured, and it is not `cue.Value.Subsume` (rider added 2026-08-01).** This decision originally named no implementation because subsume's behaviour across two builds — with closedness and defaults in play — was unmeasured, and `04-graduation.md` made sequencing that measurement a gate. [`experiments/03-d27-compat-gate`](experiments/03-d27-compat-gate/) is that measurement, and it returns a negative and a positive.

**A single `Subsume` call cannot express the rule, in either direction.** Across 14 cases covering every change class D27 names: `next.Subsume(prev)` agrees with D27 on **10/14**, `prev.Subsume(next)` on **8/14**, and they fail on disjoint sets. The cause is structural rather than incidental — adding a field to a struct makes a value **more specific**, while adding an option to a disjunction makes it **less specific**. D27 calls both "additive", so the rule spans both directions of the lattice while a subsume call tests one. The forward call is right about disjunctions and wrong about struct fields; the reverse call is exactly inverted. There is no third direction. A changed default is missed by **both**, because a default does not change what a value accepts — only which value it settles on when unconstrained — which independently confirms `0010/experiments/02`'s finding from the producer side.

**A three-rule field-wise walk does express it: 14/14.** Recurse structs, applying the removed-field and must-be-optional-or-defaulted rules; at leaves use forward subsume for the value domain, where it is correct; and compare defaults explicitly at every level. Violations come back path-located (`metadata.labels.wt: domain narrowed`, `s.b: field removed`, `t: default changed ("a" -> "b")`), which is most of what this document's refusal-message gate asks for. The walk is level-aware per 0010 D34 — the same field removal is accepted at `v1alpha1` and refused at `v1beta1`, `v1` and `v2`.

**What this settles for the gate above.** The stakes were stated here: a gate that could not be built as described would send 0010 D27 back to publisher discipline. It can be built, so **0010 D27 stands unchanged** and this decision gains an implementation shape rather than losing its premise. Two implementation consequences follow. The comparator is pure `cue.Value` logic and belongs in **`library`**, so this command, `opm catalog registry check --compat` (D7) and any CI action share one implementation — the same argument 0010 D32 uses for placing its guard in the kernel. And predecessor selection already exists: `library/opm/materialize/enumerate.go`'s `enumerateVersions` lists published versions for a module path, and `filter.go:112`'s `highestStable` implements exactly the right selection — skip `-dev.*` and prereleases, fall back to highest overall. **0010 D14 deletes `filter.go`, and `highestStable` with it**; that should be a move rather than a delete-and-rewrite. The experiment's comparator is a demonstration of shape and feasibility, not code to copy.

**Source:** User decision 2026-07-29. Rule defined in enhancement 0010 D27; match-side limits measured in `enhancements/0010/experiments/02-primitive-closedness-skew/` (2026-07-29, cue v0.17.1).
**Revised:** 2026-08-01 — implementation mechanism measured in [`experiments/03-d27-compat-gate`](experiments/03-d27-compat-gate/) against cue v0.17.1. Subsume ruled out in both directions; a field-wise walk adopted. No part of the decision above is reversed.

---

### D10: Published artifacts are immutable, enforced by the registry across every path it hosts

**Decision:** OPM requires that any registry it publishes to refuse to overwrite an existing tag, in **every repository that registry hosts** — not only under `opmodel.dev`. A registry that permits tag overwrite is not a conforming OPM registry.

The requirement binds a **class rather than a host**, because OPM's registry configuration ships as an open module: there is a reference configuration and N deployments, of which the central one is the default target rather than the only instance. The registry is also multi-tenant — anyone who registers may publish, under paths OPM does not choose — so immutability is a property of *the registry* rather than of OPM's namespace, and it cannot be scoped by path.

Enforcement is the registry's **authorization policy**, not OPM tooling. The configuration below is recorded as *demonstrated feasibility* of the requirement, not as deployment specification this entry owns: standing up and operating a central registry is out of scope, and what belongs here is that the property OPM depends on is achievable, and by what mechanism. Zot has no immutability flag; the mechanism is withholding the `update` action, measured 2026-08-02:

```json
"repositories": { "**": { "defaultPolicy": ["read", "create"] } }
```

`create` and `update` are distinguished **per tag**, not per repository — `pkg/api/authz.go` selects `CreatePermission` and upgrades to `UpdatePermission` only when the reference already appears in the repository's tag list. So a new tag in an existing repository is always permitted and only a re-push of an existing tag is refused, which is what makes this usable for a catalog that ships many releases. Authorization does not require authentication to be configured, so the same policy shape applies to a local dev Zot through `anonymousPolicy`.

`delete` is withheld from the default policy on the same grounds. A registry administrator retains both `update` and `delete`; that is inherent in operating the storage rather than a permission this design grants, and it is stated rather than pretended away.

Publish **also** refuses client-side to overwrite an existing tag. That is a fast, legible failure naming the tag, and it is explicitly not the guarantee — `cue mod publish` bypasses it, as enhancement 0010 D11 records for every other producer-side gate.

**The requirement does not take effect until a conforming registry is in place.** GHCR, which the fleet resolves against today, has no configurable container-tag immutability — the request is open and unanswered since 2025-12-12. This is accepted deliberately: there is no urgency to reach Zot, and until then tag immutability is a property OPM neither has nor claims. What this entry fixes is the requirement and the evidence that it is satisfiable, so the registry can be stood up against a written contract rather than the contract being reverse-engineered from whatever gets deployed.

**Alternatives considered:**

- **Namespace asymmetry — catalogs immutable, modules mutable by any publisher.** The author's initial position, and rejected on a fact rather than an argument: with arbitrary third-party paths there is no path predicate to scope it on, since `**/catalogs/**` would be a guess about another tenant's layout. Two further objections stand independently. Nothing in the normal flow needs `update` — every `-dev.*` and `-e2e.g<sha>` tag is a *new* tag and therefore a `create` — so the carve-out buys convenience for an operation that should be rare and deliberate. And the reproducibility exposure is the same in kind rather than in degree: a `ModuleInstance` pins `spec.module.{path,version}`, so a mutable module tag moves rendered bytes under an instance whose own source did not change. Difference of degree is precisely the test D6 set when it justified its own module/catalog asymmetry as differing *in kind*, and this case fails it.
- **Client-side refusal alone.** Rejected: `cue mod publish` bypasses it, so the guarantee would hold only for artifacts that were already published correctly. It ships anyway, as a better error rather than as the mechanism.
- **Maven-style permanence — no deletion, ever.** Rejected on a measured counter-example from this workspace. The `opm_experimental` canonicalisation on 2026-07-31 required deleting a repository in two registries; on `localhost:5000` the `registry:2` container refused with `405` because deletes were not enabled, forcing an on-disk removal. A blanket no-delete policy blocks legitimate cleanup and produces exactly that workaround.
- **Restricted unpublish windows, as npm and crates ship.** Rejected: deleting an artifact breaks reproducibility for anyone who already resolved it, which is enhancement 0010 D14's own argument for naming a build rather than resolving one.
- **Rely on a registry with a dedicated immutability flag.** Not available in the chosen one and not worth choosing a registry over: Zot's authorization policy is the documented mechanism, and expressing immutability as a withheld permission composes with the tenancy model rather than sitting beside it.

**Rationale:** A pinned version is only worth pinning if a tag names fixed bytes. Enhancement 0010 D14 makes a platform's reproducibility rest on exactly that, and 0010 D35 already accepted the exposure in writing — tag immutability is "a deployment constraint OPM **states** rather than a property it verifies." This decision supplies the constraint that sentence refers to, and puts it where it can be enforced: the registry is the only actor that sees every push, including those that never touch OPM's tooling.

Withholding a permission is also the right shape for a multi-tenant registry. It is default-deny, it applies to tenants OPM has no relationship with, and its failure mode is a refused push rather than a silent overwrite. The threat this closes is not only a leaked first-party CI credential but any tenant's.

**Source:** User decision 2026-08-02. Zot mechanism measured 2026-08-02 against the project's `immutable-tags` and `authn-authz` articles (`zotregistry.dev`, v2.1.12) and `project-zot/zot`'s `pkg/api/authz.go` on `main`; the GHCR gap from GitHub community discussion #181783, opened 2025-12-12 and unanswered.
**Revised:** 2026-08-02 — reframed from a statement about *the* central registry to a requirement binding any conforming registry, on the author's clarification that OPM's registry configuration ships as an open module and that these entries define how OPM works with a future central registry rather than specifying one. No part of the requirement changed; the Zot policy was relabelled as demonstrated feasibility.

---

### D11: `opm login` exists, targets the resolved registry, and stores credentials where CUE already reads them

**Decision:** The CLI gains `opm login [registry]`. With no argument it targets the registry `ResolveRegistry` produces — `--registry`, then `OPM_REGISTRY`, then `config.registry` from `~/.opm/config.cue` — so it follows the same resolution as every other registry-touching command rather than carrying a second notion of "the registry". Pointing OPM at a different deployment is therefore an operation that already exists, and `opm login` and its siblings inherit it with no new configuration surface.

This is required because the registry is **not a singleton**. OPM's Zot configuration is published as an open module, so anyone may run a conforming registry (D10); the central deployment is the default target, not the only one. A CLI that could authenticate against a single fixed host would make the open module unusable by the people it exists for.

**Credentials land in a store CUE already reads.** This is a mechanical constraint rather than a preference: the push is performed by CUE's resolver, which reads `$CUE_CONFIG_DIR/logins.json` and Docker/podman credential configuration. A credential written anywhere else is invisible at the exact moment it is needed. The default is the standard OCI credential file; a `docker-credential-opm` helper is the upgrade path if OPM later wants to own the flow, since helpers are discovered through `credHelpers` and that route keeps one store rather than adding a second. An OPM-private credential store that CUE cannot see is **excluded**, not deferred.

**The authentication mechanism is deliberately left open.** Whether a deployment uses htpasswd, LDAP, OIDC social login, API keys, mTLS, or OIDC workload identity for CI is a registry-operations decision belonging to the rollout, not to this entry — which defines how OPM works with a registry rather than specifying one. What is fixed here is the command's contract: which registry it targets, where the credential goes, and that publish itself never prompts.

**Alternatives considered:**

- **No `opm login` at all; document `docker login` and inherit.** The measured minimum, and it works today: `cue login --help` (v0.17.1) directs users to `docker login` / `podman login` for any non-Central registry, and CUE reads what those write, so publish needs no new code. Rejected on ownership rather than on mechanics — OPM ships a default registry, a reference deployment, and an open module for running more, and directing users to another project's CLI to authenticate against OPM's own registry moves setup cost onto them to save implementation cost here.
- **`opm login` with its own credential store.** Rejected as non-functional rather than merely redundant: CUE performs the push and would never read it, so the command would appear to succeed and change nothing.
- **Wrap `cue login`'s OAuth 2.0 device authorization grant.** Attractive, being what the CUE Central Registry uses, and not chosen now because it presumes the target implements the device-grant endpoint — unverified for Zot. It stays available: because the target is *resolved* rather than assumed, adding it later changes the mechanism behind one command and nothing else.
- **Bind login to a fixed central host.** Rejected: it contradicts the open-module distribution model D10 rests on.

**Rationale:** Two constraints had to hold at once. Publishing must work through CUE's credential path, because CUE is what talks to the registry — so OPM cannot own the store. And OPM should own the *experience*, because it ships the registry people will run. Writing into the shared location satisfies both: `opm login` is the front door, and nothing downstream needs to know it was used.

Resolving the target through `ResolveRegistry` rather than a constant is what makes the open module real rather than nominal. It also avoids a defect already present elsewhere in the workspace: `opm-operator/cmd/main.go`'s `resolveRegistry` documents a `--registry` > `OPM_REGISTRY` > CUE-default precedence but gives the flag a non-empty compiled-in default, so both lower tiers are unreachable and `OPM_REGISTRY` is inert on the operator. The CLI's flag defaults to empty and its precedence works, and it already records shadowed values so an override is reportable rather than silent. This decision keeps `opm login` on that path instead of introducing a parallel one.

**Source:** User decision 2026-08-02. CLI resolution read from `cli/internal/config/resolver.go`, `cli/internal/config/templates.go` and `cli/internal/cmd/root.go:48` on 2026-08-02; CUE credential sources measured from `cue v0.17.1` (`cue login --help`, `cue help registryconfig`); Zot authentication options from `zotregistry.dev`'s `authn-authz` article (v2.1.14); operator precedence defect recorded in enhancement 0010's migration inventory (2026-07-31).

---

### D12: Modules carry an identity subpackage and a version; `version set` and `--version` behave identically on both artifact types

**Decision:** A module gets a catalog-style identity subpackage — `identity/identity.cue`, `package identity`, exporting **both** `ModulePath` and `Version`. The module's root package consumes it:

```cue
import id "opmodel.dev/m/<owner>/<name>/identity"

metadata: {
	modulePath: id.ModulePath
	version:    id.Version
}
```

`#Module.metadata.version` exists again, required, and is the value `Instance.ModuleVersion()` reads. **It must never feed `fqn` or `uuid`** — see the constraint below.

The command surface becomes symmetric. `opm module version set <semver>` and `opm catalog version set <semver>` both write `Version` in their artifact's `identity/identity.cue`, in place and idempotently, by the surgical rewrite D8 specifies. `--version` on publish means **one thing on both commands**: against an open `Version` it fills it, against a concrete one it asserts equality and refuses on mismatch. It writes the **working tree**, not a copy — the author sees the diff and may commit it, where publishing bytes that exist in no commit is what D2 refuses and D10 makes permanent.

**Publish additionally verifies `metadata.modulePath == id.ModulePath` and `metadata.version == id.Version`.** This check exists because `core` cannot enforce the wiring: `#Module` cannot declare `metadata: version: id.Version`, since `core` has no way to reference an arbitrary module's identity package. The template establishes the derivation and CUE then enforces it — a developer who edits the literal gets `conflicting values` at `cue vet`, earlier and louder than any gate. But a developer who *replaces* the derivation with a literal leaves nothing to conflict with, and this check is what catches that case.

`opm module init` templates the subpackage, the import path and the wiring, so the author never writes the self-import by hand. That is what makes the cost manageable rather than merely accepted.

**The permanent constraint.** Enhancement 0010 D2 rejected a module version partly on a measured failure: because `fqn` interpolated `version`, a moving version changed `module.uuid` → `instance.uuid` → the owner label on every rendered resource, and `opm-operator/internal/apply/prune.go:107` skips any delete whose live label disagrees with `Status.InstanceUUID` — so every upgrade silently orphaned whatever it removed.

0010 **D41** states the surviving rule, in two halves, and it belongs in `core/SPEC.md` beside the fields rather than only in a decision log:

> **Module artifact identity** — `#Module.metadata.fqn` and `.uuid` distinguish majors and nothing finer. The major reaches them through the module path; minor and patch reach them not at all.
>
> **Instance identity** — `#ModuleInstance.metadata.fqn` and `.uuid`, which carry the owner label `prune.go:107` reads, derive from the module's major-free `registryPath`. Neither the version nor the major reaches them.

Wiring a version back into `fqn` or `uuid`, or deriving instance identity from `module.uuid` again, restores the orphaning — and it reports success while doing it.

**Alternatives considered:**

- **Keep modules version-less, as 0010 D2 wrote it, with the git tag as the review seam.** Rejected on two grounds. An instance derives its version from the module and has none of its own (`library/opm/module/instance.go:110`; `core/src/module_instance.cue` declares none), so deleting the module's version removes the only source for a value the instance still needs. And `core/src/transformer.cue:105` declares `version: string` non-optionally inside `#moduleInstanceMetadata`; a registry-acquired module could be filled from the resolved coordinate, but a module rendered **from disk** has no coordinate — which is D2's own stated reason for rejecting its second alternative, that "a module read from disk has no identity". Keeping the field means the question does not arise. Measured 2026-08-03 and recorded so the argument is not overstated: no shipped transformer reads `.version` — 117 uses of `#moduleInstanceMetadata` across `catalog_opm`, `catalog_kubernetes` and `catalog_opm_experimental`, every one of them `.name` or `.namespace` — so nothing breaks either way. The choice is about which design leaves an unfilled field, not about a broken consumer.
- **Publish refuses instead of writing, requiring `version set` first.** Rejected by the author in favour of keeping D3's writer intact. With `version set` now available on both artifact types, the reviewed seam is available to anyone who wants it without forcing two commands on release automation that does not.
- **Publish writes a copy and pushes that.** Rejected: it is the only candidate that *guarantees* the published bytes exist in no commit — the condition D2 rejected the current catalog copy-and-stamp mechanism for — and D10 makes every instance of it permanent.
- **A top-level `Version` in the module's root package.** Rejected on 0010 D7's measurement: a top-level field beside the embedded `#Module` vets clean standalone and fails only at re-unification into the closed `#ModuleInstance.#module` slot (`field not allowed`), in a code path the module's own author never runs.
- **A hidden `_version` in the root package**, which 0010 D7 sanctions as an indirection. Rejected: it delivers the review seam and `version set` while leaving the version out of the published artifact, which is exactly the value the instance derives from.
- **A subpackage carrying only `Version`, with `modulePath` still written directly.** Rejected as the worst of both: it pays the self-import cost without buying the consistency that justifies paying it.
- **Derive `metadata.version` inside `core` so the two cannot disagree.** Not available rather than rejected: `core` cannot reference a module's identity package, because it does not know the path. That impossibility is the reason the publish check exists.

**Rationale:** The asymmetry this removes was never designed. It fell out of 0010 D2 deleting the only field a module version could live in, and it cost modules the one thing catalogs have — a version visible in a diff before it becomes permanent. Restoring the field restores `version set`, and restoring `version set` is what lets `--version` mean the same thing everywhere instead of being a writer on one command and a bare coordinate on the other.

The subpackage is adopted for consistency rather than for a structural need, and 0010 D23 is right that a single-package module has none: nothing computes an FQN from a module-wide constant across a package boundary. What changes the balance is `opm module init`. The self-import D23 priced as authored duplication becomes generated, so the cost lands on a template rather than on every module author, and the two artifact types stop requiring two explanations.

**Source:** User decision 2026-08-03. Instance-derives-from-module verified at `library/opm/module/instance.go:110` and `core/src/module_instance.cue`; transformer-context exposure at `core/src/transformer.cue:101-109`; catalog reader set measured across the three catalogs 2026-08-03. **Amends enhancement 0010 D2, D7 and D23**, and is contingent on those amendments landing.

---

### D13: OPM imposes no namespace on third parties; path ownership is domain ownership

**Decision:** OPM does not arbitrate names it does not own. A module or catalog path is any valid CUE module path, and the authority over a path is whoever controls its domain. Three spaces follow, and only the first is OPM's to shape:

- **First-party — `opmodel.dev/*`, unchanged from today.** Modules stay at `opmodel.dev/modules/<name>`, catalogs at `opmodel.dev/catalogs/<name>`, schema at `opmodel.dev/core`. The `m` segment D5 proposed is **not adopted here** and no owner segment is added: there is exactly one publisher in this space, so owner-scoping has nothing to disambiguate.
- **Community — `community.opmodel.dev/m/<owner>/<name>`**, and `community.opmodel.dev/catalogs/<owner>/<name>` for catalogs. The space for publishers using OPM's central registry without a domain of their own, with `<owner>` assigned at registration. The kind segment is kept here where first-party keeps the longer `modules`, and the asymmetry is deliberate rather than an oversight: community paths already carry an owner segment, so the short form holds the length down, while the first-party spelling is retained because changing it costs a full fleet republish for no design gain. `modules` is a **grandfathered spelling**, not a second canonical one.
- **Anywhere else — unconstrained.** A vanity domain on the central registry, subject to proof of control over that domain; or any path at all on a self-hosted registry, where OPM has no say by construction.

**This works because a path's domain and its hosting registry are independent.** Measured against `cue v0.17.1` (`cue help registryconfig`): CUE maps module paths to hosts through prefix→host entries in `CUE_REGISTRY`, and a bare host with no prefix is a catch-all used "to fetch all modules" — which is how the default Central Registry serves arbitrary paths. So `example.com/k8up` resolves from OPM's registry for anyone with a stock CLI and no configuration edited. The subdomain split extends a mechanism already deployed here rather than inventing one: `testing.opmodel.dev` is mapped in every `CUE_REGISTRY` configuration in the workspace.

**Proof of domain control is a requirement stated, not a mechanism specified.** Nothing today stops a push to `microsoft.com/evil`, and a path-domain is only an ownership claim if something checks it. Whether that is a DNS TXT record, an ACME-style challenge, or manual review belongs to the registry rollout — the same boundary D10 drew for immutability and D11 for authentication.

**What this changes in D5.** *Hosts rather than indexes* survives untouched — OPM still hosts, and the argument that "publish anywhere" and "resolves with no setup" are not simultaneously available is unaffected. Three other parts do not: module owner-scoping under `opmodel.dev` is dropped, the `m` spelling is not adopted for first-party, and the partitionability claim narrows from a global property to a first-party layout convention. D5's own note that the `m`-versus-`modules` spelling is "cosmetic" and cheap to reverse is what makes the last one free to take now.

**Alternatives considered:**

- **Owner-scope catalogs symmetrically under `opmodel.dev/c/<owner>/<name>`** (OQ7 candidate (a)). Rejected: it makes OPM the registrar for names it does not own, which is the outcome the question existed to avoid. It also has no good spelling for the first-party owner segment — `opmodel.dev/c/opm/opm` is the reductio.
- **Keep the flat namespace curated and add an owner-scoped space beside it under the same domain** (OQ7 candidate (b)). Rejected in favour of the subdomain, which states the same separation in the address rather than in a path segment a reader has to know the convention for, and which is repointable to a different registry deployment by one `CUE_REGISTRY` entry where a path segment is not.
- **Keep it flat and arbitrate by hand** (OQ7 candidate (c)). Rejected: OPM as registrar, explicitly.
- **Make a domain the price of entry** — first-party plus proven vanity domains, no community space. Rejected: it makes an unbuilt vanity-domain mechanism a hard prerequisite for every third-party publisher, and turns "no domain" into "no OPM".
- **Adopt `m` for first-party as well.** Rejected on cost against benefit: it rewrites every published module coordinate and every pin in the deployment repositories for a spelling change D5 itself calls cosmetic, now that the owner segment that motivated the reserved-segment shape is gone from that space.
- **Drop the kind segment inside `community.` and go owner-first** (`community.opmodel.dev/<owner>/<name>`). Rejected by the author in favour of mirroring the first-party layout, which keeps one vocabulary across both spaces and leaves room for kinds beyond modules and catalogs — the gap OQ9 is open on.

**Rationale:** In the author's words — "OPM should not impose anything on other developers regarding this." A developer who proves they own `example.com`, or who points their registry configuration at their own deployment, uses whatever paths they like. OPM registers names under `opmodel.dev` because it owns that domain, and for no other reason.

D10 had already presumed this without D5 catching up: it records the registry as "multi-tenant — anyone who registers may publish, **under paths OPM does not choose**", and rejected a path-scoped immutability policy because `**/catalogs/**` "would be a guess about another tenant's layout." This decision ratifies what that one assumed.

The first-party half is decided on migration cost rather than taste. With third parties on `community.` or their own domains, nothing shares `opmodel.dev/modules/*` with the first-party fleet, so the land-grab D5's owner-scoping defends against cannot occur there. Keeping the current paths makes the expensive half of OQ6 disappear rather than be scheduled.

**Source:** User decision 2026-08-04. CUE prefix→host and catch-all resolution measured from `cue v0.17.1` (`cue help registryconfig`) 2026-08-04; the `testing.opmodel.dev` subdomain precedent from the workspace `CUE_REGISTRY` configuration. **Amends D5** (module owner-scoping, the `m` segment, and the scope of the partitionability claim); **resolves OQ7**. One knock-on lands in enhancement 0010: **D41** rejects deriving instance identity from `name` citing "`registryPath` is owner-scoped under 0011 D5" — the property survives, because a full module path is unique by construction, but the reason is now the domain rather than an owner segment and the citation needs rewording.

---

### D14: Platforms get a reserved segment; instances get none, because they are not CUE modules

**Decision:** `opmodel.dev/platforms/<name>` is reserved for `#Platform` artifacts, with `community.opmodel.dev/p/<owner>/<name>` in community space, following D13's long/short split. The reservation is **forward-looking**: no platform is published or fetched from a registry today. The CLI reads its platform from `~/.opm/platform.cue` (`cli/internal/config/platform.go`), and `materialize` resolves a platform's *subscriptions* against the registry while never fetching the platform spec itself.

Instance artifacts get **no segment and no reservation**. Nobody publishes an instance, and OQ9's premise — that `opmodel.dev/releases/*` sits under a segment D5 failed to reserve — is wrong: they are not in the namespace D5 partitions. Measured 2026-08-04: the deployment repository's Taskfile publishes with `flux push artifact` to `oci://…/opmodel.dev/releases`, and `ModulePackageSpec.SourceRef` fetches a Flux source (`OCIRepository`/`GitRepository`/`Bucket`) and loads `instance.cue` off the unpacked tree. Nothing resolves them through CUE's module resolver, imports them, or lists them in a `deps` block. They are OCI repository paths that share a spelling convention with module paths and nothing else. (`releases` is also pre-enhancement-0002 vocabulary for `instances`; renaming the artifact path belongs to that vocabulary sweep, not to this decision.)

**No collision guard is needed, because D13 makes a collision unrepresentable.** `#FirstPartyPath.kind` is a closed disjunction, so no first-party artifact can land under `opmodel.dev/releases/*`, and no third party publishes under `opmodel.dev` at all — they are on `community.opmodel.dev` or their own domain.

The Flux repositories are in scope for **D10**, which binds immutability to "every repository that registry hosts" and explicitly does not scope by path. They satisfy it already: that publisher bumps to a fresh tag on every publish, so every push is a `create` and never an `update` — the pattern D10's own alternatives section argues is the normal case.

`opmodel.dev/modules/opm-platform` (`v1.0.0`, `v1.0.1`, `localhost:5000` only, absent from GHCR) is a **defect to delete**, not an artifact to migrate. `library/modules/opm_platform/platform.cue`'s own header declares it "an unpublished in-repo fixture… not part of any publish path", so the artifact contradicts its source.

**Alternatives considered:**

- **Reserve `opmodel.dev/instances/…` symmetrically** (OQ9 candidate (a) as filed). Rejected on measurement: it reserves module-namespace space for artifacts that are not modules, and a reserved segment implies a publish path that does not exist and is not wanted.
- **A separate domain per class** (OQ9 candidate (b), extending the `testing.opmodel.dev` precedent). Rejected: D13 spent the subdomain axis on **ownership** and put kind in the path segment. Applying both axes to subdomains goes combinatorial at the first community platform — `community.opmodel.dev/p/<owner>/<name>` or `platforms.community.opmodel.dev/<owner>/<name>` is a choice nothing should have to make.
- **Treat both measured cases as defects** (OQ9 candidate (c)). Adopted for `opm-platform`, rejected for the instance artifacts: `opmodel.dev/releases/*` is a working, intentional deployment mechanism, not a mistake. The candidate was right about half the evidence.
- **Reserve `releases` *against* use as a collision guard**, on the ground that both namespaces are repository paths in one registry. Considered and found **redundant rather than merely unnecessary**: D13's closed kind vocabulary makes the collision inexpressible, so the guard would restate a constraint the schema already enforces. Recorded because the reasoning is worth having when someone next notices the two namespaces share a host.

**Rationale:** In the author's words, "instances are instances of modules" and "no one will or is supposed to publish an instance" — and the mechanism turns out to be stronger than the intuition. There is nothing to reserve because there is nothing to collide with in that namespace; the Flux artifacts were never in it.

Platforms are the opposite case. Nothing publishes one today, but a platform is plausibly publishable later — an organisation depending on a published platform spec is a coherent thing to want — and the segment is costless to reserve now and expensive to retrofit once `opmodel.dev/platforms/*` could already mean something else.

**Source:** User decision 2026-08-04. Flux publish path read the same day from the deployment repository's Taskfile, named out of band (`flux push artifact`, `RELEASE_REGISTRY: oci://localhost:5000/opmodel.dev/releases`); read side from `opm-operator/api/v1alpha1/modulepackage_types.go:26-40`; platform loading from `cli/internal/config/platform.go` and `library/opm/materialize/`; fixture header at `library/modules/opm_platform/platform.cue:1-9`. **Resolves OQ9**; extends D13's namespace.

---

### D15: The authored version is the trigger; an already-published version is always a refusal; nothing predicts a version

**Resolves:** OQ4

**Decision:** Publishing is decided by the version an author wrote, and by nothing else.

- **The trigger is the authored `Version`** in `identity/identity.cue`, written by `version set` or supplied by `--version` (D3, D12). Writing a version the registry does not hold *is* the decision to release.
- **An already-published version is always a refusal.** Publish resolves whether the tag exists and errors if it does, naming the artifact, the version, and that it must be bumped. There is no sweep mode, no `--skip-if-published`, and no invocation in which the condition is a success. This is the same client-side check D10 specifies from the immutability side, reached from the other direction.
- **Idempotency belongs to the sweep, not to publish.** The sweep resolves which artifacts carry an unpublished version and invokes publish only for those, rather than invoking publish on everything and relying on it to no-op. The filter is a registry lookup, so nothing is predicted and no ledger is consulted.
- **CI needs no notion of whether an artifact changed** — only of what the registry already holds. That is the trigger question this decision dissolves and the thing the checksum was doing wrong. A sweep over every module on `main` stays idempotent by construction; running it twice, or on every commit, changes nothing.
- **`modules/versions.yml` and the checksum machinery are deleted**, not demoted to advisory.
- **The "you forgot to bump" warning survives, sourced from git.** Has anything under a module's directory changed since the commit tagged with its current version? That is a `git diff`, it cannot drift out of sync the way a side ledger did, and it is a warning rather than a gate.
- **`branch-tag.sh` is retained unchanged.** The `-dev` prerelease path already derives a correct, deterministic version with no clock and no network, and OQ4 filed it as an open case that shipped code had in fact already closed.
- **Catalogs keep release-please, and nothing requires modules to adopt it.** Release-please decides a version and hands it to `version set` / `--version`; it must **not** write `identity.cue` directly through an `x-release-please-version` annotation, which would make it a second writer beside D3's and reintroduce the drift this design removes. Conventional commits stay a catalog convention rather than a requirement this decision imposes on `modules/`.

**Measured 2026-08-04, and this is why the checksum is deleted rather than kept.** `modules/versions.yml` lists twelve modules and **two** carry a `checksum` (`seerr`, `web_app`). `modules/Taskfile.yml`'s `publish` treats a missing checksum as changed — `if [ -z "$stored" ]; then … changed+=("$module")` — so ten of twelve are blind patch-bumped on every run. The mechanism presents as change detection and behaves as an unconditional bump. (The task is named `publish`. Several documents called it `publish:smart`, which is the name of the equivalent task in a deployment repository outside the workspace; corrected across `01-problem.md`, `02-design.md`, `06-operational.md` and `README.md` on 2026-08-04. OQ4's own prose still carries it and is left for compaction.)

**Alternatives considered:**

- **Conventional commits drive the decision** (OQ4 candidate (a)), with release-please calling `version set`. Rejected as a *requirement*, not as a practice: it is the only candidate that can distinguish a breaking change from a patch, and that is exactly the inference the author declined to build a system around. It stays in place for catalogs, where it already runs, and is not imposed on `modules/`, which has no release-please today and would need per-module components or a single repo-wide version to gain one.
- **Keep the checksum as an advisory warning** (OQ4 candidate (c)). Rejected on the measurement above and on redundancy: with a version now authored in-tree (D12), "files changed and the version did not" is a git question, and answering it from a committed ledger reintroduces the drift that left ten of twelve entries empty.
- **Hash decides *whether*, the author decides *what***. The author's intermediate proposal, and rejected on a case analysis rather than on taste. Across the four states — {substance changed, version bumped} — the hash agrees with the registry check when nothing changed and when both changed, is merely noisier when substance changed without a bump, and is **wrong when a version is bumped with no other change**: it reports "unchanged" and silently blocks a deliberate act, which is what an author does when escaping a bad tag or republishing after a registry incident. The registry lookup is correct in all four, and needs no ledger, no per-file hashing and no stored state.
- **Publish infers the version from the last published tag and increments.** Rejected by D3 already, and this decision does not reopen it: a tool cannot know whether a change is a patch, a minor or a major, and the fleet produced by trying is the evidence.
- **Skip rather than refuse when publish is run as a fleet sweep, and refuse when targeted — originally adopted here, then reversed.** This decision first had the registry lookup used "to *skip* rather than to *refuse* when publish is run as a fleet sweep", leaving which behaviour applied to a mode on the command, and `04-graduation.md` carried it as the last unsettled item on the command surface. Reversed by the author: it makes one condition mean two things depending on how the command was reached, and the mode itself would have needed a spelling nobody wanted to invent. The consistency argument is the stronger one — D10 already has publish "refuse client-side to overwrite an existing tag", so a skip in sweep mode would have been a carve-out from a rule the design had already stated, and carve-outs on refusals are how the producer-side half becomes decorative (`05-risks.md`, *a refusal that fires too easily gets routed around*, arriving from the opposite direction).
- **Always skip.** Rejected as bad on the interactive path, which is the one a human uses: a command asked to publish that exits zero having published nothing has reported success for a non-event.
- **Refuse, and have the sweep tolerate the specific exit code.** Viable and not chosen: it makes the sweep parse failure to detect a normal state, so a genuine error and an expected no-op arrive on the same channel and are distinguished by a number. Filtering first keeps the sweep's success path free of expected failures.

**Rationale:** In the author's words — "I don't want to develop and maintain a complex system that tries to predict what version to publish, I would rather it be up to the authors." What makes this cheap rather than merely simple is that the trigger question dissolves once versions are authored: the registry already knows what has been released, so nothing needs to infer it. The mechanism that was there to answer that question was answering it wrongly at a rate of ten modules in twelve.

That the check is a **refusal** rather than a tolerated no-op follows from the same place — in the author's words, "It should be a refusal. It should check against the registry and error." A command asked to publish that exits zero having published nothing has reported success for a non-event, and a mode flag that made the condition mean two things would have been a carve-out from a rule D10 already stated. Idempotency is a property the *caller* arranges by filtering, which keeps the sweep's success path free of expected failures.

The failure mode is stated rather than designed around: an author who changes code and forgets to bump gets silence — nothing publishes and nothing refuses. The git-sourced warning is what addresses it, and it is deliberately not a gate, because a gate here would block the fourth case above for the same reason the checksum did.

**Source:** User decision 2026-08-04. `modules/versions.yml` and `modules/Taskfile.yml`'s `publish` read 2026-08-04 (twelve modules, two checksums, missing-checksum-means-changed at `Taskfile.yml:143-145`); `catalog_opm/.tasks/branch-tag.sh` and `.github/workflows/branch-publish.yml` read the same day; release-please configuration from `catalog_opm/release-please-config.json`. **Resolves OQ4.** Depends on D12 for the authored module version and on D10 for tag immutability, which is what makes an unpublished version a safe trigger.
**Revised:** 2026-08-04 — absorbed D19, which reversed the skip-in-sweep half of the idempotency bullet and narrowed the CI claim. The trigger half is untouched: the authored version still decides a release, nothing predicts a version, and no ledger is consulted. D19 also closed the last item under `04-graduation.md`'s command-surface gate — whether an already-published version is a skip or a refusal — so no mode flag exists and nothing needs a spelling.

---

### D16: Publish enforces the author's `cue.mod` and never generates it; the same check is available at vet

**Decision:** Publish **validates** that `cue.mod/module.cue`'s `module:` line and the artifact's declared identity state the same module path, and **refuses loudly** when they differ — printing both values, naming both files, and stating the fix. It never edits `cue.mod`, and it never synthesises one.

The same validation is available in **`opm module vet`** (`cli/internal/cmd/module/vet.go`), so the drift is caught while an author is working rather than at the moment they push. Publish still performs it; the vet copy moves the discovery earlier, it does not replace the gate.

**`opm module init` writes the `module:` line** alongside the identity subpackage, the self-import and the `metadata` wiring D12 already assigns to it. Generation happens once, at scaffold, into the committed tree where a diff can be read — not silently at every push. That is the answer to the ergonomic objection generation exists to raise: the author never types the path twice either way.

A tree with **no** `cue.mod` is refused with a message pointing at `cue mod init`. Publish does not offer to create one.

This is already expressed in `schemas/target.cue`: `#PublishPlan` carries `cueModPath: declaredPath`, so a disagreement is a unification failure rather than a check someone has to remember to write.

**The self-import is what settles this, and it is why "generate" is larger than it sounds.** The module path has **three** statements, not two, measured 2026-08-04:

1. `cue.mod/module.cue` — `module: "opmodel.dev/catalogs/opm@v1"`, which governs how imports resolve
2. a literal import string in source — `catalog_opm/src/catalog.cue:13` reads `import id "opmodel.dev/catalogs/opm/identity"`
3. `identity/identity.cue`'s `ModulePath` — a data value CUE never checks against either of the others

(1) and (2) must agree or the tree does not build. (3) is unconstrained, and it is what every FQN interpolates. Generating (1) from (3) leaves (2) — a hardcoded string in a `.cue` file — pointing at the old path, so the self-import stops resolving. "Generate the `cue.mod`" therefore means the `module:` line **plus every self-import in the tree**, which is a refactoring tool rather than a publish step. D12 makes self-imports the norm for modules as well as catalogs, so this reaches the whole fleet rather than the three catalog repos.

**Alternatives considered:**

- **Generate `cue.mod` from identity** (OQ5 candidate (b)). Rejected on the three-statement analysis above. The ergonomic gain it offers is real and is delivered by `init` instead, without making publish a writer.
- **Generate into a copy of the tree and push that.** Rejected by D2 outright — published bytes must equal committed bytes — and `catalog_opm/.build/catalog/cue.mod/module.cue` is the duplicate this design deletes.
- **Generate only when `cue.mod` is absent or its `module:` line is empty.** Rejected on the instability D6 already named: it makes publishability depend on what happens to be in a working tree, so the same commit publishes or refuses depending on machine state. It is also not achievable in the narrow sense — a synthesised `cue.mod` needs a correct `deps` block, and resolving dependencies is `cue mod tidy`'s job, not publish's.
- **A separate `--check`-only mode**, as the Open Question floats. Not rejected so much as already present: the plan output `06-operational.md` describes — the resolved path, tag, repository and gate outcomes, printable before the push — is the dry run, and adding a second flag for the same behaviour is surface without function.

**Rationale:** In the author's words — publish "should validate that both module paths are the same. It should fail loudly if they differ and explain what to do." Enforcement keeps authored source authoritative, which is D2 applied to the one file CUE itself reads to decide what the module is called. A tool that quietly rewrites that line is changing what the author's own imports resolve to.

Adding the check to `opm module vet` is worth more than its cost: the condition is cheap to detect at any point and is only expensive when discovered at a push, which is the same argument D4 makes for the identity-completeness gate.

**Source:** User decision 2026-08-04. Self-import measured at `catalog_opm/src/catalog.cue:13` against `catalog_opm/src/cue.mod/module.cue` the same day; command surfaces verified to exist at `cli/internal/cmd/module/vet.go` and `init.go`. **Resolves OQ5.** Builds on D12's identity subpackage and D2's published-equals-committed rule.

---

### D17: There is no fleet migration; what remains is a bounded cleanup, and its sequencing runs the other way

**Decision:** The published fleet does **not** move. D13 keeps first-party modules at `opmodel.dev/modules/<name>`, so every published module keeps its coordinate, its `registryPath`, and — under 0010 D41 — the instance identity derived from it. OQ6 is resolved by **dissolution**: the question asked how the fleet reaches an owner-scoped namespace, and there is no longer one for it to reach.

0010 D1's `@vN` suffix does not change this. `opmodel.dev/modules/postgres@v2` addresses OCI repository `opmodel.dev/modules/postgres` with `v2.*` tags, so adding the major to `metadata.modulePath` moves no repository.

**Measured 2026-08-04 against `localhost:5000`** — 72 repositories, 60 under `opmodel.dev/`, 39 of them modules. Three items this question carried are already done:

| Item | State |
| --- | --- |
| `opmodel.dev/modules/opm-platform` | **absent** — already deleted; D14's disposition is satisfied |
| `opmodel.dev/library/testdata/modules/web-app` | **absent** — the fixture is now `testing.opmodel.dev/modules/web_app@v1` (`library/testdata/modules/web_app/cue.mod/module.cue`) |
| the `opm-experimental` / `opm_experimental` spelling collision | **resolved** — three catalogs remain, underscore form only |

**What remains is a cleanup list, and it is bounded:**

1. **The legacy `v1alpha1` namespace** — eleven `opmodel.dev/<name>/v1alpha1` repositories plus `opmodel.dev/core/v1alpha1` and `opmodel.dev/kubernetes/v1`. **These cannot be removed yet.** 0010 D18 records that both deployment repositories still pin `opmodel.dev/core/v1alpha1@v1` and `opmodel.dev/opm/v1alpha1@v1`; they are the deprecated `catalog/` tree the v0 fleet runs on. They go when the v0 → v1 fleet migration completes, and not before.
2. **One hyphenated module** — `opmodel.dev/modules/test/hello-web` → `test/hello_web`. That is the entire snake_case sweep; every other module is already conformant.
3. **`opmodel.dev/modules/test/*`** (four repositories) and their `-e2e` prerelease tags — moved to `testing.opmodel.dev` or deleted. The separate-domain precedent is the one D13 and D14 both rest on.
4. **`opmodel.dev/test/cleanmod`** — developer detritus, deleted.
5. **`opmodel.dev/releases/*`** (four repositories) — out of scope per D14; Flux artifacts, not CUE modules.

Items 2–4 are independent of everything else and may run at any time. Item 1 is gated by a migration this entry does not own.

**The sequencing claim in `05-risks.md` and `06-operational.md` is inverted and is corrected here.** Those documents say the migration "is cheapest now and compounds with every publish", making delay strictly more expensive. Nothing compounds: there is no coordinate rewrite, so a module published tomorrow costs no more to leave in place than one published last month. The only real ordering constraint runs the other way — the legacy paths must **wait** for the v0 → v1 fleet migration.

**The joint window with enhancement 0010 dissolves into a single operation.** 0010's step 6 republishes every module carrying the new identity shape; this entry's contribution is that those republishes go through `opm module publish` rather than the checksum task D15 deletes. That is one event, not two events requiring a shared window — a stronger relationship than the coordination both entries currently describe, and it removes the "written down but not owned" gap `04-graduation.md` carries.

**Alternatives considered:**

- **Republish old coordinates as aliases during a transition window**, as OQ6 floats. Rejected as moot — no coordinate changes, so there is nothing to alias. Recorded because it was a live option while D5's owner-scoping stood, and its cost (two published artifacts claiming one identity, with D10 making both permanent) is worth having on the record if a future decision reopens a path move.
- **Hard-cut the namespace**, OQ6's other branch. Same disposition, same reason.
- **Adopt or recreate deployed instances.** Not applicable: 0010 D18 measured that every deployed instance is on the v0 schema line, so no live instance carries an identity this entry or 0010 alters. The relabel-in-place holding survives as an input to the v0 → v1 migration, which is where D18 put it.
- **Delete the legacy `v1alpha1` paths now**, since they are deprecated. Rejected on the pin measurement: the fleet resolves against them today, and D10's own argument against unpublishing is that deleting an artifact breaks reproducibility for anyone who already resolved it.
- **Keep OQ6 open until the cleanup has run.** Rejected as confusing a design question with an implementation task. What the cleanup *is* is now decided; that it has not been performed belongs to `04-graduation.md`'s `accepted → implemented` list, where it already appears.

**Rationale:** This question existed because D5 rewrote every published coordinate and the declared path is also the artifact's identity. D13 removed the rewrite, and with it the migration, the two-adoption-passes cost, the joint scheduling window, and the largest risk in `05-risks.md`. What is left is the residue that was always going to need cleaning — legacy artifacts, a test namespace in the wrong place, and one hyphen — none of which is a fleet migration and none of which shares a deadline with the other.

Recording the inverted sequencing matters more than recording the cleanup. Both documents currently tell a reader that delay is expensive and that a window must be scheduled with 0010; a reader acting on that would schedule work that no longer exists while missing the one ordering that does bind.

**Source:** User decision 2026-08-04. Live registry enumerated the same day (`localhost:5000/v2/_catalog`, 72 repositories); fixture relocation confirmed at `library/testdata/modules/web_app/cue.mod/module.cue`; v0 fleet pins from enhancement 0010 D18. **Resolves OQ6.** Consequence of D13; supersedes the migration premise in `05-risks.md` and `06-operational.md`, and invalidates line 106 of 0010's [`research/migration-inventory.md`](../0010/research/migration-inventory.md).

---

### D18: The published tag must name the version the artifact declares

**Decision:** Publish refuses when the tag it would push under does not equal the artifact's declared `Version`. The comparison is against the **effective** version — the value the artifact already declares, or the value `--version` supplies into an open field (D3, D12) — so both authoring routes are covered by one rule.

The check runs in the CLI, in `opm module publish` and `opm catalog publish`, and is available in `opm module vet` / `check` on the same shift-left argument D16 makes for the `cue.mod` comparison: the condition is cheap to detect while working and expensive only when discovered at a push.

`schemas/target.cue` states the rule as well, because that file is this entry's **specification** rather than a second enforcement point — the same status `#OverrideGate.proceed` (D6), `#IdentityState._asserted` (D12) and `cueModPath: declaredPath` (D16) already have. None of those run at publish time either; all of them are implemented in Go and stated in CUE so the rule is testable before the Go exists.

**The gap this closes, probed 2026-08-03 against the entry's own schema.** A catalog declaring `Version: "1.2.0"` published under tag `v1.3.0` yielded **`go: true`**. `#TagRef` compares the tag's major against the path's, and `#IdentityState` checks only that `Version` is concrete; nothing joined the two. The pushed bytes would interpolate `1.2.0` into every transformer FQN while the registry served them as `1.3.0` — the local-versus-published divergence D2, D5 and D6 exist to remove, reintroduced at the final step. Enhancement 0010 **D39** makes the result detectable at read rather than silent, which downgrades this from a silent-divergence defect to a publish-produces-unusable-artifacts defect; it does not close it.

**Implemented in the schema 2026-08-04 and measured.** `#IdentityState` gains `effective`; `#PublishPlan` gains `_versionAgrees`, asserted on its own rather than folded into `go` so that one cause produces one refusal naming the version rule — the asymmetry `experiments/02-publish-plan-gates` fixed when a renamed field produced two refusals for a single cause. The MUST-FAIL case fails with `_versionAgrees: conflicting values false and true`, and two positive cases pass: a concrete `1.3.0` under `v1.3.0`, and an open field filled by `--version 1.3.0` under the same tag. `_planOK` was given a concrete `declaredValue` so it exercises the rule rather than short-circuiting on an empty effective value.

**Alternatives considered:**

- **Leave it to the CLI and say nothing in the schema.** Rejected on what the schema is *for*. `#PublishPlan`'s own comment claims "a plan that does not unify is a push that does not happen", and that completeness claim was false while this rule was missing. An implementer building the command from the specification would have built a publisher that accepts the skew.
- **Fold it into `go`** alongside the identity and override gates. Rejected: `go` already carries two conditions, and a third would report a version mismatch as a generic plan failure. The named assertion produces a legible refusal.
- **Derive the tag from the declared version instead of comparing them**, so disagreement is unrepresentable. Attractive and rejected as too narrow: the tag is supplied by `cue mod publish` semantics and by release automation, and D3 keeps version authoring separate from publishing precisely so a value can be reviewed between the two. Deriving would also leave `cue mod publish` — which D10 and 0010 D11 both record as continuing to work — with no rule stated at all.
- **Warn rather than refuse.** Rejected for the reason D6 and D9 rejected it: a warning in a CI log is not a gate, and D10 makes the artifact it warns about permanent.

**Rationale:** In the author's words, this is validated by "`opm module publish`, `opm catalog publish` and optionally `opm module check`" — there is no need to validate it in CUE when the CLI can. That is right about enforcement and is not what the schema is doing. The schema is where this entry writes down what the command must implement, and it was permitting a plan the command must refuse.

The rule itself is the last unjoined pair in the plan. Every other coordinate publish resolves is already tied to the artifact: the path to `cue.mod`, the major to the path, the identity to concreteness. The version was tied to nothing.

**Source:** User decision 2026-08-04. Gap probed against `schemas/target.cue` 2026-08-03; constraint implemented and the MUST-FAIL case measured against `cue v0.17.1` 2026-08-04. Detectability at read from enhancement 0010 D9.

---

### D19: (merged into D15, 2026-08-04)

Publishing an already-published version is always a refusal; the sweep filters — content now in D15. Number retired.

---

### D20: `opm mod init` adopts and repairs an existing tree, behind a second confirmation

**Decision:** `opm module init` (already aliased `opm mod init`) stops being create-only. Run against a directory that already holds a module, it **detects what is missing or non-conformant, reports it, and offers to repair** — and because that writes into a tree someone else authored, it asks for confirmation a second time, separately from the invocation itself.

What it may repair:

- a missing or malformed `cue.mod/module.cue`, including a `module:` line that disagrees with the artifact's declared identity (D16)
- a missing `identity/identity.cue`, or one that does not satisfy `#IdentityPackage` (D21)
- missing `metadata` wiring — the `import id "<path>/identity"` and the `modulePath` / `version` derivation D12 specifies

**What it may never do is invent identity.** If the tree states no module path anywhere, `init` asks for one or takes it as an argument; it does not derive a name from the directory, and it does not choose a version. That is D2 and D3 applied one command earlier: publish refuses to invent a version, and a repair tool that invents one has simply moved the invention upstream of the gate.

This is what makes D16's refusal actionable rather than merely correct. Publish enforces that `cue.mod` and identity agree and refuses to write either; without a command that *can* write them, the author's only recourse is hand-editing two files and knowing which of three statements of the module path is authoritative.

**The second confirmation is the whole of the safety mechanism**, so it states what will change before asking: each file to be created or edited, and for an edit, the current value and the replacement. A repair that reports a summary and asks "proceed?" has not given the author anything to judge.

**Alternatives considered:**

- **Keep `init` create-only and add `opm module fix` / `opm module adopt`.** Genuinely viable, and rejected on discoverability: an author who runs `init` in an existing directory is already asking the question this answers, and directing them to a second command they have not heard of converts a fixable state into a documentation lookup. The behaviours are also the same behaviour — scaffold what is absent — differing only in how much is absent.
- **Repair silently, with no second confirmation.** Rejected: it writes to files the author did not name, and `init` is a command people run speculatively to see what happens.
- **Refuse on a non-empty directory**, as create-only tools usually do. Rejected as the status quo's failure mode: it is exactly the case where help is worth most.
- **Repair as part of `opm module vet`.** Rejected on separation: `vet` is a read-only check that D16 also uses, and a checker that edits is a checker nobody can run safely in CI.

**Rationale:** In the author's words, `init` "should attempt to fix it, and the command should detect and ask an extra time for approval". D12 already assigns `init` the job of templating the identity subpackage and the self-import so no author writes them by hand; this extends that job from new trees to existing ones, which is where the fleet actually is — twelve modules today with no identity package at all.

The invention boundary is what keeps this from undermining the gates it serves. `init` may write structure; only a human or a release process supplies identity.

**Source:** User decision 2026-08-04. Command surface read from `cli/internal/cmd/module/mod.go` (the `mod` alias already exists) and `init.go` (`Use: "init <module-name>"`, create-only) the same day. Extends D12's `init` responsibility; makes D16's refusal actionable.

---

### D21: Identity is validated by unifying against a shipped `#IdentityPackage`, and CUE produces the diagnostic

**Decision:** `identity/identity.cue` is validated by **unifying it against the official `#IdentityPackage` schema and surfacing CUE's own error**. OPM does not hand-roll an expected-versus-found comparison, does not check field names procedurally, and does not maintain a second statement of what a conformant identity package looks like.

**`#IdentityPackage` must therefore ship in `core`.** Today it exists only in enhancement 0010's `schemas/target.cue` — 0010 D40's own alternative records that it is "defined in this entry's `schemas/target.cue` and nowhere in shipped code". A schema that lives only in a design document cannot validate anything.

**The validation is external, and that is a constraint rather than an implementation detail.** `identity/identity.cue` deliberately imports nothing: `catalog_opm/src/identity/identity.cue` states that it "sits at the bottom of the catalog's import graph (it imports nothing within the module)" and mirrors `core.#VersionType` locally rather than importing `core`, precisely so it stays import-free and cannot create a cycle. Validation must not change that. The CLI loads the identity package and unifies it against `core`'s `#IdentityPackage` through the CUE API, in Go — the author's file gains no import, and the naive shape (`identity.cue` importing `core` and embedding `core.#IdentityPackage`) is **excluded**, because it would put the schema module at the bottom of every catalog's graph to buy a check that works fine from outside.

**This is already being leaned on.** 0010 **D43** deleted a duplicate `VersionMajor` assertion on the ground that "0011 D8 already requires publish to refuse an identity file that does not match `#IdentityPackage`. With the shape validated at publish, the second assertion is defence against a case the first already covers." That reasoning holds only if the validation is real. As of today it is not — D8 states the requirement and nothing implements it against a shipped schema — so this decision is what makes 0010 D43 safe rather than a check traded for a promise.

**Alternatives considered:**

- **A procedural check in Go** — walk the package, look for `ModulePath` and `Version`, report what is missing. This is what the drafted refusal message assumed, and it is rejected for the reason D8 rejected marker attributes: it is a second statement of the contract, and the two drift. It also produces a worse diagnostic than CUE does for the interesting cases, since a wrong *type* or a wrong *constraint* is not a missing field.
- **Ship `#IdentityPackage` in a catalog rather than in `core`.** Rejected: modules carry an identity package too under D12, and a module need not depend on any particular catalog. `core` is the only module everything already depends on.
- **Have `identity.cue` import and embed the schema itself**, so `cue vet` catches it with no tooling at all. Attractive — it would move the check to the author's own vet run — and rejected on the import-free invariant above. Recorded because it is the first thing a reader will propose, and because if that invariant is ever revisited this becomes the better design.
- **Validate only at publish.** Rejected as too late for a condition `opm module vet` can catch: D16 already puts the `cue.mod` agreement check in `vet` on the shift-left argument, and this belongs beside it.

**Rationale:** In the author's words — "validate the user's `identity.cue` with our official SCHEMA and utilize CUE as the backend, throwing errors on invalid file." The schema is the contract, CUE is the engine that checks contracts, and every line of Go that re-states the contract is a line that can disagree with it. D8 already framed the refusal as "this tree is not a conformant catalog" rather than "this field lacks an attribute"; this supplies the mechanism that makes that sentence true.

**Source:** User decision 2026-08-04. `#IdentityPackage`'s absence from shipped code recorded in enhancement 0010 D40's alternatives; the dependency in 0010 D43's rationale; the import-free invariant read from `catalog_opm/src/identity/identity.cue` the same day. Supplies the mechanism D8 requires.

---

### D22: A catalog member's declared path and FQN are validated by unifying against a shipped `#CatalogMemberFQNGate`

**Decision:** `#CatalogMemberFQNGate` ships in `core` beside `#IdentityPackage` (D21), and `opm catalog publish` unifies **every** member of the tree — resource, trait, blueprint and transformer — against it, surfacing CUE's own error. This is refusal 11.

The gate is the enforcement point four separate enhancement 0010 decisions delegate here, and none of them had an owner until now:

- **D17** — a primitive's `metadata.modulePath` must sit under the `modulePath` of the catalog that defines it. 0010 put the rule in a publish gate rather than in `core`, because `core` cannot express it where the primitives live without forbidding enhancement 0001 D16's cross-catalog references.
- **D21** — a primitive's `fqn` is authored rather than derived, so `core` can no longer refuse a wrong one. This decision is what 0010 traded that derivation away for.
- **D25** — a contract FQN must equal `kindPrefix[kind]/name@apiVersion`, a transformer's `…@catalogVersion`, and `catalogVersion` must equal `identity.Version`.
- **D42** — exactly one path segment per kind, no grouping subdirectory. The gate is what makes `kindPrefix` a rule rather than a description.

**A SECOND GATE JOINS THIS ONE (rider added 2026-08-07, following enhancement 0010 D46).** `#TraitOptionalGate` ships in `core` on the same terms and `opm catalog publish` runs it over every published `#Trait`, refusing a trait whose `optional` is never stated or is pinned to a concrete value. It is listed here rather than given its own refusal number because an implementer reads this decision for "what does publish unify against", and a gate absent from that list does not get run. Two mechanical properties differ from this gate's and an implementer must not carry them over: it takes the FIELD rather than the member — handing it a whole `#Trait` would drag that trait's `spec` into concreteness checking, and a spec is a schema that must never be concrete — and one of its two rules is only visible under `cue vet -c`, because an unstated posture is an *incomplete* value rather than a wrong one. It must also be unified into a non-hidden value: `cue vet -c` does not check hidden fields. Both measured 2026-08-07 against cue v0.17.1.

**The mechanism is D21's, not a second one.** The same argument applies unchanged: the schema is the contract, CUE is the engine that checks contracts, and a hand-rolled expected-versus-found comparison is a second statement that drifts from the first. Both shapes therefore ship in the same `core` release and both are checked the same way — the CLI loads the value and unifies, and what the author reads is CUE's error.

**Alternatives considered:**

- **A procedural check in Go** — recompute the expected path and FQN per member and compare strings. Rejected for D21's reason. It also produces a worse diagnostic on the interesting case: a blueprint one segment too deep fails on *both* `declaredModulePath` and `declaredFQN`, and 0010 D42 measured that CUE reports the second wrapped as `2 errors in empty disjunction` because `#FQNType` is a disjunction — information a string comparison discards.
- **Leave it unimplemented and rely on catalog-author discipline.** Rejected as the state this decision was filed to fix. 0010 D21 accepted a *measured* loss of enforcement — a catalog on `1.2.0` shipping `fqn: "…/secrets@1.1.0"` passes `cue vet -c` with exit 0 — explicitly on the promise that publish would catch it, and 0010 D4 makes a wrong key permanent: modules match against it forever.
- **Ship the gate in `cli` rather than in `core`.** Rejected on D21's placement argument, which transposes without change: a catalog need not depend on any particular catalog, `core` is the only module everything already depends on, and a gate living in one consumer's binary cannot be run by anyone else. It also splits one validation route into two.
- **Check only the primitives and skip transformers.** Rejected: 0010 D44 records that the gate's four-kind scope is correct and survives the primitive/adapter split — D17's rule binds a transformer's package path, and a transformer's build-keyed FQN is exactly what D21's stale-literal failure applies to. Only the shape's *name* changed (`#PrimitiveFQNGate` → `#CatalogMemberFQNGate`).

**Rationale:** 0010 states this rule four times and implements it nowhere. The gate exists as CUE in that entry's `schemas/target.cue` and, as 0010 D40's own alternative records of `#IdentityPackage`, "a schema that lives only in a design document cannot validate anything." This decision does for the member gate exactly what D21 does for the identity package, at the same moment and by the same mechanism, so the two ship as one piece of work rather than one shipping and the other being rediscovered later.

**Source:** User decision 2026-08-05, on an audit of enhancement 0010's decisions against both entries' slice plans. Gate shape read from `enhancements/0010/schemas/target.cue`'s `#CatalogMemberFQNGate` (`:466-503`); the delegating claims at 0010 D17, D21, D25, D42 and `0010/05-risks.md:41`. Extends D21's mechanism; supplies the gate 0010 D21 trades `core`'s FQN derivation for.

---

## Open Questions

- **OQ1: When `--version` fills an open identity field, does publish write the working tree or a copy?** Status: resolved-by-D12.

- **OQ2: What is the credential story for publishing?** Status: resolved-by-D11.

- **OQ3: What are the republish and tag-immutability semantics?** Status: resolved-by-D10.

- **OQ4: What decides that an artifact should be published at all, and at what version?** Status: resolved-by-D15.

- **OQ5: Does publish enforce the author's `cue.mod`, or generate it?** Status: resolved-by-D16.

- **OQ6: How does the published fleet move to the owner-scoped namespace?** Status: resolved-by-D17.

- **OQ7: Who owns a catalog name?** Status: resolved-by-D13.

- **OQ8: Does `--version` mean one thing?** Status: resolved-by-D12.

- **OQ9: What reserved segments do Platform and instance artifacts get?** Status: resolved-by-D14.
