# 04-catalog-stamping-flow — #Platform Redesign Umbrella

Status: Concluded

Pins: OQ9 → resolved-by-D7, OQ10 → resolved-by-D7, OQ11 → resolved-by-D8, OQ12 → resolved-by-D9

## Hypothesis

A pure-CUE catalog package with root `Catalog: { Version: string | *"0.0.0-dev", ModulePath }` constant — and a subpackage `resources/container.cue` that reads `Catalog.Version` via standard CUE cross-package import — vets clean in the source tree at `0.0.0-dev`; after a `rsync → .build/ → overwrite Catalog.Version → cue export` stamping flow, every primitive's `metadata.version` is the requested SemVer; reverting the source tree leaves zero diff.

## Setup

Two-package CUE catalog under `./catalog/`:

- `./catalog/cue.mod/module.cue` — `module: "opmodel.dev/experiments/0001/04/catalog@v0"`.
- `./catalog/catalog.cue` (package `catalog`, root) — copies minimal slice from `enhancements/0001/schemas/target.cue` (`#NameType`, `#ModulePathType`, `#VersionType`, `#FQNType`, `#PrimitiveMetadata`, `#Resource`). Declares exported `Catalog: { Version: #VersionType | *"0.0.0-dev", ModulePath: ... | *"opmodel.dev/experiments/0001/04/catalog" }`.
- `./catalog/resources/container.cue` (package `resources`, subpackage) — imports `opmodel.dev/experiments/0001/04/catalog` and references `catalog.Catalog.Version` / `catalog.Catalog.ModulePath` in `#ContainerResource.metadata`. One concrete `container_resource` instance for export.

`./stamp.sh` — driver: `rsync` catalog → `.build/catalog/`, write `version_override.cue` setting `Catalog.Version` to the requested SemVer, `cue vet`, `cue export` filtered through `jq` to surface every `metadata.{name,modulePath,version,fqn}`, then `diff -r` source vs build.

`./cue.mod/module.cue` — outer experiment-wrapper module path `enhancements.opmodel.dev/0001/experiments/04-catalog-stamping-flow@v0`.

## Run

```bash
( cd catalog && cue vet ./... )         # MUST succeed at 0.0.0-dev
( cd catalog && cue export ./resources/... | jq '.container_resource.metadata' )
bash stamp.sh 1.0.0                     # stamped build dir prints "1.0.0" everywhere
bash stamp.sh 1.4.0-rc.1                # prerelease handled cleanly
```

## Outcome

Observed on 2026-05-23 with cue v0.16.1, jq 1.7:

- Source-tree vet succeeds at `Catalog.Version` default `0.0.0-dev`.
- Source-tree export yields:
  ```json
  { "name": "container",
    "modulePath": "opmodel.dev/experiments/0001/04/catalog/resources/workload",
    "version": "0.0.0-dev",
    "fqn": "opmodel.dev/experiments/0001/04/catalog/resources/workload/container@0.0.0-dev" }
  ```
- After `stamp.sh 1.0.0`: same shape but `version: "1.0.0"`, `fqn: "…@1.0.0"`.
- After `stamp.sh 1.4.0-rc.1`: `version: "1.4.0-rc.1"`, `fqn: "…@1.4.0-rc.1"` — prerelease propagates correctly.
- `diff -r catalog .build/catalog` after each stamp reports only `Only in .build/catalog: version_override.cue` — source tree is byte-clean.
- Subpackage `resources/container.cue` reads `catalog.Catalog.Version` via standard `import "opmodel.dev/experiments/0001/04/catalog"` — cross-package access works as expected with the exported (capital-C) `Catalog` identifier.

**Hypothesis held.** Confirms (a) root-package constant pattern (OQ9 → D7), (b) capital-C exported identifier crosses package boundaries (OQ10 → D7), (c) `0.0.0-dev` source default keeps dev-time `cue vet` cheap (OQ11 → D8), (d) temp-build-dir + `version_override.cue` sibling-file stamping leaves source tree untouched (OQ12 → D9). All four OQs closed in `03-decisions.md`.
