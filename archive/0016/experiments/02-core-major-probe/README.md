# 02-core-major-probe — Initialize a Module Instance Package from a Published Module

Status: Concluded

## Hypothesis

A candidate version's `opmodel.dev/core` dependency major can be read by fetching only its `cue.mod/module.cue` (`modregistry.Client.GetModule` then `Module.ModuleFile`), without downloading the module zip, at a fraction of the cost of a full acquire. Backs D5: the core-compatibility check that drives major selection must be cheap enough to run per candidate major by default.

## Setup

Same throwaway Go module shape as experiment 01 (`cuelang.org/go v0.17.1`, Go 1.26.5; shares nothing with it). `main.go` takes a major-suffixed module path and a version, calls `Client.GetModule` (one manifest fetch), then `Module.ModuleFile` (one blob fetch of manifest layer 1, the module file; the zip is layer 0 and is not touched), parses with `modfile.ParseNonStrict`, and prints the `deps` entry whose path starts with `opmodel.dev/core@`. `DUMP_MODFILE=1` prints the whole module file. The `--full` comparison arm additionally calls `Module.GetZip` and drains it in the same process.

Per call the program prints wall time for the manifest fetch and the blob fetch, and the blob's byte count. `CUE_CACHE_DIR` points at a fresh temp dir per run, so every run is cold. Targets: cert_manager at its newest v2, v1 and v0 tags (from experiment 01) and metallb at its newest v2 and v0 tags.

## Run

```bash
export CUE_REGISTRY='opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'
for t in "opmodel.dev/modules/cert_manager@v2 v2.0.1" "opmodel.dev/modules/cert_manager@v1 v1.1.1" \
         "opmodel.dev/modules/cert_manager@v0 v0.1.0" "opmodel.dev/modules/metallb@v2 v2.0.1" \
         "opmodel.dev/modules/metallb@v0 v0.0.8"; do
  for i in 1 2 3; do CUE_CACHE_DIR=$(mktemp -d) go run . $t; done
done
for i in 1 2 3; do CUE_CACHE_DIR=$(mktemp -d) go run . --full opmodel.dev/modules/cert_manager@v2 v2.0.1; done
DUMP_MODFILE=1 go run . opmodel.dev/modules/cert_manager@v0 v0.1.0
```

## Outcome

**Hypothesis held, with one finding that changed D5's rule.** Run 2026-08-24 against GHCR, cold cache every run, three runs per target.

| Target | Manifest fetch | module.cue blob | Blob size | Core dependency read |
| --- | --- | --- | --- | --- |
| cert_manager v2.0.1 | 506–624 ms | 169–324 ms | 226 B | `opmodel.dev/core@v2 v2.0.0-alpha.4` |
| cert_manager v1.1.1 | 501–721 ms | 172–296 ms | 274 B | `opmodel.dev/core@v1 v1.1.0` |
| cert_manager v0.1.0 | 521–570 ms | 170–371 ms | 272 B | **none** (a v0-era module on the retired `opmodel.dev/core/v1alpha1` path) |
| metallb v2.0.1 | 491–528 ms | 172–329 ms | 221 B | `opmodel.dev/core@v2 v2.0.0-alpha.4` |
| metallb v0.0.8 | 509–838 ms | 266–378 ms | 215 B | **none** |
| cert_manager v2.0.1 `--full` (zip on top) | 501–829 ms | 176–446 ms | 226 B | plus zip: 205–516 ms, **230 268 B** |

- The probe is two round-trips (manifest, then one small blob) and never touches the module zip: the blob is 0.1% of the zip's bytes for cert_manager (which ships CRD data). Latency is dominated by the manifest round-trip (~0.5 s cold against GHCR), so a walk over three majors costs about 2 s cold and writes nothing to the module cache. Acceptable as the default for a one-shot scaffolding command.
- The probe distinguishes majors correctly: cert_manager v2 → core v2, v1 → core v1.
- **Finding for D5:** a published major can declare *no* `opmodel.dev/core` dependency at all (cert_manager v0, metallb v0). D5's compatibility rule treats "no `opmodel.dev/core` dependency" as incompatible with the CLI's core major (skip, and report it as such), never as an error and never as a wildcard match. Written into D5 on 2026-08-24. Nothing else about the pre-v2 lines matters to this enhancement; they exist only as lines the walk skips.

Evidence linked from D5's `Source:` in `../../03-decisions.md`.
