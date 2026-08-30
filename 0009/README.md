# Enhancement 0009: Operational Primitives: Op, Action, Lifecycle, Workflow

This entry gives OPM a second kernel half, a pure planner and orchestrator over four new primitives, so a module can carry operational intent (install/upgrade hooks, migrations, on-demand operations) alongside what it renders.

See [`config.yaml`](config.yaml) for the metadata contract; it is the sole source of metadata, and no parallel metadata table lives in this README.

## Summary

OPM can render declarative modules to Kubernetes but cannot describe what should happen: install/upgrade hooks, migrations, on-demand operations. This enhancement adds a second half to the kernel that interprets the same `#Module` for execution. Four operational primitives land in `core`: `#Op` (a controlled smallest-denominator primitive), `#Action` (compositions over Ops), `#Lifecycle` (steps bound to fixed state-transition phases), and `#Workflow` (on-demand flows). The library acts as a pure planner and orchestrator; the executable code is pluggable and catalog-sourced, dispatched via CUE attributes, so operations are as extensible as transformers already are. Composition never re-imports Helm's "arbitrary script as a hook" failure mode.

<!--
Do NOT add an implementation-status block here. Whether this design has been
delivered is DERIVED from this entry's `delivery.yaml` log: run `task delivery ID=NNNN`. A
status block written here is a snapshot that goes stale the moment another change
lands, which is exactly the drift the implementation axis was removed to stop.
-->

## Documents

The seven split documents below are mandatory and always present. Add optional
documents (e.g. `experiments/`) only when a specific need surfaces.

1. [01-problem.md](01-problem.md): OPM renders but cannot execute operations; side scripts and Helm-style hooks are the anti-pattern
2. [02-design.md](02-design.md): A second kernel half (planner + orchestrator) over four operational primitives, with attribute-dispatched, catalog-sourced pluggable executors
3. [03-decisions.md](03-decisions.md): Decision log
4. [04-graduation.md](04-graduation.md): Gates that must hold before `draft → accepted`
5. [05-risks.md](05-risks.md): Risks and Mitigations, Drawbacks, high-level Alternatives
6. [06-operational.md](06-operational.md): Operational concerns (PRR-lite)
7. [07-questions.md](07-questions.md): Open Questions register

Pure-CUE schema definitions live in [`schemas/`](schemas/) as compilable
files, never as fenced blocks inside markdown.

## Scope

Concrete boundary of this enhancement. The validator (future) requires this
section starting at `status: accepted`. For design-time aspirations (what the
solution must achieve), see [`02-design.md`](02-design.md) `## Design Goals`.

### In scope

- The four operational constructs in `core`: `#Op`, `#Action`, `#Lifecycle`, `#Workflow`, plus the `@op(...)` dispatch-attribute convention and additive `#ops` / `#actions` maps on `#Catalog`.
- The execution half of the library kernel: a pure planner + orchestrator (`opm/flow/`) and the opt-in executor backend layer with its registry and fail-fast-on-unsupported behavior.
- The initial Op vocabulary (`exec`, `http` full-CRUD, `wait`, `cue.eval`, k8s get/apply) as catalog-published definitions.
- Frontend wiring: CLI and operator each composing their backend set; operator driving `#Lifecycle` phases from the reconcile loop.
- The kernel's cancellation path and its logger, tracer and clock slots: designed and wired by this entry, untouched by any other change until it lands (D9).

### Out of scope

- Any change to the render half (`opm/compile/`): execution is purely additive.
- A general-purpose scripting language for operations; composition of a closed primitive set is intentional.
- The meta-controller toolkit (OQ5): a north-star the architecture must allow, not a v1 deliverable; likely a follow-up enhancement.
- Final production implementations of every executor backend; artifact form is still under decision (OQ1).

## Experiments

Experiments are **optional** and usually appear **part-way through an enhancement's life**: once a specific design claim emerges that benefits from a runnable proof. Do not create `experiments/` upfront when copying this template; add it the first time a claim actually needs validation. If the enhancement reaches `implemented` without ever needing one, that is fine.

When an idea does need to be tested or showcased before adoption, place proofs-of-concept under `experiments/` inside this enhancement directory. Experiments live with the enhancement so reviewers can find them next to the design that motivated them.

### Rules

- **One concept per experiment.** Each experiment proves a single claim. If two claims are entangled, split into two experiments.
- **Self-contained.** An experiment runs without modifying anything outside its own directory. No edits to `core/`, `library/`, `catalog/`, sibling experiments, or any other source-of-truth artefact.
- **Copy, never reference.** CUE schemas, Go fixtures, transformer bodies: copy them into the experiment's directory and modify the copies. Never import from or mutate the originals.
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

1. **Hypothesis**: Which claim from the design is this validating?
2. **Setup**: What was copied in, from where, and what was modified.
3. **Run**: Exact commands to reproduce the result.
4. **Outcome**: What was observed; whether the hypothesis held.

The status line uses one of three values: `Status: Draft` (just scaffolded), `Status: Running` (in flight), `Status: Concluded` (outcome recorded). `task experiments:list ID=NNNN` parses this line to render the status table.

Update the per-experiment README in place as the experiment evolves. Once concluded, record the outcome and link the result back into `02-design.md` or `03-decisions.md` so the enhancement carries the evidence.

### Index README

`experiments/README.md` is a thin hand-maintained index. The scaffold seeds it; you add a row per experiment. Format:

