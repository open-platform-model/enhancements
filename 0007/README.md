# Manifest Passthrough: Side-Channel Raw and Kustomize Manifests

See [`config.yaml`](config.yaml) for the metadata contract — it is the sole
source of metadata; no parallel metadata table lives in this README.

## Summary

OPM gains a first-class side-channel for **extra manifests** — plain YAML and/or a Kustomize directory declared on a release — that the CLI and operator apply alongside rendered output and own identically: stamped with OPM ownership labels, recorded in `status.inventory`, staged, drift-detected, and pruned as one set. The feature lives entirely at the **apply layer**: `opmodel.dev/core@v0` and the library kernel are untouched (the kernel is pure by constitution and cannot read a filesystem or run Kustomize), Kustomize is rendered by the embedded `krusty` library rather than a shelled-out binary, and the whole thing exists to lower OPM's adoption cliff for teams who already have manifests without diluting the typed component happy path.

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
documents (e.g. `experiments/`) only when a specific need surfaces.

1. [01-problem.md](01-problem.md) — No supported way to ship arbitrary/Kustomize manifests through OPM's managed apply path; out-of-band apply leaks and drifts
2. [02-design.md](02-design.md) — Apply-layer side-channel: declare `extraManifests`, render (embedded krusty) into `[]Unstructured`, fold into the existing label/inventory/SSA/prune set; core + kernel untouched
3. [03-decisions.md](03-decisions.md) — Append-only decision log + Open Questions
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

- A release-spec side-channel (`extraManifests`) on the operator's `ModuleRelease`/`Release` CRDs and an equivalent CLI input, declaring `raw` (plain YAML) and/or `kustomize` (a kustomization directory) sources.
- A shared passthrough renderer embedding `sigs.k8s.io/kustomize/api/krusty` (no shelled-out binary), with a hardened default options set for operator use.
- Folding passthrough output into the existing apply path so side objects are labeled, inventoried, staged, drift-detected, and pruned identically to rendered output — one ownership model.
- Identical semantics across the CLI (`opm release build`/`apply`) and the operator.

### Out of scope

- Any change to `opmodel.dev/core@v0` or the library kernel (D1). Side manifests never become components or transformer output.
- Typing arbitrary Kubernetes objects inside the CUE pipeline — that is enhancement [0005](../0005/README.md)'s `#Objects` redesign (relationship tracked as OQ2).
- A general external-renderer plugin system (Helm, jsonnet, cdk8s, …). Only Kustomize + raw YAML in this pass.
- Templating/interpolating release values into side manifests (verbatim passthrough only; possible follow-up, OQ4).

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
# Experiments — Manifest Passthrough: Side-Channel Raw and Kustomize Manifests

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

## Deviations from Design

None at this stage. Update this section when implementation lands and any
deliberate divergences from the design need to be documented. The validator
(future) requires this section to be present (it may say "None") for
`status: implemented`.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `library/CONSTITUTION.md` | Principle I (kernel purity: no I/O, no shell, no exec) — the constraint that forces passthrough to the apply layer (D1) |
| `opm-operator/api/v1alpha1/modulerelease_types.go` | Add optional `spec.extraManifests []ExtraManifestSource` |
| `opm-operator/api/v1alpha1/release_types.go` | Add optional `spec.extraManifests []ExtraManifestSource` |
| `opm-operator/api/v1alpha1/common_types.go` | Inventory entry — side objects record here unchanged; verify provenance marker fits |
| `opm-operator/internal/render/` | Fold passthrough renderer output into the rendered resource list |
| `opm-operator/pkg/core/labels.go` | Stamp OPM ownership labels + passthrough provenance on side objects |
| `opm-operator/internal/apply/apply.go` | Staged SSA — verify passed-through CRDs/namespaces stage correctly (no logic change expected) |
| `opm-operator/internal/apply/prune.go` | Inventory-based prune — confirm side objects prune under the ownership guard |
| `opm-operator/internal/inventory/` | Confirm passthrough objects record and diff like rendered ones |
| `opm-operator/internal/source/fetch.go` | Artifact extraction tree — the path root for `Release` side-manifest sources |
| `opm-operator/config/crd` | Regenerated CRDs after the `extraManifests` field addition |
| `cli/internal/cmd/release/build.go` | Accept `extraManifests`; serialize passthrough objects with rendered output |
| `cli/internal/cmd/release/apply.go` | Accept `extraManifests`; apply passthrough objects in the same SSA set |
| `cli/internal/cmdutil/manifest_output.go` | Ensure passthrough objects serialize alongside rendered output |
| `enhancements/0005/README.md` | Related — the in-pipeline `#Objects` redesign; relationship tracked as OQ2 |

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

### Cross-refs to legacy library enhancements

The seven three-digit entries under `library/enhancements/` (001..007) are
frozen historical predecessors. To reference one from a new enhancement, use
the `legacy:NNN` form in `related` / `supersedes` / `superseded_by`. Once
those entries are deleted, the references become dangling and the validator
(future) will flag them — fix or remove at that point.
-->
