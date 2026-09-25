# The KCP documentation voice

Captured 2026-09-25, for review. This is the voice the OPM documentation takes as its model: what KCP's pages sound like, measured and quoted, and what OPM keeps, adapts or drops. Page structure and page types are out of scope here; they are D7 to D9.

**Source.** The kcp repository at tag `v0.33.0` (commit `1a4cb725`, 2026-09-15), the 77 Markdown pages under `docs/content/`, generated reference excluded. Counts are over prose only: front matter, code blocks, tables and headings removed, inline code replaced by a placeholder. About 63,000 words.

**The model is KCP's Concepts and Setup pages, not the whole site.** The Developers section reads like internal notes and is measured separately below to show the difference.

## The voice in one paragraph

KCP writes like a Kubernetes engineer explaining their project to another Kubernetes engineer. The product is the subject of the sentence, and each idea is placed against something the reader already runs: a namespace, a CRD, an API server. It talks to the reader directly, guesses the question they are about to ask, and answers it. It says what a page assumes and what it covers before it starts. It is candid about what does not work. It is conversational, with contractions and the occasional "let's". Its weaknesses are the ones conversational writing tends to have: promises about later work, filler words like "simply" and "just", Latin abbreviations, and a long tail of sentences that run on.

## Measurements

| Measure | Concepts | Developers | Whole site |
| --- | --- | --- | --- |
| "you" per 1,000 words | 8.7 | 2.4 | 8.5 |
| "we" per 1,000 words | 4.1 | 8.0 | 5.4 |
| Median sentence length in words | 16 | 21 | 16 |
| Sentences over 30 words | 12% | 28% | 14% |
| Contractions per 1,000 words | 6.5 | 3.3 | 6.2 |

Whole-site counts of individual markers:

| Marker | Count | Per 1,000 words |
| --- | --- | --- |
| "Kubernetes" | 319 | 5.1 |
| "e.g." and "i.e." | 121 | 1.9 |
| "should" | 87 | 1.4 |
| "you can" | 83 | 1.3 |
| "simply", "easily", "just" | 70 | 1.1 |
| "might" | 52 | 0.8 |
| Sentences starting "If you" | 37 | 0.6 |
| "let's", excluding "Let's Encrypt" | 24 | 0.4 |
| "in the future" | 9 | 0.1 |

## Keep

**1. The product is the subject, placed against Kubernetes.** Most Concepts and Setup pages open by saying what kcp does, relative to Kubernetes, in one sentence:

> "kcp implements the same authentication mechanisms as Kubernetes, allowing the use of Kubernetes authentication strategies."

> "kcp includes some, but not all, of the APIs you are likely familiar with from Kubernetes:"

> "Within workspaces, kcp implements the same RBAC-based authorization mechanism as Kubernetes."

Of the 42 Concepts and Setup pages that open with prose, 14 open with kcp doing something ("kcp implements…", "In kcp, a request…"). Most of the rest open with a one-line statement about the thing the page covers, such as "Workspaces have a type." Four open with "This document…", and they read as the weakest openings on the site. OPM keeps this: a page opens by saying what OPM does, and relative to what.

**2. Analogies, labelled, with the point where they stop.** KCP reaches for the nearest thing the reader already knows, inside Kubernetes and outside it:

> "A logical cluster is able to amortize the cost of a new cluster to be near-zero memory and storage (similar cost as a namespace)"

> "Workspace mounts allow you to mount external Kubernetes-like API endpoints onto a workspace, similar to how you mount remote filesystems in Linux using NFS."

It sometimes labels the device outright, with a bold "**Analogy**:" before a comparison to Linux directories. The best examples also say where the comparison breaks: an APIResourceSchema "is almost identical to a CRD, but creating an APIResourceSchema instance does not add a usable API to the server." OPM keeps analogies and makes the second half mandatory: every comparison says where it stops holding.

**3. It answers the question the reader is about to ask.** KCP writes descriptions as questions ("What are workspace mounts and how do they work?"), and ends its tenancy tour with questions a reader would actually have:

> "Q: Why is there a new `APIResourceSchema` resource type that appears to be very similar to `CustomResourceDefinition`?"

OPM keeps the habit and moves it. A reader's "why" question becomes a heading on the explanation page that answers it, rather than a list of questions at the end of a tutorial.

**4. It says what a page assumes and what it covers.** The clearest example opens the WorkspaceType best-practices page:

> "Read those first — this page assumes you already know *how* the pieces work and focuses on *when* and *whether* to use them."