```markdown
# Experiments — Operational Primitives: Op, Action, Lifecycle, Workflow

| # | Concept | Status |
| - | ------- | ------ |
| 01 | matcher-mechanics | Concluded |
| 02 | read-portability  | Running   |
```

The validator checks that every `NN-*/` subdir has a `README.md`; it does not enforce the index table's contents (kept loose so the index can carry extra columns or prose if a particular enhancement warrants it).

## Research

Research is **optional** and holds the external evidence a design rests on: most importantly **deep-research reports**, but also benchmark write-ups, vendor-doc summaries, comparison matrices, and curated link collections. When the design of an enhancement is grounded in research (a `/deep-research` run, a literature sweep, a prior-art survey), drop the cited findings under `research/` so the evidence travels with the design instead of evaporating into a chat log.

Research differs from `experiments/`: research is **gathered and synthesised** (read-only evidence: what is true in the world), whereas experiments are **authored and executed** (runnable proofs we wrote: what holds in our model). A claim verified by reading sources belongs in `research/`; a claim verified by running code belongs in `experiments/`.

### Rules

- **Cited.** Every non-obvious claim carries its source (URL, doc, file path). A deep-research dossier reproduces its source list and, where it has them, confidence levels and verification verdicts: distinguish verified facts from design recommendations.
- **Referenced back.** A `research/` file is dead weight unless the design points at it. Cite it from the `Source:` line of the relevant decisions in `03-decisions.md`, and from `01-problem.md` / `05-risks.md` where the evidence drives a claim.
- **Snapshot, not canon.** Research reflects what was true when gathered; date it. It is not a maintained spec: supersede with a new file rather than silently editing conclusions.
- **Not gated.** `task vet` does not require or validate `research/`; add it only when an enhancement actually has external evidence worth preserving.

### Layout

```
NNNN/research/
├── findings.md                     # primary dossier (e.g. a deep-research report): summary, cited findings, caveats, sources
└── {topic}.md                      # optional further write-ups (benchmark-x-vs-y.md, prior-art-survey.md, …)
```

`findings.md` is the conventional name for the primary dossier; add topic-named files for distinct investigations. There is no per-file scaffold task: `research/` is hand-authored prose.

## Deviations from Design

None at this stage. Update this section when implementation lands and any
deliberate divergences from the design need to be documented. The validator
(future) requires this section to be present (it may say "None") for
`status: implemented`.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `core/CLAUDE.md`, `core/SPEC.md`, `core/.claude/skills/core-schema-edit/SKILL.md` | Schema home for the four constructs; SPEC co-update protocol for the core slice |
| `core/src/catalog.cue` | `#Catalog` shape the additive `#ops` / `#actions` maps extend |
| `core/src/transformer.cue` | Render-half transformer/matcher pattern the execution half parallels |
| `library/CLAUDE.md`, `library/CONSTITUTION.md` | Kernel neutrality (Principle I) and the `kernel` vs `helper` boundary the planner/executor split honors |
| `library/opm/compile/` | The render half (`finalize → match → execute → emit`) the new `opm/flow/` half parallels |
| `library/opm/helper/loader/` | Existing opt-in I/O layer that `helper/executor/` mirrors |
| `library/opm/materialize/` | Catalog pull/compose machinery the op artifacts ride on |
| `catalog_opm/CLAUDE.md`, `catalog_opm/src/catalog.cue` | Where the initial Op/Action definitions and artifacts are published (no `#Area` token; tracked in prose) |
| https://hofstadter.io/getting-started/task-engine/ | Prior art for the attribute-dispatch (`@task`) model adapted here |

<!--
## Agent Instructions

To create a new enhancement from this template:

1. Pick the next available four-digit id by scanning `enhancements/` for the
   highest existing NNNN directory and incrementing by one. Ids are
   never reused: supersession is recorded via `supersedes` / `superseded_by`
   in `config.yaml`, not by renumbering.
2. Copy the entire `0000/` directory to `enhancements/NNNN/`.
3. Overwrite every `{Capitalised}` placeholder string across the README and
   the seven split documents.
4. Fill `config.yaml` with real values: id matches the directory name, slug
   is short kebab-case, title is human-readable, area + affects describe
   ownership, created + updated set to today's date.
5. Write `01-problem.md` and `02-design.md` first: full prose. Decisions
   accrete iteratively in `03-decisions.md` as design choices emerge.
6. `05-risks.md` and `06-operational.md` start as scaffolds
   and mature alongside the decision log.
7. Sketch the target schema in `schemas/target.cue`. Update the `module:`
   line in `schemas/cue.mod/module.cue` to match the new four-digit id.
8. Do not strip these HTML-comment Agent Instructions when copying: they
   are the in-template guidance for the next author/agent.

### Status lifecycle

- **draft**: initial design, actively being written
- **accepted**: design agreed upon, ready for implementation
- **implemented**: design has been realized in code
- **superseded**: replaced by a newer enhancement (paired with
  `superseded_by` on this entry and `supersedes` on the replacement)

### Cross-refs to legacy library enhancements

The seven three-digit entries under `library/enhancements/` (001..007) are
frozen historical predecessors. To reference one from a new enhancement, use
the `legacy:NNN` form in `related` / `supersedes` / `superseded_by`. Once
those entries are deleted, the references become dangling and the validator
(future) will flag them: fix or remove at that point.
-->
