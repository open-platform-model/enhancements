# 01-tidy-roundtrip — Machine-Readable Artifact Metadata in cue.mod/module.cue

Status: Draft

## Hypothesis

A `custom: "opmodel.dev@v0"` block seeded into a copy of `modules/cert_manager`'s `cue.mod/module.cue` survives `cue mod tidy` and `cue mod get` with every value intact (comments dropped, keys sorted, scalars normalised), and the gate in `../../schemas/target.cue` still passes against the rewritten file. Backs D1 (CUE carries the block) and answers OQ5 (tidy-then-gate stability).

## Setup

Copy `modules/cert_manager/cue.mod/module.cue` (modules commit 7c946b0) into `pkg/cue.mod/module.cue` together with the minimal `.cue` files the tidy needs to see the imports (copy `module.cue` and `identity/identity.cue`; the catalog imports resolve from GHCR through `CUE_REGISTRY`). Add the block from `../../schemas/examples.cue` (`certManagerBlock`) by hand, with a comment inside it and keys deliberately out of order. Record the file before and after each command; then feed the after-file's `module`, `deps` and the block into a copy of `#ModuleFileCustomGate` (copy `../../schemas/target.cue` into `gate/`, never import it) and vet.

CUE toolchain: `cue` v0.17.1 (record `cue version`).

## Run

Exact commands to reproduce the result:

```bash
export CUE_REGISTRY='opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'
cd pkg && cp cue.mod/module.cue /tmp/e01-before.cue
cue mod tidy && diff /tmp/e01-before.cue cue.mod/module.cue
cue mod get opmodel.dev/core@v2 && diff /tmp/e01-before.cue cue.mod/module.cue
cd ../gate && cue vet -c ./...
```

## Outcome

Not yet run. Update `Status:` to `Running` once the experiment is live; `Concluded` once the outcome is recorded, then link the result back into `03-decisions.md` next to the decision it backs.
