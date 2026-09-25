# Design Decisions: Documentation Architecture

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent**, never reused and never renumbered, because other repos cite them from commit messages and OpenSpec changes. The *text* under a number states what is true now: a reversal is recorded as its own `DN` while the design is in motion, then woven into the decision it changes at the next compaction pass. The merged decision keeps the lower number, and the vacated number keeps a one-line tombstone. See the `enhancement-compaction` skill.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source.

---

## Decisions

### D1: Reference is generated from source; guidance is authored

**Kind:** contract

**Decision:** Every reference fact that can be derived from CUE or from cobra is generated, never hand-transcribed. That covers a member's name, `apiVersion`, `fqn`, `modulePath`, description, category, spec key and schema shape, a trait's `optional` posture and `appliesTo`, a blueprint's composed sets and `matchLabels`, the set of transformers that serve a member, worked examples taken from the transformers' embedded golden tests, and the full CLI command reference. Everything a reader needs that CUE does not encode is authored by hand: which blueprint to start from, which traits are legal on which blueprint, cross-member interactions, family guidance, and every Concepts and Diagnostics page.

Generation reads evaluated CUE, not source text. The catalog's `metadata.description` is populated on all 70 members; the current index generator is a shell text scraper that reads doc comments instead and therefore reports an empty description for exactly the members readers need most. Hand-written doc comments remain load-bearing for what a one-line description cannot carry, and a CI gate refuses a new catalog member that ships without one.

**Requirements:**

- R1: A generated reference entry's one-line summary is the member's evaluated `metadata.description`, so every member that carries a description shows one.
- R2: Generated and authored content on a reference page are distinguishable to the reader; a generated block is delimited as such.
- R3: A new catalog blueprint, resource or trait that ships without a doc comment is refused by the catalog's CI.

**Alternatives considered:**

- **Hand-write the reference.** Rejected on volume and on decay: 120 catalog members, 50 transformers and roughly 35 undocumented `core` definitions is more than can be maintained by hand, and the measured failure mode of this workspace's existing prose is precisely that renames invalidate hand-written examples silently.
- **Generate everything, including guidance.** Rejected because the guidance a reader needs is not in the CUE. Which blueprint to pick is nowhere expressed in the schema; only a transformer's `requiredLabels` implies it. `appliesTo` is uniformly `[#ContainerResource]` across 26 of 27 traits and therefore carries no information about what is legal where.
- **Generate now, backfill later.** Rejected: generating against the current doc-comment coverage produces authoritative-looking pages that say nothing for every blueprint and most traits, which is worse than no page.

**Rationale:** The split is decided by whether a rename can invalidate the content. Generated facts move with the source; authored guidance does not decay when a field is renamed, because it explains a relationship rather than restating a value.

**Source:** User decision 2026-08-18.

### D2: `core/SPEC.md` is not published; the public reference is a projection of its normative spine

**Kind:** policy

**Decision:** `SPEC.md` remains contributor-facing. The public reference takes its Definition, Shape and Constraints content as a source and drops the Rationale sections. Rationale is instead mined as raw material for Concepts pages, rewritten rather than copied.

**Requirements:** none (documentation stance on what the public reference is projected from)

**Alternatives considered:**

- **Publish `SPEC.md` as the reference.** Rejected: its stated audience is "anyone evolving the schema", its Rationale is dense with enhancement decision numbers, experiment paths and cross-repo file references that a public reader cannot resolve, and it documents unshipped state as first-class content, so a reader would take a Constraint's MUST as a description of what the toolchain does today.
- **Fork `SPEC.md` into a public copy.** Rejected as the workspace's own demonstrated failure mode. Two copies of a contract drift, and the drift is invisible until a reader hits the half that did not keep up.

**Rationale:** The four-part format already cuts the seam this decision needs. Keeping one specification and projecting it means the public reference cannot contradict the contract, while the explanation gets rewritten for an audience that cannot follow a `D36` citation.

**Source:** User decision 2026-08-18.

### D3: The documentation states what OPM does not do

**Kind:** policy

