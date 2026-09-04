# Design Decisions: Documentation Architecture

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

**Decision:** A page documents the deletion semantics as they exist:

- `spec.prune` defaults to false, so the finalizer's default behaviour is to orphan.
- A CLI-owned instance carries no hold, so deleting the CR destroys the only inventory record and orphans everything it tracked.
- CLI and operator deletion paths have diverged in ways that decide whether a resource is actually removed.

**Alternatives considered:**

- **Wait for enhancement 0012.** Rejected: 0012 is draft and not started, while the behaviour it describes already exists. Documentation that waits for a design to merge leaves the hazard undocumented for as long as the design takes.
- **Document it as a bug rather than as behaviour.** Rejected: whether the asymmetry is a defect is 0012's question. A user needs to know what happens when they delete an instance regardless of how that question resolves.

**Rationale:** This is the only place in the shipped system where following the documentation's happy path can destroy state the user expected to keep. Hazards get documented at their current behaviour, not at their intended behaviour.

**Source:** User decision 2026-08-18.

### D5: Secrets documentation waits for enhancement 0013

**Kind:** scope

**Depends:** 0013:D9

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

Open Questions live in [`07-questions.md`](07-questions.md): the entry's question register.
