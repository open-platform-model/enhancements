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
    ├── 03-decisions.md     append-only DN log + Open Questions
    ├── 04-graduation.md    draft → accepted → implemented gates
    ├── 05-risks.md         risks, drawbacks, alternatives not taken
    ├── 06-operational.md   PRR-lite: observability, semver, deprecation, rollback, cross-repo coordination
    ├── schemas/            pure CUE — vettable, importable, never markdown-fenced
    │   ├── cue.mod/module.cue
    │   └── target.cue
    ├── experiments/        (optional) self-contained proofs-of-concept
    │   ├── README.md       hand-maintained index of experiments
    │   └── NN-{concept}/   one directory per experiment (per-experiment README carries Status:)
    └── research/           (optional) external evidence — deep-research dossiers, benchmarks, surveys
        ├── findings.md     primary dossier (cited summary + sources)
        └── {topic}.md      further write-ups
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

## Validation

Two gates run against every entry:

- **`task vet`** — hard gate (PR-blocking). CUE schema validation of `config.yaml`, cross-reference existence, placeholder absence in the six mandatory docs, `area ∈ affects`, schemas/ compiles standalone.
- **`task check`** — soft gate (pre-PR aid). Per-status prose conventions: scope section, decision headings, Open Questions block, implementation snapshot quote block, deviations section. Warns rather than blocks.

Run `task vet` before any PR that touches an enhancement; run `task check` before promoting a status (draft → accepted, accepted → implemented).

## Status lifecycle

| Status | Meaning |
| --- | --- |
| `draft` | Initial design, actively being written. Cheap entry state. |
| `accepted` | Design agreed upon, ready for implementation. Schema, graduation criteria, decisions all locked. |
| `implemented` | Design has been realized in code. Implementation snapshot quote block in README; `config.yaml.implementation.status: complete` with date. |
| `superseded` | Replaced by a newer enhancement. Paired with `superseded_by` on this entry and `supersedes` on the replacement. |

Design lifecycle (`status`) and code lifecycle (`implementation.status`) are independent axes — see `schema.cue` for the coupling constraints.

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
