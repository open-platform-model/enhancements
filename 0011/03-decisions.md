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

### D6: Publish never honours `cue.mod/local-module.cue`; modules may override explicitly, catalogs may not

**Decision:** Publish always resolves dependencies as published. `replaceWith` entries are **ignored** — never honoured, never baked into the artifact. When the tree being published carries any replacement, publish reports each one alongside the registry version that will be resolved in its place, and refuses.

For `opm module publish`, an explicit allow flag overrides the refusal. For `opm catalog publish` there is **no override**: presence of the file is an unconditional refusal, and the check is on presence rather than on whether the replacements currently resolve.

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

**Decision:** Publish gains a **compatibility gate**. For every primitive in the tree being published, it pulls the last published build that shipped a primitive of that `name` at that `apiVersion`, and refuses if the new definition is not backwards-compatible with it under enhancement 0010 D27's rule: fields and options may be added, never removed; a newly added field must be optional or defaulted; and an existing field's default may not change.

**The gate is level-aware (rider added 2026-07-31, following enhancement 0010 D34).** D34 keys D27's promise to the API version's level, so the rule this decision defers to no longer reaches alpha: the gate reads each primitive's `apiVersion`, and runs the pull-and-compare **only at beta and GA**. An `alpha` contract may remove a field, narrow a type or change a default without refusal, because that is what its level promises. This is inherited rather than an amendment — this decision names D27 rather than restating it, so narrowing D27 narrows the gate automatically — but it is recorded because the sentence above says *every primitive in the tree*, and an implementer working from that sentence would gate all of them. Two properties are unchanged by the rider: the `apiVersion` bump remains the escape hatch, since the lookup is keyed on `name` + `apiVersion` and a bumped contract finds no predecessor and passes trivially; and the match-side rung does **not** skip alpha, so a module using a field a later alpha build removed still fails loudly. What alpha gives up is exactly one class — the default drift `0010/experiments/02` measured, which no consumer-side check catches — and under D34's day-one assignment that is confined to `catalog_opm_experimental`.

A primitive at an `apiVersion` that has never been published has nothing to compare against and passes. Removing a field, narrowing a type, or changing a default is not blocked — it is redirected: the author bumps `apiVersion`, and both versions may ship in the same build.

**Rationale:** 0010 D24 makes a contract key stable across catalog releases, which is what lets a module and a provider catalog meet without being compiled against the same build. That only works while the definition behind the key stays compatible, and 0010 D27 states the rule. This is the end that can enforce it *before* the damage is distributable: `experiments/02-primitive-closedness-skew` in 0010 measured that the match rung catches a removed field and a narrowed type, but **not** a changed default — two builds disagreeing on a default unify to a non-concrete value, so the match passes and the render fails later on an incomplete value naming a field rather than a build. The one violation the consumer side cannot catch is the one that silently moves output, so a publish-side gate is not redundant with it.

Sequencing follows the same split as D17 in 0010 and the `#PrimitiveFQNGate`: 0010 defines the rule, this entry implements the command that enforces it. The machinery already exists here — D7's `opm catalog registry check` pulls and decodes a published catalog, which is the same operation this gate needs.

**Two properties worth stating, because they bound what the gate is worth.**

Subsumption is **transitive**, so comparing against the immediate predecessor secures the whole published history by induction — the gate never needs more than one prior build. But that induction holds only while every build passes through it, and 0010 D11 records that `cue mod publish` keeps working and is what every artifact published to date used. A catalog published outside `opm catalog publish` breaks the chain with nothing reporting it. Whether that gap gets a read-side counterpart is 0010 OQ13; this decision does not assume one.

**Alternatives considered:**

- **Leave it to the publisher.** Rejected on 0010 D13's own argument against D4 — a promise nothing checks is a convention, and 0010 D17 already records that a third-party catalog author has no reason to copy a convention nothing checks. It is also the argument this entry's D4 already made about incomplete identity: a producer's mistake should not be discovered by every consumer.
- **Enforce only at match time.** Rejected on the default-drift measurement above.
- **Refuse any change to a published primitive, compatible or not.** Rejected: additive evolution is the normal case, and forbidding it would make every new field an `apiVersion` bump — the cost 0010 rejected D4 for.
- **Warn rather than refuse.** Rejected for the reason D6 rejected it for local overrides: a warning in a CI log is not a gate, and the artifact it warns about is immutable once pushed.

