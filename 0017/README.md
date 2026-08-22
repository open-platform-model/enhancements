# 0017 — Layered Defaults

See [`config.yaml`](config.yaml) for the metadata contract — it is the sole
source of metadata; no parallel metadata table lives in this README.

## Summary

Defaults for component fields currently have no working home: trait schemas are kind-agnostic so cannot default, blueprints force every composed field present, module `#config` defaults annihilate against any second default they meet, and transformer fallbacks are dead code because the field they guard on is never absent. This enhancement assigns each authoring layer exactly one defaulting role — primitives publish bounds, blueprints narrow per kind and carry the single catalog-side default, module authors default in `#config` (which the kernel finalizes to plain data before composition), and transformers keep absence-keyed per-kind fallbacks — producing the deterministic precedence **instance values > config defaults > blueprint defaults > transformer fallbacks** from ordinary CUE unification, with the rules CUE cannot enforce codified as core SPEC.md §6 (L1–L6) for CLI gates.

## Documents

The seven split documents below are mandatory and always present. Add optional
documents (e.g. `experiments/`, `research/`) only when a
specific need surfaces.

1. [01-problem.md](01-problem.md) — why no layer can default a component field today, and what that costs
2. [02-design.md](02-design.md) — one defaulting role per layer; the precedence chain and its four mechanisms
3. [03-decisions.md](03-decisions.md) — DN decision log
4. [04-graduation.md](04-graduation.md) — Per-status gates (draft → accepted → implemented)
5. [05-risks.md](05-risks.md) — Risks and Mitigations, Drawbacks, high-level Alternatives
6. [06-operational.md](06-operational.md) — Operational concerns (PRR-lite)
7. [07-questions.md](07-questions.md) — Open Questions register

Pure-CUE schema definitions live in [`schemas/`](schemas/) as compilable
files, never as fenced blocks inside markdown.

## Scope

Concrete boundary of this enhancement. The validator (future) requires this
section starting at `status: accepted`. For design-time aspirations (what the
solution must achieve), see [`02-design.md`](02-design.md) `## Design Goals`.

### In scope

- The layer contract (SPEC.md §6, rules L1–L6) and its L5 reword from author obligation to kernel guarantee.
- core: the optionality-aware `#Component._allFields` trait projection (D5) and its regression fixtures.
- library: kernel finalize-before-fill of validated `#config` on all three value paths (D4).
- catalog_opm (v2 line): the blueprint narrowing + field-level-default idiom (D3) on the workload blueprints; blueprint-path transformer fixtures; the `#*Defaults` removal (D7, landed).
- cli: template cleanup and a template render smoke test.
- modules (v2 staging): extracted-boilerplate deletion with render-diff verification.

### Out of scope

- The exhaustive per-kind field audit across all blueprints — tracked by catalog_opm issue 40 (this entry establishes the mechanism).
- CLI gate engineering for L1–L6 — a later cli slice; this entry defines the rules and their identifiers.
- Any v1-line change (core `v1` branch, catalog `v1` branches, modules `v1`/`v0_legacy` fleets).
- In-language precedence (CUE `SetLayer`) — rejected for now, D4 alternatives.

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
# Experiments — Layered Defaults

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

Cross-repo sequencing is a delivery concern, tracked outside this entry under `plans/` (see `plans/README.md`). Plans reference this entry's decisions and Open Questions by number; this entry never references a plan — the one-way rule.

## Diagrams

Diagrams are welcome throughout this enhancement's documents — the medium depends on what's being shown, never a blanket default:

- **Mermaid** — relationships between enhancements or slices: whether this entry should `related`/`supersedes` another, or whether a slice should `depends_on` another. This is exactly what the generated `GRAPH.md` already renders; a live Mermaid sketch during discussion (reusing its `classDef` palette) previews what it will look like once the edit lands and `task graph` regenerates it. Never hand-authored into these documents.
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
| `core/SPEC.md` | §6 layering contract (L1–L6, landed ahead of this entry); §2.2/§3.1 constraint updates land with the core slice |
| `core/src/component.cue` | `_allFields` — the projection D5 changes |
| `core/src/trait.cue` | `#Trait.optional`, the single-regular-field gate, `#TraitOptionalGate` |
| `library/opm/kernel/process.go` | instance build: validate → fill → concreteness gate; D4's finalize step lands between validate and fill |
| `library/opm/kernel/validate.go` | `runValidate` / `ValidateConfigDetailed` — the value paths D4 covers |
| `library/opm/kernel/synth.go` | debugValues-as-values policy; same fill point |
| `catalog_opm/src/blueprints/v1beta1/stateless_workload.cue` | first blueprint to carry D3's narrowing + default idiom |
| `catalog_opm/src/traits/v1beta1/update_strategy.cue` | the motivating trait; `rollingUpdate` union loosening |
| `catalog_opm/src/transformers/deployment_transformer.cue` | the absence-keyed fallbacks D5 makes reachable |
| `cli/templates/minimal/module.cue` | the template whose render failure motivated the entry |
| `research/cue/concepts/default-precedence.md` | workspace research: CUE default semantics (M/U rules, SetLayer status) grounding D1/D4 |
| catalog_opm issue 40 | per-kind narrowing audit (companion scope) |

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

These documents state what is true *now*. Provenance lives in git and in `config.yaml.history` — the one strictly append-only structure. `DN` and `OQN` numbers are never reused or renumbered (other repos cite them); a number vacated by a merge or retraction keeps a one-line tombstone.

- **draft** — decisions are revised **in place** as part of ordinary editing (fold evidence-backed old positions into *Alternatives considered*); compaction is only the repair path for legacy stacked reversals. Leave Open Question prose alone, it is the active work surface.
- **accepted** — decision bodies are protected: changes append a new `DN` with `**Amends:**`/`**Supersedes:**` relation fields, and the compaction skill is the only body-edit path — weaving those reversals in, collapsing resolved Open Questions to a one-line `Status: resolved-by-DN`. Available right up to the flip.
- **implemented** — frozen. Nothing changes, ever.
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
