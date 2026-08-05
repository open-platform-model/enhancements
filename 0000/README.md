# Enhancement Template (id 0000, reserved)

This directory is the canonical copy-from template for OPM enhancements. To
create a new enhancement, copy the entire directory to `enhancements/NNNN/`
(the next available four-digit id) and fill in every `{Capitalised}` placeholder
across the README and the six split documents.

See [`config.yaml`](config.yaml) for the metadata contract — it is the sole
source of metadata; no parallel metadata table lives in this README.

## Summary

{One to three sentences describing what this enhancement introduces and why
it matters. Write this last — once the design has settled the summary writes
itself. Keep it free of jargon that requires reading further documents.}

<!--
When implementation lands (status → implemented, or implementation.status → partial+),
add an Implementation Status quote block here. Format:

  > **Implementation status (YYYY-MM-DD).** {One-paragraph summary of what
  > shipped, with file paths to landed code. If there are deliberate deviations
  > from the original design, point readers to the `## Deviations from Design`
  > section below.}

The date in the block MUST match `config.yaml.implementation.date` (which
exists only when implementation.status reaches `complete`).
-->

## Documents

The six split documents below are mandatory and always present. Add optional
documents (e.g. `experiments/`, `research/`, `plan.yaml`) only when a
specific need surfaces.

1. [01-problem.md](01-problem.md) — {One-line description of the problem being solved}
2. [02-design.md](02-design.md) — {One-line description of the proposed design}
3. [03-decisions.md](03-decisions.md) — DN decision log + Open Questions
4. [04-graduation.md](04-graduation.md) — Per-status gates (draft → accepted → implemented)
5. [05-risks.md](05-risks.md) — Risks and Mitigations, Drawbacks, high-level Alternatives
6. [06-operational.md](06-operational.md) — Operational concerns (PRR-lite)

Pure-CUE schema definitions live in [`schemas/`](schemas/) as compilable
files, never as fenced blocks inside markdown.

## Scope

Concrete boundary of this enhancement. The validator (future) requires this
section starting at `status: accepted`. For design-time aspirations (what the
solution must achieve), see [`02-design.md`](02-design.md) `## Design Goals`.

### In scope

- {Bulleted boundary of what this enhancement covers.}

### Out of scope

- {Items deliberately deferred, owned by other enhancements, or out of scope by intent.}

## Experiments

Experiments are **optional** and usually appear **part-way through an enhancement's life** — once a specific design claim emerges that benefits from a runnable proof. Do not create `experiments/` upfront when copying this template; add it the first time a claim actually needs validation. If the enhancement reaches `implemented` without ever needing one, that is fine.

When an idea does need to be tested or showcased before adoption, place proofs-of-concept under `experiments/` inside this enhancement directory. Experiments live with the enhancement so reviewers can find them next to the design that motivated them.

### Rules

- **One concept per experiment.** Each experiment proves a single claim. If two claims are entangled, split into two experiments.
- **Self-contained.** An experiment runs without modifying anything outside its own directory. No edits to `core/`, `library/`, `catalog/`, sibling experiments, or any other source-of-truth artefact.
- **Copy, never reference.** CUE schemas, Go fixtures, transformer bodies — copy them into the experiment's directory and modify the copies. Never import from or mutate the originals.
- **Disposable.** Experiments are not production code. They may be deleted once the enhancement is `implemented` or rejected. Do not build infrastructure that other code depends on.
- **Languages.** Go for runtime / pipeline experiments; CUE for schema experiments; shell or other languages where they fit.

### Scaffold and layout

```bash
task new:experiment ID=NNNN NAME=concept-name
```

Creates `NNNN/experiments/` (with an index README, if absent), computes the next two-digit experiment number from existing `NN-*/` subdirs, creates `NNNN/experiments/NN-concept-name/README.md` with a Hypothesis / Setup / Run / Outcome skeleton, and seeds `Status: Draft`. Run from this directory or via the workspace include (`task enhancements:new:experiment …`).

```
NNNN/experiments/
├── README.md                       # Index — table of experiments + status (hand-maintained)
├── 01-{concept-name}/
│   ├── README.md                   # Per-experiment: Hypothesis / Setup / Run / Outcome / Status
│   ├── ...                         # Copied schemas, Go modules, fixtures, etc.
│   └── ...
└── 02-{concept-name}/
    └── ...
```

### Per-experiment README

Each experiment's README answers four questions and carries a status line:

1. **Hypothesis** — Which claim from the design is this validating?
2. **Setup** — What was copied in, from where, and what was modified.
3. **Run** — Exact commands to reproduce the result.
4. **Outcome** — What was observed; whether the hypothesis held.

The status line uses one of three values: `Status: Draft` (just scaffolded), `Status: Running` (in flight), `Status: Concluded` (outcome recorded). `task experiments:list ID=NNNN` parses this line to render the status table.

Update the per-experiment README in place as the experiment evolves. Once concluded, record the outcome and link the result back into `02-design.md` or `03-decisions.md` so the enhancement carries the evidence.

### Index README

`experiments/README.md` is a thin hand-maintained index. The scaffold seeds it; you add a row per experiment. Format:

