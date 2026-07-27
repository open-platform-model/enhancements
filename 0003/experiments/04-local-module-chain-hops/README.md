# 04-local-module-chain-hops — OPM Module Publishing Workflow

Status: Concluded

Pins: OQ8 (does a `cue.mod/local-module.cue` replacement chain survive more than one hop) — bullets 1 and 2. Bullet 3 (catalog materialization) is out of scope here; see Outcome.

## Hypothesis

CUE honours `cue.mod/local-module.cue` only for the **main** module, so a replaced dependency's own `local-module.cue` is ignored. The dev loop OPM wants is two hops — an instance replaces its module with a local checkout, and that module in turn replaces a catalog with a local checkout — so the inner hop is dropped and the instance resolves *local module bytes against the published catalog*. The chain can nonetheless be reconstructed by hand if the main module's `local-module.cue` carries an entry for every hop, and `cue mod tidy` preserves such a multi-entry file rather than dropping the transitive entry as unreferenced.

## Setup

Self-contained; nothing outside this directory is read or modified. A three-link chain `inst → mod → cat`, where every artifact carries an `Origin` marker naming which bytes were resolved.

Published to the local dev registry under the throwaway namespace `testing.opmodel.dev/exp0003h/`:

- `registry/cat/` — `cat@v1`, `Origin: "REGISTRY"`.
- `registry/mod/` — `mod@v0`, depends on `cat@v1`, `Origin: "REGISTRY"`, and **re-exports `CatOrigin: c.Origin`** — the mechanism that lets the outermost module report which `cat` the *inner* module resolved against.

Local checkouts, never published, declaring the same module paths so they are substitutable:

- `local/cat/` — `Origin: "LOCAL-CHECKOUT"`.
- `local/mod/` — `Origin: "LOCAL-CHECKOUT"`, and carries **its own** `cue.mod/local-module.cue` replacing `cat@v1` with `../cat`. This is the inner hop under test.

Four instance modules, differing only in their `local-module.cue`:

| Case | `local-module.cue` | `cat` in `deps` |
| --- | --- | --- |
| `case1_baseline` | none | — |
| `case2_one_hop` | replaces `mod` only | — |
| `case3_two_entry` | replaces `mod` **and** `cat` | pinned `v: "v1.0.0"` |
| `case4_two_entry_no_dep` | replaces `mod` **and** `cat` | present but version-less (`{}`) |

The `local-module.cue` syntax (`deps: "<path>": replaceWith: "<dir>"`, and the version-less `deps` entry for a dependency that exists solely to be replaced) mirrors the shape exercised by `cli/pkg/loader/local_module_resolution_test.go`; the fixtures here are written fresh rather than copied.

`run.sh` publishes the registry side, resolves all four cases, then runs `cue mod tidy` on `case3_two_entry` and diffs both module files before and after.

## Run

```bash
bash run.sh
```

Requires a registry at `localhost:5000` (the driver preflights and exits non-zero if absent).

## Outcome

Observed 2026-07-25 with cue v0.17.1 against a live registry at `localhost:5000`.

| Case | `modOrigin` | `catOrigin` | Reading |
| --- | --- | --- | --- |
| `case1_baseline` | `REGISTRY` | `REGISTRY` | control — clean registry resolution |
| `case2_one_hop` | `LOCAL-CHECKOUT` | **`REGISTRY`** | **inner hop dropped — mixed resolution** |
| `case3_two_entry` | `LOCAL-CHECKOUT` | `LOCAL-CHECKOUT` | chain reconstructed by hand |
| `case4_two_entry_no_dep` | `LOCAL-CHECKOUT` | `LOCAL-CHECKOUT` | version-less `deps` entry works |

`cue mod tidy` on `case3_two_entry` **preserved both entries**. It reformatted (`x: y: z` expanded to nested braces) and sorted keys alphabetically, but dropped nothing from either `module.cue` or `local-module.cue`, and re-resolution after tidy still yields `LOCAL-CHECKOUT` for both.

**Hypothesis held, in all three parts.**

1. **The inner hop is dropped.** `case2_one_hop` is the failure OQ8 predicted, reproduced exactly: `local/mod`'s own `local-module.cue` asks for a local `cat` and is silently ignored, so the instance renders local module bytes against the *published* catalog. Nothing in the output names a replacement or warns that one was discarded — the only visible symptom is a value that came from somewhere the developer did not intend.
2. **The chain can be reconstructed by hand.** A main-module `local-module.cue` carrying one entry per hop resolves every link locally (`case3`), and this works whether the transitive dependency is pinned in `deps` or present with no version at all (`case4`) — so a dependency that exists solely to be replaced does not need a published version to be replaceable.
3. **`cue mod tidy` maintains the multi-entry file.** The transitive `cat` entry is not treated as unreferenced and is not pruned. Tidy is safe to run against a hand-built chain.

**Implications:**

- The dev-loop workaround is real but manual and non-obvious: every developer wanting a local module *and* a local catalog must know to list both in the outermost `local-module.cue`, because the natural thing — putting the catalog replacement next to the module that depends on it — silently does nothing. That asymmetry is worth an explicit note wherever the local-dev workflow is documented.
- The failure is silent, which puts it in the same family as the drift this enhancement exists to remove: a resolution that is *plausible* but not what either replacement asked for. If a catalog version is involved, the downstream symptom is the familiar `no matching transformer`, naming neither the replacement nor the catalog.
- Because `cue mod tidy` preserves the entries, tooling that generates a chain-complete `local-module.cue` (rather than asking the developer to hand-maintain it) is viable.

**Not answered here — OQ8 bullet 3.** Whether catalog *materialization* honours `replaceWith` at all is a kernel question, not a CUE-resolution question, and needs its own experiment against a full render fixture (Platform with a `#registry` subscription + catalog + module). Reading the code gives a strong prior that it does not: `library/opm/materialize/enumerate.go` builds its own `modconfig.NewResolver` and calls `client.ModuleVersions(ctx, path)` to enumerate *published versions* of a subscription path, entirely separately from main-module load. A local directory has no version list to enumerate, so a `replaceWith` has no way to participate — which would mean a local catalog checkout supplies the primitives a module imports while the registry supplies the transformers that render them, even at one hop. That is a prior, not a result; it is not established by this experiment.