**Decision:** A page enumerates the systems OPM does not have, naming them plainly: no lifecycle hooks, no workflows, no rollback, no reverse handoff from operator back to CLI, no export to GitOps manifests, no provider classes. Draft enhancements are not described as forthcoming features on that page or anywhere else.

**Requirements:** none (documentation stance; the page's content list is authored guidance, not a behaviour a consumer relies on)

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

**Requirements:** none (sequencing decision; the deletion semantics it documents are owned by the operator and cli today and by 0012 once it lands)

**Alternatives considered:**

- **Wait for enhancement 0012.** Rejected: 0012 is draft and not started, while the behaviour it describes already exists. Documentation that waits for a design to merge leaves the hazard undocumented for as long as the design takes.
- **Document it as a bug rather than as behaviour.** Rejected: whether the asymmetry is a defect is 0012's question. A user needs to know what happens when they delete an instance regardless of how that question resolves.

**Rationale:** This is the only place in the shipped system where following the documentation's happy path can destroy state the user expected to keep. Hazards get documented at their current behaviour, not at their intended behaviour.

**Source:** User decision 2026-08-18.

### D5: Secrets documentation waits for enhancement 0013

**Kind:** scope

**Depends:** 0013:D9

**Decision:** The public documentation carries no secrets material until enhancement 0013 lands. 0013's `docs-secrets-authoring` slice authors it, and its concern was amended on 2026-08-18 to say so: it writes the first secrets documentation rather than rewriting anything.

**Requirements:** none (defers to 0013's docs slice; recorded as no_work in delivery.yaml)

**Alternatives considered:**

- **Document the current vocabulary with an expiry banner.** Rejected: 0013 is accepted with zero open questions and four concluded experiments, and it deletes the `$opm` / `$secretName` / `$dataKey` shape entirely. Writing a page with a known expiry spends authoring effort on content whose replacement is already specified.
- **Document the accepted 0013 model ahead of implementation.** Rejected under the same rule as D3: documenting an unshipped design as though it works is the failure this entry exists to end.

**Rationale:** A gap that a reader can see (a section that says secrets documentation is pending, with a link) is honest and cheap. A page that is wrong in a known way is neither.

**Source:** User decision 2026-08-18.

### D6: The abstraction family is the documented default; the raw passthrough family is a marked escape hatch

**Kind:** policy

**Decision:** Reference splits catalog members by family. The abstraction family (11 resources, 27 traits, 5 blueprints) gets full per-member pages and leads every authoring path, with blueprints first. The raw `k8s-*` family (27 resources) gets one index page plus a generated table, labelled as the last resort, each entry pointing at the abstraction that covers the same ground where one exists.

**Requirements:** none (documentation stance on reference layout and family framing)

**Alternatives considered:**

- **Present all 38 resources as one list.** Rejected: it gives 27 members that no first-party module imports the same prominence as the 11 that every module uses, and it hides the fact that the two families behave differently (the raw family takes no traits, participates in no blueprint, and emits exactly one object per component).
- **Omit the raw family from public documentation.** Rejected: it is the deliberate escape hatch for what the abstractions do not model, and an undocumented escape hatch is one that gets used wrongly.

**Rationale:** The framing is a fact about the system rather than an editorial preference. No first-party module imports the raw family, and `task vet:layering` fails the catalog build if an abstraction member depends on one. Documentation that presented the two as peers would contradict the catalog's own CI.

**Source:** User decision 2026-08-18.

### D7: Every page declares one type, a title and a one-line description

**Kind:** contract

**Decision:** Every page on the site is exactly one of four types: tutorial, how-to guide, explanation or reference. A section holds several types, but a page never mixes them. Each authored page declares its title, a one-line description and its type, and nothing else is required.

The section a page belongs to, and the address other pages link it by, come from where the page sits, never from a declared field, so the two cannot disagree. Every section's index page is generated from its pages' descriptions, grouped by type in a fixed order: tutorials, how-to guides, explanations, reference. No index page is written by hand.

**Requirements:**

- R1: Every published page carries a title, a one-line description and exactly one of the four types; a page missing any of them, or declaring any other type, fails the site build.
- R2: A section's index lists every page in the section with its description, grouped by type in the order tutorial, how-to guide, explanation, reference.
- R3: A page's section and link address follow from where it sits in the site; no page declares either.

**Alternatives considered:**

- **One genre per section.** Previously adopted in this entry's design and contract. Rejected: Authoring modules held guides and reference from the start, and a section-level genre cannot tell a reviewer which rules a given page must follow.
- **The four types as the top-level navigation.** Already rejected for the disjoint-audience reason in `05-risks.md`. Kept one level down instead, on every page.
- **Declare the section and a link id on each page.** Rejected: the same fact stated in two places drifts, and a moved page would keep claiming its old section.
- **Hand-written section index pages.** Rejected: an index nobody regenerates is the first page to go stale. KCP generates its section indexes from each page's description line and writes none by hand.

**Rationale:** The central failure Diátaxis names is types bleeding into each other, worst of all tutorials and how-to guides collapsing into one. The risk is higher here than in a single-repo project because several repositories write pages. A declared type tells the writer which rules apply and lets a reviewer check them. The description does double duty as the index entry and the search snippet, so it is always written.

**Source:** User decision 2026-09-24. Evidence: [research/findings.md](research/findings.md), sections on Diátaxis and on KCP's section indexes.

### D8: A page lives in the repository whose change would make it wrong; the site is assembled by section

**Kind:** policy

**Decision:** A page's source lives in the repository whose change would make the page wrong. The site engine owns no content.

- `core` owns concepts about a single core definition and the schema reference.
- `catalog` owns catalog member reference, blueprint and trait guidance, and the extending guides for catalog authors.
- `cli` owns command reference, publishing guides, registry namespaces and publish refusals.
- `opm-operator` owns operator installation, deletion behaviour, its resource reference and its status conditions.
- `library` owns kernel embedding and every kernel diagnostics entry.
- `opm` owns what has no single owner: the home page, Start here, concepts and tutorials that span repositories, the boundaries page and the glossary.

Each repository keeps its published pages apart from its contributor documents, and only the published pages reach the site. The site is assembled by section, never by repository: pages from several repositories sit side by side in one section, and the reader never sees a repository boundary. Two repositories publishing the same address fail the build.

A section appears in the navigation only once it holds a real page. No placeholder page is ever published; a known gap, such as the secrets pointer D5 describes, is stated on a page that exists for its own reason.

**Requirements:** none (a placement and assembly posture; what a reader observes of it is D7's page contract)

**Alternatives considered:**

- **All content in the site repository.** Rejected: prose far from the code it describes is the drift this entry exists to end. Write the Docs' "Nearby" principle says the same.
- **All authored prose in `opm`, only generated reference in the source repositories.** Rejected: a concept page about one core definition would change in a different repository from the definition, so a core change could not carry its own documentation fix.
- **One site per repository under one domain, linked from a landing page.** This is KCP's model: kcp and kcp-operator are separate sites with separate navigation and separate version lists. Rejected: it shows the reader the repository layout instead of the product, and the reader must know which repository owns a topic before they can find it.
- **Publish each repository's whole documentation folder.** Rejected: those folders hold contributor material today, such as catalog authoring rules, CLI design RFCs and core's publishing strategy. KCP's public navigation shows the result, with load-test reports and a long architecture brain dump beside user pages.
- **Create every section up front with placeholder pages.** Rejected: Diátaxis calls empty four-part scaffolds the thing not to do, and a placeholder looks like documentation while saying nothing.

**Rationale:** The owning-change test makes placement mechanical: whoever changes the behaviour is in the same pull request as the page describing it. Assembling by section keeps the reader-state navigation independent of how OPM happens to be split into repositories, which will change. The diagnostics placement pays off twice: with the entries next to the kernel's error types, a check that every error type has an entry stays inside one repository (OQ3).

**Source:** User decisions 2026-09-20 (reference in the owning repository, prose with no natural home in `opm`) and 2026-09-24 (the site engine assembles one cohesive site and holds no content). Evidence: [research/findings.md](research/findings.md), sections on KCP's site model and on Write the Docs.

### D9: Each page type has a fixed shape

**Kind:** policy

**Decision:** Every page of a type carries that type's parts, in that order.

- **Tutorial:** the end result shown first; prerequisites with exact versions; numbered steps, each followed by its expected output; what was built; at most three next links. One path, no options, and no explanation beyond one line and a link.
- **How-to guide:** a title that starts with a verb; one sentence on what it achieves and when to use it; the state the reader must already be in; steps as imperatives, with forks written as conditions; how to check it worked; links to the reference and the concept.
- **Explanation:** a title that reads naturally after "About"; the concept in Kubernetes terms, including where the comparison stops holding; how it works; why it is built this way; the misreadings people actually make; what enforces each rule. No steps and no field tables.
- **Reference:** an authored reference page says in one sentence what it lists, then gives entries ordered by the product's structure, with each rule stated plainly and badged. A generated entry follows one order everywhere: summary, an at-a-glance table, spec, example, notes, what serves it, what enforces it.
- **Diagnostics entry:** a how-to guide with a fixed shape: the error's name as printed, the exact message, what it means in two sentences at most, each cause with its fix, and where the error is raised.

Exact heading wording and the page templates belong to the writing guide in `opm`, not to this entry. Length targets per type are a convention, not a gate.

**Requirements:** none (a writing posture checked in review; the only part enforced mechanically is the declared type, D7:R1)

**Alternatives considered:**

- **Free-form pages within a type.** Rejected: several repositories writing independently produce several house styles, and a reader cannot predict where the prerequisites or the fix will be. KCP shows it: similar pages put their parts in different orders, and page length runs from a few hundred words to over six thousand.
- **Diagnostics entries as authored reference.** Previously adopted in this entry's design and contract. Rejected: a reader on a diagnostics page is at work fixing something, which the Diátaxis compass classifies as a how-to guide. A reference entry would describe the error and stop short of the fix.
- **Fix the exact headings in this entry.** Rejected as mechanism: wording is refined as pages get written, and writers look in the writing guide, not here.

**Rationale:** A fixed shape per type is what makes a site written in several repositories read as one. The explanation shape leads with Kubernetes terms because the target reader already runs Kubernetes. KCP defines its concepts that way ("similar cost as a namespace", "almost identical to a CRD"), and it is the shortest route to plain English for that reader. The tutorial shape shows expected output after every step because Diátaxis requires a visible result per step, and KCP does it on every command.

**Source:** User decision 2026-09-24. Evidence: [research/findings.md](research/findings.md), sections on Diátaxis and on KCP's writing.

### D10: Notes on one catalog member live in its doc comment; guidance across members lives in how-to guides

**Kind:** policy

**Decision:** Hand-written notes about a single catalog member, such as why two of its fields conflict, what a default means or why the member exists, are written in the member's doc comment and rendered on its generated reference page. Guidance relating several members lives in how-to guides and explanations: which blueprint to start from, which traits are legal on which blueprint, how members interact, and when to reach for the raw family. No per-member Markdown file exists beside the source.

D1 still decides what is generated and what is authored. This decision places the authored text about members.

**Requirements:** none (a placement posture for authored text; the doc-comment gate is D1:R3)

**Alternatives considered:**

- **A Markdown notes file per member, merged into the generated page.** Rejected: two sources per member, one of which a rename leaves behind.
- **Authored fields on each member entry for when to use it, its interactions and family guidance.** Previously in this entry's contract. Rejected: all three relate members to each other, so they belong on one page about the choice, not repeated on every member the choice involves.

**Rationale:** The doc comment moves with the member, so a rename carries its notes along, which is D1's test for what can be trusted to stay current. Guidance about choosing between members is read by someone making that choice, and that reader is on a how-to guide.

**Source:** User decision 2026-09-24.

### D11: The documentation assumes Kubernetes knowledge, never CUE or OPM knowledge

**Kind:** contract

**Decision:** Every public page is written for a reader who runs Kubernetes and has never used OPM or CUE. Kubernetes terms such as Pod, CRD, controller and namespace are used without explanation. Every CUE term and every OPM term is defined once, in the glossary, and linked to that entry the first time it appears on a page. The site may make that link itself; either way the reader gets it.

**Requirements:**

- R1: On every public page, the first use of a CUE or OPM term links to the term's glossary entry.

**Alternatives considered:**

- **Assume nothing, and explain Kubernetes too.** Rejected: OPM's reader already runs a cluster. Explaining Pods to them costs every page length and signals the wrong audience.
- **Assume CUE as well.** Rejected: OPM asks its users to read and write CUE, but most arrive from Helm and YAML. A page that assumes unification or closedness loses them on the first sentence. Even the catalog's own maintainers keep written authoring rules for closedness and for disjunctions.
- **Define terms inline on each page instead of in a glossary.** Rejected: the same definition written in many places drifts. A link costs the reader one click and costs the writer nothing.

**Rationale:** Naming the audience makes "plain English" checkable. A reviewer cannot judge whether a page is plain enough in general, but anyone can tell whether it assumes a term the reader does not have. The Kubernetes comparison that KCP and Diátaxis both recommend only works if the reader knows Kubernetes, so the assumption and the voice rely on each other.

**Source:** User decision 2026-09-25. Evidence: [research/kcp-voice.md](research/kcp-voice.md), traits 1 and 2, and [research/findings.md](research/findings.md), the section on Diátaxis.

### D12: (retracted, 2026-09-25)

One vocabulary, as CUE data, generating the glossary and the linter's word lists. Retracted the day it was drafted: a hand-written vocabulary is no more tied to the definitions it names than a hand-written glossary page, so it did not fix the drift it was meant to fix. Number retired here.

### D13: Every writing rule names what checks it, and machine checks run in the owning repository's pull requests

**Kind:** contract

**Decision:** Each rule in the writing guide names what checks it: the page contract, the prose linter, the site build, a script that walks a tutorial, or review. A rule nothing checks is either assigned to review or left out of the guide.

A rule becomes a machine check only after review has caught the same problem twice. Machine checks run in the pull requests of the repository that owns the page, against one shared rule set. No repository keeps its own copy of the rules. A new machine check starts as a warning, and becomes an error once the existing pages pass it.

**Requirements:**

- R1: A page that breaks the page contract or an error-level writing rule fails the pull request in the repository that owns it, before merge.
- R2: Every repository checks its pages against the same shared rule set; none carries a copy that can diverge.

**Alternatives considered:**

- **A custom rule register and vocabulary in CUE, with a generated review checklist and generated word lists.** Drafted in this entry on 2026-09-25, with experiments showing both could be built, and withdrawn the same day. Rejected: CUE suits data shapes, not prose rules. A "checked by" column in the guide does the register's job, and review or a standard linter does the rest.
- **Check only when the site builds.** Rejected: the failure reaches the author after the merge, in a repository they do not watch. KCP avoids this only because each of its repositories builds its own site, which D8 rejects.
- **Copy the rules into every repository and keep the copies identical with a sync check.** Rejected: the workspace already does this twice, for the fixture flow and for the doc-comment gate, and needs a dedicated lint task for each.
- **A guide with no machine checks.** Rejected: several repositories and agent sessions write pages, and agents follow a failing check more reliably than a guide.
- **New checks as errors from the start.** Rejected: a banned-word rule meets its exceptions within days, such as "just" in "just-in-time". An error that fires on correct prose teaches writers to switch the linter off.

**Rationale:** Naming the checker keeps the guide honest, the way D1's badges keep OPM's own rules honest: no rule claims more than whatever enforces it. The twice-caught threshold keeps tooling driven by evidence, not by what could be automated. Running checks where the page is written keeps the feedback in the pull request that caused the problem.

**Source:** User decision 2026-09-25.

Open Questions live in [`07-questions.md`](07-questions.md): the entry's question register.
