# 08-render-module-qualified-keys: Module-Dictated Catalog Versions and the Generated Platform

Status: Concluded

## Hypothesis

With module-qualified contract keys (experiment 03's core patch) and no library change, a real render against a platform carrying two majors of one catalog routes each module to its own major's transformers, lets one provider build serve both majors, and lets one module split majors across components; the same probe shows the hazard left open: a component mixing majors inside itself loses an optional attachment without refusing.

## Setup

This experiment needs a library and a core checkout, so it is packaged as a pinned recipe rather than copied bytes. `run.sh` clones, into a fresh work directory:

- library at `30f08c1208c6dca893f08f2c9255165328ee2668` (main, one commit after release 1.0.0-alpha.35), unchanged apart from `overlay/` copied over it;
- core at `cbe93e0aa003b8cd5bbc34420f021ec62694c079` (release 2.0.0-alpha.12 plus two comment-only commits), with `core.patch` applied. `core.patch` is a copy of experiment 03's patch: the widened contract key type, `ContractScope` and `keyPrefix` in the identity package, and the ownership assertion on `#Catalog`.

`overlay/` holds:

- `opm/kernel/exp08_render_test.go`: `TestExp08`. For the stock-core case it resolves core v2.0.0-alpha.12 from GHCR; for the patched-core cases it serves the patched `core/src` in-process (pin files, `zz_` files and Markdown left out) as `opmodel.dev/core` v2.0.0-alpha.12 under an isolated CUE cache. It logs inventory, gate, refusal or pairs, unify refusals and objects, and never fails on a verdict.
- `testdata/lineage/`: catalog `lin` at 0.1.0 (major v0, legacy keys `.../lin/<kind>/...`) and 1.0.0 (major v1, qualified keys `.../lin@v1/<kind>/...`); provider `lprov` 0.1.0 depending on both lin majors with one backup transformer per major; platforms `lplat_both` (lin@v0, lin@v1, lprov@v0) and `lplat_v1only`; modules `app_lin0`, `app_lin1`, `app_lin_split` (component `web` on lin@v0, component `api` on lin@v1) and `app_lin_mixed` (one component with lin@v1's container and lin@v0's optional expose trait).

The fixtures and cases come from a scratch run on 2026-09-30 against the same commits.

## Run

Needs git, Go (measured with go1.26.5) and network access to GitHub, the Go module proxy and GHCR:

```bash
./run.sh
LIBRARY_SRC=/path/to/library CORE_SRC=/path/to/core ./run.sh   # or from local clones
```

The log lands in `$WORK/render.log`, grouped by `=== RUN TestExp08/<core>/<platform>/<instance>`.

## Outcome

Measured 2026-09-30, go1.26.5, library `30f08c1`, core `cbe93e0` plus the patch. Keys below drop the `testing.opmodel.dev/library-render/` prefix.

- **Stock core refuses the key shape.** `stockcore/lplat_both`: `ACQUIRE PLATFORM ERROR: ... #registry."lin@v1".#catalog.#ContainerResource.metadata.fqn: invalid value "lin@v1/resources/container@v1" (out of bound ...)`. The core type change is required.
- **Both majors, one provider build: disjoint.** On `lplat_both` the inventory maps `lin/...` keys to lin@v0 and `lin@v1/...` keys to lin@v1, `providedBy` lists lprov@v0 once per declaring major, and `overSubscribed` and `comparable` are empty. `inst_app_lin0` renders only `built-by: lin-0.1.0` objects plus the Schedule `built-by: lprov-for-lin-v0`; `inst_app_lin1` only `lin-1.0.0` objects plus `lprov-for-lin-v1`. Gate `true` and zero unify refusals both times.
- **A lin@v0 module on a lin@v1-only platform: refused cleanly.** `unresolved resource demand "lin/resources/container@v1": no enabled catalog defines this contract`, with no alternatives and no disqualified candidates.
- **One module split across majors by component: routes per component.** `inst_app_lin_split` pairs `web` with the 0.1.0 transformers and `api` with the 1.0.0 ones and renders four objects with the matching `built-by`; gate `true`.
- **One component mixing majors: silent drop.** `inst_app_lin_mixed` (lin@v1 container, lin@v0 optional expose) matches only `lin/transformers/deployment-transformer@1.0.0` and renders one Deployment with no Service, gate `true`, no refusal.

**Hypothesis held.** Module-qualified keys route two majors through the shipped library with no library change, one provider build serves both majors, and a module can split majors across components. A component mixing majors inside itself drops an optional attachment silently, so the design would need a rule refusing it (experiment 03 prototypes one). Linked from D9's alternatives, OQ9 and OQ10.
