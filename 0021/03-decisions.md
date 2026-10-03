# Design Decisions: OPM Versioning Policy

This document records every design choice, with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent**: never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** While the entry is `draft`, a changed choice is an in-place edit to the existing `DN`, with an evidence-backed old position folded into *Alternatives considered*. Once `accepted`, bodies are protected and a change lands as a new `DN` with `**Amends:**` / `**Supersedes:**` relation fields, edited only through the `enhancement-compaction` skill.

Each decision carries a `**Kind:**` line (`contract`, `policy` or `scope`) and passes the admission test: *if every affected repo were rewritten from scratch, would this decision still bind the result?* Mechanism decisions belong in the implementing OpenSpec change in the target repo.

---

## Decisions

### D1: One versioning policy names every published artifact class

**Kind:** scope

**Decision:** OPM has one versioning policy, and it covers every class of artifact a consumer can pin: the core schema, catalog builds, catalog contracts, modules, the kernel library, the CLI, the operator and its CRDs. Each class answers the same five questions (carrier, compatibility surface, bump rules, pre-stable semantics, enforcement layer), and a class with an unanswered question is an open question in this entry, not a class the policy is silent on. The policy is published where a third-party author can read it without access to the workspace.

**Requirements:** none (fixes the entry's coverage; the class list is D4 and each class's rule is its own decision or copied source)

**Alternatives considered:**

- **A module-only entry.** The originating question was about modules, and a module-only entry would have been smaller. Rejected by the author: the module rule is the fourth versioning rule OPM would have written in four places, and the gaps in 01-problem.md (cross-class relations, uneven enforcement) are between classes, which a per-class entry cannot see.
- **Per-repo policy sections in each `CLAUDE.md`, no central document.** This is the current state. Rejected on Gap 2: it reaches workspace contributors only, and it lets the classes disagree without anyone noticing.
- **One policy for CUE artifacts and none for the Go binaries.** Rejected: the CLI and the operator are what consumers actually install, and "a version means nothing in particular here" is itself a policy that should be stated rather than implied.

**Rationale:** In the author's words, the aim is "to finalize and codify all the OPM versioning policies". A policy that omits a class leaves that class where it is today, on convention with no stated surface; naming it, even to say its enforcement is convention, is what makes the unevenness visible and decidable.

**Source:** User decision 2026-08-24.

### D2: A module's compatibility surface is its `#config` schema

**Kind:** contract

**Decision:** A module's version is bound to its `#config` schema, and compatibility between two releases is subsumption over the values that schema accepts. A release that stops accepting values the previous release accepted is **breaking** and requires a new major. A release that accepts a strict superset (an optional field, a field with a default, a loosened constraint) is **additive** and requires at least a minor. A release whose accepted value set is unchanged is a **fix** and requires at least a patch. A release's bump is the maximum change class across the schema (U2). Adding a required field is breaking because the previous release accepted values without it.

Whether the rendered output's stateful identity forms a second surface is OQ1; whether a default change is additive or breaking is OQ3; the pre-stable form is OQ4. This decision fixes the first surface and its classification; those questions complete it and do not reopen it.

**Requirements:**

- R1: A module release whose `#config` stops accepting a value the previous release accepted is breaking and carries a new major.
- R2: A module release whose `#config` accepts a strict superset of the previous release's values (an optional field, a defaulted field, a loosened constraint) carries at least a minor.
- R3: A module release whose `#config` accepts exactly the values the previous release accepted carries at least a patch.
- R4: A release's bump is the maximum change class across the whole `#config` schema.
- R5: Adding a required field to `#config` is breaking.

**Alternatives considered:**

- **The whole rendered output as the surface.** Every resource a module renders, compared structurally. Rejected as the *sole* surface: output changes with every catalog version and every transformer, so a module that changed nothing would read as breaking whenever its platform moved, and it makes the module's version depend on artifacts the module does not own. Its stateful subset is what OQ1 weighs as a second surface.
- **The component set as the surface.** Adding or removing components as the bump signal. Rejected: components are the module's internals; an instance depends on what it can pass in and on what stays running, not on how the module is decomposed.
- **No defined surface; conventional commits as the rule.** The current state. Rejected on 0010 D27's argument, which the author accepted for catalogs: a promise nothing can check is a convention, and a third-party author has no reason to follow it.

**Rationale:** `#config` is the one input contract a module has: an instance is values unified against it, and nothing else an instance authors reaches the module. The schema comment already requires it to be OpenAPIv3-shaped, which means it has no `for` or `if` and is mechanically comparable, so the rule can be verified rather than trusted. Subsumption is the natural CUE reading of "accepts everything the old one accepted", and it classifies every case in the design table without a special case except the default, which is why OQ3 is separate.