**What is not yet established, and it is the reason this decision names no implementation.** Whether `cue.Value.Subsume` can express the rule reliably across two builds — with CUE's closedness and default handling in play — is unmeasured. It is the natural primitive and the fixtures already exist: 0010's `experiments/02-primitive-closedness-skew` carries four builds of one primitive that a correct gate must classify as pass (additive), refuse (narrowed), and refuse (default flipped). Sequencing that measurement before the command is specified is a graduation gate, not a nicety — a gate that cannot be built as described would send 0010 D27 back to publisher discipline.

**Source:** User decision 2026-07-29. Rule defined in enhancement 0010 D27; match-side limits measured in `enhancements/0010/experiments/02-primitive-closedness-skew/` (2026-07-29, cue v0.17.1).

---

## Open Questions

- **OQ1: When `--version` fills an open identity field, does publish write the working tree or a copy?** Status: open. D3 lets `--version` supply a value for a field the author left open, and D2 requires published bytes to equal committed bytes — which pull in opposite directions for exactly this case. **(a) Write the working tree**, as `npm version` does: the developer sees the diff, the value is traceable to a commit if they make one, and the tree is dirty afterwards. **(b) Write a copy and push that**: the tree stays clean, but the published artifact carries a version that exists in no commit, which is the property D3's commit seam exists to guarantee. **(c) Refuse, and require `version set` first**: the strictest reading of D2, at the cost of leaving ephemeral CI checkouts — where the tree is discarded either way — with two commands instead of one. Resolving this fixes what `--version` actually does and whether a catalog release pipeline needs a commit step. A neighbouring mechanical question rides along: whether the in-place edit is a surgical AST rewrite that preserves formatting and comments, or a reformatting round-trip that does not.

- **OQ2: What is the credential story for publishing?** Status: open. D5 makes the central registry the write target, so publish must authenticate to it, and the CLI has **no credential surface at all** today — no `opm login`, no credential-helper handling, no token storage. It inherits whatever the CUE SDK's resolver finds in the ambient environment. The minimum viable answer may be "inherit `cue login` and document it", which is still an answer this entry has to give rather than assume. Also unresolved: whether CI publishes with a short-lived token, how an owner scope under D5 binds to a credential, and what the failure looks like when a publisher is authenticated but not authorised for the owner segment they are pushing to. Signing and attestation stay out of scope regardless of how this resolves.

- **OQ3: What are the republish and tag-immutability semantics?** Status: open. A pinned version is only meaningful if a tag names one immutable artifact. If a tag can be overwritten under a consumer who already resolved it, every downstream digest comparison silently checks a moving target, and the mutable tag is a time-of-check-to-time-of-use vector in its own right. The ecosystems split cleanly: package registries treat release immutability as fundamental (Maven Central rejects redeployment of a release outright) while OCI registries treat it as **opt-in configuration** (ECR repositories are mutable by default and must be explicitly set immutable; Harbor implements project-level rules covering re-push, re-tag, delete, and replication). CUE modules live in OCI registries, so OPM inherits the weaker default — a gap to close deliberately rather than a property to assume. The remedy is two-sided and well-precedented: a registry-side immutability requirement OPM must *state* as a deployment constraint, plus client-side refusal to overwrite an existing tag at publish. The yank question is genuinely open and the ecosystems disagree on it (Maven: immutable forever, no deletion; npm and crates: restricted unpublish windows), with the constraint that deleting an artifact breaks reproducibility for anyone who already resolved it.

