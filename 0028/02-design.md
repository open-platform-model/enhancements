# Design: The Operator Ships as an OPM Module

The operator becomes an ordinary OPM module, published by its own release, and `opm operator install` becomes an ordinary CLI apply of that module with one bootstrap step in front. All trade-off reasoning lives in `03-decisions.md`.

## Design Goals

- **One artifact per release.** An operator release produces the image and one module of the same version; the install manifest is a render of that module and cannot differ from it (D1, D2).
- **Install is a module apply.** `opm operator install` leaves the operator recorded as one CLI-owned ModuleInstance whose inventory lists every object the release installed (D3).
- **Tuning survives upgrades.** Every setting a platform team changes on the operator is a value of its instance, and re-running install keeps it (D5).
- **The CLI pins one number.** The CLI's operator pin is a module version; selecting another version needs only a registry, which a mirror can serve (D3).
- **Install stays the recovery path.** Nothing about installing, upgrading or repairing the operator depends on the operator running (D4).
- **Existing clusters migrate in place.** The first module install over a manifest-installed operator recreates nothing (D8).

## Non-Goals

- **An operator that manages itself.** The operator never reconciles the instance that deploys it (D4).
- **The ownership transfer of other instances.** Entry 0029 designs it; this entry only fixes that the operator's own instance is never transferred.
- **A Platform or a workload applier inside the module.** Platform seeding and the CLI user role stay install steps (D6); whether the module offers an applier identity is OQ8.
- **An offline install with no registry at all.** The owner chose a registry pull; a mirror is the air-gapped answer.
- **Changing the operator's CRDs or its controller.** The module packages what the release already builds.
- **Registry credentials for the operator.** The operator pulls from registries it can reach without credentials; plumbing credentials is a separate question.

## High-Level Approach

The operator release gains one step: after the image is built, it publishes the operator module at the release's version, with the image's version tag as its default, and renders the module at its defaults into the install manifest it already publishes. The module's CRDs and controller RBAC come from what the controller's code declares, and a mismatch refuses the release.

The module renders the CRDs and the Namespace through the first-party catalog, and writes the controller's Deployment, Service, ServiceAccount and RBAC in the shape of the earlier manifest, so the names, the Deployment's selector and the pod's security posture stay what running clusters already have (D2).

The CLI drops its embedded manifest. Install resolves the operator module from the registry and renders it, runs every check that could refuse the instance, applies the CRD subset and waits for it to be served, then applies the module as a CLI-owned instance, and reports success once the cluster Platform is Ready from the new release. The CLI-owned marker means the operator never touches the instance that runs it. CLI commands that need the operator find it through that instance. Upgrade is install with another version, uninstall deletes the instance, and both keep the guarantees 0006:D34 gave the manifest: CRDs and the Namespace are never deleted, and no delete of the operator's instance goes ahead while instances still carry the operator's cleanup finalizer (D3, D9).

The [README](README.md#how-it-works) draws this flow.

The release is the only producer. The CLI and kubectl are two consumers of the same module, one through the registry and one through its rendered manifest.

**Evidence.** Both experiments concluded on 2026-10-04.

- [`experiments/01-operator-module-render/`](experiments/01-operator-module-render/) rendered the whole 19-object install with no cluster and the CRDs equal to the controller's own. The catalog's workload and role resources changed three binding names and the Deployment's selector and dropped the seccomp profile; writing those objects in the manifest's shape reached spec parity. D2 now requires the names, the selector and the security posture (D2:R5, R7, R8), and OQ1 is resolved. The CRD and RBAC drift check worked as a regenerate-and-diff.
- [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/) installed, reinstalled with no change, upgraded and deleted a CLI-owned operator instance on a fresh cluster, and the operator left its own instance alone (OQ2 resolved by D3). It also found what D3 and D9 now require: a refused install had already changed the CRDs (D3:R12), the wait returned before the operator reconciled (D3:R10), the CLI's readiness check reads the embedded manifest (D3:R13), and `opm instance delete` of the operator's instance skipped the finalizer guard (D9:R5). Its migration probe and its self-transfer probe back D8 and D4.

## Schema / API Surface

The entry changes no core definition and adds no contract CUE. The new consumer-facing surface is the operator module's `#config` (D5), which falls under the module class of 0021, so its schema is the operator's compatibility surface (D2:R6). Its headline fields:

| Value | What it tunes |
| --- | --- |
| Image | repository, tag (default: the release's own) and an optional digest |
| Registry mapping | where the operator resolves modules from |
| Default service account | the identity the operator applies instances as |
| Resources | the controller container's requests and limits |
| Replicas | the controller's replica count; leader election stays on |
| Extra arguments | anything the schema does not type |

Field names and shapes are the operator repository's to choose in the implementing change; once published they are part of the contract.

## Affected Surfaces

```text
core, catalog_opm --pins--> operator module <--publishes-- opm-operator release
                                  |                                |
                          resolve + render                  install manifest
                                  |                                |
                      opm operator install (cli)              kubectl apply
```

- **opm-operator.** Each release publishes the module `opmodel.dev/modules/opm_operator` at the release version (D1). The install manifest the release publishes becomes the module's render at defaults (D2:R4), with the earlier manifest's names, selector and pod security (D2:R5, R7, R8). The release refuses a module whose CRDs or controller RBAC differ from the controller's declarations (D2:R3). The operator's `#config` is now a versioned surface: narrowing it is a breaking release (D2:R6). The operator repository becomes a downstream of core and the catalog (D7).
- **cli.** `opm operator install` installs the module as a CLI-owned instance in two steps (D3), refusing before it changes anything (D3:R12) and waiting for the new operator to reconcile (D3:R10). Selecting another version takes a module version, resolved through the CLI's registry mapping, instead of a release tag fetched from GitHub. The CRDs-only form renders the same module and applies only its CRDs (D3:R7). Re-running install keeps recorded values (D5:R2). The readiness check behind the CLI's delete guard finds the operator through its instance (D3:R13). Uninstall deletes the operator's instance and refuses as 0006:D34 did, and the generic instance delete keeps that refusal for the operator's instance (D9). The first install over a manifest-installed operator adopts its objects (D8). Install needs a module registry, where the embedded manifest did not.
- **opm.** The install and quickstart pages describe install as a module apply, the registry or mirror it needs, and how tuning is set as values instead of Deployment patches.
- **Workspace release rules.** The operator's tier and pin classes name core and the catalog as upstreams of the operator module (D7).

## Before / After

The scenario from 01-problem.md's Concrete Example: a team whose modules live in an internal registry upgrades the CLI and re-runs install.

```text
Before                                         After
------                                         -----
opm operator install                           opm operator install, with values:
  applies the embedded manifest                  registry: opmodel.dev=registry.internal/opm
kubectl patch deployment                         defaultServiceAccount: opm-applier
  --registry, --default-service-account        (recorded on the operator's instance)
upgrade CLI, opm operator install              upgrade CLI, opm operator install
  manifest force-applied, flags gone             module of the new version rendered with
  operator pulls from the public registry,       the recorded values, flags kept
  applies as itself                            instances keep reconciling
  instances fail
```

What changes is where the tuning lives. Before, it lived on a live object no record describes, so the next install could not know about it. After, it lives on the instance record install renders from.
