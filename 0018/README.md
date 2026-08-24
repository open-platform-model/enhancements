# Enhancement 0018 — Documentation Architecture

OPM has no usable public documentation, and not for want of writing. The largest body of prose in the workspace describes the v0 catalog line, was last touched in April, and contains 121 references to an artifact renamed four months ago. Meanwhile the material that is current sits where no reader looks: a CLI README, a contributor specification, and worked examples embedded inside catalog transformers. This enhancement defines what the documentation is, how it is sourced, and what keeps it from drifting again.

See [`config.yaml`](config.yaml) for the metadata contract; it is the sole source of metadata, and no parallel metadata table lives in this README.

## Summary

Eight sections organised by **what a reader is holding when they arrive**: nothing, a question about why, a blank module file, a cluster, a vocabulary gap, a Go program, a field name, an error message. Genre still governs how a page is written, but not the navigation, because OPM's audiences are close to disjoint and a genre-first split makes each of them filter every section.

Two placements are deliberate. **Diagnostics is top-level** because it is an entry point: readers arrive from an error string, and the kernel's error taxonomy maps to genuinely different fixes that the message text does not distinguish. **Concepts is large** in proportion to a concept surface that is unusually big relative to the user surface; seventeen concepts were ranked subtle enough that a reader gets them actively wrong without prose.

Underneath sits one rule that decides where content comes from: **generate every fact a rename can invalidate, author everything else**. Member names, keys, spec shapes, postures, the transformers that serve a member and their worked examples are emitted from evaluated CUE. Which blueprint to start from, which traits are legal on it, and every Concepts page are written by hand, because none of it is expressible in the schema.

And one convention that exists because OPM enforces across four layers: every normative statement carries an **enforcement badge** naming what actually stops you, whether that is CUE unification, the kernel at render, a publish gate, or nothing at all.

## Documents

The seven split documents below are mandatory and always present.

1. [01-problem.md](01-problem.md): documentation exists and describes a version of OPM that has not existed since April; coverage is inverted against usage
2. [02-design.md](02-design.md): eight reader-state sections, generated facts versus authored guidance, enforcement badges
3. [03-decisions.md](03-decisions.md): decision log
4. [04-graduation.md](04-graduation.md) — Gates that must hold before `draft → accepted`
5. [05-risks.md](05-risks.md): risks and mitigations, drawbacks, high-level alternatives
6. [06-operational.md](06-operational.md): operational concerns (PRR-lite)
7. [07-questions.md](07-questions.md): Open Questions register

Pure-CUE definitions live in [`contracts/contracts.cue`](contracts/contracts.cue), which states the section taxonomy, the badge vocabulary, the per-field provenance of a reference entry, and the doc-comment obligation as shapes rather than prose.

The landing order across five repos is constrained by [`06-operational.md`](06-operational.md) `## Cross-Repo Coordination`, which carries why the order is what it is; landings are logged in `delivery.yaml` as they happen.

## Scope

### In scope

- The section taxonomy: eight top-level sections keyed to reader state, and what each one owns.
- The generated-versus-authored split, per field, and the generator changes it requires (evaluate CUE rather than scrape text; fix the `generate:cli` step that fails on a clean tree).
- Doc-comment backfill in `catalog_opm` and `core`, plus a CI gate that keeps coverage from regressing.
- The enforcement badge vocabulary and its application to normative statements.
- Concepts pages for the concepts ranked highest for reader harm, mined from `core/SPEC.md`'s Rationale and rewritten.
- A Diagnostics section mapping kernel errors to causes and fixes.
- A boundaries page stating what OPM does not do.
- A page documenting the current deletion and prune behaviour, including the orphaning defaults.
- Splitting catalog reference by family, with the abstraction family as the documented default path.
- Rewriting `library/docs/getting-started.md` so that following it produces working code.

### Out of scope

- **Secrets documentation.** Enhancement 0013 owns the model and, as of 2026-08-18, its documentation. This entry leaves the gap visible and linked.
- **Publishing `core/SPEC.md`.** It stays contributor-facing; the public reference is a projection of its normative spine.
- **Documenting draft systems.** Lifecycle, workflows, provider classes, export, rollback and reverse handoff do not exist, and D3 makes their absence explicit rather than describing them as forthcoming.
- **Site presentation.** The Hugo theme, search, and styling. The theme is currently disabled and no section renders to HTML, which blocks verification but is not this entry's to fix.
- **Versioned documentation.** Whether the site carries a v1 line alongside v2 is OQ6, deferred while the v1 line has only internal consumers.
- **Retiring `opm/docs`.** The meta repo is not a member of the area vocabulary and cannot own a slice; the retirement path is OQ4.
- **A v0 migration guide.** The v0 fleet is frozen on its own branch with internal consumers only.

## Deviations from Design

None at this stage. Update when implementation lands.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `core/SPEC.md` | Normative schema contract; its Definition/Shape/Constraints spine is the reference's source, its Rationale the raw material for Concepts |
| `core/src/types.cue` | The identity type system; densest doc-worthy file in the workspace and has no SPEC section |
| `catalog_opm/src/` | Catalog members and the transformers' embedded golden tests, source of generated reference and its examples |
| `library/opm/errors/` | The error taxonomy the Diagnostics section is keyed to |
| `library/docs/getting-started.md` | The embedder guide, currently missing the mandatory Materialize step |
| `cli/README.md`, `cli/QUICKSTART.md` | Current, well-written user prose; the only written account of owner semantics and handoff |
| `cli/docs/STYLE.md` | Prose conventions to inherit, with amendments (cites commands that no longer exist) |
| `opmodel.dev/site/content/reference/` | The two hand-written pages that landed with enhancement 0010, and the shape the rest follows |
| `opmodel.dev/cmd/docgen/` | The generator this entry repairs and extends |
| `opm/docs/` | The stale tree this entry replaces; salvage its formats, not its content |
