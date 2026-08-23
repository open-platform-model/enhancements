# Enhancement Template (id 0000, reserved)

This directory is the canonical copy-from template for OPM enhancements. To
create a new enhancement, copy the entire directory to `enhancements/NNNN/`
(the next available four-digit id) and fill in every `{Capitalised}` placeholder
across the README and the seven split documents.

See [`config.yaml`](config.yaml) for the metadata contract — it is the sole
source of metadata; no parallel metadata table lives in this README.

## Summary

{One to three sentences describing what this enhancement introduces and why
it matters. Write this last — once the design has settled the summary writes
itself. Keep it free of jargon that requires reading further documents.}

<!--
Do NOT add an implementation-status block here. Whether this design has been
delivered is DERIVED from the plans side — run `task delivery ID=NNNN`. A
status block written here is a snapshot that goes stale the moment the plan
moves, which is exactly the drift the implementation axis was removed to stop.
-->

## Documents

The seven split documents below are mandatory and always present. Add optional
documents (e.g. `experiments/`, `research/`) only when a
specific need surfaces.

1. [01-problem.md](01-problem.md) — {One-line description of the problem being solved}
2. [02-design.md](02-design.md) — {One-line description of the proposed design}
3. [03-decisions.md](03-decisions.md) — DN decision log
4. [04-graduation.md](04-graduation.md) — Gates that must hold before `draft → accepted`
5. [05-risks.md](05-risks.md) — Risks and Mitigations, Drawbacks, high-level Alternatives
6. [06-operational.md](06-operational.md) — Operational concerns (PRR-lite)
7. [07-questions.md](07-questions.md) — OQN Open Questions register

Pure-CUE definitions live as compilable files, never as fenced blocks inside
markdown. [`schemas/`](schemas/) is strictly the **core-schema delta** — it
exists iff `config.yaml.core_schema: true` (target.cue + examples.cue +
spec.md); non-core compilable CUE (decision procedures, behaviour contracts,
taxonomies) lives in the optional `contracts/` (`task new:contracts ID=NNNN`).

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

## Delivery Plan

Cross-repo sequencing is a delivery concern, tracked outside this entry in a delivery plan under `plans/` (see `plans/README.md`). Plans reference this entry's decisions and Open Questions by number (`NNNN:D34`, `NNNN:OQ9`); this entry never references a plan, a slice, or a plan file — the one-way rule. When delivery completes, this entry records **nothing** — `task delivery` derives the state from the plan, so there is no field for a pointer to hide in.

## Diagrams

Diagrams are welcome throughout this enhancement's documents — the medium depends on what's being shown, never a blanket default:

- **Mermaid** — relationships between enhancements or slices: whether this entry should `related`/`supersedes` another, or whether a slice should `depends_on` another. This is exactly what the generated `GRAPH.md` (and, on the plans side, each plan's `PLAN.md`) already renders; a live Mermaid sketch during discussion (reusing the `classDef` palette) previews what those files will look like once the edit lands and `task graph` / `task plans:graph` regenerates them. Never hand-authored into these documents.
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
   the seven split documents.
4. Fill `config.yaml` with real values: id matches the directory name, slug
   is short kebab-case, title is human-readable, area + affects describe
   ownership, created + updated set to today's date.
5. Write `01-problem.md` and `02-design.md` first — full prose. Decisions
   accrete iteratively in `03-decisions.md` as design choices emerge.
6. `05-risks.md` and `06-operational.md` start as scaffolds
   and mature alongside the decision log.
7. If the enhancement adds or changes opmodel.dev/core definitions
   (`config.yaml.core_schema: true`), sketch the delta in
   `schemas/target.cue` (scaffolded by `task new CORE_SCHEMA=true`;
   `examples.cue` + `spec.md` are required before draft → accepted).
   Otherwise there is no `schemas/`; put non-core compilable CUE in
   `contracts/` via `task new:contracts ID=NNNN` if needed.
8. Do not strip these HTML-comment Agent Instructions when copying — they
   are the in-template guidance for the next author/agent.

### Status lifecycle

- **draft** — initial design, actively being written
- **accepted** — design agreed upon, ready for implementation; the resting
  state (delivery is derived from `plans/`, never stored here)
- **rejected** — the idea was not accepted; the entry moves to
  `archive/NNNN/` with `rejected_reason` (`task reject`)
- **superseded** — replaced by a newer enhancement (paired with
  `superseded_by` on this entry and `supersedes` on the replacement); the
  entry moves to `archive/NNNN/` (`task supersede`)

Both terminal states are always archived — a terminal entry never stays in
place, and `task vet` fails one that does.

### Compaction

These documents state what is true *now*. Provenance lives in git and in `config.yaml.history` — the one strictly append-only structure. `DN` and `OQN` numbers are never reused or renumbered (other repos cite them); a number vacated by a merge or retraction keeps a one-line tombstone.

- **draft** — decisions are revised **in place** as part of ordinary editing (fold evidence-backed old positions into *Alternatives considered*); compaction is only the repair path for legacy stacked reversals. Leave Open Question prose alone, it is the active work surface.
- **accepted** — decision bodies are protected: changes append a new `DN` with `**Amends:**`/`**Supersedes:**` relation fields, and the compaction skill is the only body-edit path — weaving those reversals in, collapsing resolved Open Questions to a one-line `Status: resolved-by-DN`. Available at latest until the design is delivered.
- **delivered** (derived from `plans/`, not a status) — closed. Nothing changes, ever.
- **superseded** — narrative documents collapse to pointers at the successor;
  the decision log keeps its numbers and its *Alternatives considered*.
  The pass runs on the archived entry (`archive/NNNN/`).
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
