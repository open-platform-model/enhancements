---
name: enhancement-experiments
description: Protocol for creating, updating, validating, and concluding experiments inside OPM enhancements. Load before scaffolding a new experiment under enhancements/NNNN/experiments/, before editing an existing experiment's README, before transitioning an experiment's Status (Draft → Running → Concluded), or when reviewing whether a design claim needs runnable validation.
user-invocable: true
---

# Enhancement Experiments

## When this skill applies

Load this skill when any of the following is true:

- A decision in `enhancements/NNNN/03-decisions.md` rests on a CUE evaluation pattern, kernel behaviour, or Go fixture that hasn't been demonstrated end-to-end and you are about to validate it.
- A reviewer asks "does that actually work?" about a specific design claim and the cheapest honest answer is a small runnable sandbox.
- A complex schema interaction (CUE comprehension, lock-step pattern, cycle-avoidance trick) is about to be baked into `schemas/target.cue` and you want evidence first.
- You are about to invoke `task new:experiment` or `task experiments:list`.
- You are editing any file under `enhancements/NNNN/experiments/`.
- You are transitioning an experiment's `Status:` line.

If your task is to *read* an existing experiment to learn what was tried, you do not need this skill — open the experiment's `README.md` and follow the Hypothesis / Setup / Run / Outcome sections.

## Core rules

1. **One concept per experiment.** Each experiment validates a single claim from `02-design.md`. If you are tempted to test two claims in one experiment, split into two — entangled experiments are uninterpretable when one half succeeds and the other fails.
2. **Self-contained.** An experiment runs without modifying anything outside its own directory. No edits to `core/`, `library/`, `catalog/`, sibling experiments, or any other source-of-truth artefact. If your experiment needs a CUE schema or a Go fixture from the rest of the codebase, **copy it into the experiment dir** and modify the copy.
3. **Copy, never reference.** Imports from `core/`, `library/`, `catalog/`, or another experiment are forbidden. Copy the bytes in. Why: experiments validate a claim as of a *specific* moment; an upstream change six months later silently invalidates a "reference" experiment.
4. **Disposable.** Experiments are not production code. They may be deleted once the enhancement is `implemented` or rejected. Do not build infrastructure that other code depends on. Do not commit Go modules that other repos import. Do not write helper packages that escape the experiment's directory.
5. **Languages.** Go for runtime / pipeline experiments; CUE for schema experiments; shell for orchestration; other languages where they fit. Pick the minimum tooling that proves the claim.
6. **No tests, no CI.** Experiments are demonstrations, not test suites. They are exercised by running the documented `## Run` commands manually. CI does not exercise them; `task vet` validates only their structural presence.

## Lifecycle

Three `Status:` values, recorded as the first non-heading content of the per-experiment README:

| Status | Meaning | Next |
| --- | --- | --- |
| `Draft` | Just scaffolded. Hypothesis written; Setup / Run / Outcome are placeholders. | Fill in Setup and Run, attempt the experiment, transition to `Running`. |
| `Running` | Live work. Hypothesis and Setup are concrete; commands in Run reproduce the in-flight state. Outcome may be partial or empty. | Once the outcome is recorded and the hypothesis is judged held / refuted, transition to `Concluded`. |
| `Concluded` | Outcome recorded. Whether the hypothesis held is unambiguously stated. The experiment's claim is linked back into the enhancement's `02-design.md` or `03-decisions.md` so the evidence sits next to the design. | The experiment may be retained as historical reference or deleted; either is valid. |

Status drives `task experiments:list`. Anything other than these three values renders verbatim (no enforcement), but reviewers and tooling expect the canonical set — use them.

## Create

```bash
# from enhancements/, or via the workspace include `task enhancements:new:experiment …`
task new:experiment ID=NNNN NAME=concept-name
```

What this does:

