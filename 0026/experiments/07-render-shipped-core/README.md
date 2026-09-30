# 07-render-shipped-core: Module-Dictated Catalog Versions and the Generated Platform

Status: Concluded

## Hypothesis

Through the shipped library and core, with no patch, a platform cannot carry two majors of one catalog that share contract keys: the platform fails to evaluate, and every shape that sidesteps that failure routes by major only because the stamped `catalogVersion` conflicts at unification, counts a provider built on the other major as a second provider, or renders a bridge transformer's object twice without refusing. Only disjoint keys route cleanly.

## Setup

This experiment needs a library checkout, so it is packaged as a pinned recipe rather than copied bytes: `run.sh` clones library at commit `30f08c1208c6dca893f08f2c9255165328ee2668` (main, one commit after release 1.0.0-alpha.35) into a fresh work directory and copies `overlay/` over it. No library file is changed. Core is `opmodel.dev/core` v2.0.0-alpha.12, the release every fixture pins, resolved from GHCR; the render fixtures are served in-process by the test.

`overlay/` holds:

- `opm/kernel/exp07_render_test.go`: one test, `TestExp07`, that acquires each platform, logs its contract inventory, renders one instance with `SkipUnprovided` on, and logs the gate, the refusal or the matched pairs, the unify refusals and every rendered object. It never fails on a verdict.
- `testdata/render/`: the fixtures, all pinning core v2.0.0-alpha.12.
  - Shared keys: catalog `maj` at 0.1.0 (major v0), 1.0.0 and 1.1.0 (major v1), where 1.0.0 lists the same contract keys as 0.1.0 and 1.1.0 lists only a `container@v2`; provider `bprov` at 0.1.0 built on maj@v0 and 1.0.0 built on maj@v1; modules `app_maj0`, `app_maj1`, `app_bk0` (a maj@v0 component with the provider-fulfilled backup trait).
  - A shared-key bridge, added for this experiment: `maj` 1.3.0 lists only `container@v2` and ships a bridge transformer requiring maj@v0's container; platform `mplat_maj_bridge_nodef`.
  - The major as a key path segment on the shipped core: catalog `majk`, whose keys read `.../majk/v0/...` and `.../majk/v1/...`, which the shipped key type accepts; modules `app_majk0`, `app_majk1`; `majk` 1.1.0 ships a bridge requiring majk@v0's container.

The fixtures and all cases but the shared-key bridge come from a scratch run on 2026-09-30 against the same library commit.

## Run

Needs git, Go (measured with go1.26.5) and network access to GitHub, the Go module proxy and GHCR:

```bash
./run.sh                                  # clones library from GitHub
LIBRARY_SRC=/path/to/library ./run.sh     # or from a local clone
```

The log lands in `$WORK/render.log`, one line per fact, grouped by `=== RUN TestExp07/<platform>/<instance>`.

## Outcome

Measured 2026-09-30, go1.26.5, library `30f08c1`, core v2.0.0-alpha.12. Keys below drop the `testing.opmodel.dev/library-render/` prefix.

- **Baseline, `mplat_maj_v0` + `inst_maj0`:** gate `true`, the 0.1.0 Deployment and Service.
- **Both majors list the same keys, `mplat_maj_both`: the platform fails to evaluate.** `ACQUIRE PLATFORM ERROR: building platform package ...: #contracts.defined."maj/resources/container@v1".metadata.catalogVersion: conflicting values "1.0.0" and "0.1.0"`. No inventory and no render are reachable.
- **Only maj@v0 lists the keys, `mplat_maj_both_nodef`: routes by major, through unification only.** `inst_maj0` renders only the 0.1.0 objects and `inst_maj1` only the 1.1.0 ones, gate `true` both times, but every other-major transformer is a unify refusal (for `inst_maj0`: `deployment-transformer@1.1.0` conflicting at `maj/resources/container@v1`, `service-transformer@1.1.0` at the container and `expose@v1`). The inventory reports the twins as `comparable` with `discriminated: false`, a false positive on a healthy platform.
- **A maj@v0 module on a maj@v1-only platform, `mplat_maj_v1` + `inst_maj0`: refused**, as `unresolved resource demand "maj/resources/container@v1": defined by "maj@v1", implemented at a different apiVersion`, with two candidates disqualified. The row names maj@v1 as definer, the wrong major for this component.
- **One provider per declaring major, `mplat_bprov_both` + `inst_bk0`: refused as over-subscribed.** The match picks the right provider (`bprov/transformers/backup-transformer@0.1.0`) and unify-disqualifies `backup-transformer@1.0.0` at `maj/traits/backup@v1`, yet the render is refused: `contract "maj/traits/backup@v1" declares fulfilment "provider" but is supplied by transformers from 2 catalogs ("bprov@v0", "bprov@v1")`. The inventory reads `overSubscribed: [maj/traits/backup@v1]`, `routable: false`.
- **Only the other major's provider, `mplat_bprov_v1only` + `inst_bk0`: inventory and render disagree.** The inventory reads `fulfilled: true` with `providedBy` naming bprov@v1, the render marks the demand `Unprovided: false`, so the skip switch does not skip it, and refuses `unresolved trait demand "maj/traits/backup@v1": ... 1 candidate(s) disqualified`.
- **Shared-key bridge, `mplat_maj_bridge_nodef` + `inst_maj0`: renders twice, gate `true`.** The pairs are `deployment-transformer@0.1.0`, `service-transformer@0.1.0` and `deployment-bridge-transformer@1.3.0`, and the objects include two `Deployment`s named `probe-maj0-web`, `built-by` `0.1.0` and `bridge-1.3.0`. Only the inventory's `comparable` rows report it.
- **Keys with a major segment, shipped core, `mplat_majk_both`: disjoint.** `inst_majk0` renders only 0.1.0 objects and `inst_majk1` only 1.0.0 objects, gate `true`, zero unify refusals, `comparable` empty. On `mplat_majk_v1`, `inst_majk0` is refused cleanly: `unresolved resource demand "majk/v0/resources/container@v1": no enabled catalog defines this contract`, with no alternatives offered.
- **Segment-key bridge, `mplat_majk_bridge` + `inst_majk0`: renders twice, gate `true`.** Two `Deployment`s named `probe-majk0-web`, `built-by` `0.1.0` and `bridge-1.1.0`; the inventory reports `comparable` with `discriminated: false`, which the render gate does not read.

**Hypothesis held.** With shared keys the shipped stack cannot evaluate a platform where two majors define the same keys; the sidesteps route only on the `catalogVersion` conflict, count a provider built on the other major against the right one, and let the inventory and the render disagree; and a bridge double-renders with the gate passing, with shared keys and with a major in the key alike. Linked from `05-risks.md`, experiment 02, OQ15 and D9's alternatives.
