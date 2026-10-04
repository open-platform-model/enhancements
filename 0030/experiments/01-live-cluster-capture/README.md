# 01-live-cluster-capture — OPM Portal V1

Status: Concluded

## Hypothesis

The status, inventory, label and event shapes a released opm-operator writes on a live cluster are enough for a read-only portal to show applied state, workload health, the instance graph and a recent-activity feed without re-rendering any module, and the portal design read from source alone matches what the operator actually writes.

## Setup

A throwaway kind cluster (`opm-portal-probe`, Kubernetes v1.36.1, podman provider), created for this capture and deleted afterwards. Never the shared development or dogfood clusters.

- CLI v1.0.0-beta.7 (checksum verified) installed opm-operator v1.0.0-beta.5 from its release manifest.
- The Platform subscribed `opmodel.dev/catalogs/opm@v4` at 4.5.2 and went Ready in about 3 s.
- Inputs applied, copied into [`inputs/`](inputs/) (no Secret data in any of them):
  - `mi-cert-manager.yaml`: `opmodel.dev/modules/cert_manager@v2` v2.0.5, cluster-scoped kinds, CRDs and webhooks. First under the operator's own ServiceAccount, then with `cert-manager-applier.yaml` naming a cluster-admin applier ServiceAccount.
  - `mi-podinfo.yaml`: `testing.opmodel.dev/modules/operator/podinfo@v0` v0.1.11 with a namespaced applier ServiceAccount. Used for the scripted image break.
  - `tregs.yaml`: two hand-applied TransformerRegistrations, each exercising a refusal verdict. No published provider module rendered one at capture time.
  - `mp-noflux.yaml`: a ModulePackage on a cluster without Flux, exercising the missing-source state only.
  - `web-cli-owned/`: a CLI-owned instance of `opmodel.dev/modules/web_app@v1` v1.0.5, applied with `opm instance apply` (owner-approved, throwaway cluster only).
- Scripted break: the podinfo ModuleInstance's `values.image.tag` patched to a tag that does not exist, so the operator applied the bad image (instance generation 1 to 2); sampled every 2 s until `ProgressDeadlineExceeded`. The two old replicas kept running and serving while the new Pod failed to pull, which is why the Deployment's `Available=True` stayed truthful.
- Phases 7 to 9, on a second throwaway cluster (`opm-portal-f1`, same versions, deleted afterwards): a backup provider fixture set (catalog, provider module and consumer module at 0.1.0, from opm-operator PR 212, branch `test/add-active-provider-fixture`) served from a local registry mapped for `testing.opmodel.dev` only. Phase 7 ran the released operator v1.0.0-beta.5; phases 8 and 9 ran opm-operator `main` at 40a2345 rebuilt with library v1.0.0-beta.4, which is not a release.

[`capture.sh`](capture.sh) is the snapshot script for phases 1 to 6, with the scratch paths replaced by environment variables. It never reads Secrets: the all-objects listing excludes them by resource name. Phases 7 to 9 were snapshotted by hand with the same `kubectl get` calls, limited to the OPM kinds, events and the consumer's rendered objects.

## Run

```bash
# against a throwaway cluster only; the script refuses any other context
KUBECONFIG_FILE=<throwaway kubeconfig> OUT_ROOT=./out ./capture.sh phase3-healthy
```

The full snapshots (all OPM CRs, every events.k8s.io/v1 event, all non-Secret objects, workload ownership chains, the operator log, about 12 MB across nine phases) stayed outside the repo. [`samples/`](samples/) holds a trimmed subset: `managedFields`, the `kubectl.kubernetes.io/last-applied-configuration` annotation and `spec.values` are removed from every object, status histories are cut to one or two entries, and inventories to the first few entries.

