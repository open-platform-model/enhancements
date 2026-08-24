# 05-probe-cost — Machine-Readable Artifact Metadata in cue.mod/module.cue

Status: Draft

## Hypothesis

Reading `kind` and `core.major` from the block costs the same two requests as 0016 experiment 02's `deps` probe (manifest plus a ~230-byte blob), so D7's reader adds no round-trip over today's walk. Backs D7.

## Setup

Copy 0016's `experiments/02-core-major-probe/main.go` (never import it) and extend it to print `File.Custom["opmodel.dev@v0"]` when present. Targets: `opmodel.dev/modules/cert_manager` at its three majors on GHCR (no block today: expect rung 2 and rung 3 verdicts) and the fixture experiment 02 published locally (rung 1). Three cold runs each; record bytes and wall time per arm.

## Run

Exact commands to reproduce the result:

```bash
export CUE_REGISTRY='opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'
for t in "opmodel.dev/modules/cert_manager@v2 v2.0.1" "opmodel.dev/modules/cert_manager@v0 v0.1.0"; do
  for i in 1 2 3; do CUE_CACHE_DIR=$(mktemp -d) go run . $t; done
done
```

## Outcome

Not yet run. Update `Status:` to `Running` once the experiment is live; `Concluded` once the outcome is recorded, then link the result back into `03-decisions.md` next to the decision it backs.
