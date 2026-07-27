# 05-decided-shapes-module-catalog — OPM Module Publishing Workflow

Status: Running

> **Superseded in part by D27 (2026-07-26).** This experiment implements identity as *gitignored, generated* files, which is what D25 recorded at the time. D27 changed that to *committed, visible, tool-written* files after experiment 06 measured the alternatives. The structural placement demonstrated here still holds — modules take a file in their own root package, catalogs keep `identity/` for their leaves — but `.gitignore` and the "do not commit" banners in the generated output no longer reflect the design.

Pins: D13–D20 as a whole — a readable reference implementation of the decided shapes, built so the decisions can be reviewed as code rather than as a decision log. Also carries the open A/B question on `#Catalog.metadata.version`, plus OQ17 and OQ18, as marked choice points.

## Hypothesis

Decisions D13–D20 compose into a working `#Module` and `#Catalog` in which **identity and match keys are stable while the compatibility signal moves**: a module's `fqn`, its `uuid`, and every primitive FQN it demands are byte-identical across a catalog MINOR bump *and* between a local checkout and a published artifact, whereas the full catalog version the module was built against varies and is what the D19 floor check compares.

One claim, two halves that must hold together. If identity moved, the design would break the operator's prune guard and render parity. If the compatibility signal did not move, the too-old-platform check would have nothing to compare.

## Setup

Self-contained; nothing outside this directory is read or modified.

**One CUE module, not three.** The three artifacts are package trees under a single `cue.mod`, so the experiment runs with no registry and no `local-module.cue` wiring. That is deliberate: cross-module resolution is already measured by experiments 01 and 04, and this experiment is about the *shapes*. Each artifact's identity comes from its own generated `identity` package — the mechanism under test — so the enclosing CUE module path is irrelevant to what is demonstrated.

- **`core/core.cue`** — trimmed copy of `core/src/{types,module,catalog,resource,transformer}.cue` taken 2026-07-26, modified to the decided shapes. Every divergence from today's core carries a `CHANGED` or `REMOVED` comment naming the decision and the current source line, so it can be diffed by eye without opening `core/`. Copy, never reference (skill rule 3).
- **`cat/`** — the catalog as an author writes it: `catalog.cue`, `resources/configmaps.cue`, `transformers/configmap_transformer.cue`. No `modulePath` and no `version` are hand-written anywhere.
- **`mod/`** — the module as an author writes it. Declares a `name`, and nothing else about identity.
- **`platform/compat.cue`** — the D19 floor check as plain CUE. Compares MAJOR.MINOR.PATCH numerically and **ignores prerelease ordering**; the production comparison is Go, where `library/opm/materialize/filter.go` already uses a semver library.
- **`check.cue`** — assembles the scenario and exposes the values `run.sh` prints.
- **`cat/identity/`, `mod/identity/`** — **generated and gitignored.** `run.sh` writes them, playing the role publish (or a local build) would.

### Choice points deliberately left visible

- **`#Catalog.metadata.version` implements Reading B** — absent from the catalog root, with primitives reading `id.Version` directly for their own `metadata.version`. `core/core.cue` marks the exact spot and shows the one-line Reading A alternative beside it. This is the open question.
- **`mod/identity/` is generated rather than derived**, implementing the publish-generates-identity proposal. OQ18's alternative — `modulePath` authored in module source per D16 — is not implemented here. (`@embed` was a third option and was ruled out by user decision 2026-07-26.)
- **OQ17** is visible as the last row of the floor table.

## Run

```bash
bash run.sh          # generates identity per mode, evaluates, prints a verdict
cue vet ./...        # validates the shapes against whatever identity is generated
```

No registry required.

## Outcome

Observed 2026-07-26 with cue v0.17.1.

| Mode | `moduleUUID` | demanded FQN | `builtAgainstCatalog` |
| --- | --- | --- | --- |
| publish, catalog 1.2.0 | `acd2ccb3-…46326` | `…/cat/resources/config-maps@v1` | `1.2.0` |
| publish, catalog 1.3.0 | `acd2ccb3-…46326` | `…/cat/resources/config-maps@v1` | `1.3.0` |
| local dev, catalog `1.0.0-dev` | `acd2ccb3-…46326` | `…/cat/resources/config-maps@v1` | `1.0.0-dev` |

Identity and match key are byte-identical across all three; only the compatibility signal moves. The floor check behaves as designed:

| built against | platform on | satisfied |
| --- | --- | --- |
| 1.0.0 | 1.2.0 | `true` — the supported cross-minor pattern |
| 1.2.0 | 1.2.0 | `true` |
| 1.2.0 | 1.0.0 | **`false`** — platform catalog too old |
| 1.0.0-dev | 1.2.0 | `true` — but see OQ17 |

**Hypothesis held so far.** Status remains `Running` rather than `Concluded` because the A/B question on `#Catalog.metadata.version` is unresolved and its answer changes `core/core.cue`.

### Findings

1. **`#ModulePathType` must accept underscores, which the enhancement had not noticed.** `core/src/types.cue:20` is `=~"^[a-z0-9.-]+(/[a-z0-9.-]+)*$"` — no underscore. Harmless while `modulePath` was a bare prefix (`opmodel.dev/modules`), but under D16 the path *ends in `nameSnakeCase`*, and every multi-word snake name contains one: `media_server`, `cert_manager`, `zot_registry_ttl`. The fixture would not vet until the character class was widened, and `#FQNType` needs the same widening on its path portion. A concrete addition to the D16 blast radius.

2. **D1's leaf constraint fires, and earns its place.** Writing the module as `name: "media-server"` against a path ending `/mod@v2` failed with `_leafOK: conflicting values false and true` before anything else evaluated. Under D16 the rule is expressible as `strings.HasSuffix(registryPath, "/" + nameSnakeCase)` over a single field; today it is a relationship between two independently-authored fields with nowhere to live.

3. **CUE has no string slicing.** Splitting `path@vN` into registry path and major is `strings.SplitN(in, "@", 2)`, not `LastIndex` plus a slice. A module path carries at most one `@`, always terminal, so `SplitN(2)` is exact.

4. **`uuid` as a field name shadows the `uuid` import.** `core/src/module.cue:4` already aliases it `cue_uuid "uuid"`; rebuilding the shape from scratch hit the same wall, confirming the alias is load-bearing rather than stylistic.

5. **The compatibility signal is only meaningful once frozen.** In this single-tree setup, regenerating the catalog's identity also changes what the module reports as `builtAgainstCatalog`, because the module is re-evaluated against the live catalog. In production that value is frozen into the module's published artifact. This is a limitation of the setup, not of the design — but it names something the design must guarantee: **the module's record of what it was built against has to be captured at publish, not recomputed at render.** Nothing in D13–D20 currently says so.
