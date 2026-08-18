# Design — Documentation Architecture

Eight sections organised by what a reader is holding when they arrive, a hard split between generated facts and authored guidance, and an enforcement badge on every normative statement.

## Design Goals

- A reader with a specific artifact in hand (a blank file, a cluster, an error message, a field name) reaches the right page without knowing OPM's internal vocabulary first.
- Every normative statement answers "what actually stops me" visibly, because OPM enforces across four layers and the gaps between them are where users get hurt.
- Reference content that can be derived from source is derived from source, so that a rename cannot silently invalidate it.
- The documentation states what OPM does today and is explicit about what it does not do, so that nine draft systems do not read as features.
- Explanation is a first-class section rather than an appendix, in proportion to a concept surface that is unusually large relative to the user surface.
- The abstraction family is the documented default path; the raw passthrough family is reachable and clearly marked as the escape hatch.

## Non-Goals

- Publishing `core/SPEC.md`. It stays contributor-facing (D2).
- Documenting secrets. The current vocabulary has a known expiry and enhancement 0013 owns its replacement, including the documentation (D5).
- Documenting draft systems as features. Lifecycle hooks, workflows, provider classes, export, rollback and reverse handoff do not exist.
- A migration guide from the v0 line. The v0 fleet is frozen on its own branch and its consumers are internal.
- Site theming, search, or the Hugo theme decision. Presentation, not architecture.

## High-Level Approach

The organising question is what the reader has in their hands, not what genre the content belongs to. Genre (tutorial, guide, reference, explanation) still governs how a page is written; it does not govern the top-level navigation, because OPM's audiences are close to disjoint and a genre-first split forces each of them to filter every section.

```
reader arrives with...            section                      dominant genre
--------------------------------------------------------------------------------
nothing, evaluating           1. Start here                tutorial
a question about why          2. Concepts                  explanation
a blank module file           3. Authoring modules         guide + reference
a cluster                     4. Deploying and operating   guide
a vocabulary gap              5. Extending OPM             guide (advanced)
a Go program                  6. Embedding the kernel      guide (narrow)
a field name                  7. Reference                 generated
an error message              8. Diagnostics               reference (authored)
```

Two of those placements are deliberate and worth stating.

**Diagnostics is top-level because it is an entry point.** A reader arrives from an error string pasted into a search box, not from navigation. The kernel's error taxonomy is unusually well structured and maps to genuinely different fixes: an unresolved demand, an unhandled trait, an identity mismatch and a materialize failure are four distinct problems that a reader cannot tell apart from the message text alone. This section also carries the "why does a render now fail that used to succeed" question, whose answer is that the render was under-delivering rather than succeeding.

**Concepts is large, and that is proportionate.** The `core` survey ranked seventeen concepts as subtle enough to need prose. The top four are the four version-shaped axes, `fqn == modulePath` for artifacts, `matchLabels` versus `metadata.labels`, and the component derivation rule. Each of these has a measured failure story behind it in `SPEC.md`'s Rationale, which is the raw material for these pages.

### Generated facts, authored guidance

The split is decided per field, not per page. A page may contain both, with the generated block clearly delimited.

```
GENERATED FROM SOURCE                      AUTHORED BY HAND
-------------------------------------      ---------------------------------------
name, apiVersion, fqn, modulePath          which blueprint to start from, and why
description (metadata.description)         which traits are legal on which blueprint
category label                             cross-member interactions
spec key and schema shape                  the matching story end to end
trait `optional` posture, `appliesTo`      family guidance (abstraction vs raw)
blueprint composed sets, matchLabels       every Concepts page
which transformers serve a member          every Diagnostics entry
worked examples (transformer golden tests)
CLI command reference (cobra)
```

The precondition is smaller than it looks. `metadata.description` is populated on all 70 catalog members; the reason `src/INDEX.md` shows empty descriptions is that its generator is a text scraper reading CUE doc comments rather than an evaluator reading the field. Switching to evaluation yields 70 of 70 one-line descriptions at no authoring cost. Hand-written doc comments then carry only what a one-liner cannot: why `exactName` and `immutable` conflict, why `podMetadata` exists, what `clusterIP: "None"` means.

### Enforcement badges

Every normative statement in Reference and in Concepts carries a badge naming the layer that enforces it:

```
cue         CUE unification refuses it. Fails at `cue vet`, before any OPM tool runs.
kernel      The kernel refuses it at render. Fails at vet, build, plan, apply.
publish     A publish gate refuses it. Fails at `opm module|catalog publish`.
convention  Nothing checks it. Stated because a reader must know it anyway.
```

The badge vocabulary is defined in `schemas/target.cue` so that it is a closed set rather than prose. Its value is highest exactly where `SPEC.md` is currently wrong in both directions: the layering contract's rules are MUSTs with a `convention` badge, and the publish gates moved from unenforced to `publish` when the CLI slices landed.

### The abstraction family leads

Reference splits by family rather than presenting 38 resources as one list. The abstraction family (11 resources, 27 traits, 5 blueprints) gets full pages. The raw `k8s-*` family (27 resources) gets one index page plus a generated table, labelled as the escape hatch, each entry pointing at the abstraction that covers the same ground where one exists. Blueprints lead the authoring track, since a component cannot render without one answering its matching key.

The framing is a fact about the system rather than an editorial preference: no first-party module imports the raw family, and `task vet:layering` in `catalog_opm` fails the build if an abstraction member depends on one.

## Schema / API Surface

`schemas/target.cue` states four shapes: the section taxonomy with its reader-state entry condition, the enforcement badge vocabulary, the generated-versus-authored field classification for a reference entry, and the doc-comment obligation a catalog member must satisfy to pass the CI gate. Stating them in CUE makes the taxonomy testable before any page exists, and gives the generator a contract to emit against.

## Integration Points

| Repo | What changes |
| --- | --- |
| `opmodel.dev` | All site content; the `docgen` generator (evaluate CUE rather than scrape comments, emit enforcement badges, split reference by family); the broken `generate:cli` step |
| `catalog` | Doc-comment backfill on blueprints, abstraction resources and traits; a CI gate refusing a new member without one |
| `core` | Doc-comment backfill on the roughly 35 definitions that have no `SPEC.md` section, `types.cue` foremost |
| `cli` | Command help text aligned with the generated reference; `cli/docs/STYLE.md` amended (it cites commands that no longer exist and links the glossary by a workspace-relative path its own sibling rule forbids) |
| `library` | `docs/getting-started.md`, which omits the mandatory Materialize step and therefore cannot be followed to working code |

The `opm` meta repo holds the stale prose this entry replaces, but `opm` is not a member of the area vocabulary in `enhancements/schema.cue`, so it cannot own a slice. Its retirement is tracked in `06-operational.md` and raised as OQ4.

## Before / After

**Before.** A reader searching for OPM documentation finds `opm/docs`, follows a getting-started that describes a schema line retired in April, copies examples that do not compile, and hits an error the documentation does not mention. The material that would have helped exists in a CLI README, a contributor specification and seventeen embedded transformer tests.

**After.** The same reader lands on a site whose first section takes them to a rendering module. When their next component fails, the error string leads to a page naming the cause and the fix. When they ask why a component needs a blueprint, an explanation page answers with the measured reason. When they look up a trait, the entry states its spec, its posture, which transformers consume it and what enforces each claim. When they wonder whether OPM runs lifecycle hooks, a page says plainly that it does not.
