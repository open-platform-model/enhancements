# 03-gate-error-text — Machine-Readable Artifact Metadata in cue.mod/module.cue

Status: Draft

## Hypothesis

Each drift case listed at the bottom of `../../schemas/examples.cue` fails unification against `#ModuleFileCustomGate` at the field named there, and CUE's error text names that field and both conflicting values. Backs D4 (refuse with CUE's own diagnostic; the message an author reads).

## Setup

Pure CUE. Copy `../../schemas/target.cue` into `gate/` (it imports `opmodel.dev/core@v2`; keep the `cue.mod` and run `cue mod tidy` once). One file per drift case under `cases/`, each a `#ModuleFileCustomGate` instance with exactly one value changed from the passing `certManagerGate`. `run.sh` vets each case separately and records the first error line verbatim.

## Run

Exact commands to reproduce the result:

```bash
bash run.sh
```

## Outcome

Not yet run. Update `Status:` to `Running` once the experiment is live; `Concluded` once the outcome is recorded, then link the result back into `03-decisions.md` next to the decision it backs.
