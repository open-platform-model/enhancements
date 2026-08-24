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

### D3: Settled rulings are inherited by reference, never restated

**Kind:** policy

**Decision:** Where an accepted enhancement has already decided a versioning rule, this policy cites the decision and does not restate its body. The contract ladder and the per-level additive-only promise are 0010 D27/D34; enforcement posture is 0010 D35; authored versions and the already-published refusal are 0011 D15; predecessor selection is 0011 D23; identity across a major is 0010 D41/D45; the branch-build ranking is `core/docs/publishing.md`; promotion and retirement are 0020. The published policy page may paraphrase for a reader, and the citation is the normative text.

**Alternatives considered:**

- **Restate every rule in full so the policy reads standalone.** Rejected: a restated rule is a second copy, and the accepted entries' bodies are protected and compacted on their own schedule; the copy would drift, and a reader with two texts would not know which binds.
- **Supersede 0010's and 0011's versioning decisions into this entry.** Rejected: those decisions are delivered, their entries are closed to body edits, and supersession would move numbers other repos cite from commit messages for no gain.

**Rationale:** The entry's value is the matrix and the gaps, not the rules that already exist. Citing keeps one normative home per rule, which is the same principle the enhancements repo applies to its own metadata: a fact lives where it is decided.

**Source:** Design 2026-08-24, following from D1 and from the enhancements repo's rule that accepted decision bodies are protected.

Open Questions live in [`07-questions.md`](07-questions.md), the entry-wide question register with its own numbering and status rules.