- **OQ4: What decides that an artifact should be published at all, and at what version?** Status: open. Retiring the modules repo's checksum-driven bump removes the fleet's answer to "should this publish?" without supplying a replacement. The current mechanism cannot survive on its own terms: a content checksum answers "did these bytes change", not "is this a patch, a minor, or a major", and it becomes self-referential the moment a version lives in the files being hashed. Candidates: **(a)** conventional commits drive the decision and release automation calls `version set` / `--version`, so automation contributes the decision but not the write; **(b)** the authored version is the sole trigger, and a version equal to the highest published tag means "nothing to do" — safe only if republishing a tag is refused anyway, so this depends on OQ3; **(c)** keep a checksum purely as an advisory "you changed this and forgot to bump" warning rather than as the trigger. Note release-please can rewrite a version in arbitrary files through an `x-release-please-version` comment annotation, so it *could* write `identity.cue` directly — but that makes it a second writer alongside D3's, which is the shape of drift this design removes; (a) keeps D3 intact. This also has a concrete instance to satisfy: each catalog repo's `branch-publish.yml` publishes a `-dev` pre-release for non-main branches, which needs both a version and a sort order that places it above the releases it descends from.

**Candidate (b) is catalog-only by construction, and that asymmetry is the substance of this question rather than a detail of it.** Under enhancement 0010 D2 a module declares no version anywhere in source, so there is no authored version available to be the trigger — (b) can answer only for catalogs. The module case is also the one that loses the most: retiring `publish:smart` removes its only existing answer, and D3's review seam (`version set` → diff → commit → `publish`) is structurally unavailable to it, because `--version` supplies the tag directly and writes nothing. So a module's version is decided wholly outside the artifact, by (a) or by (c), while a catalog may use any of the three. A single mechanism covering both should not be assumed to exist. This is the same asymmetry `04-graduation.md`'s command-surface gate reaches from the other direction when it asks whether `opm module version set` exists at all: it does not, because there is nothing for it to write, and what is unresolved is what replaces it.

- **OQ5: Does publish enforce the author's `cue.mod`, or generate it?** Status: open. Two modes. **(a) Enforce** — read the author's `cue.mod/module.cue` `module:` line and the package clause and refuse the push if either disagrees with the artifact's declared identity. **(b) Generate** — synthesise a conformant `cue.mod` from identity so the author never writes it. Enforce keeps authored source authoritative and is the less magical of the two; generate is more ergonomic but hides the one line CUE itself uses to name the module, and it sits awkwardly with D2. A `--check`-only mode could support both. Resolving this fixes the command's contract with the author, and it interacts with OQ1 — if publish may write `cue.mod`, the working-tree-versus-copy question applies to that file too.

- **OQ6: How does the published fleet move to the owner-scoped namespace?** Status: open. D5 rewrites the registry path of every artifact already published — and a path change is not a redirect here, because the declared path is also the artifact's identity, which feeds its UUID and thence the owner label on every deployed resource. So this is a new identity for every module and every live instance of one. Unresolved: whether old paths are republished as aliases during a transition window or hard-cut; whether deployed instances are adopted in place or recreated; and what happens to the artifacts sharing the namespace without being modules at all — the workspace registry currently carries a test fixture at `opmodel.dev/library/testdata/modules/web-app` and a set of legacy `opmodel.dev/<name>/v1alpha1` paths. The migration is cheapest now and compounds with every publish, so this is the sequencing constraint on D5 rather than a detail of it. **It must land in the same window as enhancement 0010's identity migration**, or every artifact's identity moves twice.

