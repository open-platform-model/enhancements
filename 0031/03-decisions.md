# Design Decisions: Module Presentation Contract

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they
are made. **Numbers are permanent**, never reused, never renumbered, because
other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** How that stays true depends on the entry's `status`:

- While the entry is **`draft`**, decisions are living text: a changed choice is an **in-place edit** to the existing `DN`, and the log never contains two conflicting decisions. If the replaced position was backed by real evidence (an experiment outcome, an explicit user decision), fold it into *Alternatives considered* (marked as previously adopted) before overwriting; a mere sketch may be replaced outright. A decision retracted outright keeps its number as a one-line tombstone (`### DN: (retracted, YYYY-MM-DD)`).
- Once **`accepted`**, decision bodies are **protected**. A change lands as a *new* `DN` with `**Amends:**` / `**Supersedes:**` relation fields; existing bodies are edited only through the `enhancement-compaction` skill, which weaves stacked reversals into the decisions they reverse (lower number survives, vacated number keeps a tombstone), at latest in the mandatory pass immediately before the `implemented` flip.
- **`implemented`** entries are frozen; **`superseded`** entries are stubbed via compaction.

Either way the log stays safe to read linearly: a reader who stops halfway should never come away believing something a later entry already killed.

Each decision carries a `**Kind:**` line plus the body fields: Decision, Requirements (numbered `Rn` items cited as `NNNN:DN:Rn`; `none` with a reason on a `policy` or `scope` decision), Alternatives considered, Rationale, Source. The Source field is specific: `"User decision YYYY-MM-DD"`, a URL, or a file path, so the provenance of a choice never gets lost. A decision revised in place or by a merge keeps its original `Source:` and gains a `Revised: YYYY-MM-DD` line. *Alternatives considered* always survives revision and compaction: it is what stops a rejected option being re-litigated later.

A decision that rests on another entry's decision also carries a `**Depends:** MMMM:DN` line (tokens only, comma-separated) directly after `Kind`, and `config.yaml.depends_on` lists exactly the entries those lines name; `task vet` enforces both directions and refuses a cycle. The test for whether the line is owed: *if that other decision were reversed, would this one need an `Amends:`?* If yes, it depends. A citation for precedent, contrast, or a delegated enforcement site is prose, not a dependency.

A decision that **changes** another entry's decision says so on the same relation fields it uses locally, with the token qualified: `**Amends:** MMMM:DN` when that decision survives narrowed, `**Supersedes:** MMMM:DN` when it is dead. `config.yaml.amends` lists exactly the entries those tokens name; `task vet` enforces both directions, requires a live heading, refuses a superseded or rejected target (amend the successor), refuses a cycle, and refuses one decision both depending on and superseding the same token. The amended entry is never edited, closed or not: `task show ID=MMMM` derives "amended by" from lines like these, so the reverse can never go stale and can say whether the change has landed. Depends is *I rest on it*; Amends is *I change it*; a decision may carry both for the same token when it narrows what it rests on.

**The Kind gate.** A decision belongs in this log only if it passes the admission test: *if every affected repo were rewritten from scratch, would this decision still bind the result?* Three kinds pass it:

- `contract`: changes what a consumer can observe or rely on: a schema shape, a command's semantics, a compatibility or refusal rule, a naming guarantee.
- `policy`: a posture OPM commits to ("publish never invents a version").
- `scope`: a boundary decision: what this entry defers, what a successor owns, what a supersession keeps.

A *mechanism* decision is how a repo achieves the contract: algorithm choice, code placement, internal wiring. It fails the admission test and belongs in the implementing slice's OpenSpec change in the target repo, decided when the code in front of the implementer is current. Measured evidence that *constrains* a contract (an experiment proving a primitive cannot express a rule) stays here, attached to the contract decision it constrains. The winning implementation design does not carry it.

**Prescriptive versus evidential.** The line that keeps mechanism out in practice: an entry never tells a repo *how to name a file, spell an identifier, lay out a directory, or structure its code*.