The quickstart does the same for the whole product: "kcp is not a platform you can simply pick up and use immediately. Instead, it's a framework for building platforms." OPM keeps this. It is what the "Before you begin" part of every template is for, and what the Start here pages do for OPM as a whole.

**5. It is candid about limits and misuse.** KCP states limits flatly and next to the thing they limit:

> "`service`-based validating/mutating webhooks are not supported; you must use `url`-based `clientConfigs` instead."

> "`WorkspaceType` is a powerful extension point in kcp, but it is also very easily misused."

OPM keeps this, and it is the voice for the deletion and prune hazard in D4.

## Adapt

**6. Conversational, but not chatty.** Contractions run at about six per 1,000 words. "let's" appears 24 times once "Let's Encrypt" is excluded, spread across the tenancy tutorial ("Let's verify that the resource provided by the `APIExport` is now available"), the architecture brain dump and several explanation pages. OPM keeps contractions everywhere and keeps "let's" for tutorials only, where Diátaxis wants the tutor and learner working together.

**7. Opinions, in the right place.** The best-practices page gives firm advice, and it is the most useful page on the site for someone designing with WorkspaceTypes. OPM allows opinion in explanation pages ("OPM checks this at render rather than at apply, because…") and never in reference.

**8. Hedges only for real uncertainty.** "should" and "might" together run above two per 1,000 words, and some of them soften a rule that is actually firm: "kcp should be conformant to the subset of the Kubernetes conformance suite that applies to the APIs available in kcp." OPM hedges only where the outcome genuinely varies ("depending on how your platform is configured"), and states rules as rules.

**9. The project is not a narrator.** "We provide a Helm chart to install kcp", "We're working with the upstream community", "We ❤️ our contributors!". The Developers section uses "we" twice as often as Concepts. OPM pages make OPM the subject ("OPM provides…"). "We" appears only in tutorials, meaning the reader and the page together.

**10. The reader's question, not the FAQ.** See 3. KCP's FAQ is good content in a weak place, after the tutorial where a reader who needed it has already left. OPM asks the question at the top of the explanation that answers it.

## Drop

**11. Promises.** "In the future, some form of automatic removal will be implemented." "We are working on extending this documentation further, to include multiple site deployment, …" "Not implemented at the moment." 0018 D3 rules all three out. OPM says what is true today, and "at the moment" becomes a flat statement.

**12. Hype and filler.** "If you're looking to provide APIs that can be consumed by multiple workspaces, this section is for you!" "if you have experience with operating Kubernetes, you can very easily apply it to kcp." "simply", "easily" and "just" appear 70 times. They tell the reader something should be easy, which helps nobody for whom it is not. OPM drops them, along with emoji and exclamation marks.

**13. Latin abbreviations.** "e.g." and "i.e." appear 121 times, often inside parentheses: "(e.g. client-go, controller-runtime, and others)". OPM writes "for example" and "that is", or restructures the sentence so it needs neither.

**14. Long sentences.** One sentence in eight in Concepts runs past 30 words, and more than one in four in Developers. The terminology page's conformance sentence runs 31 words. OPM keeps KCP's median, 16 words, and caps the tail; the number is OQ12.

**15. Uneven polish.** "it's own", "in-transtit", "indivudual" all sit on pages a new reader will open. OPM runs a spell check.

## The adaptation, applied

A KCP opening, as written:

> "If you're looking to provide APIs that can be consumed by multiple workspaces, this section is for you! kcp adds new APIs that enable this new model of publishing and consuming APIs."

The same opening, adapted: the reader's situation stated plainly, no exclamation, and the product as subject naming exactly what it adds.

> "This page is for API providers who want many workspaces to use one API. kcp adds three resources for it: an APIResourceSchema defines the API, an APIExport publishes it, and an APIBinding brings it into a workspace."

The voice applied to OPM, keeping traits 1, 2, 4 and 8:

> "A ModuleInstance is to a Module roughly what a Helm release is to a chart: one installed, configured copy, in one namespace. The comparison stops at the values. Helm renders your values into templates, and a mistake shows up when Kubernetes rejects the result. OPM checks your values against the module's configuration schema first, so a misspelled field fails before anything reaches the cluster."

## How this is used

The keep, adapt and drop lists are the voice section of the writing guide the `opm` repository will hold (D9, D13). The page templates in [`../drafts/templates/`](../drafts/templates/) already follow traits 1, 2 and 4. When the voice document from OQ7 exists, it refines this list from the author's own writing; this capture is the stand-in until then.
