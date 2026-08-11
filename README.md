# OPM Enhancements

Cross-OPM enhancement proposals. Every significant change to the Open Platform Model — schema, kernel, catalog, operator, CLI, docs, or any combination — gets a design package here before code lands.

This repo is the **canonical home** for OPM design work going forward. Repo-local enhancements (the seven entries under `library/enhancements/001-007`) are frozen historical predecessors and will be deleted as their content is either migrated or superseded by entries here.

## Quick start

Browse [`INDEX.md`](INDEX.md) for the status table — id, area, status, last history event, title. Drill into any `NNNN/` directory to read the full design package. Folder names are id-only (four digits, zero-padded); the title and slug live inside `config.yaml`.

```bash
task list                  # status table in the terminal
task show ID=0001          # full metadata + document list for one entry
```

## Directory layout

```
enhancements/
├── schema.cue              CUE contract validating every config.yaml
├── Taskfile.yml            workflow tasks (vet, list, new, graph, index, …)
├── INDEX.md                generated browse aid — id → area → status → title
├── GRAPH.md                generated Mermaid relationship diagram
├── README.md               this file
├── CLAUDE.md               agent guide for working in this repo
├── 0000/                   canonical template — copy from here
└── NNNN/                   one directory per enhancement (id-only)
    ├── config.yaml         sole source of metadata
    ├── README.md           index, summary, scope, cross-references
    ├── 01-problem.md       why this enhancement needs to exist
    ├── 02-design.md        what the solution is and how it works
    ├── 03-decisions.md     DN decision log + Open Questions (numbers immutable; bodies in-place while draft, protected from accepted)
    ├── 04-graduation.md    draft → accepted → implemented gates
    ├── 05-risks.md         risks, drawbacks, alternatives not taken
    ├── 06-operational.md   PRR-lite: observability, semver, deprecation, rollback, cross-repo coordination
    ├── schemas/            pure CUE — vettable, importable, never markdown-fenced
    │   ├── cue.mod/module.cue
    │   └── target.cue
    ├── experiments/        (optional) self-contained proofs-of-concept
    │   ├── README.md       hand-maintained index of experiments
    │   └── NN-{concept}/   one directory per experiment (per-experiment README carries Status:)
    ├── research/           (optional) external evidence — deep-research dossiers, benchmarks, surveys
    │   ├── findings.md     primary dossier (cited summary + sources)
    │   └── {topic}.md      further write-ups
    ├── plan.yaml           (optional) structured slice plan — repo, concern, depends_on, status per slice
    └── PLAN.md             generated from plan.yaml (task plan:graph) — do not hand-edit
```

## How to read an enhancement

Start at the entry's `README.md` — it has the summary, scope, and cross-references. Then walk the split documents in order:

1. **`01-problem.md`** — current state, gap, concrete example, user stories. Answers "why does this exist?".
2. **`02-design.md`** — goals, non-goals, high-level approach, integration points, before/after. Answers "what changes?".
3. **`03-decisions.md`** — every architectural choice with alternatives, rationale, and source. Open Questions track what is still unresolved.
4. **`04-graduation.md`** — gates that must hold to advance status.
5. **`05-risks.md`** — honest costs: risks, drawbacks, high-level alternatives ruled out.
6. **`06-operational.md`** — production-readiness questionnaire (five prompts).

CUE schemas live in `schemas/` as compilable files; the markdown documents reference shapes by name, not by re-pasting code blocks.

## How to create a new enhancement

```bash
task new SLUG=platform-context TITLE="Platform Context"
```

Auto-numbers the next four-digit id, copies `0000/`, fills `config.yaml` with today's date and your slug/title, and updates `schemas/cue.mod/module.cue` with the new id. Fill in `01-problem.md` and `02-design.md` first; decisions and the supporting documents accrete iteratively. See [`CLAUDE.md`](CLAUDE.md) for the full workflow.

## Experiments

Optional. When a specific design claim needs a runnable proof, scaffold an experiment inside the enhancement:

```bash
task new:experiment ID=0001 NAME=matcher-mechanics
```