- Naming a path to **prove** something, or to say where something is emitted today, is evidence, and is wanted.
- The test: would deleting the named path change what an implementer is **obliged** to do, or only what a reader can **verify**? Obliged means prescription; it does not belong here. Verify means provenance; it stays.
- A decision may state that a name is part of the published contract (for example, a member name that reaches a key, or a command's flag) because that is what a consumer observes. It may not state what the file holding it is called.

---

## Decisions

### D1: Three authored layers and one derived listing; no new `#Module` field

**Kind:** scope

**Decision:** Presentation is three authored layers and one derived listing. The module author writes the card (in the module-file block) with its images (in the zip), and field hints with help text (on `#config`). The platform team writes curation (on the 0027 definition). The publisher's release pipeline derives the index from the cards. No layer is a 0025 aspect or module trait, and `#Module` gains no field.

**Requirements:** none (scope: the layers' contents and rules are D2 to D7)

**Alternatives considered:**

- **Typed presentation fields on `#Module.metadata`.** Rejected: reading them needs the zip and CUE evaluation, so a list view pays for every module, and every new field is a core release.
- **A 0025 aspect or the 0027 `offering` trait carrying the card.** Rejected for the same reason: an aspect is module content, read only after acquisition and evaluation. The `offering` trait stays the declaration 0027:D5 compares, which presentation is outside.
- **OCI manifest annotations as the card.** Rejected: OPM publishes through CUE's module registry client, which writes none; CUE tooling never reads them; no gate can validate them, and they are outside the module's content-addressed bytes.
- **A listing referrer per module.** Rejected as the source of truth: GHCR has no native referrers API, a referrer per module still lists nothing, and 0022:D1 already rejected a sidecar for drift. It may later sit beside the index as an accelerator.
- **One hand-authored UI schema beside `#config`.** Rejected: a second schema drifts from the one it describes, which is the problem 0027:D2 refuses a hand-authored CRD schema for.

**Rationale:** Each layer is owned by exactly one party and lives where its reader can afford to read it. The card is for list views, so it lives in the smallest fetch; hints and help text describe `#config`, so they sit on its fields; curation must change without a release, so it lives in the cluster; the index exists only to make listing cheap, so it is derived and never authored.

**Source:** User decision 2026-10-04 ("Propose layered direction": draft decisions for the author card in the 0022 block, field hints as `@opm(ui, ...)` attributes plus doc comments on `#config`, platform curation on the 0027 definition, and a published index module). Prior-art survey of ten package and service ecosystems (OLM, Cozystack, OpenShift catalog items, Open Service Broker, Artifact Hub, Helm, Crossplane, Kratix, Score, Backstage), portal design research 2026-10-04; summarised in `05-risks.md` Alternatives.

### D2: The author card is the `listing` key of the 0022 module-file block

**Kind:** contract

**Depends:** 0022:D1

**Decision:** A module's author card is an optional struct at key `listing` inside its module-file block, `custom."opmodel.dev@v0"` in `cue.mod/module.cue`. It carries its own `schemaVersion` (1 here), independent of the block's `@v0` suffix. Its fields and caps are `#Listing` in `schemas/target.cue`: required `title`, `summary` and `category`; optional `keywords`, `icon`, `screenshots`, `readme`, `links` (each URL at most 256 runes), `maintainers`, `vendor`, `license` and `deprecated`; `locales` reserved. The card is author-supplied, so the publish gate validates it rather than asserting it against another source, and never edits it. Beside the field caps, a separate size line refuses a card whose canonical JSON encoding exceeds 8 KiB. The caps are set so that a card at every cap passes the size line.

**Requirements:**

- R1: A module's card is readable from its module file alone, with no zip download and no CUE evaluation.
- R2: A card missing `schemaVersion`, `title`, `summary` or `category`, or exceeding any field cap, is refused at publish, naming the field.
- R3: A card whose canonical JSON encoding exceeds 8192 bytes is refused at publish, naming the size; a card with every field at its cap is not.
- R4: A card carrying `locales`, image bytes, a data URI or an image URL is refused at publish.
- R5: A reader that does not know `listing` ignores it, and a reader shows the fields it knows of a card whose `schemaVersion` is newer than it knows; no reader refuses a module for its card.
- R6: A module without a card publishes exactly as it would without this entry.
- R7: Publish never edits a card.

**Alternatives considered:**

- **Link URLs capped at 512 runes with the 8 KiB cap as the only total check** (the first draft). Measured: a card at every cap was 8,486 bytes, over its own cap, so the caps contradicted each other. Lowering the URL cap to 256 and the maintainer list to five brings a card at every cap to 7,099 bytes (`schemas/examples.cue`), and the size line stays as a separate check so a later card version cannot outgrow the cap unnoticed.
- **A larger cap, or none.** Rejected: every consumer re-fetches the module file on every dependency resolve, and a 1 MiB block measured as publishable shows nothing else would stop it.
- **Versioning the card with the block's `@v0` suffix.** Rejected: a breaking card change would force the whole block to a new key that 0022's own readers must then learn.
- **Asserting the card against `#Module.metadata.description`.** Not decided here: OQ14 holds it.

**Rationale:** The module file is the one part of a published module that is small, fetched without the zip and readable without CUE, which is exactly what a list view needs. 0022 opened it for OPM's block and anticipated later readers and keys; the card is the first author-supplied, non-derived key in it, so it is validated where 0022's keys are asserted. Measured on 20 real modules: the card survived tidy value-intact 20/20 and vetted 20/20 at 471 to 585 bytes.

**Source:** User decision 2026-10-04 (author card in the 0022 module-file block). `experiments/02-listing-card/` (E4a, E4b). The block is admitted by older gates only through 0022's open tail, a revision of 0022 made in place while it is draft.

### D3: Card images are files under `assets/` in the module zip

**Kind:** contract

**Decision:** A card names its icon and screenshots by zip-relative path under a top-level `assets/` directory of the module zip. Publishing a module with a card adds no layer, annotation or referrer: the manifest keeps its two layers. An icon is SVG or PNG and at most 64 KiB; a screenshot is PNG, JPEG or WebP, at most 512 KiB, and at most four per card. Publish refuses an SVG that can run script or load anything: a script, an event attribute, a reference that is not a same-document fragment, a style that imports or loads a URL, an embedded document, or an external entity. Every OPM UI renders a module-supplied image so that nothing in it executes in the page.

**Requirements:**

- R1: Publishing a module with a card adds no layer, annotation or referrer to its manifest.
- R2: A card path that names no file in the zip, a file of the wrong format, or a file over its cap is refused at publish, naming the path.
- R3: An SVG asset that carries script, an event attribute, an external reference, a URL-loading style or an embedded document is refused at publish, naming the element.
- R4: Every OPM UI renders a module-supplied image so that no image content executes in the page.

**Alternatives considered:**

- **Image URLs in the card.** Rejected: a URL breaks on an air-gapped or sovereign platform and can change after release, while a path inside the immutable zip cannot.
- **Data URIs in the card.** Rejected: the module file is fetched on every dependency resolve, so image bytes there are paid by every consumer.
- **A third OCI layer or an image referrer.** Rejected: CUE's client refuses a module manifest that does not have exactly two layers, and GHCR has no native referrers API.
- **Sanitising SVG at render only.** Rejected as the only defence: a reader that skips the step runs the script. Refusal at publish and inert rendering are each a layer a bad actor must defeat.

**Rationale:** The zip is the one carrier that costs nothing in the OCI shape and works on every registry and mirror. The cost is that the zip is downloaded whole on every render fetch, so the caps are small: the worst case adds about 2.1 MiB to a module version. Measured: an `assets/icon.svg` ships inside the published zip unchanged.

**Source:** User decision 2026-10-04 (card images as files in the zip, two-layer manifest kept, scripted SVG refused, inert rendering). `experiments/02-listing-card/` (E4a). Carriage measured in the portal design research 2026-10-04 with cue v0.17.1, Zot v2.1.21 and `registry:2` 2.8.3: the zip includes `.png` and `.svg` files unfiltered up to 500 MiB, and GHCR returns 404 on the referrers endpoint.

### D4: Field hints are `@opm(ui, ...)` attributes from a closed, versioned vocabulary; a field may carry several `@opm` attributes

**Kind:** contract

**Depends:** 0013:D2

**Amends:** 0013:D2

**Decision:** A field hint is a CUE field attribute on a `#config` field, in the `@opm` namespace, with `ui` in position 0 and `key=value` pairs or bare flags after it. An optional `v=<int>` names the vocabulary version the hint targets; absent, it is 1. Vocabulary version 1 is the nine keys of `contracts/hints.cue`: `title`, `group`, `order`, `widget`, `advanced`, `hidden`, `placeholder`, `options` and `discriminator`. A hint never states or changes a constraint: no `visibleWhen`, no `sensitive` (a secret is core's tagged `#Secret` type), no `description` (help text is D5), no `default`, `required` or bounds. Choices that are values come from the field's own disjunction; `options` names only a source of names the user can list.

What survives of 0013:D2: the `@opm` name, dispatch on position 0, and secret discovery ignoring a position 0 other than `secret`. What changes against it: a field may carry several `@opm` attributes, one per kind, and every reader of any kind considers every `@opm` attribute on the field. No reader acts on only the first.

The gate's refusal scope keeps a newer vocabulary from breaking an older gate. On a field the module itself declares, an unknown key at a version the gate knows, a malformed value, an incompatible widget, or any attribute form `contracts/hints.cue` lists as refused fails publish. On a hint a field inherits from a dependency, the same findings are warnings. A hint with a `v` newer than the gate knows is a warning, and its keys are not judged. Readers ignore keys they do not know.

**Requirements:**

- R1: A hint written as `@opm(ui, ...)` on a `#config` field reaches every reader of the published module after publish and acquisition, unchanged.
- R2: A field carrying both `@opm(secret, ...)` and `@opm(ui, ...)`, in either order, is discovered as a secret and rendered with its hints; no reader acts on only the first `@opm` attribute of a field.
- R3: On a field the module declares, a hint with an unknown key at a known vocabulary version, a malformed value, an incompatible widget, `advanced` or `hidden` on a required field, a position 0 that is not exactly `ui`, a duplicate key, a second `@opm(ui, ...)` attribute, or a flag written with a value is refused at publish, naming the field and the finding.
- R4: A hint finding on a field inherited from a dependency, or on a hint whose vocabulary version is newer than the gate knows, is a warning and never a refusal.
- R5: No hint changes which values `#config` accepts.
- R6: A reader ignores a hint key it does not know.

**Alternatives considered:**

- **A separate attribute name, such as `@ui(...)`.** Rejected for the reason 0013:D2 gives: a second attribute namespace for the second concept, and a third for the third. One name with a dispatch slot scales.
- **Hints as vendor keywords inside the served CRD schema** (`x-opm-ui`, as several surveyed portals do). Rejected: measured, the Kubernetes API server's strict decoding refuses a CRD carrying `x-opm-ui`, and lenient decoding drops it silently; and a binding-only definition has no CRD at all. Where hints travel instead is OQ10.
- **A UI-only `visibleWhen` condition.** Rejected: the form and the API server would disagree about what is valid. A conditional field is a discriminated union in `#config`, rendered as OQ9 decides.
- **A required `v=` on every hint.** Rejected: noise on every hinted field for a version that rarely changes. An absent `v` is unambiguous while version 1 is the first, and a module targeting a later vocabulary states `v`, which is what lets an older gate warn instead of refuse.
- **Reading only the first `@opm` attribute, as the single-attribute accessor does.** Measured wrong: it returns only the first, so a hint written before the secret marker hides the secret.

**Rationale:** A hint sits next to the field it describes, in the namespace OPM already uses, and survives every path a module travels. Refusing on the module's own fields catches a typo that would otherwise silently do nothing; warning on inherited ones keeps a catalog released against a newer vocabulary from making every dependent module unpublishable under an older CLI.

**Source:** User decision 2026-10-04 (field hints as `@opm(ui, ...)` attributes on `#config`). `experiments/01-ui-hint-attributes/`: E2a (30 hinted fields survive publish and acquisition byte-identical; the field-attribute accessor returns both `@opm(ui, ...)` and `@opm(secret, ...)` on one field while the single-attribute accessor returns only the first), E2c (27 parse cases behind the refused forms), E2d (the CRD strict-decoding refusal). `contracts/hints.cue`.

### D5: Help text is the field's doc comment, the module's before the catalog type's, and core's never; type-level hints reach every field typed by the type

**Kind:** contract

**Decision:** A field's help text is its doc comment. The module author's own comment wins; when the author wrote none, the comment of the catalog type the field is typed by is used; core's comments on `#config` and `#Module` never surface. The first paragraph is the short help shown with the input, and the rest is detail. A comment separated from its field by a blank line is not a doc comment in CUE, and stays internal.

A catalog type may carry default hints for every field typed by it: as a declaration attribute inside the type's body, as field attributes on its sub-fields, or as a field attribute on a scalar definition. A reader collects them by following the field's references to the type, so they reach the field whether it unifies the type with a literal, embeds it, names it bare, or reaches it through a disjunction arm, a list element or a map value. Where the module's hint and the type's set the same key, the module's wins, key by key. Origin decides precedence, never the order in which CUE reports attributes or comments.

**Requirements:**

- R1: A field's help is its own doc comment; absent one, the doc comment of the catalog type it is typed by; core's comments never appear as help.
- R2: The first paragraph of a field's help is its short help and the remaining paragraphs are its detail.
- R3: A hint a catalog type carries reaches every module field typed by that type, including a field that names the type bare, through a disjunction arm, or as a list or map element.
- R4: Where a module's hint and its catalog type's hint set the same key, the module's value is the one every reader shows, whatever order the two are reported in.

**Alternatives considered:**

- **A separate help-text key in the hint vocabulary.** Rejected: doc comments are already written (heavy prose in all 19 modules sampled), and a second channel would drift from the first.
- **Every comment that unifies onto the field, in reported order.** Measured wrong: core's "Value schema ... MUST be OpenAPIv3 compliant" comment surfaces as root help text on half the corpus.
- **Reading a type's hints only through the declaration-attribute accessor** (the first draft). Measured incomplete: a type-level attribute reaches the field only when the type is unified with a literal, embedded or reached through a `let`, and is lost for a bare reference, a disjunction arm, list and map elements and nested bare references; a field attribute on a scalar definition never reaches a field typed by it. Following references recovers all of them after kernel acquisition, across packages.
- **Relying on CUE's reported order, module before catalog** (the observed order). Rejected: it comes from an undocumented internal order, and an attribute carries no position.
- **Dropping catalog-type hints from the vocabulary.** Rejected for now: a catalog's image type is the best place to say "render me as an image picker" once for every module. The cost is a reader rule, not an author burden.

**Rationale:** Help text must come from the person who knows the field, and the catalog type's text is the right fallback for a field the module only reuses. Core's text is written for schema authors, never for the person filling in a form. Type-level hints need the reference-following rule, because the measured CUE behaviour otherwise drops them on the most common way modules use catalog types, a bare reference.

**Source:** User decision 2026-10-04 (doc comments as help text on `#config`). `experiments/01-ui-hint-attributes/`: E2b (accumulation order, the lost-reference cases and their recovery by following references), E2d (doc-comment order and core's leaking comment).

### D6: The 0027 definition carries `presentation`, which overrides the author field by field and is inert

**Kind:** contract

**Depends:** 0027:D1, 0027:D6

**Decision:** The platform-owned definition of entry 0027 may carry `presentation`, shaped as `#OfferingPresentation`: display name, summary, description, category, tags, icon (a data URI checked by D3's SVG rules), weight, featured, hidden, presets, and per-field layout overrides keyed by config path. Every field is optional. A set field replaces the author's value in every UI; an unset one falls through to the author's card and hints. Per-field overrides change layout only (title, group, order, advanced, hidden), never a widget or a validation, and `advanced` or `hidden` only on optional or defaulted fields. A preset is checked at acceptance through the definition's own projection (0027:D6) with its bound values. Changing presentation re-renders no instance, rebinds nothing and changes no served schema. Disagreement between presentation and the module's card or hints is the point of the block and is never reported. Presentation is outside the offering declaration that 0027:D5 compares.

Whether 0027 admits the field by revising 0027:D1 in place or after acceptance is 0027:OQ17.

**Requirements:**

- R1: A presentation field set on a definition replaces the author's value in every OPM UI, and an unset one falls through to the author's value.
- R2: Changing a definition's presentation re-renders no instance, rebinds nothing, and changes no served schema.
- R3: A definition whose preset values, unified with its bound values through the projection, would be refused is itself refused at acceptance, naming the preset.
- R4: A hidden definition is listed by no marketplace, and its kind keeps serving.
- R5: A per-field override that names a widget or a validation, or sets `advanced` or `hidden` on a required field, is refused at acceptance, naming the path.
- R6: No difference between a definition's presentation and the module's card or hints is reported as drift.

**Alternatives considered:**

- **A registry-side overlay that edits a published module's card.** Rejected: a published version is immutable (0011:D15), and an overlay would make the card say two things depending on who reads it.
- **Presentation on the Platform resource.** Rejected for the reason 0027:D1 rejects binding there: every offering change would become a Platform edit with its regeneration blast radius.
- **Presets checked against the served structural schema.** Rejected: the served schema is a lossy subset of `#config` (measured, `experiments/04-served-schema-boundary/`), so a preset that passes it can still fail every order made from it.
- **Letting the platform change widgets.** Rejected: a widget is the author's statement about the field's meaning; the platform's need is naming and arrangement.

**Rationale:** The definition is the one layer a platform owns and can change without a module release, which is what "the logo is wrong today" needs. Inertness is what keeps a label change from being an operational event.

**Source:** User decision 2026-10-04 (platform overrides and curation on the 0027 definition). Prior art: Cozystack v1.6.4 carries presentation (`spec.dashboard`: category, weight, description, icon, tags) on a cluster-scoped, platform-authored application definition, read from its source in the portal design research 2026-10-04.

### D7: The first-party index is a CUE module at the reserved path `opmodel.dev/modules/index`; any other index is read only when configured

**Kind:** contract

**Amends:** 0011:D13, 0011:D14

**Decision:** An index is a CUE module whose package holds data that validates against `#ListingIndex`: per member module path with major, the newest version on that major, its manifest digest, a verbatim copy of its card, and an optional thumbnail derived from its icon. The publisher's own release pipeline builds and publishes it. It is a snapshot, never an edit point. `opmodel.dev/modules/index` is reserved for the first-party index, by curation, as 0011:D25 reserved `index` inside the templates segment. Third-party and community indexes live at any path their publisher chooses; nothing outside first-party space is refused for using the name, and a reader reads such an index only when configured with its path. An index is a hint, not the truth: a reader checks each member's tags for a newer release on the same major.

What survives of 0011:D13 and 0011:D14: OPM imposes no namespace on third parties, and first-party space keeps its segments. What changes: first-party modules space gains one reserved name. 0011:D5's surviving holding, that OPM's registry hosts rather than indexes foreign hosts, is untouched: an index is one more hosted module, and resolution still goes through the registry configuration.

**Requirements:**

- R1: An index validates against core's index schema, and every entry's card and digest equal the member's module file and manifest digest at that version; an index that disagrees is refused at publish.
- R2: Nothing but the first-party index is published at `opmodel.dev/modules/index`.
- R3: No publish outside first-party space is refused for its use of the name `index`.
- R4: An index is mirrored by the same copy that mirrors its members, with no registry extension, and a reader marks an entry its mirror lacks instead of failing.
- R5: A reader detects a member release newer than its index entry without the index being republished.
- R6: A reader reads an index outside first-party space only when it is configured with that index's path.

**Alternatives considered:**

- **A reservation under every publisher's prefix.** Rejected: 0011:D13 says OPM does not arbitrate names it does not own, and a third party's paths are arbitrary, so "a publisher's modules prefix" is undefined for them.
- **A listing referrer per module.** Rejected as the listing: one fetch per path still lists nothing, and GHCR has no native referrers API. It may sit beside the index if 0023's work proves the fallback tag on GHCR.
- **Registry search (Zot GraphQL) or `/v2/_catalog`.** Rejected as the contract: Zot-only and blind to CUE card data, and GHCR's catalog is one list of all of GHCR. A reader may use search as an accelerator.
- **A central index service.** Rejected: it does not fit air gaps, and the central registry is undecided.
- **Thumbnails required.** Rejected: measured, they grew the published zip 3.7 times and forced the builder to download every member zip.

**Rationale:** A CUE module is published, resolved, cached and mirrored by the tooling every OPM user already has, identically on GHCR, Zot, a plain registry and an air-gapped copy. Measured on 20 real modules: a cold reader lists all 20 cards in 3 direct requests against 60 for crawling module files, and a mirror copy of the index with its members resolved with digests intact.

**Source:** User decision 2026-10-04 (a published index module for listing). `experiments/03-index-module/` (E4c). Reservation precedent 0011:D25.

Open Questions live in [`07-questions.md`](07-questions.md), the entry-wide question register with its own numbering and status rules.
