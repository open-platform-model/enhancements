# Design Decisions — Documentation Architecture

This document records every significant design choice with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent**, never reused and never renumbered, because other repos cite them from commit messages and OpenSpec changes. The *text* under a number states what is true now: a reversal is recorded as its own `DN` while the design is in motion, then woven into the decision it changes at the next compaction pass. The merged decision keeps the lower number, and the vacated number keeps a one-line tombstone. See the `enhancement-compaction` skill.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source.

---

## Decisions

### D1: Reference is generated from source; guidance is authored

**Kind:** policy

**Decision:** Every reference fact that can be derived from CUE or from cobra is generated, never hand-transcribed. That covers a member's name, `apiVersion`, `fqn`, `modulePath`, description, category, spec key and schema shape, a trait's `optional` posture and `appliesTo`, a blueprint's composed sets and `matchLabels`, the set of transformers that serve a member, worked examples taken from the transformers' embedded golden tests, and the full CLI command reference. Everything a reader needs that CUE does not encode is authored by hand: which blueprint to start from, which traits are legal on which blueprint, cross-member interactions, family guidance, and every Concepts and Diagnostics page.

Generation reads evaluated CUE, not source text. The catalog's `metadata.description` is populated on all 70 members; the current index generator is a shell text scraper that reads doc comments instead and therefore reports an empty description for exactly the members readers need most. Hand-written doc comments remain load-bearing for what a one-line description cannot carry, and a CI gate refuses a new catalog member that ships without one.

**Alternatives considered:**

- **Hand-write the reference.** Rejected on volume and on decay: 120 catalog members, 50 transformers and roughly 35 undocumented `core` definitions is more than can be maintained by hand, and the measured failure mode of this workspace's existing prose is precisely that renames invalidate hand-written examples silently.
- **Generate everything, including guidance.** Rejected because the guidance a reader needs is not in the CUE. Which blueprint to pick is nowhere expressed in the schema; only a transformer's `requiredLabels` implies it. `appliesTo` is uniformly `[#ContainerResource]` across 26 of 27 traits and therefore carries no information about what is legal where.
- **Generate now, backfill later.** Rejected: generating against the current doc-comment coverage produces authoritative-looking pages that say nothing for every blueprint and most traits, which is worse than no page.

**Rationale:** The split is decided by whether a rename can invalidate the content. Generated facts move with the source; authored guidance does not decay when a field is renamed, because it explains a relationship rather than restating a value.

**Source:** User decision 2026-08-18.

### D2: `core/SPEC.md` is not published; the public reference is a projection of its normative spine

**Kind:** policy

**Decision:** `SPEC.md` remains contributor-facing. The public reference takes its Definition, Shape and Constraints content as a source and drops the Rationale sections. Rationale is instead mined as raw material for Concepts pages, rewritten rather than copied.

**Alternatives considered:**

- **Publish `SPEC.md` as the reference.** Rejected: its stated audience is "anyone evolving the schema", its Rationale is dense with enhancement decision numbers, experiment paths and cross-repo file references that a public reader cannot resolve, and it documents unshipped state as first-class content, so a reader would take a Constraint's MUST as a description of what the toolchain does today.
- **Fork `SPEC.md` into a public copy.** Rejected as the workspace's own demonstrated failure mode. Two copies of a contract drift, and the drift is invisible until a reader hits the half that did not keep up.

**Rationale:** The four-part format already cuts the seam this decision needs. Keeping one specification and projecting it means the public reference cannot contradict the contract, while the explanation gets rewritten for an audience that cannot follow a `D36` citation.

**Source:** User decision 2026-08-18.

### D3: The documentation states what OPM does not do

**Kind:** policy

**Decision:** A page enumerates the systems OPM does not have, naming them plainly: no lifecycle hooks, no workflows, no rollback, no reverse handoff from operator back to CLI, no export to GitOps manifests, no provider classes. Draft enhancements are not described as forthcoming features on that page or anywhere else.

**Alternatives considered:**

- **Silence.** Rejected: nine of seventeen enhancements are draft, several of them describing systems a reader would reasonably assume exist (enhancement 0009 defines an entire execution half of the kernel). Silence converts each into a question that reaches the maintainers individually.
- **A roadmap page instead.** Rejected as answering a different question. A roadmap says what may come; this page says what is absent today, which is what someone evaluating the tool needs before committing to it.

**Rationale:** The cost of stating an absence is one page. The cost of leaving it implicit is paid repeatedly by every reader who assumes presence, and once by whoever discovers the absence after building on the assumption.

**Source:** User decision 2026-08-18.

### D4: The deletion and prune hazard is documented now, independent of enhancement 0012

**Kind:** scope

**Decision:** A page documents the current, shipped deletion semantics: `spec.prune` defaults to false, so the finalizer's default behaviour is to orphan; a CLI-owned instance carries no hold, so deleting the CR destroys the only inventory record and orphans everything it tracked; and CLI and operator deletion paths have diverged in ways that decide whether a resource is actually removed.

**Alternatives considered:**

- **Wait for enhancement 0012.** Rejected: 0012 is draft and not started, while the behaviour it describes is shipped today. Documentation that waits for a design to land leaves the hazard undocumented for as long as the design takes.
- **Document it as a bug rather than as behaviour.** Rejected: whether the asymmetry is a defect is 0012's question. A user needs to know what happens when they delete an instance regardless of how that question resolves.

**Rationale:** This is the only place in the shipped system where following the documentation's happy path can destroy state the user expected to keep. Hazards get documented at their current behaviour, not at their intended behaviour.

**Source:** User decision 2026-08-18.

### D5: Secrets documentation waits for enhancement 0013

**Kind:** scope

