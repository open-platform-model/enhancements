# Design — Initialize a Module Instance Package from a Published Module

## Design Goals

- A single CLI command turns a published module's path (plus an optional version) into a complete on-disk module instance package: `cue.mod/module.cue`, `instance.cue`, `values.cue`.
- The command is learned for free by anyone who knows `opm module init`: same positional/flag conventions, prompting, refusal behavior and exit codes, with the deployed module standing where the template stands.
- With no version given, the deployer gets the newest module line this CLI can actually build: the highest major whose core dependency matches the CLI's core major.
- The generated package is correct by construction: dependency majors and pins, the core import, and the `#module:` wiring all derive from the acquired artifact, never from user-typed boilerplate.
- The generated package is the same shape `LoadInstancePackage` already consumes — the output of init is immediately valid input to `opm instance build`, `opm instance apply`, and the operator's ModulePackage path.
- The module author controls what a fresh instance's `values.cue` starts as, through a new optional field on `#Module` dedicated to that purpose.
- Modules published before that field exists still initialize usefully: `debugValues` is the default template source when the dedicated field is absent.
- The command reports which source populated `values.cue` (dedicated field, `debugValues`, or empty scaffold), so the user knows what they are looking at.

## Non-Goals

- **Deploying anything.** Init writes files; `opm instance build` / `apply` remain the execution path.
- **Round-tripping a deployed instance.** Exporting a *live* instance to files is enhancement [0014](../0014/)'s territory (cluster → git). This entry is registry → disk, pre-deployment.
- **Validating the generated package.** Init does not vet what it wrote (D8); the report names `opm instance vet`, and a template source that does not satisfy `#config` surfaces there.
- **Module scaffolding.** `opm module init` (author-side templates) is untouched.
- **A general templating language.** The new `#Module` field carries a CUE value, not a text template; rendering it to `values.cue` is serialization, not template expansion.
- **Registry discovery/search.** The user supplies the reference; finding modules is out of scope.

## High-Level Approach

```text
  user: instance name + module path + namespace [+ --version]
            |
            v
  +-------------------------------+
  | opm instance init             |
  |                               |
  |  1 resolve version            |----> list published versions (all majors);
  |    (D5)                       |      --version vN / X.Y.Z narrows; omitted:
  |                               |      highest major whose core dep major ==
  |                               |      this CLI's core major, newest release
  |                               |
  |  2 acquire module from        |----> CUE registry (OCI): fetch + decode,
  |    registry (existing kernel  |      same path opm module init uses
  |    acquire path)              |      (AcquireModuleFromRegistry)
  |                               |
  |  3 pick values source         |      initValues  present -> use it
  |    (D2, D3, D6)               |      else debugValues    -> use it
  |                               |      else                -> values: {} + warning
  |                               |
  |  4 render package to disk     |
  |    (D7, D9)                   |
  +-------------------------------+
            |
            v
  cert-manager/                    (or --dir)
    cue.mod/module.cue             module: instance.local/<name>@v0 (or --module-path);
                                   deps: the module (exact pin) + core (module's
                                   major) + the rest of the closure, tidied
    instance.cue                   package p; import core + module;
                                   core.#ModuleInstance; metadata {name, namespace};
                                   #module: <module pkg>
    values.cue                     package p; values: { ...rendered source... }
```

The command is the write-to-disk sibling of `synth.Instance`: synth overlays a generated `instance.cue`/`values.cue` *inside the acquired module's staged tree* for one in-memory build; init emits the same logical package as a *standalone* directory whose `cue.mod/module.cue` declares the module and core as registry dependencies. The two renderers are separate by decision (D7): init's lives in the CLI beside `opm module init`, and the CLI's end-to-end test loads the generated package through the real `LoadInstancePackage` so the two shapes cannot drift silently.

`synth.Instance`'s documented refusal to fall back to `debugValues` ("a frontend policy concern") stays intact — init is precisely the frontend defining that policy, and only for its own scaffolding output.

## Schema / API Surface

Full shapes in [`schemas/target.cue`](schemas/target.cue) (core delta) and [`contracts/contracts.cue`](contracts/contracts.cue) (CLI contracts). Two surfaces:

**Core — one new optional field on `#Module`** (D3, D4):

- `initValues?: _` — the values a freshly initialized instance package starts from. Author-supplied, optional, open, may be non-concrete, and intended to satisfy `#config` (SHOULD; not asserted by the schema). Sits beside `debugValues`, which keeps its existing meaning (concrete values for testing/debugging) and becomes the documented *fallback* template source.
- Additive change: no existing module is invalidated; consumers that never read the field are unaffected.

**CLI — one new command** (D5):

- `opm instance init [instance-name] [module-path] [--from <module-path>] [--version <vN | X.Y.Z>] --namespace <ns> [--dir <dir>] [--module-path <path>]`
- `module-path` is major-free (`opmodel.dev/modules/cert_manager`); a major suffix is refused with a hint to use `--version`. Resolution to an OCI repository goes through the standard `CUE_REGISTRY`/`OPM_REGISTRY` routing, exactly as every existing registry-facing command; there is no OCI-URL form and no bare-word shortcut.
- `--version vN` floats within a major, an exact SemVer pins; omitted, init selects the newest release of the highest major whose `opmodel.dev/core` dependency major equals the CLI's core major, and the report names what it chose and which higher majors it skipped.
- Missing name or namespace is prompted for when a terminal is attached and refused otherwise; `--dir` defaults to the instance name and refuses an existing or module-holding directory. Exit codes 0 / 2 refused / 3 registry unreachable, as `module init`.
- Output: the three-file package above plus a report naming the resolved version, the values source used, any warnings, and the vet command to run next.

## Integration Points

- **`core/`** — `src/module.cue`: add the optional field beside `debugValues` (`core-schema-edit` protocol; `SPEC.md` co-update). This is the only schema change.
- **`cli/`** — the new subcommand in the instance command group, with the version selection, values-source ladder and package rendering CLI-side beside the existing `opm module init` scaffolding, reusing its reference grammar, version resolution and kernel acquire path (D5, D7).
- **`library/`** — nothing ships. The kernel acquire path and the module decode surface are used as they are; `initValues` is read off the decoded module value like any other field. `synth.Instance` is unchanged (D7).
- **`opmodel.dev/`** — CLI reference regenerates mechanically after the command lands; follows the landing, does not gate it.

## Before / After

**Before** (today, cert_manager): copy `opm-kind-demo/web_app/instance.cue`, rewrite imports from `web_app@v0`/`core@v1` to `cert_manager@v2`/`core@v2`, hand-write `cue.mod/module.cue` with guessed pins, then iterate `cue vet` until an unfamiliar `#config` is satisfied.

**After**:

```text
$ opm instance init cert-manager opmodel.dev/modules/cert_manager --namespace cert-manager
Resolved opmodel.dev/modules/cert_manager -> v2 2.0.1 (highest major on core v2)
Values template: debugValues (module declares no initValues; review before deploying)
Initialized instance cert-manager/
  cue.mod/module.cue
  instance.cue
  values.cue

Validate it:  opm instance vet cert-manager/instance.cue

$ opm instance build ./cert-manager/instance.cue   # succeeds before any edit
```

The user then edits `values.cue` — starting from author-intended content, with the contract (`#config`) enforced by `cue vet`/`opm instance vet` as they go. When the cert_manager author later adds `initValues` to the module, the same command scaffolds from that field instead, and the report line says so.