| Sample | What it shows |
| --- | --- |
| `mi-apply-failed.yaml` | `Ready=False/ApplyFailed`, `Reconciling=True`, no inventory and no `lastAppliedAt`, but `requiredContracts` already set; failed history entries carry `message` and no `phase`; `failureCounters.drift` climbing on the failure |
| `mi-podinfo-healthy.yaml`, `mi-podinfo-image-broken.yaml` | the same instance before and one minute after the image break: operator status identical in kind (`Ready=True/ReconciliationSucceeded`), only the digests and history move |
| `pods-image-broken.txt`, `break-timeline-excerpt.txt` | the new Pod in `ErrImagePull` / `ImagePullBackOff` while the Deployment stays `Available=True` and the instance stays `Ready=True` until `ProgressDeadlineExceeded`, about 600 s later |
| `events-operator-podinfo.yaml` | operator events (`opm-controller`) for podinfo: each repeat a separate event with no `series` |
| `events-operator-series.yaml` | operator events that do carry `series` (`count: 2`): a Platform `Generated` repeat inside the recorder's window, the first from the released beta.5 controller |
| `events-kubelet-image-pull.yaml` | kubelet events with `eventTime: null`, counted through `deprecatedCount` and `deprecatedLastTimestamp` |
| `mi-cli-owned.yaml` | `spec.owner: cli`, `Ready=Unknown/ManagedExternally`, an inventory the CLI wrote, no `requiredContracts` |
| `platform-fresh.yaml` | `ContractsFulfilled=False/UnfulfilledContracts` on a fresh install with two provider-fulfilled contracts nobody implements |
| `treg-catalog-unresolved.yaml`, `treg-refusals.yaml` | hand-applied refusals: `Stalled=True` plus `Ready=False` with the same reason (`CatalogUnresolved`, `ProvidesMismatch`, `ProviderMismatch`); no `status.accepted`, no `status.active`, no `Active` condition |
| `treg-rendered-refused-beta5.yaml` | phase 7: the claim the provider module rendered, with the bare `0.1.0` the opm catalog's transformer writes, refused `CatalogUnresolved` by the released beta.5 operator |
| `treg-accepted-active.yaml`, `platform-registration-entry.yaml`, `mi-backup-consumer-ready.yaml` | phase 8: the same claim with `status.accepted: true`, `status.active: true`, `Ready=True/Accepted` and `Active=True/ProviderReady`; the Platform's registry lists the catalog with `source: Registration`; the consumer is Ready with one ConfigMap the provider catalog's transformer rendered |
| `treg-removal-blocked.yaml` | phase 9: the claim deleted while the consumer still demands its contract: `Stalled=True` plus `Ready=False`, reason `DependentsRemain`, while `status.accepted` and `status.active` stay true and `Active=True` stays |

## Outcome

Measured on the live cluster. Fourteen observations, each correcting or confirming a claim the design had read from source:

1. **The default install cannot deploy a module with cluster-scoped objects.** cert-manager went `ApplyFailed` under the operator's ServiceAccount (cannot patch CRDs) and Ready once `serviceAccountName` named a cluster-admin applier. ApplyFailed is a state the portal must render: `Reconciling=True`, `Ready=False`, no inventory, no `lastAppliedAt`, `requiredContracts` already written.
2. **`status.requiredContracts` lists every contract the render used** (15 for cert-manager, 7 for podinfo), mostly catalog-fulfilled ones. It is not the set of provider contracts the instance demands, so it cannot draw "requires a provider" edges.
3. **An image-pull failure does not reach kstatus Failed until the progress deadline.** The new Pod sat in `ErrImagePull` / `ImagePullBackOff` from the first second, the Deployment stayed `Available=True` and kstatus said InProgress for about 600 s, and the operator's Ready stayed True throughout. Only a Pod-level waiting reason shows the break within seconds.
4. **Operator events carry `series` only on a repeat inside the event recorder's window.** The released beta.5 controller emitted a Platform `Generated` event with `series: {count: 2}` (phase 7), while cert-manager's four `ApplyFailed` repeats in phases 1 to 6 were four separate events with no `series`. Phases 1 to 6 had no NoOp events; phases 7 to 9 had `NoOp` events from reconciles that changed nothing. Kubelet events have `eventTime: null` and are counted through the deprecated count and timestamp fields. A feed has to fold repeats with and without `series` itself.
5. **Events about the cluster-scoped Platform and TransformerRegistration land in namespace `default`.**
6. **`failureCounters.drift` climbs on healthy instances.** The operator's drift dry-run runs as its own ServiceAccount and ignores `spec.serviceAccountName` (opm-operator issue 209). The counters are not a health signal.
7. **`regarding.*`, `reason` and `type` field selectors work server-side** on events.k8s.io/v1 at 1.36.
8. **ReplicaSets and Pods carry `module-instance.opmodel.dev/name` and `component.opmodel.dev/name`**, but not the uuid label. All 44 operator-owned inventory objects carry the uuid label, and none has an ownerReference to its ModuleInstance.
9. **Registration state is in `status.accepted` and `status.active`, not in the condition pair.** A refusal is `Stalled=True` plus `Ready=False` with the same reason, no `accepted` or `active` field and no `Active` condition. But a registration whose removal is blocked (phase 9) shows the same condition pair, reason `DependentsRemain`, while `accepted` and `active` stay true. And the released beta.5 operator refuses every claim the opm catalog's transformer renders: the transformer writes the bare SemVer `0.1.0`, which library v1.0.0-beta.1 rejects as not well formed, so the claim is `CatalogUnresolved` (phase 7, opm-operator issue 210). Library v1.0.0-beta.4 canonicalises the version (library PR 170); an operator built on it accepted the same claim (phase 8). The hand-applied claims, written with a `v` prefix, got past version parsing to other verdicts. Issue 210 is filed as a doc mismatch, but the effect is that no rendered claim is accepted until an operator release ships library v1.0.0-beta.4 or later.
10. **History entries are `{action: reconcile, phase: complete}` on success; failed entries carry `message` and no phase.** The operator keeps at most ten entries (five were present in the largest snapshot), so a failing instance's retries push older successes out after ten attempts.
11. **`ContractsFulfilled=False/UnfulfilledContracts` is normal on a fresh Platform.** A portal that paints it red alarms every new install.
12. **A request-path graph is too slow.** Serving cert-manager's graph live took 7.4 to 9.4 s: about 45 GETs at client-go's default 5 queries per second. A watch-fed cache is required, not an optimisation.
13. **cert-manager's graph has 86 nodes and 85 edges**, 20 of them component nodes, most holding one RBAC or config object. Unreadable without grouping.
14. **The last-applied annotation copies the full `spec.values`** whenever an instance is applied with client-side `kubectl apply`. Hiding values means stripping that annotation too.

Phases 7 to 9 added the registration states D4 shows: refused, accepted and active, and removal blocked (observation 9). Two further facts from the CLI-owned instance: the CLI stamps `module-instance.opmodel.dev/namespace` and `app.kubernetes.io/managed-by: opm-cli` on the ModuleInstance it writes, and the operator emits one `ManagedExternally` event for it. A ModulePackage without Flux sat at `Ready=False/SourceNotReady`, retried every 60 s.

Sizes: the cert-manager ModuleInstance is 14.6 KB (status 12.6 KB, inventory 6.3 KB at about 148 B per entry, history 4.1 KB for five entries); podinfo is 3.4 KB.

Not captured: a working ModulePackage (needs Flux and a pushed artifact), and an accepted, active registration on a released operator: phase 8 ran an unreleased build, because no released operator carries library v1.0.0-beta.4 yet.

**Hypothesis held, with corrections.** The operator's status, inventory and labels carry enough for applied state, the instance graph and a feed without any render, but health needs a Pod-level rule (3), contract demand is not recorded (2), events need deduplication (4, 5), and the cache tier is mandatory (12). These corrections are folded into D3, D4, D8, D9 and D10 of the decision log.
