---
name: enhancement-experiments
description: Protocol for experiments inside an OPM enhancement entry. Load before you add an experiment under an entry's evidence/experiments/, edit an experiment's README, change an experiment's Status (Draft, Running, Concluded), or check whether a design claim needs a runnable proof.
user-invocable: true
---

# Enhancement Experiments

An experiment is a small runnable proof of one claim in an entry's `design.md`. It lives in the entry's `evidence/experiments/`. `evidence/` is outside every word cap, and no task scaffolds or lists experiments: you make the folders by hand.

## When this skill applies

Load it when:

- a theme of `design.md` rests on a CUE evaluation pattern, kernel behaviour or Go fixture that nobody has shown end to end;
- a reviewer asks "does that actually work?" and the cheapest honest answer is a small sandbox;
- you edit any file under `evidence/experiments/` of an entry;
- you change an experiment's `Status:` line.

To read an existing experiment, you do not need this skill. Open its `README.md` and follow Hypothesis, Setup, Run and Outcome.

## Core rules

1. **One claim per experiment.** If you write two Hypothesis sentences, split it.
1. **Self-contained.** An experiment runs without changing anything outside its own folder. If it needs a CUE schema or a Go fixture from another repo, copy it in and change the copy.
1. **Copy, never import.** An import from `core/`, `library/` or `catalog_opm/` makes the experiment break when upstream moves, and nobody can tell whether the claim was ever valid. Cite the source path of every copy in Setup.
1. **Disposable.** Nothing else depends on an experiment. Do not write a Go module that another repo imports.
1. **Minimum tooling.** Go for runtime experiments, CUE for schema experiments, shell for orchestration.
1. **A demonstration, not a test suite.** A human runs the commands in `## Run`. CI does not run them. If you want table-driven cases, write a test in the target repo.

## Make an experiment

Under the entry folder, `openspec/changes/<id>-<slug>/`:

```text
evidence/
  README.md                  one line per file or folder, including experiments/
  experiments/
    README.md                the index: # / Concept / Status
    01-concept-name/
      README.md              Status, Hypothesis, Setup, Run, Outcome
      ...                    the files the experiment needs
```

1. Make `evidence/experiments/` the first time a claim needs proof. Do not make it at scaffold time.
1. Pick the next two-digit number and a kebab-case name.
1. Write `01-concept-name/README.md`. The first content after the heading is `Status: Draft`. Then:
   - **Hypothesis**: one sentence naming the claim in `design.md`. Name the specific assertion, not "the design works".
   - **Setup**: what you copied, from where, and what you changed.
   - **Run**: the exact commands. Prefer one command (`go run .`, `cue eval`, `bash run.sh`). If more are needed, number them.
   - **Outcome**: a placeholder at Draft.
1. Add a row to `evidence/experiments/README.md`: `| 01 | concept-name | Draft |`. The index is hand-kept.
1. Add or keep a line naming `experiments/` in `evidence/README.md`. `task vet` warns (V29) when a file or folder of `evidence/` is not named there.
1. Run `task vet ID=<id>`. It always runs `cue vet ./...` in each CUE module under `evidence/` and reports a failure as a warning.

## Status

| Status | Meaning | Next |
| --- | --- | --- |
| `Draft` | Hypothesis written. Setup, Run and Outcome are placeholders. | Fill Setup and Run, try it, move to `Running`. |
| `Running` | Setup and Run reproduce the current state. Outcome may be partial. | Record the outcome, then move to `Concluded`. |
| `Concluded` | The outcome ends with "Hypothesis held." or "Hypothesis refuted." and one sentence of evidence. | Keep it, or delete it. |

Edit the `Status:` line and the index row together. While `Running`, keep Setup and Run true for the current state, and write what you observe without judging the hypothesis early.

When an experiment concludes, link the result into the entry: one line in the `design.md` theme it informs, such as "Shown by `evidence/experiments/01-concept-name/`". If the hypothesis was refuted, the design must change. Change the theme, and keep the refuted option in `Considered and rejected` with one line on why.

Do not link `evidence/` from a requirement. A requirement states what holds, and the experiment is the proof behind a theme.

## When to remove

An experiment is disposable. Delete it with `git rm` before `task deliver` when the shipped code proves the claim better, or when a new design makes its question moot. Keep a refuted experiment if the refutation is the lesson. Remove its index row and its line in `evidence/README.md`. An archived entry is not edited, so remove an experiment only while the entry is live.

## Anti-patterns

- **Making `experiments/` at scaffold time.** An empty folder is noise.
- **Two claims in one experiment.**
- **Importing instead of copying.**
- **Writing tests.** An experiment is a runnable demonstration.
- **A Concluded experiment with a placeholder Outcome.** Write the outcome, or move the status back to `Running`.
- **Not linking the result into `design.md`.** Evidence that nobody can find is not evidence.
- **Treating the experiment's code as canonical.** The canonical CUE is in the target repo. The copies show one moment.

## Cross-references

- `AGENTS.md`: the rules of the repo, including `evidence/`.
- `.claude/skills/enhancements/SKILL.md`: the workflow protocol.
- `core/.claude/skills/core-schema-edit/SKILL.md`: the SPEC.md co-update protocol, when an experiment's result lands as a change in `core/*.cue`.
