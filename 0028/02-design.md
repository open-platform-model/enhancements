# Design: The Operator Ships as an OPM Module

The operator becomes an ordinary OPM module, published from the operator's repository on a version train of its own, and `opm operator install` becomes an ordinary CLI apply of that module with one bootstrap step in front. All trade-off reasoning lives in `03-decisions.md`.

## Design Goals

- **One published source of the install shape.** The operator module is a release unit of its own in the operator's repository, and the install manifest is a render of that module and cannot differ from it (D1, D2).
- **OPM's controller is a catalog-rendered module.** The controller's workload, service account and RBAC come from the first-party catalog's abstractions, with the catalog changes they need landed first (D2, D12).
- **Install is a module apply.** `opm operator install` leaves the operator recorded as one CLI-owned ModuleInstance whose inventory lists every object the module installed (D3).
- **Tuning survives upgrades.** Every setting a platform team changes on the operator is a value of its instance, and re-running install keeps it (D5).
- **The CLI pins one number.** The CLI's operator pin is a module version anchored by its content digest, and the module names the operator image by digest; selecting another version needs only a registry, which a mirror can serve (D1, D3).
- **Install stays the recovery path.** Nothing about installing, upgrading or repairing the operator depends on the operator running or on the cluster Platform (D4, D11).
- **Existing clusters migrate in place.** The first module install over a manifest-installed operator keeps the CRDs, the custom resources, the Namespace and the managed workloads; only the controller's Deployment is recreated, once (D8).

## Non-Goals

- **An operator that manages itself.** The operator never reconciles the instance that deploys it (D4).
- **Ownership transfer between the CLI and the operator.** It is out of scope and designed elsewhere; this entry only requires that the operator's own instance is never transferred (D4).
- **A Platform or a workload applier inside the module.** Platform seeding and the CLI user role stay install steps (D6); whether the module offers an applier identity is OQ8.
- **An offline install with no registry at all.** The owner chose a registry pull; a mirror is the air-gapped answer.
- **Changing the operator's CRDs or its controller.** The module packages what the operator release already builds.
- **Registry credentials for the operator.** The operator pulls from registries it can reach without credentials; plumbing credentials is a separate question.
- **Every catalog rough edge.** Experiment 01 hit four catalog errors besides the two D12 fixes; they are catalog follow-ups (D12).

## High-Level Approach

The operator's repository gains a second release unit. An operator release builds and publishes the image as today. A module release, on its own version train starting at `v0`, publishes the operator module with the image named by tag and digest, and renders the module at its defaults into the install manifest kubectl users apply. An operator release is followed by a module release that moves the image reference; a core or catalog adoption, or a change to the module's `#config`, is a module release alone. The module's CRDs and controller RBAC come from what the controller's code declares, and a mismatch refuses the module release (D1, D2, D7).

The module renders the CRDs, the Namespace, the controller's workload, its service account and its roles and bindings through the first-party catalog. Two catalog changes come first: a seccomp profile, so the pods keep the Pod Security `restricted` posture, and roles with no subjects, for the five ClusterRoles the operator ships for administrators to bind (D12). Every name the CLI and the documentation read stays what running clusters have; the three bindings take the catalog's names and the Deployment's selector becomes the catalog's (D2).

The CLI drops its embedded manifest and pins a module version with its content digest. Install resolves the operator module from the registry, checks it against that digest when it is the default, renders it against the module's own pins, never the cluster Platform (D11), and runs every check that could refuse the install: recorded values, the apply guard, the migration's adoption, and the version rules of D10 (no operator newer than the CLI, no unasked downgrade, no CRD that stops serving a version the cluster serves). Only then does it apply the CRD subset, wait for it to be served, apply the module as a CLI-owned instance, and report success once the cluster Platform is Ready from the new release. The CLI-owned marker means the operator never touches the instance that runs it. CLI commands that need the operator find it through that instance, or, on a cluster with no record, by the fixed names every install path keeps. Upgrade is install with another version, uninstall deletes the instance, and both keep the guarantees 0006:D34 gave the manifest: CRDs and the Namespace are never deleted, and no delete of the operator's instance goes ahead while instances still carry the operator's cleanup finalizer (D3, D9, D10).

On a cluster whose operator came from a manifest, the first module install adopts exactly the objects it can prove came from an earlier operator release, deletes the earlier Deployment so the instance can create it with the new selector, and deletes the three superseded bindings. The controller pauses for that rollout; nothing it manages is touched (D8).