**Measured 2026-08-24:** `core/src/module.cue` declares `#config: _` with the comment "MUST be OpenAPIv3 compliant (no CUE templating - for/if statements)", and `#ModuleInstance` unifies `values` into it as `#module & {#config: values}` (`core/src/module_instance.cue`), so the instance's only authored input reaches the module through this one field. The CLI's publish report documents its compatibility fields as "Zero-valued for modules" (`cli/internal/publish/publish.go`), so no comparison of that field exists today.

**Source:** User decision 2026-08-24 ("any breaking changes to the #config schema requires a new MAJOR. Any new fields mean MINOR and any fixes are PATCH").

### D3: Settled rulings are copied verbatim into the policy, each under its source

**Kind:** policy

**Depends:** 0010:D4, 0010:D27, 0010:D34, 0010:D35, 0010:D41, 0010:D44, 0010:D45, 0010:D48, 0011:D9, 0011:D15, 0011:D18, 0011:D23

**Decision:** Where an accepted enhancement or a repo document has already decided a versioning rule, the policy text ([`policy/`](policy/), one file per class plus an index carrying the universal rules) carries that rule **verbatim**, unedited, under a line naming its source. The copy is what a reader follows and what the published policy page ships; the source is where the reasoning, alternatives and measurements stay, and a reader who wants them follows the citation. Copied today: 0010 D4, D27, D34, D35, D41, D44, D45, D48; 0011 D9, D15, D18, D23; the commit-type tables and repository rules of `core` and `catalog_opm`; the `modules` major separation rule; the core `schema-release` spec; and the tag-format, leading-zero and consumer-resolution sections of `core/docs/publishing.md`. Enhancement 0020 is cited, not copied, until it is accepted, because a draft body may still move. A copied block is refreshed only when its source changes through that source's own process (a new amending decision, a compaction, a repo-document edit); it is never edited in place here.

**Requirements:** none (documentation posture; every copied rule keeps its original decision ID)

**Alternatives considered:**

- **Inherit by reference and paraphrase for the reader.** Previously adopted here (2026-08-24), on the argument that a copy drifts and a reader with two texts does not know which binds. Reversed by the author: a policy a third-party author reads must be complete on its own page, and a page that is a list of citations into a design repo is not a policy. Drift is answered by the refresh rule above and by the source line on every block, not by refusing to copy.
- **Supersede 0010's and 0011's versioning decisions into this entry.** Rejected: those decisions are delivered, their entries are closed to body edits, and supersession would move numbers other repos cite from commit messages for no gain.

**Rationale:** In the author's words, "even those that we have already defined, in these cases we just copy verbatim". The policy's value to its reader is that it is one document; the value of the source entries is that they hold the argument. Verbatim copying with a source line gives both without editing either.

**Source:** User decision 2026-08-25. **Revised:** 2026-08-25, reversing the by-reference position adopted 2026-08-24.

### D4: The classes the policy covers

**Kind:** scope

**Decision:** The policy covers nine classes: the core schema; the catalog build; the catalog contract; the transformer; the module; the CLI template; the tooling train of kernel library, CLI and operator; the CRDs; and the documentation site. Each has its own file under `policy/` and a row in `contracts/policy.cue`. Out of scope, by the author's selection from the workspace sweep of 2026-08-24: the test fixture fleets under `testing.opmodel.dev` (three publish mechanisms, no consumer outside CI); the CLI's importable Go packages (no stated consumer); the operator install manifest as a class of its own (it is an artifact of the operator release); and platforms (consumers, not artifacts, until something publishes one; OQ11).

The sweep also surfaced cross-actor wire contracts: the operator version-skew ceiling, the CRD constants the CLI mirrors, the inventory digest, the label vocabulary, and the catalog-version coupling between platform and modules. These are compatibility contracts without a version of their own. They are named under the CRD class as its shared surface and gated by parity, not by a bump rule.

**Requirements:** none (names the nine classes in and the four artifact kinds out)

**Alternatives considered:**

- **Every class the sweep found.** Fourteen artifact classes plus eight wire contracts. Rejected by the author as scope: the fixtures and the CLI's Go packages have no consumer a promise could reach, and the install manifest is the operator release seen from the CLI's side.
- **Drop the catalog build as a class, since the contract class carries the promise.** Considered and kept. A `#Platform` subscription pins a build as a scalar and never a contract, and every transformer key embeds the build version, so the build is the unit a platform actually depends on. The contract class says what a member promises; the build class says which members and transformers ship together. What the build class lacks is the rule for how a contract-level event moves its number, which is OQ7.

