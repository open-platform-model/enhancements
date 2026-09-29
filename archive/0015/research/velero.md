# Velero v1.18.2: field-level reference for an engine-neutral backup abstraction

Gathered 2026-09-12 by a research agent against v1.18.2 (latest stable, 2026-06-26). Input to `backup-trait-design.md`. Snapshot, not canon.

---

## 1. Schedule CR

Source: [schedule_types.go#L26-L52](https://github.com/vmware-tanzu/velero/blob/v1.18.2/pkg/apis/velero/v1/schedule_types.go#L26-L52). `ScheduleSpec` is exactly five fields:

| Field | Type | Notes |
|---|---|---|
| `template` | `BackupSpec` (required) | see 2 |
| `schedule` | `string` (required) | cron; also `@every 1h` (robfig/cron) |
| `useOwnerReferencesInBackup` | `*bool` | deleting the Schedule cascades its Backups |
| `paused` | `bool` | |
| `skipImmediately` | `*bool` | nil -> server flag `--schedule-skip-immediately`. Added v1.13 |

Generated backup name: `<schedule>-<YYYYMMDDHHmmss>`.

**Namespace: velero namespace only.** The manager cache is scoped to one namespace (`cache.Options{DefaultNamespaces: {f.Namespace(): {}}}`, [server.go#L269-L275](https://github.com/vmware-tanzu/velero/blob/v1.18.2/pkg/cmd/server/server.go#L269-L275)). A Schedule or Backup in a tenant namespace is **silently ignored**: no event, no status. The single hardest constraint on an abstraction.

**Label/annotation propagation**: the Backup takes labels from `spec.template.metadata.labels` if set, else the Schedule's labels; `velero.io/schedule-name` is always added; the Schedule's annotations are copied verbatim onto the Backup ([backup_builder.go#L85-L133](https://github.com/vmware-tanzu/velero/blob/v1.18.2/pkg/builder/backup_builder.go#L85-L133)). That copy is how per-schedule CSI class overrides work (5).

**RBAC**: granting a tenant `create` on `schedules.velero.io` means granting it in the velero namespace, where `template.includedNamespaces: ["*"]` exfiltrates every namespace. No admission-level restriction upstream (12).

---

## 2. Backup spec / template fields

Source: [backup_types.go#L28-L194](https://github.com/vmware-tanzu/velero/blob/v1.18.2/pkg/apis/velero/v1/backup_types.go#L28-L194).

```
includedNamespaces / excludedNamespaces          []string
includedResources / excludedResources            []string
includedClusterScopedResources / excluded...     []string
includedNamespaceScopedResources / excluded...   []string
labelSelector                                    *metav1.LabelSelector
orLabelSelectors                                 []*metav1.LabelSelector   # mutually exclusive with labelSelector
snapshotVolumes                                  *bool
ttl                                              metav1.Duration    # Go duration: "720h0m0s", "168h". NOT "30d".
volumeGroupSnapshotLabelKey                      string             # v1.17+
includeClusterResources                          *bool
hooks.resources[]                                []BackupResourceHookSpec
storageLocation                                  string
volumeSnapshotLocations                          []string
defaultVolumesToFsBackup                         *bool
orderedResources                                 map[string]string
csiSnapshotTimeout                               metav1.Duration    # default 10m
itemOperationTimeout                             metav1.Duration    # default 4h
resourcePolicy                                   *corev1.TypedLocalObjectReference  # {kind: configmap, name}
snapshotMoveData                                 *bool
datamover                                        string             # "" or "velero"
uploaderConfig.parallelFilesUpload               int
```

Defaults are server flags: `defaultBackupTTL = 30*24h`, `defaultCSISnapshotTimeout = 10m`, `defaultItemOperationTimeout = 4h` ([config.go#L37-L43](https://github.com/vmware-tanzu/velero/blob/v1.18.2/pkg/cmd/server/config/config.go#L37-L43)).

---

## 3. Backup hooks

**Annotation form** (on the Pod, [docs/backup-hooks](https://velero.io/docs/v1.18/backup-hooks/)): `pre.hook.backup.velero.io/container`, `/command` (JSON array string), `/on-error` (`Fail|Continue`, default Fail), `/timeout` (default 30s); and `post.hook.backup.velero.io/...`.

**Spec form** ([backup_types.go#L196-L273](https://github.com/vmware-tanzu/velero/blob/v1.18.2/pkg/apis/velero/v1/backup_types.go#L196-L273)): `hooks.resources[].{name, includedNamespaces, excludedNamespaces, includedResources, excludedResources, labelSelector, pre[].exec{container,command,onError,timeout}, post[].exec{...}}`. **No pod annotation needed.**

**No shell.** "hooks are _not_ executed within a shell"; put `/bin/sh -c` in `command`.

**Ordering** ([backup.go#L785-L875](https://github.com/vmware-tanzu/velero/blob/v1.18.2/pkg/backup/backup.go#L785-L875)), ItemBlock-scoped since v1.15:
1. Collect pods in the ItemBlock not already backed up (hooks run on Pods only).
2. Run all **pre** hooks.
3. Back up every item in the block: CSI VolumeSnapshot creation **and** `PodVolumeBackup` CR creation happen here.
4. `handleItemBlockPostHooks` -> `waitUntilPVBsProcessed` -> **post** hooks.

**Pre hooks run strictly before the snapshot and before fs-backup; post hooks wait for all PVBs of the block.** A failed pre hook with `onError: Fail` marks the backup `PartiallyFailed`. The pre-hook exec session is NOT held open across the snapshot: the exec returns before step 3. A lock that releases on disconnect (MariaDB `BACKUP STAGE`, Postgres `pg_backup_start`) therefore needs the hook command itself to background a held session, or the lock is gone before the snapshot.

**Can a hook write a file the same backup captures?** Yes, for both fs-backup and CSI: the standard "dump-then-backup" pattern.

---

## 4. File-system backup (node-agent, kopia/restic)

[docs/file-system-backup](https://velero.io/docs/v1.18/file-system-backup/).
- Opt-in annotation `backup.velero.io/backup-volumes=<vol,...>` (pod-level, pod-spec volume names). Opt-out `backup.velero.io/backup-volumes-excludes`. Both are pod annotations.
- Opt-out mode auto-excludes SA token volumes, Secrets, ConfigMaps, hostPath.
- **Requires a running pod** mounting the volume; orphan PVCs need a staging pod. `emptyDir` works but every backup is full.
- **No per-path include/exclude.** The kopia uploader's only `IgnoreRules` are two unconditional Windows paths ([snapshot.go#L113-L135](https://github.com/vmware-tanzu/velero/blob/v1.18.2/pkg/uploader/kopia/snapshot.go#L113-L135)). `.kopiaignore` is not honored (zero hits in tree). Granularity is the volume.
- Data goes to a `BackupRepository` CR per (namespace, BSL, repo type). Unit of work: `PodVolumeBackup`. Maintenance runs as a separate Job in the velero namespace (v1.14+), configured by `--repo-maintenance-job-configmap` (v1.15+); `maintenanceFrequency` default 1h.
- Security note: "Velero uses a static, common encryption key for all backup repositories it creates."

---

## 5. CSI snapshots and data movement

- Feature flag `--features=EnableCSI`; CSI plugin in-tree since v1.14 ([docs/csi](https://velero.io/docs/v1.18/csi/)).
- VolumeSnapshotClass precedence: PVC annotation `velero.io/csi-volumesnapshot-class` -> Backup/Schedule annotation `velero.io/csi-volumesnapshot-class_<driver>` -> VSClass label `velero.io/csi-volumesnapshot-class: "true"` -> default class annotation.
- VolumeSnapshots are retained only for the backup's lifetime.
- `snapshotMoveData: true` -> a `DataUpload` moves the snapshot into the kopia repo on the BSL; needs node-agent ([docs/csi-snapshot-data-movement](https://velero.io/docs/v1.18/csi-snapshot-data-movement/)).

**Pod-referenced PVCs are auto-included.** `PodAction` returns every PVC volume as a related item ([pod_action.go#L38-L50](https://github.com/vmware-tanzu/velero/blob/v1.18.2/pkg/backup/actions/pod_action.go#L38-L50)); additional items re-check the exclude label and namespace/resource filters but **not `labelSelector`** ([item_backupper.go#L112-L152](https://github.com/vmware-tanzu/velero/blob/v1.18.2/pkg/backup/item_backupper.go#L112-L152)). **Consequence: label a Pod and its PVCs come along even if unlabelled. Label only a PVC and it is CSI-snapshotted (no pod needed) but not fs-backed-up.**

---

## 6. Volume policies / resource policy ConfigMap

[volume_resources_validator.go#L40-L48](https://github.com/vmware-tanzu/velero/blob/v1.18.2/internal/resourcepolicies/volume_resources_validator.go#L40-L48), [resource_policies.go](https://github.com/vmware-tanzu/velero/blob/v1.18.2/internal/resourcepolicies/resource_policies.go#L31-L100), [docs/resource-filtering](https://velero.io/docs/v1.18/resource-filtering/).

| Condition | Shape | Introduced |
|---|---|---|
| `capacity` | `"10Gi,100Gi"` | v1.11 |
| `storageClass` | `[]string` | v1.11 |
| `nfs` | `{server, path}` | v1.11 |
| `csi` | `{driver, volumeAttributes}` | v1.11 |
| `volumeTypes` | `[]SupportedVolume` | v1.13 |
| `pvcLabels` | `map[string]string`, AND | **v1.16** |
| `pvcPhase` | `[]string` | **v1.18** |

Actions: `skip`, `snapshot`, `fs-backup`, `custom`. `snapshot`/`fs-backup` added v1.14. First matching policy wins; conditions within a policy are AND.

**ConfigMap placement: the velero namespace** (fetched from `backup.Namespace`, [resource_policies.go#L238-L255](https://github.com/vmware-tanzu/velero/blob/v1.18.2/internal/resourcepolicies/resource_policies.go#L238-L255)). Exactly one data key; unknown YAML keys are a hard error (good for a generator).

Caveat (CHANGELOG-1.14): external BIA plugins that check `snapshotVolumes` will not see the volume policy.

---

## 7. `velero.io/exclude-from-backup`

Label `velero.io/exclude-from-backup: "true"` ([labels_annotations.go#L101-L103](https://github.com/vmware-tanzu/velero/blob/v1.18.2/pkg/apis/velero/v1/labels_annotations.go#L101-L103)). Checked for **every** item including PVCs and PVs, wins over a matching `labelSelector` ([item_backupper.go#L116-L121](https://github.com/vmware-tanzu/velero/blob/v1.18.2/pkg/backup/item_backupper.go#L116-L121)). **Tenant-writable**: an ordinary label on the tenant's own object. A self-service opt-out primitive and footgun. For an OPM adapter it is still a label on an object another transformer renders.

---

## 8. BSL and VSL

[backupstoragelocation_types.go#L27-L160](https://github.com/vmware-tanzu/velero/blob/v1.18.2/pkg/apis/velero/v1/backupstoragelocation_types.go#L27-L160).

```yaml
spec:
  provider: aws
  objectStorage: {bucket, prefix, caCertRef: {name, key}}
  config: {region, s3Url, s3ForcePathStyle, insecureSkipTLSVerify, checksumAlgorithm, publicUrl}  # plugin-owned keys
  credential: {name, key}      # corev1.SecretKeySelector
  default: false
  accessMode: ReadWrite | ReadOnly
  backupSyncPeriod: 1m
  validationFrequency: 1m
```

**Namespace: velero only.** The credential Secret **must be in the velero namespace** ([docs/locations](https://velero.io/docs/v1.18/locations/)). **Tenant-defined BSL: no. No per-namespace or per-backup credential override.** Per-tenant credential isolation = one admin-created BSL per tenant, all in the velero namespace. A tenant-scoped "backup target" maps to an admin-owned BSL, never to anything the tenant can write.

---

## 9. Retention

**TTL is the only mechanism.** No keep-last, keep-daily, or GFS. `status.expiration = start + ttl`; default 30d. GC every 60 min ([gc_controller.go#L44](https://github.com/vmware-tanzu/velero/blob/v1.18.2/pkg/controller/gc_controller.go#L44)). Deletion removes CSI snapshots, native snapshots, pod-volume snapshots in the repo, data-mover uploads, the tarball, the Backup CR, and all Restores referencing it ([backup_deletion_controller.go#L270-L400](https://github.com/vmware-tanzu/velero/blob/v1.18.2/pkg/controller/backup_deletion_controller.go#L270-L400)). Kopia space is reclaimed only after repository maintenance.

---

## 10. Restore

[restore_types.go#L28-L251](https://github.com/vmware-tanzu/velero/blob/v1.18.2/pkg/apis/velero/v1/restore_types.go#L28-L251): `backupName` / `scheduleName`, namespace/resource filters, `namespaceMapping`, `labelSelector`/`orLabelSelectors`, `restorePVs`, `existingResourcePolicy` (`none|update`), `resourceModifier`, `uploaderConfig.{writeSparseFiles, parallelFilesDownload}`, `hooks.resources[].postHooks[].{exec, init{initContainers[]}}`. Restore hook annotations: `init.hook.restore.velero.io/*`, `post.hook.restore.velero.io/*` ([docs/restore-hooks](https://velero.io/docs/v1.18/restore-hooks/)).

**Single PVC restore**: `includedResources: [persistentvolumeclaims, persistentvolumes]` + `labelSelector`. Fs-backup data is restored by an init container injected into the **pod**, so a PVC-only restore yields an empty PVC unless the pod is restored too. **Cross-namespace**: `namespaceMapping` works; the BackupRepository is keyed by the source namespace.

---

## 11. Metrics

`:8085/metrics`, Deployment annotated for scraping. All `velero_*` ([metrics.go](https://github.com/vmware-tanzu/velero/blob/v1.18.2/pkg/metrics/metrics.go)): `backup_attempt_total`, `backup_success_total`, `backup_partial_failure_total`, `backup_failure_total`, `backup_duration_seconds`, `backup_items_total`, `backup_tarball_size_bytes`, **`backup_last_status`** (1/0), **`backup_last_successful_timestamp`**, all labelled `schedule`; `backup_location_status_gauge`; `csi_snapshot_*`, `data_upload_*`, `pod_volume_*`, `repo_maintenance_*`, `restore_*`. Standard alerts: `velero_backup_last_status{schedule="x"} == 0`; `time() - velero_backup_last_successful_timestamp{schedule="x"} > 2*interval`.

---

## 12. Multi-tenancy: the honest answer

**Upstream Velero has no multi-tenancy.** [Issue #2587 "[Epic] Multi-Tenancy and Self Service"](https://github.com/vmware-tanzu/velero/issues/2587), open since 2020-05-28. Every reconciled CR and every BSL credential lives in the velero namespace, and `includedNamespaces` is unconstrained.

Patterns in the wild:
1. **Admin-generated Schedules from tenant-visible intent** (the shape an OPM adapter renders into): tenant intent in its own namespace, a generator/controller creates the Schedule in the velero namespace with `includedNamespaces` pinned to the tenant. [Kyverno generate](https://nirmata.com/2021/01/24/self-service-velero-backups-with-kyverno/); [Capsule backup/restore](https://projectcapsule.dev/docs/operating/backup-restore/).
2. **A dedicated non-admin controller**: Red Hat's OADP Non-Admin Controller ([migtools/oadp-non-admin](https://github.com/migtools/oadp-non-admin), active 2026-09) with `NonAdminBackup` / `NonAdminRestore` / `NonAdminBackupStorageLocation` CRs in the tenant namespace, reconciled into velero-namespace CRs with scope forced to the tenant ([Red Hat write-up 2026-08-28](https://developers.redhat.com/articles/2026/08/28/self-service-backup-vms-openshift)). Pattern 1 productised; the closest reference architecture.
3. No tenant Velero RBAC at all: the community default.

For OPM: the Velero adapter's output is platform-admin-scoped by construction. Under tenant impersonation (0015's registration model) a tenant module cannot apply it. Either the platform applies Velero objects on the tenant's behalf (pattern 1/2), or Velero is not a tenant-usable provider.

---

## Explicitly uncertain

- Version-introduced dates for `pvcLabels` (v1.16), `pvcPhase` (v1.18), `includeExcludePolicy` (v1.17), `volumeTypes` (v1.13) are inferred from first appearance in versioned docs, not changelog entries.
- BSL `config` keys are provider-plugin-owned; see `velero-plugin-for-aws` for the authoritative list.
