# 03-generated-package-builds — Initialize a Module Instance Package from a Published Module

Status: Concluded

## Hypothesis

A standalone three-file instance package (`cue.mod/module.cue` with `module: "instance.local/cert_manager@v0"`, the module pinned exactly, core at the module's own major, plus the tidied closure; `instance.cue`; `values.cue`) loads as a CUE package, fans the module's components, builds through `opm instance build`, works offline from the module cache, and the placeholder `instance.local/...` path causes no registry lookup. Backs D1 and D9.

## Setup

`pkg/` is the package exactly as init will emit it for `opmodel.dev/modules/cert_manager@v2` at `v2.0.1`:

- `cue.mod/module.cue`: `module: "instance.local/cert_manager@v0"`, `language.version: "v0.17.0"`, and `deps` with the module at `v2.0.1` and `opmodel.dev/core@v2` at `v2.0.0-alpha.4`, the pin cert_manager's published module file names (experiment 02 dumped it). This is the *pre-tidy* state; `run.sh` runs `cue mod tidy` and diffs, and the closure it adds is what D9 obliges init to write.
- `instance.cue`: the shape `renderInstanceFile` in `library/opm/helper/synth/render.go` (library commit 11da9b0) produces, retyped by hand: `package instance`, imports `core "opmodel.dev/core@v2"` and `opmModule "opmodel.dev/modules/cert_manager@v2"`, `core.#ModuleInstance`, `metadata {name: "cert-manager", namespace: "cert-manager"}`, `#module: opmModule`.
- `values.cue`: `values:` copied byte for byte from `modules/cert_manager/module.cue` `debugValues` (modules commit 7c946b0), the D2 fallback source.

`run.sh` takes `OPM` (an `opm` built from cli commit 2370bd6, `v1.0.0-alpha.13-9-g2370bd6`, CUE SDK v0.17.1) and `PLATFORM` (a platform file whose `catalogs/opm@v2` subscription implements the module's contracts; `cli/hack/platform.cue` pins `2.0.0-alpha.5`).

## Run

```bash
export CUE_REGISTRY='opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'
OPM=../../../../cli/bin/opm PLATFORM=$PWD/../../../../cli/hack/platform.cue bash run.sh
```

## Outcome

**Hypothesis held.** Run 2026-08-24.

- `cue mod tidy` (exit 0) adds one dependency, `opmodel.dev/catalogs/opm@v2` at `v2.0.0-alpha.2`, the catalog cert_manager v2.0.1 itself pins; module and core pins are untouched. That one line is the "complete closure" D9 requires init to write.
- Pure CUE: `cue vet ./...` passes; `len(components)` evaluates to **20**, so the module's components fan through `#ModuleInstance` from the import.
- Offline: with `CUE_REGISTRY` unset and a warm cache, `cue vet ./...` still passes. No output ever mentions `instance.local`: the placeholder path is never looked up.
- `opm instance build ./instance.cue --platform cli/hack/platform.cue` renders the full tree: 10 ClusterRole, 10 ClusterRoleBinding, 6 CustomResourceDefinition, 3 Deployment, 1 MutatingWebhookConfiguration, 1 Namespace, 3 Role, 3 RoleBinding, 1 Service, 3 ServiceAccount, 1 ValidatingWebhookConfiguration.
- Two things that are *not* package problems, recorded so the CLI change does not chase them: (1) `opm instance build .` refuses a directory argument ("is an instance package, not a module"); the command takes the `instance.cue` path, so init's report must name the file, not the directory. (2) Against the local default platform (`~/.opm/platform.cue`, `catalogs/opm` at `2.0.0-alpha.3`) the same package fails with "19 unresolved demands, nothing on this platform implements this contract", and so does a platform pinned to the module's own `alpha.2`. Whether a package *builds* depends on the platform's catalog subscription; whether it is *correct* does not. That is exactly the split D8 relies on: init writes a valid package and points the user at the vet, and the vet's verdict is platform-relative.

Evidence linked from D9's `Source:` in `../../03-decisions.md`.