**Rationale:** The sweep is the evidence; the selection is the author's. Naming what is out and why keeps the omissions deliberate rather than silent, which is D1's own requirement.

**Source:** User decision 2026-08-25, selecting from the 2026-08-24 workspace sweep.

### D5: An alpha contract is encouraged, not required, to bump its alpha number on a break

**Kind:** policy

**Depends:** 0010:D34

**Decision:** A contract at an alpha `apiVersion` (`vNalphaM`) still promises nothing and its publish gate stays off (0010 D34, unchanged). On top of that, the policy **encourages** an author who breaks an alpha contract, by adding a required field, removing or renaming a field, narrowing a type or changing a default, to bump the alpha number (`v1alpha1` → `v1alpha2`) rather than reshape the same key in place. The bump is a courtesy signal to whoever is already consuming the alpha: the key they matched on no longer means what it did. It reaches the convention layer only: no gate refuses an in-place alpha break, no check command reports one, and a catalog that reshapes an alpha in place has violated nothing. The published policy states it as "should", and the catalog repositories carry it as an authoring convention.

**Requirements:** none (should-only guidance at the convention layer; the alpha gate stays off under 0010:D34)

**Alternatives considered:**

- **Gate alpha breaks like beta and GA.** Rejected by 0010 D34 and not reopened: enforcing additivity on the level whose definition is "no promise" empties the label.
- **Say nothing at alpha.** The current state. Rejected by the author: an alpha consumer who is told nothing learns about a break from a `field not allowed` at render; an alpha number that moved tells them at the import line, for the cost of one directory under 0010 D49's filing.
- **Require the bump but exempt it from the gate.** Rejected: a rule that is required and unenforced is the kind of convention 0010 D27 rejected, and "required" would contradict D34's text. "Encouraged" is the honest strength.

**Rationale:** In the author's words, alpha versions "say nothing guaranteed but I still think we should try and encourage bumping the alpha number when adding new required fields for example". The ladder already has the rung (0020 D5 permits and discourages skipping rungs, so `v1alpha2` is a normal address), the filing already has the directory, and the cost to the author is a rename. The benefit lands on exactly the consumer alpha is for: someone trying the contract early who deserves to see it move.

**Source:** User decision 2026-08-25.

### D6: A transformer serves a contract level by naming it: one registration per level, one shared body

**Kind:** contract

**Depends:** 0010:D34, 0010:D44, 0020:D4

**Decision:** A transformer binds to exact contract keys, and a contract key embeds its `apiVersion`. So a transformer that serves more than one level of a resource or trait declares **one transformer per level**, each naming that level's key in its required or optional maps, with all of them sharing one transform body. Nothing in the match path changes: each registration matches exactly the components that demand its key, and the exact-key rule of 0010 D34 stands. Under promotion by aliasing (0020 D4) the levels are one definition, so the shared body serves both without change.

**Backup rule, for a breaking level:** when two served levels differ in shape, the shared body reads a canonical shape and each per-level registration supplies the projection from its level into it. The projection is a struct, authored beside the registration, and a level with no projection is a level the transformer does not serve. The catalog states which levels each transformer serves; how it states it (index, label, vet check) is the catalog's own decision.

**Requirements:**

- R1: A transformer that serves more than one level of a resource or trait is declared once per level, each registration naming that level's exact contract key in its required or optional maps.
- R2: When two served levels differ in shape, each per-level registration carries its own projection into the shared canonical shape, and a level with no projection is a level the transformer does not serve.
- R3: A catalog states which levels each of its transformers serves, where a consumer can read it.

**Alternatives considered:**

- **An any-of form in `requiredResources` / `requiredTraits`** so one transformer declares `container@v1beta1 | container@v1`. Rejected: it is a core schema change plus a second matching semantics in the kernel, and 0010 D34 deliberately kept the match path exact-key with no comparator. It saves one registration per level and pays with an ambiguity the identity reshape exists to remove.
- **A matcher-side fallback from a missing level to a served one.** Rejected by 0020 D4 already (a lookup miss becomes ambiguous between absent and present-under-another-name) and not reopened.
- **Serve the newest level only and let consumers migrate.** Rejected: it makes every level bump a flag day for every module demanding the old key, which is what 0020 D4's dual-shipping exists to avoid on the contract side; the transformer side must keep pace or the dual-ship is empty.

