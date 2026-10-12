# 09-render-major-as-matching-scope: Module-Dictated Catalog Versions and the Generated Platform

Status: Concluded

## Hypothesis

With the catalog major as a matching scope (experiment 05's core patch) and the render glue and inventory types changed to match, a real render against a platform carrying two majors of one catalog that share contract keys routes each component to its own major, counts providers per major and agrees with the inventory, with no catalog or module republished; and a double match is caught in the render glue but not by the kernel's decision.

## Setup

This experiment needs a library and a core checkout, so it is packaged as a pinned recipe rather than copied bytes. `run.sh` clones, into a fresh work directory:

- library at `30f08c1208c6dca893f08f2c9255165328ee2668` (main, one commit after release 1.0.0-alpha.35), applies `library.patch`, and moves aside `opm/kernel/render_inventory_parity_test.go`, which no longer compiles against the changed inventory types. `library.patch` changes three files: the render glue template (buckets keyed by contract key then scope, where a demand's scope is its own value's `metadata.catalog`; `definedBy` and `providedBy` read per scope; unresolved rows carry `scope` and `otherScopes`; a `doubleMatched` row and gate term for two comparable transformers matched on one component), the Go inventory types (scope maps and `{contract, scope}` rows) and the over-subscription error (a `Scope` field).
- core at `cbe93e0aa003b8cd5bbc34420f021ec62694c079`, served in-process from the fixture registry in two versions: v2.0.0-alpha.12 is core as shipped, v2.0.0-alpha.13 is core with `core.patch` applied and its pin files left out (the reshaped inventory breaks them). `core.patch` is a copy of experiment 05's patch.

`overlay/` holds:

- `opm/kernel/exp09_render_test.go`: `TestExp09`, which routes `opmodel.dev/core` and the fixture prefix to the in-process registry under an isolated CUE cache (no registry is contacted for core), and logs inventory, gate, the glue's unresolved, skipped and `doubleMatched` rows, refusal or pairs, unify refusals, the resolved core version and every object. It never fails on a verdict.
- `testdata/render/`: catalog `maj` at 0.1.0, 1.0.0 (same keys as 0.1.0) and 1.2.0 (same keys plus a bridge transformer requiring maj@v0's container); providers `bprov` 0.1.0 (on maj@v0) and 1.0.0 (on maj@v1); modules `app_maj0`, `app_maj1`, `app_bk0` and `app_mix` (component `old` on maj@v0, component `new` on maj@v1). Catalogs, modules and instances pin core v2.0.0-alpha.12; the `sp_*` platforms pin v2.0.0-alpha.13, and `mplat_maj_both` (the control) pins v2.0.0-alpha.12.

The fixtures and cases come from a scratch run on 2026-09-30 against the same commits; the one change is the test's CUE cache, now removed cleanly at test end.

## Run

Needs git, Go (measured with go1.26.5) and network access to GitHub and the Go module proxy:

```bash
./run.sh
LIBRARY_SRC=/path/to/library CORE_SRC=/path/to/core ./run.sh   # or from local clones
```

The log lands in `$WORK/render.log`, grouped by `=== RUN TestExp09/<platform>/<instance>`.

## Outcome

Measured 2026-09-30, go1.26.5, library `30f08c1` plus the patch, core `cbe93e0` plus the patch. Keys below drop the `testing.opmodel.dev/library-render/` prefix.

- **Control, shipped core (`mplat_maj_both`): fails to evaluate**, `#contracts.defined."maj/resources/container@v1".metadata.catalogVersion: conflicting values "1.0.0" and "0.1.0"`, as in experiment 07.
- **No republish.** Every render on an `sp_*` platform reports core `ModuleVersion` v2.0.0-alpha.12 and `PlatformVersion` v2.0.0-alpha.13: artifacts pinned to the shipped core render under the patched one, each primitive carrying its derived scope.
- **Both majors, same keys (`sp_maj_both`): routes per major.** `inst_maj0` pairs only the 0.1.0 transformers and renders two objects `built-by: 0.1.0`; `inst_maj1` only the 1.0.0 ones (plus `deployment-v2-transformer@1.0.0` for `web2`); zero unify refusals, gate `true`.
- **One module split across majors (`inst_mix`): routes per component.** `old` pairs with the 0.1.0 transformers, `new` with the 1.0.0 ones, four objects.
- **A maj@v0 module on a maj@v1-only platform (`sp_maj_v1`): refused.** The glue row carries `scope: maj@v0`, `otherScopes: [maj@v1]`, `definedBy: ""`; the kernel's message drops both and reads `no enabled catalog defines this contract`.
- **One provider per declaring major (`sp_bprov_both`): routable.** `providedBy` is `{maj/traits/backup@v1: {maj@v0: [bprov@v0], maj@v1: [bprov@v1]}}`, `overSubscribed` empty; the render pairs `bprov/transformers/backup-transformer@0.1.0` and renders the Deployment and the Schedule. Experiment 07 shows the shipped stack refusing this platform as over-subscribed.
- **Only the other major's provider (`sp_bprov_v1only`): inventory and render agree.** The inventory reads `unfulfilled: [{contract: maj/traits/backup@v1, scope: maj@v0}]`; with `SkipUnprovided` the demand is skipped and the Deployment renders; without it the render refuses with `Unprovided: true`.
- **Bridge (`sp_bridge` + `inst_maj0`): caught by the glue, not by the kernel.** `doubleMatched` is `[{component: web, broader: maj/transformers/deployment-bridge-transformer@1.2.0, narrower: maj/transformers/deployment-transformer@0.1.0, scope: maj@v0}]` and the gate is an error, yet `Render` returns no refusal and two `Deployment`s named `probe-maj0-web`, `built-by` `0.1.0` and `bridge-1.2.0`. `inst_maj1` on the same platform is clean.

**Hypothesis held.** Scoping matching by the declaring major routes two majors with shared keys through a real render, counts providers per major, makes the inventory and the render agree, and needs no republished artifact. It changes the library's glue and public inventory types, and a double match must also be refused in the kernel's Go decision, which reads decoded rows rather than the in-build gate. Linked from D9's alternatives, OQ10 and OQ15.