- **OQ7: Who owns a catalog name?** Status: open. Surfaced 2026-07-29 by a provider-fulfilled contract scenario, which introduces the actor D5's owner-scoping exists for. D5 gives *modules* an owner segment (`opmodel.dev/m/<owner>/<name>`) on the ground that a flat global namespace has no owner and the first publisher of a common name holds it permanently — and then puts catalogs in exactly such a namespace (`opmodel.dev/catalogs/<name>`). The argument applies to catalogs with more force, not less: a catalog's name is the permanent prefix of every FQN every module matches on, so a land grab there is durable in a way a module name is not, and enhancement 0010 D24 makes contract keys outlive any single build. The concrete case is a third party publishing a `k8up` provider catalog: today they either persuade OPM to host `opmodel.dev/catalogs/k8up` — which reads as an endorsement and makes OPM the arbiter D5 wanted to avoid — or they publish under their own domain and are unresolvable for anyone who has not edited `CUE_REGISTRY`, which D5's own rationale rules out. Candidates: **(a)** owner-scope catalogs symmetrically (`opmodel.dev/c/<owner>/<name>`), which costs a rename of all three first-party catalogs now and nothing later; **(b)** keep the flat namespace as a curated space and add an owner-scoped one beside it for third parties, which makes "first-party" a namespace property rather than a policy; **(c)** keep it flat and arbitrate by hand, accepting that OPM is the registrar. Resolving this fixes whether a provider catalog has a home, and it is cheapest before the fleet moves under OQ6.

- **OQ8: Does `--version` mean one thing?** Status: open. Filed 2026-07-30. D3 gives the flag two jobs and states the split without weighing it. Against a **catalog** it is a writer with an assertion attached: it fills an open `identity.cue` `Version` or asserts a concrete one and refuses on mismatch. Against a **module** it names the OCI tag, and under enhancement 0010 D2 there is nothing in source for it to agree or disagree with — so the refusal path the catalog form carries has no module analogue, and neither does the value it would write. One flag, two semantics, two failure modes, on a command whose whole premise (D1) is one pipeline serving both artifact types. Candidates: **(a)** keep one flag and document the split — cheapest, and defensible on the ground that both forms answer "what version is this artifact"; **(b)** take the version positionally for both, as `cue mod publish v1.2.0` does, which makes the value read as a coordinate everywhere and demotes the catalog-side *write* to the thing that needs an explicit flag; **(c)** split the names — `--version` for the catalog write/assert, `--tag` for the module coordinate — which makes the failure modes visibly different at the cost of an artifact-type-specific surface on a deliberately shared command. Interacts with OQ1, which decides what the catalog-side write touches, and with OQ4, which decides whether anything supplies the module value automatically. It resolves under `04-graduation.md`'s existing command-surface gate rather than adding one.

- **OQ9: What reserved segments do Platform and instance artifacts get?** Status: open. Filed 2026-07-31. D5 partitions the namespace into three classes — `m` for modules, `catalogs`, `core` for schema — and the registry demonstrably holds more. Two cases are measured rather than hypothetical. `opmodel.dev/modules/opm-platform` was a `#Platform` published at a **module** path, with tags `v1.0.0` and `v1.0.1`, while `library/modules/opm_platform/platform.cue`'s own header declares it an unpublished on-disk fixture — so the artifact contradicted its source, and nothing structural could have caught it, because module space is exactly where D5 says a module lives. And `opmodel.dev/releases/*` holds four repositories of `ModuleRelease`/`ModuleInstance` artifacts (`kind_opm_dev`, `test/hello`, `test/podinfo`, `web_app`) under a segment D5 never reserved, which under enhancement 0002 are `Instance` vocabulary. **Test fixtures are settled and are the useful precedent:** they get a separate *domain*, `testing.opmodel.dev`, already mapped in every registry configuration in the workspace and now carrying the library's `web_app` fixture — which suggests the answer here may also be a domain rather than a segment. Candidates: **(a)** reserve segments symmetrically — `opmodel.dev/p/<owner>/<name>` for platforms and `opmodel.dev/i/...` for instances — keeping one domain and one rule; **(b)** a separate domain per class, extending the `testing.opmodel.dev` precedent, which costs a `CUE_REGISTRY` mapping per class and makes the class visible in the address before any path parsing; **(c)** decide that platforms and instances are **not published artifacts at all** and that both measured cases are defects, which is the cheapest answer if it holds — the `opm_platform` header already asserts it for platforms, and it would need checking against whether an instance is ever legitimately consumed from a registry. Resolving this fixes whether D5's partition is complete or merely started, and it should be settled before the owner-scoped migration runs, since that migration is what rewrites every path.
