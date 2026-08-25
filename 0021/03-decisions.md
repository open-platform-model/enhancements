# Design Decisions: OPM Versioning Policy

This document records every significant design choice with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent**: never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** While the entry is `draft`, a changed choice is an in-place edit to the existing `DN`, with an evidence-backed old position folded into *Alternatives considered*. Once `accepted`, bodies are protected and a change lands as a new `DN` with `**Amends:**` / `**Supersedes:**` relation fields, edited only through the `enhancement-compaction` skill.

Each decision carries a `**Kind:**` line (`contract`, `policy` or `scope`) and passes the admission test: *if every affected repo were rewritten from scratch, would this decision still bind the result?* Mechanism decisions belong in the implementing OpenSpec change in the target repo.

---

## Decisions

### D1: One versioning policy names every published artifact class

**Kind:** scope

**Decision:** OPM has one versioning policy, and it covers every class of artifact a consumer can pin: the core schema, catalog builds, catalog contracts, modules, the kernel library, the CLI, the operator and its CRDs. Each class answers the same five questions (carrier, compatibility surface, bump rules, pre-stable semantics, enforcement layer), and a class with an unanswered question is an open question in this entry, not a class the policy is silent on. The policy is published where a third-party author can read it without access to the workspace.

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

**Alternatives considered:**

- **The whole rendered output as the surface.** Every resource a module renders, compared structurally. Rejected as the *sole* surface: output changes with every catalog version and every transformer, so a module that changed nothing would read as breaking whenever its platform moved, and it makes the module's version depend on artifacts the module does not own. Its stateful subset is what OQ1 weighs as a second surface.
- **The component set as the surface.** Adding or removing components as the bump signal. Rejected: components are the module's internals; an instance depends on what it can pass in and on what stays running, not on how the module is decomposed.
- **No defined surface; conventional commits as the rule.** The current state. Rejected on 0010 D27's argument, which the author accepted for catalogs: a promise nothing can check is a convention, and a third-party author has no reason to follow it.

**Rationale:** `#config` is the one input contract a module has: an instance is values unified against it, and nothing else an instance authors reaches the module. The schema comment already requires it to be OpenAPIv3-shaped, which means it has no `for` or `if` and is mechanically comparable, so the rule can be verified rather than trusted. Subsumption is the natural CUE reading of "accepts everything the old one accepted", and it classifies every case in the design table without a special case except the default, which is why OQ3 is separate.

**Measured 2026-08-24:** `core/src/module.cue` declares `#config: _` with the comment "MUST be OpenAPIv3 compliant (no CUE templating - for/if statements)", and `#ModuleInstance` unifies `values` into it as `#module & {#config: values}` (`core/src/module_instance.cue`), so the instance's only authored input reaches the module through this one field. The CLI's publish report documents its compatibility fields as "Zero-valued for modules" (`cli/internal/publish/publish.go`), so no comparison of that field exists today.

**Source:** User decision 2026-08-24 ("any breaking changes to the #config schema requires a new MAJOR. Any new fields mean MINOR and any fixes are PATCH").

### D3: Settled rulings are copied verbatim into the policy, each under its source

**Kind:** policy

**Decision:** Where an accepted enhancement or a repo document has already decided a versioning rule, the policy text ([`policy/`](policy/), one file per class plus an index carrying the universal rules) carries that rule **verbatim**, unedited, under a line naming its source. The copy is what a reader follows and what the published policy page ships; the source is where the reasoning, alternatives and measurements stay, and a reader who wants them follows the citation. Copied today: 0010 D4, D27, D34, D35, D41, D44, D45, D48; 0011 D9, D15, D18, D23; the commit-type tables and repository rules of `core` and `catalog_opm`; the `modules` major separation rule; the core `schema-release` spec; and the tag-format, leading-zero and consumer-resolution sections of `core/docs/publishing.md`. Enhancement 0020 is cited, not copied, until it is accepted, because a draft body may still move. A copied block is refreshed only when its source changes through that source's own process (a new amending decision, a compaction, a repo-document edit); it is never edited in place here.

**Alternatives considered:**

- **Inherit by reference and paraphrase for the reader.** Previously adopted here (2026-08-24), on the argument that a copy drifts and a reader with two texts does not know which binds. Reversed by the author: a policy a third-party author reads must be complete on its own page, and a page that is a list of citations into a design repo is not a policy. Drift is answered by the refresh rule above and by the source line on every block, not by refusing to copy.
- **Supersede 0010's and 0011's versioning decisions into this entry.** Rejected: those decisions are delivered, their entries are closed to body edits, and supersession would move numbers other repos cite from commit messages for no gain.

**Rationale:** In the author's words, "even those that we have already defined, in these cases we just copy verbatim". The policy's value to its reader is that it is one document; the value of the source entries is that they hold the argument. Verbatim copying with a source line gives both without editing either.

**Source:** User decision 2026-08-25. **Revised:** 2026-08-25, reversing the by-reference position adopted 2026-08-24.

### D4: The classes the policy covers

**Kind:** scope

**Decision:** The policy covers nine classes: the core schema; the catalog build; the catalog contract; the transformer; the module; the CLI template; the tooling train of kernel library, CLI and operator; the CRDs; and the documentation site. Each has its own file under `policy/` and a row in `contracts/policy.cue`. Out of scope, by the author's selection from the workspace sweep of 2026-08-24: the test fixture fleets under `testing.opmodel.dev` (three publish mechanisms, no consumer outside CI), the CLI's importable Go packages (no stated consumer), the operator install manifest as a class of its own (it is an artifact of the operator release), and platforms (consumers, not artifacts, until something publishes one; OQ11). The cross-actor wire contracts the sweep surfaced (the operator version-skew ceiling, the CRD constants the CLI mirrors, the inventory digest, the label vocabulary, the catalog-version coupling between platform and modules) are compatibility contracts without a version of their own; they are named under the CRD class as its shared surface and gated by parity, not by a bump rule.