```markdown
# Experiments — {Enhancement Title}

| # | Concept | Status |
| - | ------- | ------ |
| 01 | matcher-mechanics | Concluded |
| 02 | read-portability  | Running   |
```

The validator checks that every `NN-*/` subdir has a `README.md`; it does not enforce the index table's contents (kept loose so the index can carry extra columns or prose if a particular enhancement warrants it).

## Research

Research is **optional** and holds the external evidence a design rests on — most importantly **deep-research reports**, but also benchmark write-ups, vendor-doc summaries, comparison matrices, and curated link collections. When the design of an enhancement is grounded in research (a `/deep-research` run, a literature sweep, a prior-art survey), drop the cited findings under `research/` so the evidence travels with the design instead of evaporating into a chat log.

Research differs from `experiments/`: research is **gathered and synthesised** (read-only evidence — what is true in the world), whereas experiments are **authored and executed** (runnable proofs we wrote — what holds in our model). A claim verified by reading sources belongs in `research/`; a claim verified by running code belongs in `experiments/`.

### Rules

- **Cited.** Every non-obvious claim carries its source (URL, doc, file path). A deep-research dossier reproduces its source list and, where it has them, confidence levels and verification verdicts — distinguish verified facts from design recommendations.
- **Referenced back.** A `research/` file is dead weight unless the design points at it. Cite it from the `Source:` line of the relevant decisions in `03-decisions.md`, and from `01-problem.md` / `05-risks.md` where the evidence drives a claim.
- **Snapshot, not canon.** Research reflects what was true when gathered; date it. It is not a maintained spec — supersede with a new file rather than silently editing conclusions.
- **Not gated.** `task vet` does not require or validate `research/`; add it only when an enhancement actually has external evidence worth preserving.

### Layout

```
NNNN/research/
├── findings.md                     # primary dossier (e.g. a deep-research report): summary, cited findings, caveats, sources
└── {topic}.md                      # optional further write-ups (benchmark-x-vs-y.md, prior-art-survey.md, …)
```

`findings.md` is the conventional name for the primary dossier; add topic-named files for distinct investigations. There is no per-file scaffold task — `research/` is hand-authored prose.

## Slice Plan

Also **optional**. A slice plan is the structured layer between this design and its execution: one small, single-concern **slice** per repo landing, with an explicit dependency order and a status. Add `plan.yaml` once `## Cross-Repo Coordination` in `06-operational.md` stops being enough to hold the sequence in your head — typically when `config.yaml.affects` spans more than one repo, or a single repo's work is large enough to need an explicit landing order. A single-repo, single-slice enhancement never needs this file.

`06-operational.md ## Cross-Repo Coordination` keeps the *narrative rationale* — why this order, what each hand-off produces. `plan.yaml` is the *structured backing data* the narrative refers to by slice id — the same relationship `03-decisions.md`'s prose already has to `schemas/target.cue`.

### Scaffold

```bash
task new:plan ID=NNNN
```

Creates `NNNN/plan.yaml` with an empty `slices: []`. Add one entry per slice:

```yaml
slices:
  - id: cli-kernel-adoption            # stable, short, unique within this entry
    repo: cli                          # MUST be a member of config.yaml.affects
    phase: implementation              # implementation | migration
    concern: >
      Delete pkg/render; route render through the library kernel.
    depends_on:
      - cli-cr-inventory-backend       # local slice id
      - "0001:library"                 # cross-enhancement ref: NNNN:slice-id
    status: in-progress                # planned | in-progress | done | cancelled
    openspec_ref: cli/2026-07-18-cli-kernel-adoption   # set once it lands
```

A slice is deliberately thin — `concern` is one line, not a design doc. Implementation detail lives in that slice's own OpenSpec change in the target repo, same as today; `plan.yaml` is a table of contents for execution, not the execution itself. `cancelled` slices keep their id (other slices may already depend on it) and carry `cancelled_reason`, mirroring the tombstone convention for a vacated `DN`/`OQN`.

### The two phases

Every slice declares which half of the work it is, and the two are ordered — **implementation lands before migration**:

- **`implementation`** — defines the system. Schema, code and docs changes: `core`, `library`, `cli`, `opm-operator`, `opmodel.dev`.
- **`migration`** — moves already-published artifacts onto those definitions: the official catalogs, the module fleet, the release pins.

The test is what the slice is **for**, not which files it touches, and phase is deliberately *not* derivable from `repo` — a catalog slice can be either. When a slice would straddle the boundary, split it: authoring CUE is a reviewable source change, while pushing bytes is irreversible.

