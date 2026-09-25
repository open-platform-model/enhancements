# Findings: how documentation is structured and written

Gathered 2026-09-24 for D7 to D10. Three sources: the KCP documentation as a working example of a Kubernetes-adjacent project's docs, Diátaxis for page types, and the Write the Docs guide for where documentation lives. Facts are marked as measured or quoted. What this entry takes from them is kept apart, at the end.

## KCP documentation

**Source.** The kcp repository at tag `v0.33.0` (commit `1a4cb725`, 2026-09-15), its `docs/` tree read directly, plus the live version lists at `https://docs.kcp.io/kcp/versions.json` and `https://docs.kcp.io/kcp-operator/versions.json`. The rendered site is `https://docs.kcp.io/kcp/v0.33/`.

### Site model (measured)

- **One site per repository.** `docs/mkdocs.yml` sets `site_url: https://docs.kcp.io/kcp/`. The kcp-operator and api-syncagent projects publish their own sites under their own paths. The kcp landing page links them from a tip box: "Looking for subproject documentation? Check out: api-syncagent | kcp-operator".
- **Versions are per site.** Each site is versioned with `mike` by `vMAJOR.MINOR`. The `latest` alias goes to the highest stable tag. On 2026-09-24 kcp's `latest` was `v0.33` and kcp-operator's was `v0.9`: two independent version lists for one product.
- **Navigation is by persona, then by product architecture.** The top tabs are Home, Setup, Concepts, Developers, Contributing and Reference. Concepts is split by subsystem: Workspaces, APIs, Authentication, Authorization, Sharding.
- **Types mix inside sections.** "Quickstart: Tenancy and APIs", a step-by-step lesson, sits inside Concepts. "Architecture – A Brain Dump" also sits in Concepts. Developers carries an Investigations group with load-test reports.
- **Reference is generated.** The CLI reference and the CRD reference come from two generators under `docs/generators/`. The Reference index says: "This chapter provides automatically generated references".

### Mechanisms (measured)

- **Section indexes are generated from descriptions.** A macro, `section-overview.html`, lists a page's siblings with their `description` front matter. Section index files hold only a heading and that macro.
- **Descriptions are not required.** 50 of 77 Markdown pages carry a `description` in their front matter. A page without one appears on its section index as a bare title.
- **The build is strict, and one tutorial is tested.** The docs workflow appends `strict: true` to the MkDocs config before building, and builds on pull requests without publishing. `docs/scripts/verify-docs-quickstart-kind.sh` walks the kind quickstart.

### Writing (quoted and measured)

- **Concepts are defined by comparison with Kubernetes.** A logical cluster has "near-zero memory and storage (similar cost as a namespace)". An APIResourceSchema "is almost identical to a CRD". The terminology page adds: "if you have experience with operating Kubernetes, you can very easily apply it to kcp."
- **Expectations are set on the first page.** The quickstart opens: "kcp is not a platform you can simply pick up and use immediately. Instead, it's a framework for building platforms."
- **Commands are followed by their output.** The tenancy quickstart follows commands with "Output should look similar to below" and a console block.
- **Admonitions carry limitations.** Notes state what does not work yet, for example that upstream controller-runtime does not support multi-cluster reconciliation.
- **The voice is measured separately.** Person, register, sentence length, hedges, analogies and promises are measured and quoted in [kcp-voice.md](kcp-voice.md), sorted into what OPM keeps, adapts and drops.
- **Length and polish vary.** Most concept and setup pages run 300 to 2,500 words. The longest, the architecture brain dump in Concepts, runs 6,197. Typos sit on key pages: "it's own" on the terminology page, "in-transtit" and "indivudual" on the production setup page.

## Diátaxis

**Source.** `https://diataxis.fr/`, every navigation page fetched 2026-09-24. Full notes are kept in the workspace's `research/docs-writing/diataxis/`, which is not under version control, so the points this entry relies on are restated here.

- **Four types from two questions.** Does the content serve action or cognition? Does it serve study or work? Action and study is a tutorial, action and work a how-to guide, cognition and work reference, cognition and study explanation (`/compass/`).
- **Types blur into their neighbours.** The worst case is tutorials and how-to guides collapsing into one, so neither need is met (`/map/`, `/tutorials-how-to/`).
- **Each type has its own rules.** A tutorial gives a visible result at every step and keeps explanation to a line and a link (`/tutorials/`). A how-to guide assumes competence and follows the user's goal, not the tool's features (`/how-to-guides/`). Reference describes and only describes, in a structure that mirrors the product (`/reference/`). Explanation answers why, and a title for it reads naturally after "About" (`/explanation/`).
- **Do not scaffold empty sections.** Creating empty tutorial, how-to, reference and explanation sections up front is named directly: "Don't do that. It's horrible." Structure should grow from improvements to real content (`/how-to-use-diataxis/`).
- **Each type has its own language.** Tutorials use "we" for the learner and the tutor together, and "The output should look something like…". How-to guides use conditional imperatives: "If you want x, do y." Reference states facts and plain rules: "You must use a. Never d." Explanation weighs and compares: "An x in system y is analogous to a w in system z. However…" (the per-type pages above).
- **Limit.** Diátaxis describes itself. It says what good documentation is and offers no evidence that following it works.

## Write the Docs

**Source.** `https://www.writethedocs.org/guide/`, fetched 2026-09-24 from its source repository. Full notes are in the workspace's `research/docs-writing/writethedocs/`.

- **Nearby:** "Store sources as close as possible to the code which they document."
- **Unique:** "Eliminate content overlap between separate sources." Several sources are fine when each one's scope is clearly defined and disjoint from the others.
- **Complete:** "Within each publication, cover concepts in full, or not at all." A map showing half the fire hydrants is worse than one showing none.
- **Skimmable:** descriptive headings, descriptive link text, and each paragraph starting with the concept it is about.
- **Where the two sources disagree.** Write the Docs recommends templates so every project answers "where do I put it" at once. Diátaxis forbids empty scaffolds. They are compatible when a template is guidance for writers and never an empty published page.

## What this entry takes from them

These are recommendations, not facts:

- **From Diátaxis, the type of every page, and a shape per type.** Taken in D7 and D9. The top level stays keyed to reader state, as decided before this research.
- **From KCP, the writing and not the site model.** Defining by Kubernetes comparison, setting expectations early, and showing output after every command are written into D9's shapes. Generating section indexes from description lines is taken in D7, with the description made mandatory because KCP's optional one leaves 27 pages as bare titles. The one-site-per-repository model is rejected in D8.
- **From Write the Docs, placement.** Nearby becomes D8's owning-change test, and Unique becomes D10's single source for member notes.
- **From KCP's Concepts pages, the voice, and from Diátaxis, the register.** Taken in D11 and in [kcp-voice.md](kcp-voice.md): the reader is addressed as you, ideas are introduced through Kubernetes, and each type keeps its own language. KCP's Developers pages, its promises and its long sentences are what OPM drops.
- **From the scaffold disagreement, the no-placeholder rule.** D8 lets a section appear only once it has a real page. The initial inventory in the design is a sizing aid for exactly that reason.