**Alternatives considered:**

- **Every class the sweep found.** Fourteen artifact classes plus eight wire contracts. Rejected by the author as scope: the fixtures and the CLI's Go packages have no consumer a promise could reach, and the install manifest is the operator release seen from the CLI's side.
- **Drop the catalog build as a class, since the contract class carries the promise.** Considered and kept: a `#Platform` subscription pins a build as a scalar and never a contract, and every transformer key embeds the build version, so the build is the unit a platform actually depends on; the contract class says what a member promises, the build class says which members and transformers ship together. What the build class lacks is the rule for how a contract-level event moves its number, which is OQ7.

**Rationale:** The sweep is the evidence; the selection is the author's. Naming what is out and why keeps the omissions deliberate rather than silent, which is D1's own requirement.

**Source:** User decision 2026-08-25, selecting from the 2026-08-24 workspace sweep.

### D5: An alpha contract is encouraged, not required, to bump its alpha number on a break

**Kind:** policy

**Decision:** A contract at an alpha `apiVersion` (`vNalphaM`) still promises nothing and its publish gate stays off (0010 D34, unchanged). On top of that, the policy **encourages** an author who breaks an alpha contract, by adding a required field, removing or renaming a field, narrowing a type or changing a default, to bump the alpha number (`v1alpha1` → `v1alpha2`) rather than reshape the same key in place. The bump is a courtesy signal to whoever is already consuming the alpha: the key they matched on no longer means what it did. It reaches the convention layer only: no gate refuses an in-place alpha break, no check command reports one, and a catalog that reshapes an alpha in place has violated nothing. The published policy states it as "should", and the catalog repositories carry it as an authoring convention.

**Alternatives considered:**

- **Gate alpha breaks like beta and GA.** Rejected by 0010 D34 and not reopened: enforcing additivity on the level whose definition is "no promise" empties the label.
- **Say nothing at alpha.** The current state. Rejected by the author: an alpha consumer who is told nothing learns about a break from a `field not allowed` at render; an alpha number that moved tells them at the import line, for the cost of one directory under 0010 D49's filing.
- **Require the bump but exempt it from the gate.** Rejected: a rule that is required and unenforced is the kind of convention 0010 D27 rejected, and "required" would contradict D34's text. "Encouraged" is the honest strength.

**Rationale:** In the author's words, alpha versions "say nothing guaranteed but I still think we should try and encourage bumping the alpha number when adding new required fields for example". The ladder already has the rung (0020 D5 permits and discourages skipping rungs, so `v1alpha2` is a normal address), the filing already has the directory, and the cost to the author is a rename. The benefit lands on exactly the consumer alpha is for: someone trying the contract early who deserves to see it move.

**Source:** User decision 2026-08-25.

### D6: A transformer serves a contract level by naming it: one registration per level, one shared body

**Kind:** contract

**Decision:** A transformer binds to exact contract keys, and a contract key embeds its `apiVersion`, so a transformer that serves more than one level of a resource or trait declares **one transformer per level**, each naming that level's key in its required or optional maps, and all of them sharing one transform body. Nothing in the match path changes: each registration matches exactly the components that demand its key, and the exact-key rule of 0010 D34 stands. Under promotion by aliasing (0020 D4) the levels are one definition, so the shared body serves both without change.

**Backup rule, for a breaking level:** when two served levels differ in shape, the shared body reads a canonical shape and each per-level registration supplies the projection from its level into it. The projection is a struct, authored beside the registration, and a level with no projection is a level the transformer does not serve. The catalog states which levels each transformer serves; how it states it (index, label, vet check) is the catalog's own decision.

**Alternatives considered:**

- **An any-of form in `requiredResources` / `requiredTraits`** so one transformer declares `container@v1beta1 | container@v1`. Rejected: it is a core schema change plus a second matching semantics in the kernel, and 0010 D34 deliberately kept the match path exact-key with no comparator. It saves one registration per level and pays with an ambiguity the identity reshape exists to remove.
- **A matcher-side fallback from a missing level to a served one.** Rejected by 0020 D4 already (a lookup miss becomes ambiguous between absent and present-under-another-name) and not reopened.
- **Serve the newest level only and let consumers migrate.** Rejected: it makes every level bump a flag day for every module demanding the old key, which is what 0020 D4's dual-shipping exists to avoid on the contract side; the transformer side must keep pace or the dual-ship is empty.

**Rationale:** This is the only option that needs no schema and no kernel change: the catalog already hoists shared bodies into helpers, 0010 D49 already files levels in their own directories, and the transformer's build-keyed FQN (0010 D44) means registering one more transformer costs nothing in the key space. The normalizer is kept as a backup rather than the rule because under aliasing the common case has identical shapes, and a projection that exists for no reason is a second place for the shape to drift.

**Source:** User decision 2026-08-25, choosing between three options laid out the same day; the match rule is `core/src/transformer.cue` (AND over exact keys), the body-sharing precedent is `catalog_opm/opm/transformers/*_helpers.cue`.

Open Questions live in [`07-questions.md`](07-questions.md), the entry-wide question register with its own numbering and status rules.
