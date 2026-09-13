# Other Kubernetes backup engines: KubeStash, Kanister/K10, Longhorn, VolSync, snapscheduler

Gathered 2026-09-12 by a research agent from the cited CRD sources and docs; `[unverified]` marks facts not confirmed at source level. Generality check for `backup-trait-design.md`. Snapshot, not canon.

---

## 1. KubeStash (AppsCode, successor to Stash)

API group `core.kubestash.com/v1alpha1`. [BackupConfiguration](https://kubestash.com/docs/v2024.9.30/concepts/crds/backupconfiguration/).

- **Q1 target.** `spec.target` is one typed object ref `{apiGroup, kind, name, namespace}`: Deployment, StatefulSet, DaemonSet, PersistentVolumeClaim, or a KubeDB CR (`kind: MariaDB`). Name-based. Label-driven fan-out only via [BackupBlueprint](https://kubestash.com/docs/v2024.9.30/concepts/crds/backupblueprint/) + workload annotations.
- **Q2 schedule.** Per *session*: `spec.sessions[].scheduler.schedule` (cron), `concurrencyPolicy`, `jobTemplate`. One CronJob per session; several sessions with different crons, addons and repositories in one object. Lives in the **tenant namespace**.
- **Q3 retention.** Separate [RetentionPolicy](https://kubestash.com/docs/v2024.9.30/concepts/crds/retentionpolicy/) CR: `maxRetentionPeriod` (TTL), `successfulSnapshots.{last,hourly,daily,weekly,monthly,yearly}`, `failedSnapshots.last`. **TTL + keep-N + tiered.** Reusable, with `usagePolicy` and `default`.
- **Q4 repository.** [BackupStorage](https://kubestash.com/docs/v2024.9.30/concepts/crds/backupstorage/) (namespaced): `spec.storage.{s3,gcs,azure,local}`, `spec.usagePolicy.from: Same|Selector|All` (the explicit **cross-tenant sharing switch**, default `Same`). Per session `repositories[]: {name, backend, directory, encryptionSecret{name,namespace}, deletionPolicy}`: shared bucket, per-app prefix, per-repo restic password.
- **Q5 consistency.** Two separate mechanisms: `sessions[].hooks.{preBackup,postBackup}[]` referencing a [HookTemplate](https://kubestash.com/docs/v2024.9.30/concepts/crds/hooktemplate/) (`executor.type: Pod|Function|Operator`, pod selector + `ExecuteOnOne|ExecuteOnAll`, `action.{exec,httpGet,httpPost,tcpSocket}`, `maxRetry`, `timeout`, `executionPolicy`), and `sessions[].addon.{name,tasks[]}`: for MariaDB `mariadb-addon` / `logical-backup` runs **`mariadb-dump` in a separate Job pod** over the service and **streams into the restic repo**, no intermediate PVC ([KubeDB MariaDB logical backup](https://kubedb.com/docs/v2026.4.27/guides/mariadb/backup/kubestash/logical/)).
- **Q6 modes.** Filesystem (`workload-addon`), CSI snapshot (`pvc-addon` / `volume-snapshot`), logical (`<db>-addon`). Mode = addon+task name, not an enum.
- **Q7 paths.** Yes: `params.paths`, `params.exclude`.
- **Q8 restore.** [RestoreSession](https://kubestash.com/docs/v2024.9.30/concepts/crds/restoresession/): target may be another name/namespace; `dataSource.snapshot: latest|<name>`; `logical-backup-restore` task; pre/post restore hooks.
- **Q9.** `BackupBlueprint` is a template, not a neutral layer.

## 2. Kanister / Kasten K10

- **Q1.** Kanister `ActionSet.spec.actions[].object` = one named workload. K10 `Policy.spec.selector` = label selector over namespaces/apps. ([Kanister architecture](https://docs.kanister.io/architecture.html), [K10 Policy API](https://docs.kasten.io/latest/api/policies.html))
- **Q2.** Kanister has **no scheduler**. K10 `Policy.spec.frequency` uses tokens (`@hourly|@daily|@weekly|@monthly|@yearly|@onDemand`) + `subFrequency` + `backupWindow` + `paused` + `enableStaggering`. K10 Policies and Blueprints live in `kasten-io`.
- **Q3.** Kanister: none (Blueprint author's job). K10: `spec.retention.{hourly,daily,weekly,monthly,yearly}` per action; export actions carry their own retention. No TTL.
- **Q4.** Kanister `Profile` CR (namespaced, tenant-ownable): `location.{type,bucket,endpoint,prefix,region}`, `credential.keyPair.secret{name,namespace}`; newer `RepositoryServer` fronts a Kopia server.
- **Q5.** The whole point: `Blueprint.actions.<name>.phases[]` of `{func, args}` (`KubeTask`, `KubeExec`, `ScaleWorkload`, `BackupDataUsingKopiaServer`, ...), `deferPhase`, `outputArtifacts` -> `inputArtifactNames`. `KubeTask` spawns a **throwaway pod from a named image**. Canonical MySQL pattern ([mysql-blueprint](https://github.com/kanisterio/blueprints/blob/main/mysql/mysql-blueprint.yaml)): `mysqldump ... | gzip | kando location push --profile ... --path ${s3_path} -`. **Streams stdout to object storage.**
- **Q6.** Blueprint-defined; K10 snapshot by default, `exportData` for a portable copy.
- **Q7.** Not first-class; Blueprint tool flags. K10 filters are resource-level.
- **Q8.** Same ActionSet kind with `restore` action + artifacts; K10 `RestoreAction` with namespace remap `[unverified]`.
- **Q9.** K10 `Policy.actions[]` with **per-action retention** is the closest commercial engine-neutral policy shape.

## 3. Longhorn `RecurringJob`

Source: `longhorn-manager/k8s/pkg/apis/longhorn/v1beta2/recurringjob.go`, [docs](https://longhorn.io/docs/1.7.2/snapshots-and-backups/scheduling-backups-and-snapshots/).

- **Q1.** Unit is a Longhorn Volume. **Inverted selection**: volumes opt in via labels `recurring-job.longhorn.io/<JOB>=enabled` or `recurring-job-group.longhorn.io/<GROUP>=enabled` on the Volume or PVC; `spec.groups: [default]` catches unassigned volumes.
- **Q2.** `spec.cron`; object lives in **`longhorn-system` only**. The tenant's only lever is the PVC label.
- **Q3.** `spec.retain` (keep-N), `spec.retainAge` (TTL, newer `[unverified for 1.7]`). No tiering.
- **Q4.** `BackupTarget` CR in `longhorn-system`: `backupTargetURL` (`s3://bucket@region/prefix`, `nfs://`, ...), `credentialSecret` (keys `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ENDPOINTS`, ...). Cluster-wide.
- **Q5.** **None.** Crash-consistent block snapshots only.
- **Q6.** `spec.task` enum: `snapshot`, `snapshot-force-create`, `snapshot-cleanup`, `snapshot-delete`, `backup`, `backup-force-create`, `filesystem-trim`, `system-backup`. The cleanest mode selector in the set.
- **Q7.** No (block-level).
- **Q8.** No Restore CR; new Volume/PVC from a `Backup` (`Volume.spec.fromBackup`). Always into a new volume.

## 4. VolSync

Source: `backube/volsync/api/v1alpha1/replicationsource_types.go` at v0.16.0, [restic usage](https://volsync.readthedocs.io/en/stable/usage/restic/index.html).

- **Q1.** `spec.sourcePVC`: one PVC by name, same namespace.
- **Q2.** `spec.trigger.schedule` (cron) or `spec.trigger.manual` (string handshake against `status.lastManualSync`), `spec.paused`. Tenant namespace throughout.
- **Q3.** `spec.restic.retain.{last,hourly,daily,weekly,monthly,yearly,within,withinHourly,...}`: restic forget passthrough, **keep-N + tiered + windows**. Plus `pruneIntervalDays`, `unlock`.
- **Q4.** No repository CRD: `spec.restic.repository` names a same-namespace Secret with raw restic env (`RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `AWS_*`). Fully tenant-owned, one repo per PVC.
- **Q5.** **None.** Consistency only via `copyMethod: Snapshot|Clone` (crash-consistent PiT).
- **Q6.** `copyMethod: Clone|Snapshot|Direct`; mover = which sibling of `spec.{rsync,rsyncTLS,rclone,restic,syncthing,external}` is set. **No kopia mover upstream** at v0.16.0 (fork only).
- **Q7.** Only `restic.exclude.caches`.
- **Q8.** `ReplicationDestination` with `destinationPVC`, `previous`, `restoreAsOf`; cross-namespace and cross-cluster natural. No hooks.
- **Q9.** `spec.external.{provider, parameters}`: a real engine-neutral seam for third-party movers.

## 5. snapscheduler (Backube)

Source: `backube/snapscheduler/api/v1/snapshotschedule_types.go`, [usage](https://backube.github.io/snapscheduler/usage.html).
`spec.claimSelector` (label selector over PVCs in the same namespace, the only engine whose primary selector is PVC labels); `spec.schedule` cron; `retention.expires` (duration, hours max) + `retention.maxCount`; CSI VolumeSnapshot only; no backend, no hooks, no paths; restore = `PVC.spec.dataSource`.

## 6. Distinct concepts from OADP, Trilio, WG Data Protection

- **OADP `DataProtectionApplication`**: an engine-installation CR (`backupLocations[]`, `snapshotLocations[]`, `configuration.velero.*`, `configuration.nodeAgent.uploaderType`). Concept worth keeping: **separate "which engine is installed and where it can write" from "what to back up"**. ([OADP docs](https://docs.redhat.com/en/documentation/openshift_container_platform/4.16/html/backup_and_restore/oadp-application-backup-and-restore))
- **Trilio**: `BackupPlan` as a named application definition decoupled from `Policy` (schedule + retention) `[unverified field names]`.
- **Kubernetes WG Data Protection**: the vendor-neutral app-level API proposal (kubernetes/enhancements#1051) never merged. What shipped is `VolumeGroupSnapshot` (KEP-3476), grouping PVCs by label selector for crash-consistent multi-volume snapshots. **There is no upstream engine-neutral backup policy API.** ([white paper](https://github.com/kubernetes/community/blob/main/wg-data-protection/data-protection-workflows-white-paper.md), [KEP-3476](https://github.com/kubernetes/enhancements/blob/master/keps/sig-storage/3476-volume-group-snapshot/README.md))

## 7. Comparison table

| | Velero | K8up | KubeStash | Kanister (+K10) | Longhorn | VolSync |
|---|---|---|---|---|---|---|
| **Unit / selection** | namespace + label selector + resource filters | namespace-wide PVCs, annotation opt-out, `labelSelectors` | one typed object by name | one named workload; K10 label selector | Longhorn Volume, **volume opts in** by label | one PVC by name |
| **Schedule / where** | cron, `velero` ns | cron + `@daily-random`, tenant ns | per-session cron, tenant ns | none / K10 tokens, `kasten-io` | cron, `longhorn-system` | cron or manual, tenant ns |
| **Retention** | TTL only | tiered keep-N | TTL + last + tiered (separate CR) | none / K10 tiered per action | keep-N (+ TTL) | keep-N + tiered + windows |
| **Repo/backend** | BSL in system ns | inline in tenant Schedule + secret refs | BackupStorage CR with `usagePolicy` | Profile CR (namespaced) | BackupTarget, cluster-wide | Secret in tenant ns |
| **Consistency** | pre/post exec hooks in pod | `backupcommand` exec, stdout streamed; no hooks | HookTemplate + DB addons (separate Job, streamed) | Blueprint phases, throwaway pod, streamed | **none** | **none** |
| **Modes** | CSI / cloud snapshot / FSB | filesystem restic (+ logical) | addon picks | Blueprint-defined | `spec.task` enum | `copyMethod` x mover |
| **Path include/exclude** | no | per-PVC annotation or job-wide env | yes (`params.paths/exclude`) | tool flags | no | caches only |
| **Restore** | Restore CR, ns mapping, hooks | Restore CR, folder/S3 | RestoreSession, other ns, hooks | ActionSet restore + artifacts | new Volume from Backup | ReplicationDestination |

## 8. Intersection vs uniqueness

**In all six:** cron schedule; retention attached to the schedule, at least keep-N; a target that resolves to PVCs; a status with last-backup time and phase.

**In most (4 to 5):** a repository as a separately referenced object with a credential Secret (all but VolSync and snapscheduler); tiered retention (K8up, KubeStash, K10, VolSync; **not Velero, not Longhorn**); pre/post hooks (Velero, K8up-partial, KubeStash, Kanister; **not Longhorn, VolSync, snapscheduler**); restore into another namespace/PVC; snapshot-vs-filesystem mode choice (not K8up, not snapscheduler).

**Unique to one engine (keep out of a shared schema):** multiple named sessions per policy (KubeStash); `usagePolicy: Same|Selector|All` sharing grants (KubeStash; worth adopting as a platform concept); inverted label-on-PVC opt-in with a default group (Longhorn); user-authored phase programs with artifact passing (Kanister); manual-trigger and unlock string handshakes (VolSync); backup window + staggering (K10); per-action retention (K10); filesystem-trim (Longhorn).

**Design implication.** The narrowest honest core: `{target} x cronSchedule x retention{keepLast, tiered?, ttl?} x repositoryRef x mode{snapshot|filesystem|logical} x hooks?[] x restore{targetOverride}`. Everything above that belongs behind an engine-specific escape hatch (VolSync's `spec.external.parameters` shape), not in the shared schema.