1. Validates `ID` is an existing enhancement directory (four-digit zero-padded).
2. Validates `NAME` matches the kebab-case slug regex `^[a-z0-9]([a-z0-9-]*[a-z0-9])?$`.
3. Creates `NNNN/experiments/` and seeds `experiments/README.md` (the hand-maintained index) on first invocation. Subsequent invocations skip this.
4. Computes the next two-digit experiment number from existing `NN-*/` subdirs.
5. Creates `NNNN/experiments/NN-NAME/README.md` with the canonical skeleton (Hypothesis / Setup / Run / Outcome / `Status: Draft`).
6. Prints the path to the new experiment and the recommended next steps, including the index row to add by hand.

The index row is **not** auto-appended to `experiments/README.md` — the index may carry extra columns or prose specific to that enhancement, and an auto-edit would force a parse-and-rewrite of someone else's markdown. Add the row yourself:

```markdown
| 01 | concept-name | Draft |
```

After scaffolding, the per-experiment README is a skeleton with placeholder prose for every section. Fill in:

1. **Hypothesis** — One sentence naming the claim from `02-design.md` being validated. Avoid vague claims ("the design works"); name the specific assertion ("a `for id, c in #components { (id): c.#names }` comprehension under `#Module.#ctx` produces a fully-concrete map without an evaluation cycle").
2. **Setup** — What was copied in, from where, and what was modified. Cite the source path of every copied artefact so a reviewer can compare. Note any modifications to the copies and why.
3. **Run** — Exact commands that reproduce the result. Prefer a single command (`go run .`, `cue eval`, `bash run.sh`) over a multi-step sequence. If multi-step is unavoidable, number the steps.
4. **Outcome** — Left as a placeholder during `Draft`. Filled when transitioning to `Running` (partial / in-flight observations OK) and finalised at `Concluded` with a clear "hypothesis held / refuted" statement.

## Update

Standard editing rules:

- `Status:` line lives at the top of the per-experiment README (line 3 in the canonical skeleton). Edit it in place when transitioning.
- The index table at `experiments/README.md` is hand-maintained. Update the status column when you transition an experiment.
- The enhancement's `config.yaml.updated` field bumps on any meaningful edit, including experiment work.
- A `config.yaml.history` event may capture an experiment milestone if it influenced the design (e.g. `{date: 2026-06-04, event: "Experiment 01-names-cascade concluded — D2/D3 ratified"}`).

When updating an experiment in flight (`Running`):

- Keep the Setup section accurate. If you change the copied artefacts or modify the experiment's command surface, update Setup before running.
- The Run commands must continue to reproduce the current state — not a historical state. Update them in lockstep with the experiment.
- Outcome accumulates observations. Write what you observed; do not pre-judge whether the hypothesis held until the experiment is complete.

When transitioning `Running → Concluded`:

- The Outcome section must end with an unambiguous statement: "Hypothesis held." or "Hypothesis refuted." with a one-sentence summary of the evidence.
- Link the result into the enhancement: add a one-line reference in `02-design.md` (where the claim was stated) or `03-decisions.md` (under the relevant decision's Rationale or as a Source). Format suggestion: `Validated by experiments/01-concept-name/ — outcome 2026-06-04`.
- Update the index row's Status column.
- If the hypothesis was refuted, the design must change. Record a new decision in `03-decisions.md` capturing what the refutation taught you and what the design changed to.

## Validate

Two checks, both wired into `task vet`:

1. **Index exists.** If `experiments/` is present, `experiments/README.md` MUST exist.
2. **Per-experiment README exists.** Every `experiments/NN-*/` subdirectory MUST contain `README.md`.

Neither check inspects content. The structural sanity is enforced; the prose is left to PR review.

Run the structural check directly:

```bash
task vet:one ID=NNNN
```

List experiments with parsed status:

```bash
task experiments:list ID=NNNN
```

The list command parses the `Status:` line from each per-experiment README. Missing-or-unparseable Status renders as `(no Status: line)`; missing README renders as `(missing README.md)` (which `task vet` would also flag).

## When to remove

Experiments are disposable. Three valid moments to delete:

- **Enhancement reaches `implemented`.** The design is now in production code; experiments served their purpose. Decision: delete experiments that prove nothing the production code hasn't already validated more comprehensively, or keep them as historical reference if the technique is non-obvious and a future reader might want to see it isolated.
- **Enhancement is rejected.** The whole package is being archived (or the entry is being set to `superseded`). Experiments may be deleted along with the rest of the design intent that was not adopted.
- **Refuted experiment, design redirected.** A `Concluded — refuted` experiment that drove a major design pivot may be retained or deleted. Retain if the refutation itself is the lesson; delete if the new design entirely supersedes the question the experiment asked.

Deletion is a regular `git rm`. Update the `experiments/README.md` index by removing the row. If `experiments/` becomes empty, delete it too — `task vet` does not require it to exist.

## Anti-patterns

- **Adding an experiment upfront when copying the template.** Don't. The template's HTML comments and `0000/README.md ## Experiments` section say "do not create `experiments/` until a specific claim needs validation." Empty experiment scaffolds are noise.
- **Two claims in one experiment.** If you find yourself writing two Hypothesis sentences, stop and split.
- **Importing from `core/` or `library/` instead of copying.** A reviewer six months from now reads the experiment, finds it broken because `core/platform.cue` evolved, and cannot tell whether the claim was ever valid. Copy.
- **Writing tests instead of demonstrations.** Experiments are not `go test ./...`. They are runnable scripts a human invokes to see a behaviour. If your "experiment" wants table-driven test cases and assertions, write a test fixture in `library/` instead.
- **Leaving `Outcome` as the placeholder when transitioning to `Concluded`.** A Concluded experiment without a recorded outcome is a lie. Either write the outcome or roll the status back to `Running`.
- **Not linking the result back into the enhancement.** A concluded experiment that lives only under `experiments/` is invisible to anyone reading the design. The link from `02-design.md` or `03-decisions.md` is what makes the evidence discoverable.
- **Treating the experiment's code as canonical.** It isn't. The canonical schema is `schemas/target.cue` and (eventually) `core/*.cue`. The experiment's copies are *demonstrations of a moment*, not authoritative artefacts.

## Where things live

| Artefact | Path | Authority |
| --- | --- | --- |
| Experiments index | `enhancements/NNNN/experiments/README.md` | Hand-maintained by the agent / author. Lists `# / Concept / Status` rows. |
| Per-experiment README | `enhancements/NNNN/experiments/NN-name/README.md` | Hand-maintained. Hypothesis / Setup / Run / Outcome / `Status:`. |
| Experiment source files | `enhancements/NNNN/experiments/NN-name/*` | Whatever the experiment needs — `.cue`, `.go`, `Taskfile.yml`, `cue.mod/`, etc. Self-contained. |
| Rules canonical text | `enhancements/0000/README.md ## Experiments` | The rules duplicated above live there as the template-side reference. |
| Workflow tasks | `enhancements/Taskfile.yml` (`new:experiment`, `experiments:list`, `vet`) | Tooling source. |
| Structural validation | `enhancements/Taskfile.yml` (`vet` and `vet:one` `check()` functions) | Index + README presence checks. |
| This skill | `enhancements/.claude/skills/enhancement-experiments/SKILL.md` | Workflow guidance — the file you are reading. |

## Cross-references

- `enhancements/CLAUDE.md` — repo guide; points to this skill at the experiments section.
- `enhancements/0000/README.md ## Experiments` — canonical rules text reproduced in each enhancement's template.
- `enhancement-open-questions` skill (sibling, under `enhancements/.claude/skills/`) — when an experiment's outcome lands an OQ in the `informed-by-exp-NN` / `supported-by-exp-NN` partial bucket, the walk formalizes it into a `### DN:` block. Load that skill alongside this one when concluding an experiment whose result resolves a specific OQ.
- `core/.claude/skills/core-schema-edit/SKILL.md` — sister skill governing SPEC.md co-update when an experiment's conclusion lands as a real schema change in `core/*.cue`.
