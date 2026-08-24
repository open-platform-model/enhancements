# 02-publish-fetch-verbatim — Machine-Readable Artifact Metadata in cue.mod/module.cue

Status: Draft

## Hypothesis

A module published with the block through CUE's own registry client arrives in the registry with `cue.mod/module.cue` byte-identical as OCI layer 1, and `Module.ModuleFile` plus `modfile.ParseNonStrict` return the block from the manifest and that one blob, without the zip. Backs D1 and D7 (the reader needs only layer 1). Closes the gap that upstream has no end-to-end test for `custom`.

## Setup

A throwaway Go module (`cuelang.org/go v0.17.1`) and a local OCI registry started deliberately as a registry-policy rule 3 override (`task registry:start` from the workspace root; say so in the outcome). The fixture module is published under `testing.opmodel.dev/modules/e0022@v0` with `CUE_REGISTRY` mapping only that domain to `localhost:5000`; nothing under `opmodel.dev/*` is written. `main.go` zips a fixture directory carrying the block (`modzip.CreateFromDir`), calls `Client.PutModule`, then `GetModule`, `ModuleFile`, and compares bytes with the file it zipped; it also parses the returned bytes with `modfile.ParseNonStrict` and prints `File.Custom`.

Record: manifest layer count and media types, the byte comparison, and the parsed block.

## Run

Exact commands to reproduce the result:

```bash
task registry:start   # workspace root; rule 3 override, local only
export CUE_REGISTRY='testing.opmodel.dev=localhost:5000+insecure,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'
go run . ./fixture testing.opmodel.dev/modules/e0022@v0 v0.0.1
task registry:stop
```

## Outcome

Not yet run. Update `Status:` to `Running` once the experiment is live; `Concluded` once the outcome is recorded, then link the result back into `03-decisions.md` next to the decision it backs.