**Decision:** The public documentation carries no secrets material until enhancement 0013 lands. 0013's `docs-secrets-authoring` slice authors it, and its concern was amended on 2026-08-18 to say so: it writes the first secrets documentation rather than rewriting anything.

**Alternatives considered:**

- **Document the current vocabulary with an expiry banner.** Rejected: 0013 is accepted with zero open questions and four concluded experiments, and it deletes the `$opm` / `$secretName` / `$dataKey` shape entirely. Writing a page with a known expiry spends authoring effort on content whose replacement is already specified.
- **Document the accepted 0013 model ahead of implementation.** Rejected under the same rule as D3: documenting an unshipped design as though it works is the failure this entry exists to end.

**Rationale:** A gap that a reader can see (a section that says secrets documentation is pending, with a link) is honest and cheap. A page that is wrong in a known way is neither.

**Source:** User decision 2026-08-18.

### D6: The abstraction family is the documented default; the raw passthrough family is a marked escape hatch

**Kind:** policy

**Decision:** Reference splits catalog members by family. The abstraction family (11 resources, 27 traits, 5 blueprints) gets full per-member pages and leads every authoring path, with blueprints first. The raw `k8s-*` family (27 resources) gets one index page plus a generated table, labelled as the last resort, each entry pointing at the abstraction that covers the same ground where one exists.

**Alternatives considered:**

- **Present all 38 resources as one list.** Rejected: it gives 27 members that no first-party module imports the same prominence as the 11 that every module uses, and it hides the fact that the two families behave differently (the raw family takes no traits, participates in no blueprint, and emits exactly one object per component).
- **Omit the raw family from public documentation.** Rejected: it is the deliberate escape hatch for what the abstractions do not model, and an undocumented escape hatch is one that gets used wrongly.

**Rationale:** The framing is a fact about the system rather than an editorial preference. No first-party module imports the raw family, and `task vet:layering` fails the catalog build if an abstraction member depends on one. Documentation that presented the two as peers would contradict the catalog's own CI.

**Source:** User decision 2026-08-18.

---

## Open Questions

- **OQ1: What does the generator read, and in what precedence?** Status: open.

  `metadata.description` is populated on all 70 catalog members and is the obvious primary source for a summary line. Doc comments carry the longer explanation that a one-liner cannot (why `exactName` and `immutable` conflict, why `podMetadata` exists at all) but are present on only a minority of the members that matter.

  A generated entry plausibly wants both: the description as the summary, the doc comment as body prose. Unresolved: the precedence when the two disagree, whether a member carrying a doc comment but no description is valid, and whether the same rule governs `core` definitions, whose descriptions exist only in doc comments and have no `metadata.description` equivalent at all.

- **OQ2: Does the enforcement badge appear on generated reference entries, or only on authored pages?** Status: open.

  An authored Concepts page states its badge by hand. A generated member entry cannot, unless the enforcement layer is itself derivable from the source. Some of it is: a required field is `cue`-enforced by construction. Some is not: whether the kernel refuses an unhandled trait depends on posture resolution at render, which the member's own definition does not determine.

  Three candidates: badge only authored statements and leave generated entries unbadged; badge generated entries with a conservative default; or teach the generator the small set of derivable cases and leave the remainder unbadged. The third is the most useful and the most work, and it risks a badge that says `cue` where the real answer is `convention`, which is worse than no badge.

- **OQ3: Who keeps Diagnostics current as the kernel's error types change?** Status: open.

  The Diagnostics section maps kernel errors to causes and fixes. Those types live in `library/opm/errors` and change with the kernel; nothing connects a change there to a documentation update, and this is the section most likely to rot first.

  Candidate mechanisms: a test in `library` asserting that every exported error type appears in the site's diagnostics index, a checklist item in the library's own change protocol, or explicit acceptance that the section drifts and is audited periodically. The first is the only one that fails loudly, and it couples two repos that are otherwise independent.

- **OQ4: How is `opm/docs` retired, given that `opm` is not an area?** Status: open.

  `enhancements/schema.cue`'s `#Area` enumeration has no `opm` entry, so the meta repo cannot appear in `affects` and cannot own a slice in this entry's plan. That tree holds the stale prose this enhancement replaces, and it is currently reachable and looks current, which is the failure mode.

  Options: add `opm` to the area vocabulary, which is a schema change to the enhancements repo itself; retire the tree as uncoordinated cleanup outside the plan; or move the salvageable formats into `opmodel.dev` and leave the deletion to whoever owns the meta repo. Worth salvaging as format rather than content: the glossary's shape, the persona routing at the top of `docs/index.md`, and the raw-versus-blueprint side-by-side in `concepts/resources-traits-blueprints.md`.

- **OQ5: What happens to the two catalog members that render nothing?** Status: open.

  `#SizingTrait` and `#EncryptionConfigTrait` appear in no transformer's required or optional maps, and both declare `optional: bool | *true`, so attaching either warns at most and renders nothing. `#VerticalScalingSchema` is an empty struct labelled a placeholder for future VPA support.

  Documenting them as-is advertises capability that does not exist. They need to be wired, marked explicitly unimplemented in their own metadata so the generator can render them as such, or removed. The decision belongs to the catalog rather than to this entry, but the documentation cannot ship a member page either way until it is made.

- **OQ6: Does the site need a versioned-documentation story?** Status: open.

  `core` maintains a v1 line on a protected branch alongside v2 on main, and the module fleet is mid-migration. Whether the public site documents only the current line or carries a version switcher changes both the generator's contract and the site's information architecture.

  Deferring is viable while the v1 line has only internal consumers, which is true today. The question becomes forcing the moment an external consumer pins v1.