`task vet` enforces the ordering as an edge rule — no `implementation` slice may depend on a `migration` slice — rather than as a blanket barrier, so a migration whose own dependencies are already done is not gated by unrelated implementation work. (This is unrelated to the `enhancements` workflow's numbered Phases 1–5, which describe the *entry's* lifecycle rather than a *slice's* kind.)

### Validation and views

`task vet` / `task vet:one` validate `plan.yaml` structurally whenever the file is present (never required): schema conformance, `id` uniqueness, `repo ∈ affects`, every `depends_on` resolving, no dependency cycles, and no `implementation` slice depending on a `migration` slice.

```bash
task plan:graph ID=NNNN   # regenerate NNNN/PLAN.md — Mermaid DAG + table, one subgraph per phase
task plan:ready ID=NNNN   # slices whose depends_on are all `done`, grouped by phase — the order-of-procedure answer
task slice:seed ID=NNNN SLICE=cli-kernel-adoption   # print a seed stub sized for that repo's own `openspec new`
```

`slice:seed` only emits the stub — the enhancements repo does not reach into another repo's tooling. Hand the stub to that repo's own OpenSpec workflow.

When a slice lands, update its `status` (and `openspec_ref`) in the same commit that appends the `history` event citing it in `config.yaml` — the two should always agree.

## Diagrams

Diagrams are welcome throughout this enhancement's documents — the medium depends on what's being shown, never a blanket default:

- **Mermaid** — relationships between enhancements or slices: whether this entry should `related`/`supersedes` another, or whether a slice should `depends_on` another. This is exactly what the generated `GRAPH.md` and `PLAN.md` already render; a live Mermaid sketch during discussion (reusing their `classDef` palette) previews what those files will look like once the edit lands and `task graph` / `task plan:graph` regenerates them. Never hand-authored into these documents — see `enhancement-slicing` for the slice side.
- **ASCII** — how this entry's own design or mechanism works: architecture/layering, data or control flow, state transitions, integration-points/component mapping, before/after comparisons. Plain fenced code blocks, no language tag. `enhancements/0012/02-design.md` is the reference example (a layered architecture diagram and a data-flow diagram). Prefer simple arrow/column layouts over fully bordered boxes for anything likely to be edited later — bordered boxes are fragile to hand-realign. One concept per diagram; always paired with a sentence or two of prose; never in `03-decisions.md`.

See the `enhancement-diagrams` skill for the full protocol, including live-discussion use during an Open-Questions walk or general design conversation.

## Deviations from Design

None at this stage. Update this section when implementation lands and any
deliberate divergences from the design need to be documented. The validator
(future) requires this section to be present (it may say "None") for
`status: implemented`.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `CONSTITUTION.md` (workspace root, or target-repo local) | Core design principles governing changes in the touched repo(s) |
| {path} | {purpose} |

<!--
## Agent Instructions

To create a new enhancement from this template:

1. Pick the next available four-digit id by scanning `enhancements/` for the
   highest existing NNNN directory and incrementing by one. Ids are
   never reused — supersession is recorded via `supersedes` / `superseded_by`
   in `config.yaml`, not by renumbering.
2. Copy the entire `0000/` directory to `enhancements/NNNN/`.
3. Overwrite every `{Capitalised}` placeholder string across the README and
   the six split documents.
4. Fill `config.yaml` with real values: id matches the directory name, slug
   is short kebab-case, title is human-readable, area + affects describe
   ownership, created + updated set to today's date.
5. Write `01-problem.md` and `02-design.md` first — full prose. Decisions
   accrete iteratively in `03-decisions.md` as design choices emerge.
6. `04-graduation.md`, `05-risks.md`, `06-operational.md` start as scaffolds
   and mature alongside the decision log.
7. Sketch the target schema in `schemas/target.cue`. Update the `module:`
   line in `schemas/cue.mod/module.cue` to match the new four-digit id.
8. Do not strip these HTML-comment Agent Instructions when copying — they
   are the in-template guidance for the next author/agent.

### Status lifecycle

- **draft** — initial design, actively being written
- **accepted** — design agreed upon, ready for implementation
- **implemented** — design has been realized in code
- **superseded** — replaced by a newer enhancement (paired with
  `superseded_by` on this entry and `supersedes` on the replacement)

### Compaction

These documents state what is true *now*. Reversals get woven into what they
reverse rather than stacked on top, so the entry stays safe to read linearly.
Provenance lives in git and in `config.yaml.history` — the one strictly
append-only structure. `DN` and `OQN` numbers are never reused or renumbered
(other repos cite them); a number vacated by a merge keeps a one-line
tombstone.

- **draft** — merge reversals; leave Open Question prose alone, it is the
  active work surface.
- **accepted** — the same, plus resolved Open Questions collapse to a
  one-line `Status: resolved-by-DN`. Available right up to the flip.
- **implemented** — frozen. Nothing is compacted, ever.
- **superseded** — narrative documents collapse to pointers at the successor;
  the decision log keeps its numbers and its *Alternatives considered*.
  `experiments/` and `research/` are never touched.

Run `task compact:plan ID=NNNN` for the candidate list and load the
`enhancement-compaction` skill to act on it. Compaction lands in its own
commit — never folded into a content change.

### Cross-refs to legacy library enhancements

The seven three-digit entries under `library/enhancements/` (001..007) are
frozen historical predecessors. To reference one from a new enhancement, use
the `legacy:NNN` form in `related` / `supersedes` / `superseded_by`. Once
those entries are deleted, the references become dangling and the validator
(future) will flag them — fix or remove at that point.
-->