**Rationale:** This is the only option that needs no schema and no kernel change: the catalog already hoists shared bodies into helpers, 0010 D49 already files levels in their own directories, and the transformer's build-keyed FQN (0010 D44) means registering one more transformer costs nothing in the key space. The normalizer is kept as a backup rather than the rule because under aliasing the common case has identical shapes, and a projection that exists for no reason is a second place for the shape to drift.

**Source:** User decision 2026-08-25, choosing between three options laid out the same day; the match rule is `core/src/transformer.cue` (AND over exact keys), the body-sharing precedent is `catalog_opm/src/transformers/*_helpers.cue`.

### D7: A `-beta.N` release line is pre-stable on the path to GA, and breaks only as a declared, migrated change

**Kind:** contract

**Decision:** A `-beta.N` release line is a pre-stable form under U3 with a stronger promise than alpha's. From its first beta, a prerelease line is on the path to GA. The prerelease lines are `opmodel.dev/core@v2`, the kernel library, the CLI and the operator. A breaking change is still allowed during beta, but only as a declared breaking change whose migration note the changelog shows. It advances the `-beta.N` counter and never moves the module path to a new major. Stable lines keep the stable table: `opmodel.dev/catalogs/opm@v4` and the module fleets cut a new major for a break, whatever line their dependencies are on. A core beta break that would force a major on a stable catalog line needs owner sign-off before it ships. GA drops the suffix per package, in dependency order, once D8 holds.

A beta release line is not a beta contract rung. The line is the build's prerelease label; the rung is a contract's `apiVersion` level, whose additive-only promise the catalog contract class carries (0010 D34). The two axes are independent: moving a line to beta changes no contract's level or promise, and a `v1beta1` contract may ship in a build on any line.

For the core schema this narrows the pre-stable rule copied under class 1: on a beta line, the major-crossing path that an unabsorbable break must take on an alpha line is closed, and every break advances the counter. The copied block is refreshed after its source changes (D3).

**Requirements:**

- R1: Every release on a beta line carries a `-beta.N` prerelease on the version it will reach at GA, and `N` rises by one with each release of that line.
- R2: A breaking change released on a beta line is marked breaking in that release's changelog, with a migration note a consumer can follow.
- R3: A breaking change released on a beta line keeps the line's module path and major; no beta release moves a consumer's import to a new major.
- R4: A breaking change on a stable line, including one caused by a dependency's beta break, releases as a new major of that stable line.
- R5: No core beta release forces a new major on a stable catalog line unless the owner has signed off on that catalog major before the core release ships.
- R6: Moving a release line to beta changes no catalog contract's `apiVersion` level and no promise a contract level makes.
- R7: The first GA release of a beta line is the same `MAJOR.MINOR.PATCH` with no prerelease suffix, and from it on the stable table binds the line.

**Alternatives considered:**

- **Beta keeps U3's alpha promise: promise off, label honest.** Breaks advance `-beta.N` with nothing more said. Rejected: it makes the label change carry no meaning a consumer can act on, which is the problem U3 exists to prevent.
- **Additive-only from the first beta.** Rejected by the owner: enhancement 0013 is an accepted breaking change to core, the kernel and the modules, and it lands during beta. An additive-only promise would either hold the beta cut until 0013 lands or be broken by it.
- **A break during beta may cross a module major, as the core alpha rule requires for an unabsorbable break.** Rejected: a beta line exists to reach GA on its current major, and a major crossing during beta resets that path. On a beta line an unabsorbable break lands like any other, as a declared break with a migration note that advances the counter; crossing a major waits for GA.

**Rationale:** Consumers move onto the beta lines to build against what GA will be. They can absorb a break they are told about, but not a silent one or a path change, so the promise is the migration note and the fixed path. Scoping it to the prerelease lines keeps the stable lines on the rule they already follow. The sign-off clause exists because a core break reaching catalog contracts would otherwise cut a stable catalog major as a side effect.

**Source:** User decision 2026-09-30 (beta promise and the beta-period timing of 0013).

### D8: A beta line reaches GA only when its exit criteria hold

**Kind:** contract

**Depends:** 0011:D9

**Decision:** A beta line drops its suffix only when every requirement below holds for it. The requirements are the GA exit criteria: what a consumer can observe once GA is cut. Enhancement 0013 lands during beta as an announced break, and its delivery is a GA criterion rather than a beta entry criterion.

**Requirements:**

