# Design — Initialize a Module Instance Package from a Published Module

## Design Goals

- A single CLI command turns an OCI module reference plus tag into a complete on-disk module instance package: `cue.mod/module.cue`, `instance.cue`, `values.cue`.
- The generated package is correct by construction: dependency majors and pins, the core import, and the `#module:` wiring all derive from the acquired artifact, never from user-typed boilerplate.
- The generated package is the same shape `LoadInstancePackage` already consumes — the output of init is immediately valid input to `opm instance build`, `opm instance apply`, and the operator's ModulePackage path.
- The module author controls what a fresh instance's `values.cue` starts as, through a new optional field on `#Module` dedicated to that purpose.
- Modules published before that field exists still initialize usefully: `debugValues` is the default template source when the dedicated field is absent.
- The command reports which source populated `values.cue` (dedicated field, `debugValues`, or empty scaffold), so the user knows what they are looking at.

## Non-Goals

- **Deploying anything.** Init writes files; `opm instance build` / `apply` remain the execution path.
- **Round-tripping a deployed instance.** Exporting a *live* instance to files is enhancement [0014](../0014/)'s territory (cluster → git). This entry is registry → disk, pre-deployment.
- **Values validation guarantees beyond the template source.** If the author's `debugValues` does not satisfy `#config`, init surfaces that (see OQ5) but does not repair it.
- **Module scaffolding.** `opm module init` (author-side templates) is untouched.
- **A general templating language.** The new `#Module` field carries a CUE value, not a text template; rendering it to `values.cue` is serialization, not template expansion.
- **Registry discovery/search.** The user supplies the reference; finding modules is out of scope.

## High-Level Approach

```text
  user: module ref + tag + name + namespace
            |
            v
  +-------------------------------+
  | opm instance init             |
  |                               |
  |  1 acquire module from        |----> CUE registry (OCI): fetch + decode,
  |    registry (existing kernel  |      same path opm module build uses
  |    acquire path)              |      (AcquireModuleFromRegistry)
  |                               |
  |  2 pick values source         |      initValues? present -> use it
  |    (precedence ladder)        |      else debugValues     -> use it
  |                               |      else                 -> empty scaffold
  |                               |
  |  3 render package to disk     |
  +-------------------------------+
            |
            v
  jellyfin/                        (or --dir)
    cue.mod/module.cue             module: user-local path; deps: the module
                                   (pinned to resolved tag) + core (module's major)
    instance.cue                   package p; import core + module;
                                   core.#ModuleInstance; metadata {name, namespace};
                                   #module: <module pkg>
    values.cue                     package p; values: { ...rendered source... }
```

The command is the write-to-disk sibling of `synth.Instance`: synth overlays a generated `instance.cue`/`values.cue` *inside the acquired module's staged tree* for one in-memory build; init emits the same logical package as a *standalone* directory whose `cue.mod/module.cue` declares the module and core as registry dependencies. Synth's file-rendering logic is the natural implementation seed (OQ4 decides where the shared code lives).

`synth.Instance`'s documented refusal to fall back to `debugValues` ("a frontend policy concern") stays intact — init is precisely the frontend defining that policy, and only for its own scaffolding output.

## Schema / API Surface

Full shapes in [`schemas/target.cue`](schemas/target.cue) (core delta) and [`contracts/contracts.cue`](contracts/contracts.cue) (CLI contracts). Two surfaces:

**Core — one new optional field on `#Module`** (working name `initValues`; final name is OQ1):

- `initValues?: _` — the values a freshly initialized instance package starts from. Author-supplied, optional, and intended to satisfy `#config` (whether that intent is schema-enforced is part of OQ1). Sits beside `debugValues`, which keeps its existing meaning (concrete values for testing/debugging) and becomes the documented *fallback* template source.
- Additive change: no existing module is invalidated; consumers that never read the field are unaffected.

**CLI — one new command** (surface details are OQ2):

- `opm instance init <module-ref> [--version <tag>] --name <name> --namespace <ns> [--dir <dir>]`
- `<module-ref>` is the module path (e.g. `opmodel.dev/modules/jellyfin@v3`); resolution to an OCI repository goes through the standard `CUE_REGISTRY`/`OPM_REGISTRY` routing, exactly as every existing registry-facing command.
- Output: the three-file package above plus a report naming the resolved version and the values source used.

## Integration Points

- **`core/`** — `src/module.cue`: add the optional field beside `debugValues` (`core-schema-edit` protocol; `SPEC.md` co-update). This is the only schema change.
- **`cli/`** — new `init.go` under `cli/internal/cmd/instance/`; registration in `instance.go`. Rendering either calls a library helper (OQ4) or lives in `cli/internal` beside the existing template machinery.
- **`library/`** — depending on OQ4: either `helper/synth`'s instance-file rendering is generalized and exported so CLI and synth share one generator, or library ships nothing and the CLI renders independently. The module acquire path (`Kernel.AcquireModuleFromRegistry`) is used as-is either way. `module.Module`'s decoded surface must expose the new field to Go callers (as it already exposes `debugValues` handling in the kernel).
- **`opmodel.dev/`** — CLI reference regenerates mechanically after the command lands; follows the landing, does not gate it.

## Before / After

**Before** (today, jellyfin): copy `opm-kind-demo/web_app/instance.cue`, rewrite imports from `web_app@v0`/`core@v1` to `jellyfin@v3`/`core@v2`, hand-write `cue.mod/module.cue` with guessed pins, then iterate `cue vet` until an unfamiliar `#config` is satisfied.

**After**:

```text
$ opm instance init opmodel.dev/modules/jellyfin@v3 --version 3.0.0 --name jellyfin --namespace media
Resolved opmodel.dev/modules/jellyfin@v3 -> 3.0.0
Values template: debugValues (module declares no initValues)
Created jellyfin/
  cue.mod/module.cue
  instance.cue
  values.cue

$ opm instance build ./jellyfin        # succeeds before any edit
```

The user then edits `values.cue` — starting from author-intended content, with the contract (`#config`) enforced by `cue vet`/`opm instance vet` as they go. When the jellyfin author later adds `initValues` to the module, the same command scaffolds from that field instead, and the report line says so.
