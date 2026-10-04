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
- Scripted break: the podinfo Deployment's image set to a tag that does not exist, sampled every 2 s until `ProgressDeadlineExceeded`.

[`capture.sh`](capture.sh) is the snapshot script, with the scratch paths replaced by environment variables. It never reads Secrets: the all-objects listing excludes them by resource name.

## Run

```bash
# against a throwaway cluster only; the script refuses any other context
KUBECONFIG_FILE=<throwaway kubeconfig> OUT_ROOT=./out ./capture.sh phase3-healthy
```

The full snapshots (all OPM CRs, every events.k8s.io/v1 event, all non-Secret objects, workload ownership chains, the operator log, about 12 MB across six phases) stayed outside the repo. [`samples/`](samples/) holds a trimmed subset: `managedFields`, the `kubectl.kubernetes.io/last-applied-configuration` annotation and `spec.values` are removed from every object, status histories are cut to one or two entries, and inventories to the first few entries.

| Sample | What it shows |
| --- | --- |
| `mi-apply-failed.yaml` | `Ready=False/ApplyFailed`, `Reconciling=True`, no inventory and no `lastAppliedAt`, but `requiredContracts` already set; failed history entries carry `message` and no `phase`; `failureCounters.drift` climbing on the failure |
| `mi-podinfo-healthy.yaml`, `mi-podinfo-image-broken.yaml` | the same instance before and one minute after the image break: operator status identical in kind (`Ready=True/ReconciliationSucceeded`), only the digests and history move |
| `pods-image-broken.txt`, `break-timeline-excerpt.txt` | the new Pod in `ErrImagePull` / `ImagePullBackOff` while the Deployment stays `Available=True` and the instance stays `Ready=True` until `ProgressDeadlineExceeded`, about 600 s later |
| `events-operator-podinfo.yaml` | operator events (`opm-controller`) with no `series` and no periodic NoOp events |
| `events-kubelet-image-pull.yaml` | kubelet events with `eventTime: null`, counted through `deprecatedCount` and `deprecatedLastTimestamp` |
| `mi-cli-owned.yaml` | `spec.owner: cli`, `Ready=Unknown/ManagedExternally`, an inventory the CLI wrote, no `requiredContracts` |
| `platform-fresh.yaml` | `ContractsFulfilled=False/UnfulfilledContracts` on a fresh install with two provider-fulfilled contracts nobody implements |
| `treg-catalog-unresolved.yaml`, `treg-refusals.yaml` | refusal as `Stalled=True` plus `Ready=False` with the same reason (`CatalogUnresolved`, `ProvidesMismatch`, `ProviderMismatch`); no `Active` condition when not accepted |

## Outcome

Measured on the live cluster. Fourteen observations, each correcting or confirming a claim the design had read from source:

1. **The default install cannot deploy a module with cluster-scoped objects.** cert-manager went `ApplyFailed` under the operator's ServiceAccount (cannot patch CRDs) and Ready once `serviceAccountName` named a cluster-admin applier. ApplyFailed is a state the portal must render: `Reconciling=True`, `Ready=False`, no inventory, no `lastAppliedAt`, `requiredContracts` already written.
2. **`status.requiredContracts` lists every contract the render used** (15 for cert-manager, 7 for podinfo), mostly catalog-fulfilled ones. It is not the set of provider contracts the instance demands, so it cannot draw "requires a provider" edges.
3. **An image-pull failure does not reach kstatus Failed until the progress deadline.** The new Pod sat in `ErrImagePull` / `ImagePullBackOff` from the first second, the Deployment stayed `Available=True` and kstatus said InProgress for about 600 s, and the operator's Ready stayed True throughout. Only a Pod-level waiting reason shows the break within seconds.
4. **Operator events never carry `series`, and there are no periodic NoOp events.** Kubelet events have `eventTime: null` and are counted through the deprecated count and timestamp fields. A feed has to deduplicate itself.
5. **Events about the cluster-scoped Platform and TransformerRegistration land in namespace `default`.**
6. **`failureCounters.drift` climbs on healthy instances.** The operator's drift dry-run runs as its own ServiceAccount and ignores `spec.serviceAccountName` (opm-operator issue 209). The counters are not a health signal.
7. **`regarding.*`, `reason` and `type` field selectors work server-side** on events.k8s.io/v1 at 1.36.
8. **ReplicaSets and Pods carry `module-instance.opmodel.dev/name` and `component.opmodel.dev/name`**, but not the uuid label. All 44 operator-owned inventory objects carry the uuid label, and none has an ownerReference to its ModuleInstance.
9. **A TransformerRegistration refusal is `Stalled=True` plus `Ready=False` with the same reason.** The `Active` condition is absent until accepted. `spec.version` needs a `v` prefix, contrary to the CRD's own doc comment (opm-operator issue 210).
10. **History entries are `{action: reconcile, phase: complete}` on success; failed entries carry `message` and no phase.** The list keeps about five entries, so a failing instance fills it with retries.
11. **`ContractsFulfilled=False/UnfulfilledContracts` is normal on a fresh Platform.** A portal that paints it red alarms every new install.
12. **A request-path graph is too slow.** Serving cert-manager's graph live took 7.4 to 9.4 s: about 45 GETs at client-go's default 5 queries per second. A watch-fed cache is required, not an optimisation.
13. **cert-manager's graph has 86 nodes and 85 edges**, 20 of them component nodes, most holding one RBAC or config object. Unreadable without grouping.
14. **The last-applied annotation copies the full `spec.values`** whenever an instance is applied with client-side `kubectl apply`. Hiding values means stripping that annotation too.

Two further facts from the CLI-owned instance: the CLI stamps `module-instance.opmodel.dev/namespace` and `app.kubernetes.io/managed-by: opm-cli` on the ModuleInstance it writes, and the operator emits one `ManagedExternally` event for it. A ModulePackage without Flux sat at `Ready=False/SourceNotReady`, retried every 60 s.

Sizes: the cert-manager ModuleInstance is 14.6 KB (status 12.6 KB, inventory 6.3 KB at about 148 B per entry, history 4.1 KB for five entries); podinfo is 3.4 KB.

Not captured: an accepted and active TransformerRegistration with a consumer of its contract (needs a provider catalog and module published under `testing.opmodel.dev`), and a working ModulePackage (needs Flux and a pushed artifact).

**Hypothesis held, with corrections.** The operator's status, inventory and labels carry enough for applied state, the instance graph and a feed without any render, but health needs a Pod-level rule (3), contract demand is not recorded (2), events need deduplication (4, 5), and the cache tier is mandatory (12). These corrections are folded into D3, D4, D8 and D9 of the decision log.
