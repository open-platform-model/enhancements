# 01-provider-trait-across-catalogs — Catalog Contracts and Transformer Registration

Status: Concluded

## Hypothesis

A trait declared with `fulfilment: "provider"` in one catalog and required by a transformer in a second catalog renders, through the shipped kernel and CLI with no change to core, library or the match glue, an engine policy object scoped to the demanding component by the labels the base catalog already stamps; a platform with no provider refuses the render naming the demand, a platform with two providers refuses it naming both catalogs, and the same trait is satisfiable by a second engine (Velero) whose retention vocabulary differs from the trait's.

The concrete trait is the `backup` contract designed for catalog_opm on 2026-09-11 (`traits/backup@v1alpha1`: `schedule` as five-field cron, `retention` as keep counts with at least one tier, `optional: bool | *false`, `appliesTo` the volumes resource), rendered by a k8up adapter under credential shape 1 (no `spec.backend`; the operator's `BACKUP_GLOBAL*` env supplies repository and credentials) and by a Velero adapter under the keep-more rule (one `ttl`, the longest span any tier asks for).

### Why this is one experiment and not three

The refusal cases and the Velero arm are the boundary of the same claim. A provider-fulfilled contract is only useful if its zero-provider and two-provider topologies fail loudly (0010 D37, kept by 0015 D2), and the contract is only a contract if a second engine can implement it without changing it. Splitting them would test the trait's shape three times against three fixtures.

## Setup

Everything unpublished. The four experiment modules are served through `cue.mod/local-module.cue` directory replacements that `run.sh` generates in a scratch copy; the CLI honours them unconditionally since cli PR #209. Base primitives come from the published `opmodel.dev/catalogs/opm@v4` v4.0.1 on GHCR, so the experiment tests the real 0015 dependency structure: the provider catalog imports the declaring catalog for the trait value and catalog_opm for the volumes value.

| Path | Role | Copied from |
| --- | --- | --- |
| `contracts/` | Declaring catalog `testing.opmodel.dev/experiments/0015/contracts@v0`: the backup trait, `#transformers: {}`. The stand-in for catalog_opm as declaring catalog | `catalog_opm/opm/{catalog.cue,identity/identity.cue}`, trait shape from `catalog_opm/opm/traits/v1beta1/disruption_budget.cue` |
| `k8up/` | Provider catalog: `backup-schedule-transformer` renders a `k8up.io/v1 Schedule` with no `spec.backend`, `labelSelectors` on the component labels; hand-written minimal Schedule schema (closed, so a backend is a type error) | transformer shape from `catalog_opm/opm/transformers/pdb_transformer.cue`; fields from docs.k8up.io and `api/v1/backup_types.go` |
| `velero/` | Second provider: `velero.io/v1 Schedule` in namespace `velero`, `includedNamespaces` and `labelSelector` from context, `ttl` by the keep-more rule | same |
| `webapp/` | Consumer module: one `bp.#StatelessWorkload` + `res.#Volumes` component with a persistent claim and the backup trait; `#config.backupAdvisory` narrows the trait's posture at the attachment site | `cli/tests/fixtures/modules/podinfo/` |
| `webapp/values/advisory.cue` | Case D values: `backupAdvisory: true` | authored |
| `platforms/{one-provider,no-provider,two-providers,velero-only}/` | One platform module per topology; `#registry` keys are the catalogs' `metadata.modulePath` | `cli/hack/platform/` |
| `run.sh`, `check.py` | Staging, `cue mod edit --replace`, `opm module build`, PASS/FAIL rows; per-case JSON assertions | `archive/0019/experiments/{02-platform-authority-mvs,05-match-in-one-build}/run.sh` |

Modifications to the copies: the consumer uses the stateless blueprint rather than a raw `res.#Container` (a raw container does not answer the workload-type matching key; the blueprint does) and sets the volume's `readOnly`, which the catalog schema requires without a default.

## Run

Prerequisites: `opm` built from `cli` main at or after PR #209 (`cd cli && task build`, used at `cli/bin/opm`; override with `OPM=`), `cue` v0.17.x, `python3`. Reads resolve from GHCR under the standard `CUE_REGISTRY`; no local registry.

```bash
bash run.sh
```

Five cases, 21 rows. Scratch trees land under `_out/<case>/` (gitignored) with `out.json`, `stderr.txt` and `rc` per case.

| Case | Platform | Values | Expected |
| --- | --- | --- | --- |
| A | one-provider | debug | exit 0; one `k8up.io/v1 Schedule`, no `spec.backend`, selector equals the Deployment selector and is a subset of the PVC labels, retention passes through |
| B | two-providers | debug | exit 2; over-subscription refusal naming the contract and both catalogs |
| C | no-provider | debug | exit 2; unresolved trait demand, "nothing on this platform implements this contract" |
| D | no-provider | advisory | exit 0; unhandled-trait warning; Deployment and PVC render, no Schedule |
| E | velero-only | debug | exit 0; one `velero.io/v1 Schedule` in namespace `velero`, `ttl: "672h"` |

## Outcome

`run.sh` last run 2026-09-11: **21 passed, 0 failed**. `cue v0.17.1`, `opm v1.0.0-alpha.19-11-g7ae324f` (cli `7ae324f`), core `v2.0.0-alpha.7`, catalog_opm `v4.0.1`.

**Every replaced path was served from a directory.** stderr carried `local replacement in effect: <path> served from <dir> (platform)` for the contracts and provider catalogs in every case, and the consumer's own redirect of the contracts path was reported inert ("the platform names that path"), as the precedence rule says. A provider catalog's dependency on the declaring catalog resolved through the render module's replacement with no registry hit: replacements reach a dependency's dependency.

**Case A, the k8up Schedule** (labels elided):

```yaml
apiVersion: k8up.io/v1
kind: Schedule
metadata: {name: web-demo-web, namespace: demo}
spec:
  backup:
    schedule: "0 2 * * *"
    labelSelectors:
      - matchLabels:
          app.kubernetes.io/name: web
          component.opmodel.dev/name: web
          core.opmodel.dev/workload-type: stateless
          module-instance.opmodel.dev/name: web-demo
    tags: [web-demo, web]
  prune: {schedule: "@daily-random", retention: {keepDaily: 7, keepWeekly: 4}}
  check: {schedule: "@weekly-random"}
```

The selector is exactly the Deployment's `spec.selector.matchLabels` and a subset of the rendered PVC's labels (`web-demo-web-data`), so k8up's `labelSelectors` scopes the Schedule to this component's PVCs with nothing added to the base catalog. `spec.backend` is absent and the schema refuses one, which is credential shape 1 made structural.

**Case B** refused with exit 2:

```
contract "testing.opmodel.dev/experiments/0015/contracts/traits/backup@v1alpha1" declares fulfilment "provider" but is supplied by transformers from 2 catalogs ("testing.opmodel.dev/experiments/0015/k8up@v0", "testing.opmodel.dev/experiments/0015/velero@v0"): a platform must carry exactly one provider for it
```

**Case C** refused with exit 2:

```
component "web": unresolved trait demand "testing.opmodel.dev/experiments/0015/contracts/traits/backup@v1alpha1"
  nothing on this platform implements this contract
```

This is 0015 D1's premise measured on the shipped kernel: the declaring catalog is subscribed and publishes the trait, yet with an empty `#transformers` the contract reaches no bucket and the diagnostic cannot distinguish "defined but unimplemented" from an unknown key. The contract maps D1 adds are what would let this line say which catalog defines the contract.

**Case D** rendered the Deployment and PVC with exit 0 and the warning `component "web": trait "...backup@v1alpha1" is not handled by any matched transformer (values will be ignored)`: the module's narrowing of `optional` at the attachment site works against a catalog-stated `bool | *false`.

**Case E, the Velero Schedule** (labels elided):

```yaml
apiVersion: velero.io/v1
kind: Schedule
metadata: {name: demo-web-demo-web, namespace: velero}
spec:
  schedule: "0 2 * * *"
  template:
    includedNamespaces: [demo]
    labelSelector: {matchLabels: <same four labels as case A>}
    ttl: 672h
```

`ttl` is 4 weeks × 168h, the longest tier, not 7 days: the keep-more rule keeps at least as long as any tier asks.

### Findings beyond the claims

- **A transformer definition is evaluated once at platform build with no component.** The Velero `ttl` computation first failed the platform build with `list.Max: empty list` because every retention tier is absent when `#component` is unconstrained. Any adapter field computed from the component (rather than passed through) must be guarded so the definition evaluates on its own. An adapter-authoring rule for the k8up and Velero provider catalogs, and for the catalog_opm registration transformer 0015 D9 adds.
- **The k8up selector should be the two identity labels only.** `#context.componentLabels` carries `core.opmodel.dev/workload-type`, and k8up's `labelSelectors` also gates PreBackupPods, which carry no workload-type label. The real adapter should select on `app.kubernetes.io/name` and `module-instance.opmodel.dev/name` (or the `component.opmodel.dev/name` pair), not the full selector.
- **Velero's cluster-scoped Schedule collides with tenancy.** The adapter renders into the `velero` namespace, which a tenant module applied under impersonation cannot write. The name carries the instance namespace to stay unique. Velero is the generality check for the contract, not the first adapter to ship.

### What this discharges in the design

The `backup` trait as designed (Trait, `fulfilment: "provider"`, `optional: bool | *false`, counts-based retention, no hooks, no per-volume selection) is renderable by two engines with different retention vocabularies through the shipped pipeline, and credential shape 1 needs nothing from the trait or the platform. The catalog_opm `backup` trait change and a k8up provider catalog can be cut against this shape. 0010 D37's refusals already name both catalogs; what 0015 D1 still owes is the "defined but unimplemented" arm of case C.

**Hypothesis held.**