- R1: Enhancement 0013 is delivered before any line it breaks reaches GA.
- R2: Before GA, the policy names each draft entry whose delivery would break a GA line, and each named entry either lands before GA or waits for that line's next major.
- R3: Before the operator reaches GA, the CRD API version it serves is decided: a move from `v1alpha1` to `v1beta1` or `v1` is served with conversion, and every first-party artifact that names the CRD version (platform pins, the installer, the CLI's mirrored CRD types) names the served one.
- R4: From GA on, the kernel library records a migration note for every breaking change of its exported API, and its published API-stability statement describes the GA promise.
- R5: Removed (catalog retired 2026-10-02). The number stays so citations resolve.
- R6: After GA, the GitHub "latest" release of the core, kernel library, CLI and operator repositories, the operator image's `latest` tag, and Go's latest-version query for the kernel library and the CLI each resolve the GA release; no `0.x` release or prerelease is advertised as latest.
- R7: After a line reaches GA, no first-party pin written from then on names a prerelease of that line.
- R8: The CLI's module templates and the quickstart are republished against the GA versions, and the documentation site drops its beta label.
- R9: GA releases are cut in dependency order: core; then the kernel library; then the operator; then the CLI, embedding the GA operator. No GA release pins a prerelease dependency; a CI tool pin is not a dependency.
- R10: Before a line of a repository that D10 covers reaches GA, that repository can cut a release branch as D10 R10 requires: the cut action, release workflows that run on `release/**` and pull-request checks on `release/**` are in place there and proven in the sandbox repository.
- R11: Before the kernel library reaches GA, no value its render operation returns to a caller is a live CUE value; rendered output reaches the caller as plain data. The acquired instance, platform and module packages and the configuration schema may still expose CUE values, under the library's rule that their holder bounds their lifetime (library ADR-007).
- R12: Before the kernel library reaches GA, a caller can tell each fetch or resolution failure it returns by type, without matching on message text: whether the failure is transient, and which kind of fetch or resolution failed.
- R13: Before the kernel library reaches GA, its main specs pass strict validation, and every exported identifier and behaviour its README, ADRs and specs name exists as described.
- R14: The kernel library reaches GA only after three consecutive beta releases of its line, none of which carries a breaking change.

**Alternatives considered:**

- **Hold the beta cut until 0013 lands.** Rejected by the owner in favour of an announced beta-period break under D7, with delivery moved to the GA criteria (R1).
- **An exit checklist tracked as progress in this entry.** Rejected: an entry stores rules, not progress. The criteria are requirements, and whether they hold is read from the artifacts.

**Rationale:** GA is the point where the stable table starts to bind, so it is cut only once the known breaks are delivered and the artifacts a consumer resolves by default point at it. Each requirement names something a consumer can check from outside the repos. R11 to R14 are the kernel library's API-quality bar: GA freezes its exported API, so what an embedder holds, how it tells failures apart and whether the documents describe the code must be settled before the freeze, and three quiet betas are the evidence that the API has stopped moving. R9 exists because a GA release that pins a prerelease dependency carries the dependency's beta promise, not the stable one. R10 exists because after GA a released minor is fixed only on its release branch (D10): a GA line that cannot cut one has no patch path once `main` moves past it. The operator goes GA before the CLI because the CLI embeds a pinned operator and the operator depends on no CLI; under D9's `MAJOR.MINOR` ceiling a GA operator is not refused by a beta CLI of the same `MAJOR.MINOR`.

**Source:** User decision 2026-09-30 (GA exit criteria). Owner decision 2026-10-03 (R11 to R14): "Add library API-quality R-lines to 0021:D8 (no cue.Value in public output; typed fetch/resolution errors; docs and specs match code; 3 consecutive library betas without a breaking change)." The same day the owner narrowed the first line: "'no cue.Value in public output' narrowed to Render output only; Instance/Platform/Module .Package and ConfigSchema() keep cue.Value under ADR-007's rule."

**Revised:** 2026-10-03: R11 to R14 added, the kernel library's API-quality criteria for GA.

### D9: The CLI's ceiling on operator versions compares `MAJOR.MINOR` only

**Kind:** contract

**Depends:** 0006:D24

**Amends:** 0006:D24

**Decision:** The CLI refuses an operator only when the operator's `MAJOR.MINOR` is above its own, and ignores patch and prerelease differences. This amends 0006 D24. What survives: the CLI still refuses the unsafe direction, an operator newer than itself, and still reads the operator's version from what the operator reports about itself on the Platform; the CRD capability floor is unchanged. What changes: the comparison drops patch and prerelease, so each binary releases patches and beta counters without the other. This answers OQ14's skew question for the two binaries.

During beta every release of both binaries shares one `MAJOR.MINOR`, so the ceiling refuses nothing; R2 carries the guarantee the ceiling cannot.

**Requirements:**

- R1: The CLI refuses an operator only when the operator's `MAJOR.MINOR` is above the CLI's own; patch and prerelease differences are never refused.
- R2: No operator release needs a CLI newer than the newest released CLI: a change the released CLI cannot drive ships in an operator release only after a CLI release that drives it.

**Alternatives considered:**

- **Keep the ceiling on full SemVer, the delivered rule (0006 D24), and enforce release order by hand.** The ceiling refuses an operator whose version, prerelease counter included, is above the CLI's. With counters restarting at `beta.1`, two operator releases before one CLI release refuse every apply. Rejected: the OQ14 position already says the two share `MAJOR.MINOR` and release patches independently, and a gate that contradicts the position turns every operator docs release into an outage risk.

**Rationale:** The ceiling exists to stop a CLI driving an operator that expects more than it can write. A `MAJOR.MINOR` step is where that can happen under the shared-`MAJOR.MINOR` position; a patch or a beta counter is not. Where a beta counter does carry such a change, R2 keeps the operator from shipping it before a CLI that can drive it.

**Source:** User decision 2026-09-30 (the ceiling compares MAJOR.MINOR as the OQ14 answer); 0006 D24 is the delivered full-SemVer rule it amends.

### D10: Release tags are immutable

**Kind:** contract

**Depends:** 0011:D10, 0011:D15

**Decision:** Release tags are immutable. No git tag is ever moved, deleted or re-created, by anyone. A wrong or broken release is fixed by releasing the next version. A Go module's next version retracts the bad one, published from the module's highest line because the go command reads retractions only from the latest version; a CUE module or other OCI artifact publishes the next version. On a beta line that is the next `-beta.N` (D7); after GA it is the next patch.

**Scope.** The rule binds the OPM organization repositories that release: core, the kernel library, `catalog_opm`, the CLI and the operator. The module fleet repository is excluded for now and keeps its current practice until a later decision brings it in. Repositories outside the organization are not covered.

**Registry tags.** A version-named registry tag (`vX.Y.Z`, prereleases included) always names the content first pushed under it: a release path never re-points it to different content, and re-pushing identical content is a no-op, not an overwrite. The `-0.dev.*` branch builds and the `-e2e.g*` fixture tags are create-only as well: each is a new tag and never re-pointed, which is what 0011 D10 already records for the normal flow; that is recorded here as a fact of 0011, not a requirement of this decision. Only floating aliases move: `latest`, `pr-N` and `sha-*`. A registry conforming to 0011 D10 would refuse those moves too; today they are image tags on GHCR, which has no tag-immutability control, and keeping them once a conforming registry hosts the artifacts needs either a separate registry for them or an amendment to 0011 D10, which this decision does not make. Until then every first-party release path refuses to re-point a version it has already pushed. 0011 D15's refusal of an already-published version is that guarantee for the CLI's publish commands; the other release paths owe the same.

**Release branches.** A released minor that needs a fix gets a maintenance branch named `release/<tag-prefix>vX.Y` after that repository's own tag scheme: `release/v2.0` in core, `release/v1.0` in the library, the CLI and the operator, `release/opm-v4.4` in `catalog_opm`. The branch is lazy: it is cut only when a fix must reach a released minor, from the newest `vX.Y.*` tag of that minor, by one automated "cut release branch" action, never by hand. The same action opens a pull request into the new branch carrying the branch-local release-please settings: the branch as the release target and `always-bump-patch` versioning, so a stray `feat` commit on the branch never claims a minor that only `main` may cut. The action runs as the release app, which may not change workflow files, so it never edits one. When the release workflow at the cut tag cannot release from a branch, the branch gets one only through a reviewed backport pull request. The branch releases nothing until it carries both the settings and a release workflow able to release from it. A backport reaches the branch only through a pull request. A release branch is never deleted; a minor's end of life is documented, not enacted by removing its branch. During the beta line there are no release branches: fixes go forward on `main` and ship as the next `-beta.N`. The first release branch in a repository is cut once R10 holds there and `main` has moved past that minor, which for a beta line is after GA.

**Version lines.** A release branch and `main` never release the same version. `release/<tag-prefix>vX.Y` is cut only when `main`'s next release is above `X.Y` in `MAJOR.MINOR`, a prerelease of `X.(Y+1).0` included (its manifest, or its open release pull request, already names that version), and the cut action refuses otherwise. Once the branch exists, `main`'s release path refuses any `X.Y.*` version, so a withdrawn minor bump on `main` cannot bring it back to that minor: every `X.Y.*` patch from then on comes from the branch. Without this rule both lines compute the same next patch, the release app creates the first tag, and the second line's release names a version whose immutable tag points at the other line's commit. A release from a release branch never moves the floating pointers: no `latest` image tag and no GitHub Latest flag, which stay with `main`'s line. Every release, patches on a release branch included, is tagged by release-please running as the organization's release app, `opm-release-please`.

**Delivery order.** The policy above is complete and binds as written; only its tooling is ordered. The tag rulesets, the release-branch ruleset, staged immutable releases, the draft-first release flow for the CLI and the operator, the publish guards that refuse to re-point a version, agent guidance and a drift ledger need nothing from release branches and come first. The release-branch automation comes second: R10 forbids any cut until it is in place and proven, and D8 R10 makes it a GA exit criterion. A fix a released minor needs before a repository satisfies R10 goes forward on `main`, which is what the beta line requires anyway.

**Documentation.** The documentation site pins its sources per site version, which is why the rule exists. The site version is the shared CLI and operator `MAJOR.MINOR` (the OQ15 position); each source repository's release branch is named by its own tag scheme, so core's `release/v2.0` can serve site version `v1.0`. Apart from the bootstrap mode, every ref the site's version list names is a tag or a full commit SHA, never a branch name. The bootstrap mode, `source = main` for a version with no tags yet, is allowed only while the CLI has no tag of that site version; once it has one, the version is anchored at a CLI tag. The list is `site/versions.conf` in the `opmodel.dev` repository, where `cli` anchors the version, the library, core and the operator are read from its pins, `catalog` and `opm` are explicit, and an `override` replaces one pin with a stated reason. A docs fix for a released version lands on that repository's release branch, or on `main` during the beta line and for `opm`, which cuts no release; a documentation-only fix in core or `catalog_opm` cuts no release, and the version list pins the fix's commit by full SHA. Editing the version list to move a pin, onto a later tag, a SHA on a release branch or an override, is the mechanism this rule relies on: a reviewed commit to the list. What the rule fixes is that each ref, once named, resolves to the same commit forever.

**Enforcement.** The platform carries the guarantee, not convention. Three organization rulesets cover the in-scope repositories:

- a tag ruleset over every tag that refuses update, deletion and non-fast-forward, with an empty bypass list, so no role, team, app or owner is exempt in any mode;
- a tag-creation ruleset whose only bypass is the release app, so a tag can come into existence only from a release and a stale or hand-made tag cannot exist for a release to adopt;
- a release-branch ruleset over `release/*` that refuses deletion and non-fast-forward and requires a pull request, with an empty bypass list.

The mention-guard ruleset gains `release/*` in its include list, so backport commits and the changelogs generated from them are checked like `main`.

GitHub immutable releases are switched on in stages: core, the kernel library and `catalog_opm` first. The CLI and the operator join only after their draft-first release flow (create the release as a draft, attach every asset to the draft, publish last) has shipped one real release, because an immutable release refuses assets added after publication.

**Requirements:**

- R1: In every in-scope repository, a tag keeps the commit it was first pushed with: no tag is moved, deleted or re-created after it exists.
- R2: A wrong or broken release is corrected only by a later release with a higher version; for a Go module the retraction is published from the module's highest line, even when the fix ships from a release branch.
- R3: A version-named registry tag pushed by an in-scope repository's release always resolves to the content first pushed under it; a release from a `release/*` branch never moves `latest` or GitHub's Latest flag.
- R4: For every site version the CLI has tagged, every source ref the documentation site's version list names is a tag or a full commit SHA, never a branch name, and a SHA names a commit reachable from that repository's `main` or from its `release/<tag-prefix>vX.Y` branch for the corrected minor; a pin moves only by a reviewed commit to the list.
- R5: In every in-scope repository, a `release/*` branch is cut from the newest tag of its minor by SemVer precedence by the automated cut action, is changed only through a pull request, and is never deleted or force-pushed; its release-please settings bump only the patch, and it releases nothing until it carries both the cut action's settings and a release workflow able to release from that branch.
- R6: Every in-scope repository is covered by active organization rulesets that refuse update and deletion of any tag and deletion or force-push of a `release/*` branch, each with an empty bypass list.
- R7: Only the organization's release app creates tags in an in-scope repository; an organization ruleset restricts tag creation with that app as its only bypass.
- R8: GitHub immutable releases are enabled for core, the kernel library and `catalog_opm`; the CLI and the operator are added only after each has shipped a release that was created as a draft, received every asset while a draft, and was published last.
- R9: A `release/<tag-prefix>vX.Y` branch is cut only when `main`'s next release of that component is above `X.Y` in `MAJOR.MINOR`, prereleases included, and the cut action refuses otherwise; once the branch exists, `main`'s release path refuses any `X.Y.*` version of that component.
- R10: No `release/*` branch is cut in an in-scope repository until the cut action, release workflows that run on `release/**` and pull-request checks on `release/**` exist there, proven in the sandbox repository, including a cut from a tag that predates them and the case where `main` and a branch would compute the same version.
- R11: A pull request into a `release/*` branch runs the same required checks as a pull request into `main`.
- R12: A cut that fails part-way never strands its release branch: either no branch was created, or a re-run of the cut action finds the branch at the cut tag's commit and completes the cut.

**Alternatives considered:**

- **Allow a tag to be moved to repair a botched release.** The habit the rule ends. Rejected: the documentation site pins refs per version, the Go module proxy and checksum database cache the first content of a version, and an instance pins a module version expecting fixed bytes (0011 D10). A moved tag changes what a pinned consumer resolves without telling it, and a deleted tag breaks every build that names it.
- **Protect only release-shaped tag patterns.** Rejected: GitHub tag patterns match with path semantics, so a `*` stops at `/` and misses component tags that contain a slash. No tag in these repositories is meant to move, so the rule covers all of them.
- **Let organization admins bypass the ruleset, as the mention-guard ruleset does.** Rejected: bypass is granted per ruleset, not per rule, and an admin token used by tooling or agents would carry it. Break-glass is an owner editing the ruleset in the browser, which the audit log records.
- **Check in every release workflow that the tag points at the commit the release was cut from.** Rejected once tag creation is restricted to the release app and R9 keeps `main` and a release branch on disjoint versions: a stale, hand-made or doubly computed tag cannot exist, so the check would guard a state the platform and the version-line rule already refuse, and five copies of it would drift.
- **Turn on immutable releases for every in-scope repository at once.** Rejected: the CLI and the operator attach assets after their release is published, and an immutable release refuses that, so their next release would fail. The lock is also irreversible for releases created while it is on, which is why it follows a proven draft-first release rather than preceding it.
- **A `docs/vX.Y` branch per fixed version.** Retired: the `docs/` namespace is already the ordinary prefix for documentation pull-request branches, so a rule over `docs/*` froze every topic branch. A release branch already gives a fix for a released minor a place to land, for code and docs alike.
- **A release branch cut at every release.** Rejected: most minors never need a fix, and the release tag is already a fixed ref. The branch is created only when a fix needs a place to land.
- **Let `main` keep releasing patches of a minor that has a release branch.** Rejected: both lines would compute the same next patch, the release app would create the first tag, and release-please would skip the second line's tag and fail its release, leaving a changelog that claims a version whose tag names the other line's commit.
- **Delete a release branch at end of life.** Rejected: a SHA the version list pins on it would become unreachable and eventually collected. End of life is documented instead.
- **Bring the module fleet in now.** Deferred by the owner: the fleet stays on its current practice for the moment.
- **Rule by convention and agent guidance only.** Rejected: written guidance binds whoever reads it, while a platform ruleset binds every actor, bots and release apps included.

**Rationale:** The documentation system pins sources per site version, and that pin is only worth having if a named ref never moves. The same holds for every other consumer that pins a version: Go module sums, OCI pins and the beta counter of D7 all assume one version names one content. Making releases roll forward costs a version number per mistake and nothing else; D7 already advances `-beta.N` on every release, and D8's GA cut follows the same rule, so a wrong GA is followed by a patch. Lazy release branches give a released minor a fix path without a branch per release, and patch-only versioning on them keeps the minor sequence owned by `main`. The platform rules are chosen because they bind every actor: an empty bypass list leaves only an audited owner edit, restricting creation to the release app removes the stale-tag case, and an immutable release cannot be re-pointed even by the owner.

**Source:** User decisions 2026-10-01: the rule, its scope with the module fleet excluded for now, and the reason (the documentation site); the same day's revision replacing `docs/vX.Y` branches with lazy `release/<tag-prefix>vX.Y` branches, restricting tag creation to the release app and staging immutable releases; the same day's second revision adding the version-line rule (R9) and ordering the release-branch automation before any cut and before GA (R10, D8 R10). Platform facts verified 2026-10-01 against GitHub's ruleset, immutable-release and package documentation and the release-please and goreleaser sources: [research/immutable-tags.md](research/immutable-tags.md).

Open Questions live in [`07-questions.md`](07-questions.md), the entry-wide question register with its own numbering and status rules.