The [README](README.md#how-it-works) draws this flow.

**Evidence.** Both experiments concluded on 2026-10-04.

- [`experiments/01-operator-module-render/`](experiments/01-operator-module-render/) rendered the whole 19-object install with no cluster and the CRDs equal to the controller's own. The catalog's workload and role resources changed three binding names and the Deployment's selector and dropped the seccomp profile; writing those objects in the manifest's shape reached spec parity. The owner chose the catalog path anyway, as the better showcase, so D2 renders through the catalog, D12 makes the catalog carry seccomp and subject-less roles, and D8 takes on the selector change and the bindings. The CRD and RBAC drift check worked as a regenerate-and-diff.
- [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/) installed, reinstalled with no change, upgraded and deleted a CLI-owned, catalog-path operator instance on a fresh cluster, and the operator left its own instance alone (OQ2 resolved by D3). It also found what D3 and D9 now require: a refused install had already changed the CRDs (D3:R12), the wait returned before the operator reconciled (D3:R10), the CLI's readiness check reads the embedded manifest (D3:R13), and `opm instance delete` of the operator's instance skipped the finalizer guard (D9:R5). Its migration probe is the migration D8 now requires done by hand: a Deployment delete and three leftover bindings. Its self-transfer probe backs D4, and its reinstall after a Platform was seeded backs D11.

## Schema / API Surface

The entry changes no core definition and adds no contract CUE. The new consumer-facing surface is the operator module's `#config` (D5), which falls under the module class of 0021 on the module's own train, so its schema is the module's compatibility surface (D1, D2). Its headline fields:

| Value | What it tunes |
| --- | --- |
| Image repository | where the operator image is pulled from, for a mirror; the tag and digest are always the ones the module version names (D5:R6) |
| Registry mapping | where the operator resolves modules from |
| Default service account | the identity the operator applies instances as |
| Resources | the controller container's requests and limits |
| Replicas | the controller's replica count; leader election stays on |
| Extra arguments | anything the schema does not type |

Field names and shapes are the operator repository's to choose in the implementing change; once published they are part of the contract. The catalog gains two authoring surfaces any module can use: a seccomp profile on the workload security context and a role with no subjects (D12).

## Affected Surfaces

```text
core, catalog_opm --pins--> operator module <--module release-- opm-operator repo
                                  ^                                     |
                                  +-------- image by digest <-- operator release
                                  |
                          resolve + render  -------->  install manifest --> kubectl apply
                                  |
                      opm operator install (cli)
```

- **opm-operator.** The repository releases two units: the operator binary and image, as today, and the module `opmodel.dev/modules/opm_operator` on its own version train starting at `v0`, with tags no operator release can take (D1). Each module release names one operator image by tag and digest, publishes the install manifest as its render at defaults, and refuses a module whose CRDs or controller RBAC differ from the controller's declarations (D2). The operator release stops publishing a manifest of its own. The module renders the controller through the catalog (D2:R12) and keeps every name the CLI reads (D2:R10).
- **catalog.** The workload security context gains a seccomp profile at pod and container level, and the role resource accepts a role with no subjects and renders it without a binding (D12). Both land in a catalog release the module pins before the module's first release. Four rough edges experiment 01 hit are follow-ups.
- **cli.** `opm operator install` installs the module as a CLI-owned instance in two steps (D3), refusing before it changes anything (D3:R12), refusing a default module version whose content differs from its pin (D1:R14), applying the version rules of D10, rendering against the module's own pins (D11), and waiting for the new operator to reconcile (D3:R10). The ceiling on the running operator no longer refuses install (D3:R16). Selecting another version takes a module version, resolved through the CLI's registry mapping, instead of a release tag fetched from GitHub. The CRDs-only form renders the same module and applies only its CRDs (D3:R7). Re-running install keeps recorded values (D5:R2). The readiness check behind the CLI's delete guard finds the operator through its instance, or by its fixed names where no record exists (D3:R13, R15). Uninstall deletes the operator's instance and refuses as 0006:D34 did, and the generic instance delete keeps that refusal for the operator's instance (D9). The first install over a manifest-installed operator adopts its objects, recreates its Deployment and deletes three bindings (D8). No CLI command hands the operator's instance to the operator (D4:R3). Install needs a module registry, where the embedded manifest did not.
- **opm.** The install and quickstart pages describe install as a module apply, the registry or mirror it needs, how tuning is set as values instead of Deployment patches, and the one-time migration from a manifest install.
- **Workspace release rules.** The module release sits between the operator and the CLI: core and the catalog are its upstreams, the operator binary is its other upstream, and the CLI's tier row, its shipped pin, G1 and G4 key on the operator module version and its content digest instead of the embedded manifest (D7).
- **opmodel.dev.** The documentation site's version resolver reads the operator version the CLI's pinned module deploys, instead of the removed manifest constant (D7).

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