Creates `0001/experiments/` (with an index README on first invocation), drops a per-experiment subdir with a Hypothesis / Setup / Run / Outcome README skeleton and `Status: Draft`. See `0000/README.md ## Experiments` for the full rules (one concept per experiment, self-contained, copy-don't-reference, disposable). `task experiments:list ID=0001` renders the status table; `task vet` enforces structural sanity when `experiments/` is present.

## Research

Also optional. When an enhancement's design rests on **external evidence** — a `/deep-research` report, a benchmark, a vendor-doc or prior-art survey — capture the cited findings under `research/` so the evidence travels with the design. The primary dossier is `research/findings.md`; add topic-named files for distinct investigations. Research is *gathered* evidence (read-only synthesis), as distinct from `experiments/`, which are *authored* runnable proofs. Cite every claim, date the snapshot, and reference it back from the `Source:` lines in `03-decisions.md`. There is no scaffold task and `task vet` does not gate it. See `0000/README.md ## Research` for the full convention.

## Slice Plans

Also optional. `06-operational.md ## Cross-Repo Coordination` names the sequence in prose; once that sequence grows past a couple of hand-offs (as it did for enhancement 0006, which ended up hand-numbering slices and their dependencies inline), back it with a structured `plan.yaml`:

```bash
task new:plan ID=0001
```

Each entry in `plan.yaml` is a **slice** — a small, single-concern, single-repo landing: an `id`, the target `repo` (must be a member of `config.yaml.affects`), a one-line `concern`, `depends_on` (other slice ids, or `"NNNN:slice-id"` for a cross-enhancement dependency), and a `status` (`planned | in-progress | done | cancelled`). A slice is a table of contents for execution, not the execution itself — the detail lives in that slice's own OpenSpec change in the target repo.

```bash
task plan:graph ID=0001                    # regenerate NNNN/PLAN.md — Mermaid DAG + table, coloured by status
task plan:ready ID=0001                    # slices whose dependencies are all done — the order-of-procedure answer
task slice:seed ID=0001 SLICE=cli-foo      # print a seed stub for one slice, for that repo's own OpenSpec `new`
```

`task vet` / `task vet:one` validate `plan.yaml` structurally whenever it's present (schema, id uniqueness, `repo ∈ affects`, every `depends_on` resolving, no dependency cycle) — never required when absent. See `0000/README.md ## Slice Plan` for the full field reference and the `enhancement-slicing` skill for the workflow.

## Validation

Two gates run against every entry:

- **`task vet`** — hard gate (PR-blocking). CUE schema validation of `config.yaml`, cross-reference existence, placeholder absence in the six mandatory docs, `area ∈ affects`, schemas/ compiles standalone, and — when `plan.yaml` is present — its schema, slice id uniqueness, `repo ∈ affects`, `depends_on` resolution, and dependency-cycle freedom.
- **`task check`** — soft gate (pre-PR aid). Per-status prose conventions: scope section, decision headings, Open Questions block, implementation snapshot quote block, deviations section, and a nudge (not a block) to add `plan.yaml` when an `accepted` entry's `affects` spans more than one repo and none exists yet.

Run `task vet` before any PR that touches an enhancement; run `task check` before promoting a status (draft → accepted, accepted → implemented).

## Status lifecycle

| Status | Meaning |
| --- | --- |
| `draft` | Initial design, actively being written. Cheap entry state. |
| `accepted` | Design agreed upon, ready for implementation. Schema, graduation criteria, decisions all locked. |
| `implemented` | Design has been realized in code. Implementation snapshot quote block in README; `config.yaml.implementation.status: complete` with date. |
| `superseded` | Replaced by a newer enhancement. Paired with `superseded_by` on this entry and `supersedes` on the replacement. |

Design lifecycle (`status`) and code lifecycle (`implementation.status`) are independent axes — see `schema.cue` for the coupling constraints.

## Compaction

Enhancements are epics, and their documents are living until the design freezes. While an entry is **`draft`**, a changed decision is an **in-place edit** — the log never contains two conflicting decisions, evidence-backed old positions get folded into *Alternatives considered*, and a retracted number keeps a one-line tombstone. Once the entry is **`accepted`** its decision bodies are protected: implementation-phase changes *append* a new `DN` with `**Amends:**`/`**Supersedes:**` relation fields, and those stacked reversals get woven back into the decisions they reverse by a deliberate compaction pass — otherwise the document stops being safe to read linearly, and someone who stops halfway gets an answer that a later entry already killed.

Either way these documents state **what is true now**. Provenance lives in git and in `config.yaml.history`, which is the one strictly append-only structure here. What stays immutable everywhere is the *numbering* — `DN` and `OQN` are never reused or renumbered, because other repos cite them — so a number vacated by a merge or retraction keeps a one-line tombstone pointing at where its content went.

Rewriting a protected design record is a real risk, not a free lunch, so post-acceptance compaction is deliberate: it runs under the `enhancement-compaction` skill, produces a manifest for approval before touching a file, and lands in its own commit so the diff is reviewable as a compaction rather than hidden inside a content change.

| Status | Decision bodies |
| --- | --- |
| `draft` | Revised in place as part of ordinary editing; the compaction skill is needed only to repair legacy stacked reversals. Open Question prose is left alone — it is the active work surface. |
| `accepted` | Protected. Changes append a new `DN` with relation fields; the compaction skill is the only body-edit path — weaving reversals, collapsing resolved Open Questions to a one-line `Status: resolved-by-DN` — available right up to the `implemented` flip. |
| `implemented` | **Nothing changes. Frozen.** The record of a shipped design is closed. |
| `superseded` | The narrative documents collapse to pointers at the successor; the decision log keeps its numbers and its *Alternatives considered*, so the successor does not re-litigate settled ground. `experiments/` and `research/` are never touched. |

The test for what survives any revision or weave: **keep what would change a future decision; drop what only records that we changed our mind.**

## Cross-references

Cross-references between entries use the `related`, `supersedes`, and `superseded_by` fields in `config.yaml`. Tokens accept two forms:

- **`"0042"`** — workspace-root four-digit id. Resolves to `enhancements/0042/`.
- **`"legacy:003"`** — legacy three-digit library predecessor. Resolves to `library/enhancements/003-*/`. Use when an old library enhancement is genuine prior art that informs a new design but is not being migrated.

The validator flags dangling references (`task vet` fails). Once the library predecessors are deleted, any `legacy:NNN` reference will start failing — fix or remove it at that point.

## Related repos

- **`core/`** — `opmodel.dev/core@v0`, the canonical OPM schema. Most enhancements that touch CUE definitions land here.
- **`library/`** — the Go kernel that implements the schema's semantics. Enhancements covering kernel behaviour land here.
- **`catalog/`** — primitive catalogs (resources, traits, transformers, blueprints).
- **`opm-operator/`** — Kubebuilder controller for in-cluster reconciliation.
- **`cli/`** — `opm` CLI.
- **`opmodel.dev/`** — public docs site.
- **`modules/`** — workspace-level OPM module definitions.

Each repo has its own `CLAUDE.md` describing how it consumes the OPM schema. Enhancement implementations cross several of these in coordinated PRs; see each entry's `06-operational.md ## Cross-Repo Coordination` for the sequence.
