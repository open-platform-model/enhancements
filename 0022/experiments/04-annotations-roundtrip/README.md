# 04-annotations-roundtrip — Machine-Readable Artifact Metadata in cue.mod/module.cue

Status: Draft

## Hypothesis

`Client.PutModuleWithMetadata` writes CUE's `org.cuelang.vcs-*` keys plus arbitrary `dev.opmodel.*` keys into the OCI manifest annotations, `Module.Metadata()` reads the CUE keys back, the raw manifest carries the OPM keys, and the module-file blob is unaffected. Backs D6.

## Setup

Same Go module shape and local registry as experiment 02 (may share nothing with it). `main.go` publishes the fixture with a `modregistry.Metadata` carrying VCS fields, then fetches the manifest (`Module.ManifestDigest` and a raw `GetManifest`) and prints its annotations. Because `PutModuleWithMetadata` takes only the three CUE fields, the experiment also records how OPM keys are added: either a second manifest push with merged annotations, or a fork of the put path. That finding decides how the CLI writes annotations.

## Run

Exact commands to reproduce the result:

```bash
task registry:start
export CUE_REGISTRY='testing.opmodel.dev=localhost:5000+insecure,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'
go run . ./fixture testing.opmodel.dev/modules/e0022ann@v0 v0.0.1
task registry:stop
```

## Outcome

Not yet run. Update `Status:` to `Running` once the experiment is live; `Concluded` once the outcome is recorded, then link the result back into `03-decisions.md` next to the decision it backs.
