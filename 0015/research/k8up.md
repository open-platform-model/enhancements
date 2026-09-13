# K8up v2.16.0: field-level reference for an engine-neutral backup abstraction

Gathered 2026-09-12 by a research agent from a clone verified at tag `v2.16.0` (commit `343b99d1519385d75738dbb07d6ff45785c3f186`). Line refs are that tag. Input to `backup-trait-design.md`. Snapshot, not canon.

---

## 1. CRDs

API group/version: `k8up.io/v1`. Kinds: **Schedule, Backup, Check, Prune, Archive, Restore, PreBackupPod, PodConfig, Snapshot** (all namespaced). Source: `api/v1/*_types.go`.

**ScheduleSpec** ([schedule_types.go#L14-L45](https://github.com/k8up-io/k8up/blob/v2.16.0/api/v1/schedule_types.go#L14-L45)): `restore`, `backup`, `archive`, `check`, `prune` (each = the corresponding `*Spec` inlined **plus** `ScheduleCommon{schedule, concurrentRunsAllowed}`), `backend`, `keepJobs` (deprecated), `failedJobsHistoryLimit`, `successfulJobsHistoryLimit`, `resourceRequirementsTemplate`, `podSecurityContext`, `podConfigRef` (name only, same namespace).
`activeDeadlineSeconds` is not a Schedule-level field; it lives in `RunnableSpec`, per job type.

**RunnableSpec** (inlined into backup/check/prune/restore/archive, [runnable_types.go#L7-L30](https://github.com/k8up-io/k8up/blob/v2.16.0/api/v1/runnable_types.go#L7-L30)): `backend`, `resources`, `podSecurityContext`, `podConfigRef`, `volumes`, `activeDeadlineSeconds`.

**BackupSpec** ([backup_types.go#L16-L53](https://github.com/k8up-io/k8up/blob/v2.16.0/api/v1/backup_types.go#L16-L53)): RunnableSpec + `keepJobs`, `failedJobsHistoryLimit`, `successfulJobsHistoryLimit`, `promURL`, `clusterName`, `statsURL`, `tags []string`, `labelSelectors []metav1.LabelSelector`.

**PruneSpec.retention** (`RetentionPolicy`, [prune_types.go#L35-L48](https://github.com/k8up-io/k8up/blob/v2.16.0/api/v1/prune_types.go#L35-L48)): `keepLast`, `keepHourly`, `keepDaily`, `keepWeekly`, `keepMonthly`, `keepYearly`, `keepTags []string`, `tags []string` (filter), `hostnames []string`.
- `hostnames` is dead: only in deepcopy, never read by `prunecontroller/executor.go`.
- `keepTags` is very likely broken: the operator sets `KEEP_TAGS=<comma-joined>` but the restic-side flag is a **BoolFlag** `--keepTags` with `EnvVars: [KEEP_TAG, KEEP_TAGS]` (`cmd/restic/main.go`); urfave/cli parses the env with `strconv.ParseBool`, so a non-boolean value should fail the prune container. Not verified live; suspected bug.

**CheckSpec** (`api/v1/check_types.go#L13-L37`): RunnableSpec + `promURL`, `clusterName`, history limits. No `statsURL`.
**ArchiveSpec** = `*RestoreSpec` inline.
**PreBackupPodSpec** ([prebackuppod_types.go#L8-L16](https://github.com/k8up-io/k8up/blob/v2.16.0/api/v1/prebackuppod_types.go#L8-L16)): `backupCommand string`, `fileExtension string`, `pod` (required, a `corev1.PodTemplateSpec`).
**PodConfigSpec** (`api/v1/podconfig_types.go`): `template` (`corev1.PodTemplateSpec`). Added in v2.10.0 (commit `dd9f657f`, 2024-05-13).
**SnapshotSpec** (`api/v1/snapshot_types.go`): `id`, `date`, `paths`, `repository`; synced from the backup job.

**Cron tokens**: `@yearly|@annually|@monthly|@weekly|@daily|@midnight|@hourly|@every <dur>` (robfig cron) plus K8up randoms `@hourly-random`, `@daily-random`, `@weekly-random`, `@monthly-random`, `@yearly-random`, `@annually-random` ([randomizer.go#L12-L54](https://github.com/k8up-io/k8up/blob/v2.16.0/operator/schedulecontroller/randomizer.go#L12-L54)). Seed = `namespace/name@jobType` -> SHA1 -> deterministic minute/hour/dom (dom capped to 27, weekday mod 6, so **Saturday is never picked**). Result persisted in `status.effectiveSchedules[]`.
`BACKUP_CHECKSCHEDULE` (default `0 0 * * 0`) exists in config but is **never read** in v2.16.0: no implicit check schedule. An abstraction must render `spec.check` explicitly.

PodConfig merge (`operator/job/job.go#L69-L102`): `mergo.Merge(..., WithOverride)` of `podConfig.spec.template.spec` over the generated pod spec; container[0] `name`/`image`/`command` force-overridden afterwards.

---

## 2. Backends and credentials

`Backend` ([backend.go#L17-L34](https://github.com/k8up-io/k8up/blob/v2.16.0/api/v1/backend.go#L17-L34)): `repoPasswordSecretRef` (SecretKeySelector), `envFrom []corev1.EnvFromSource`, `local`, `s3`, `gcs`, `azure`, `swift`, `b2`, `rest`, `tlsOptions{caCert,clientCert,clientKey}`, `volumeMounts`.

| backend | fields | repo string | env vars injected |
|---|---|---|---|
| `local` | `mountPath` | `<mountPath>` | none |
| `s3` | `endpoint`, `bucket`, `accessKeyIDSecretRef`, `secretAccessKeySecretRef` | `s3:<endpoint>/<bucket>` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |
| `gcs` | `bucket`, `projectIDSecretRef`, `accessTokenSecretRef` | `gs:<bucket>:/` | `GOOGLE_PROJECT_ID`, `GOOGLE_ACCESS_TOKEN` |
| `azure` | `container`, `path`, `accountNameSecretRef`, `accountKeySecretRef` | `azure:<container>:<path|/>` | `AZURE_ACCOUNT_NAME`, `AZURE_ACCOUNT_KEY` |
| `swift` | `container`, `path` | `swift:<container>:<path>` | none (use `envFrom`) |
| `b2` | `bucket`, `path`, `accountIDSecretRef`, `accountKeySecretRef` | `b2:<bucket>:<path>` | `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY` |
| `rest` | `url`, `userSecretRef`, `passwordSecretReg` *(sic)* | `rest:<proto>://$(USER):$(PASSWORD)@<host/path>` | `USER`, `PASSWORD` |

Password: `repoPasswordSecretRef` -> `RESTIC_PASSWORD`. Only **one** backend struct may be set; `getSupportedBackends()` returns the **first non-nil, alphabetical** (`backend.go#L82-L84`), a silent surprise if two are set. The S3 `bucket` field takes `bucket/prefix`: restic treats the remainder as a path (the northbyte fleet relies on this; upstream issues [#615](https://github.com/k8up-io/k8up/issues/615)/[#1064](https://github.com/k8up-io/k8up/issues/1064) ask for a first-class prefix).

**Operator-global env fallbacks** (`cmd/operator/main.go#L54-L78`): `BACKUP_GLOBALS3ENDPOINT`, `BACKUP_GLOBALS3BUCKET`, `BACKUP_GLOBALACCESSKEYID`, `BACKUP_GLOBALSECRETACCESSKEY`, `BACKUP_GLOBALREPOPASSWORD`, `BACKUP_GLOBALSTATSURL`, `BACKUP_PROMURL` (default `http://127.0.0.1/`), `CLUSTER_NAME`, plus `BACKUP_GLOBALRESTORES3*`.

**Precedence:** per-CR wins. `DefaultEnv(namespace)` (`operator/executor/envvarconverter.go#L93-L109`) sets `RESTIC_REPOSITORY=s3:$GLOBALS3ENDPOINT/$GLOBALS3BUCKET`, `RESTIC_PASSWORD`, AWS keys, `HOSTNAME=<namespace>`; merged second, filling only missing entries. `GetGlobalRepository()` used only when `spec.backend == nil`. Partial fallback: `S3Spec.String()` substitutes global endpoint/bucket for empty fields.

**Cross-namespace secrets: no.** All `*SecretRef` are `corev1.SecretKeySelector` rendered as `valueFrom.secretKeyRef` on a Job in the CR's namespace.

---

## 3. PVC / pod selection semantics

`listAndFilterPVCs` ([executor.go#L61-L180](https://github.com/k8up-io/k8up/blob/v2.16.0/operator/backupcontroller/executor.go#L61-L180)):

1. `fetchPVCs` lists PVCs in the namespace; with `spec.backup.labelSelectors` set, once per selector, results unioned (OR across selectors) ([backup_utils.go#L22-L58](https://github.com/k8up-io/k8up/blob/v2.16.0/operator/backupcontroller/backup_utils.go#L22-L58)).
2. Skip if not `Bound`.
3. Skip if neither RWX nor RWO and no `k8up.io/backup` annotation.
4. No annotation -> included, unless `BACKUP_SKIP_WITHOUT_ANNOTATION=true` (default false). Annotation parsed with `strconv.ParseBool`; falsy -> skipped.
5. Per-PVC `k8up.io/backup-restic-args` (JSON array) appends restic args; PVCs with different args land in different Jobs.
6. Node pinning from running non-k8up pods mounting the PVC (`nodeSelector: kubernetes.io/hostname`) when RWO or relaxed scheduling off; unmounted RWO PVCs read `pv.spec.nodeAffinity` (`findNode`); override via PVC annotation `k8up.io/hostname`. **Unmounted PVCs are still backed up.**
7. Classic scheduling groups PVCs per node into one Job; `BACKUP_ENABLE_RELAXED_SCHEDULING=true` makes one Job per PVC.

**Backupcommand pods**: the operator computes viable pods (`executor.go#L258-L266`), intersects with `fetchCandidatePods` (label-selector aware; always also matches `k8up.io/ownerBackupUID=<uid>` so PreBackupPod-spawned pods are included, [backup_utils.go#L60-L107](https://github.com/k8up-io/k8up/blob/v2.16.0/operator/backupcontroller/backup_utils.go#L60-L107)), then creates **one extra Job `...-prebackup`** with `TARGET_PODS=<comma list>`. PVC jobs get `SKIP_PREBACKUP=true`; later jobs get `SLEEP_DURATION=<index*10s>`.

**`ListPods`** ([pod_list.go#L54-L120](https://github.com/k8up-io/k8up/blob/v2.16.0/restic/kubernetes/pod_list.go#L54-L120)): nil when `SKIP_PREBACKUP`; lists all pods in the namespace; skips non-Running; skips pods not in `TARGET_PODS` when non-empty; requires `k8up.io/backupcommand`; **deduplicates by first ownerReference UID** (one replica per workload); container defaults to `containers[0]`, overridden by `k8up.io/backupcommand-container`.

So in v2.16.0 `labelSelectors` DO scope backupcommand pods (via TARGET_PODS). With no selectors, every annotated pod in the namespace is swept.

---

## 4. Application-aware backups

Annotations (`cmd/operator/main.go#L39-L42`): `k8up.io/backup`, `k8up.io/backupcommand`, `k8up.io/file-extension` (**no default; empty if unset**), `k8up.io/backupcommand-container`, `k8up.io/backup-restic-args`, `k8up.io/hostname`.

Execution ([pod_exec.go#L26-L100](https://github.com/k8up-io/k8up/blob/v2.16.0/restic/kubernetes/pod_exec.go#L26-L100)): **no shell is added**. The annotation string is split quote-aware (`qsplit`) and passed as `PodExecOptions.Command`, stdout captured, over WebSocket. Shell expansion needs an explicit `sh -c '...'`. Any stream error hard-fails the whole backup pod.

Storage (`cmd/restic/main.go` `backupAnnotatedPod`): `restic backup --host <namespace> --stdin --stdin-filename /<namespace>-<container><fileExtension>` ([stdinbackup.go#L11-L35](https://github.com/k8up-io/k8up/blob/v2.16.0/restic/cli/stdinbackup.go#L11-L35)). Two workloads whose backup container has the same name collide: upstream [#1068](https://github.com/k8up-io/k8up/issues/1068).

**Ordering**: `backupAnnotatedPods` runs first, then folder backup, *within one job*; in practice the `prebackup` job and PVC jobs are separate Jobs and run **concurrently**. No ordering guarantee between a dump and a folder backup.

**PreBackupPod lifecycle**: `StartPreBackup` runs before PVC listing; each PreBackupPod becomes a **Deployment** (replicas 1, ownerRef = Backup) with pod annotations `{backupcommand, file-extension}` and labels `k8up.io/backupCommandPod=true`, `k8up.io/preBackupPod=<name>`, `k8up.io/ownerBackupUID=<uid>` ([prebackup_utils.go#L66-L110](https://github.com/k8up-io/k8up/blob/v2.16.0/operator/backupcontroller/prebackup_utils.go#L66-L110)). The Backup blocks until `availableReplicas > 0`. Deletion: `StopPreBackupDeployments` after the Backup finishes, `PropagationPolicy: Foreground`. It deletes the Deployment, so pods terminate normally and a container `preStop` **would** run, but with no ordering guarantee against other jobs and up to ~30s reconcile lag. Not a post-backup hook.
**PreBackupPods are label-selected** by `spec.backup.labelSelectors` applied to the PreBackupPod CR's own labels ([prebackup_utils.go#L26-L64](https://github.com/k8up-io/k8up/blob/v2.16.0/operator/backupcontroller/prebackup_utils.go#L26-L64)).
`spec.pod.metadata.annotations` on a PreBackupPod is **ignored** (overwritten wholesale): [#1108](https://github.com/k8up-io/k8up/issues/1108).

---

## 5. Quiesce/unquiesce hooks

**None.** The only exec into an application pod is the `backupcommand` stdout dump (`pod_exec.go` is the sole `pods/exec` caller). No pre-hook, no post-hook, no freeze/thaw. Open upstream requests: [#886 "Post-Backup-Action"](https://github.com/k8up-io/k8up/issues/886) (open since 2023-09-15), [#585 "v3: replace PreBackupPod"](https://github.com/k8up-io/k8up/issues/585). Application consistency must come from inside the backupcommand or from an external controller.

---

## 6. Per-path include/exclude for folder backups

No CRD field. Two indirect mechanisms:
- Per-PVC annotation `k8up.io/backup-restic-args` (JSON array) appended to the restic-wrapper args; the wrapper accepts `--exclude`, `--exclude-file`, `--exclude-if-present`, `--iexclude`, `--excludeCaches`, `--excludeLargerThan`, `--filesFrom*`, `--oneFileSystem` (applied in `restic/cli/backup.go` `mixinBackupFlags`). PVCs with differing args split into separate Jobs.
- Env vars `RESTIC_EXCLUDE`, `RESTIC_EXCLUDE_FILE`, `RESTIC_EXCLUDE_IF_PRESENT`, `RESTIC_IEXCLUDE`, `RESTIC_EXCLUDE_CACHES`, `RESTIC_EXCLUDE_LARGER_THAT` *(sic)*, `RESTIC_ONE_FILESYSTEM`, injected job-wide via `spec.backend.envFrom`. Apply to every folder in the job.

Both are per-PVC annotation or job-wide env, so an adapter that cannot annotate PVCs can only do job-wide excludes.

---

## 7. restic layout, forget, locking

- Hostname: `HOSTNAME=<namespace>`, passed as `--host` on every backup.
- Folder backups: PVCs mounted read-only at `/data/<pvcName>`; one `restic backup --host <ns> /data/<pvc>` per directory. Snapshot `paths[0] = /data/<pvcname>`.
- **forget**: `restic forget --prune --keep-* ... --host=<namespace> [--tag ...]` ([prune.go#L11-L72](https://github.com/k8up-io/k8up/blob/v2.16.0/restic/cli/prune.go#L11-L72)). **No `--group-by`**, so restic's default `host,paths` applies: retention counts are **per PVC path per namespace**, and every stdin snapshot path is its own group. If `keepDaily` is unset the operator forces `KEEP_DAILY=14` (`prunecontroller/executor.go#L110-L113`).
- **Locking is two-layered.** In-operator: `locker.GetForRepository(repository)` keyed on the repository string, process-local. Prune, Check and Restore run **exclusively** (`k8upjob/exclusive=true`); Backup refuses to start while an exclusive job has active pods. In-container: `restic unlock` at start; prune/check `Wait()` until lock-free.
- Concurrency env names: `BACKUP_GLOBAL_CONCURRENT_BACKUP_JOBS_LIMIT`, `..._ARCHIVE_...`, `..._CHECK_...`, `..._PRUNE_...`, `..._RESTORE_JOBS_LIMIT` (default 0 = unlimited).
- **Two Schedules in different namespaces sharing one repo**: the locker serialises them if the backend strings are byte-identical; each namespace writes under its own `--host`, so `forget --host=<ns>` keeps retention isolated. Risks: concurrent `restic init` on a fresh repo, the blanket `restic unlock` at every job start, and a shared repo password.

---

## 8. Restore

`RestoreSpec` ([restore_types.go#L13-L55](https://github.com/k8up-io/k8up/blob/v2.16.0/api/v1/restore_types.go#L13-L55)): RunnableSpec + `restoreMethod{s3|folder{claimName,readOnly}}`, `restoreFilter`, `restoreTimeFilter`, `snapshot` (empty = latest), `tags`, `paths`, `delete`, history limits. The folder PVC mounts at `/restore`. Always `k8upjob/exclusive=true`.
Stdin snapshots restore as `/restore/<namespace>-<container><ext>` (folder method) or a tar-wrapped object (S3 method). Re-importing into the application is out of scope: no `restorecommand` ([#637](https://github.com/k8up-io/k8up/issues/637)).

---

## 9. Metrics

**Operator `/metrics`** (`:8080`): `k8up_jobs_total`, `k8up_jobs_successful_counter`, `k8up_jobs_failed_counter` (labels `namespace`, `jobType`), `k8up_schedules_gauge`, `k8up_schedule_last_job_succeeded`.
**Pushgateway** (`restic/stats/handler.go`): `k8up_backup_restic_*` (`new_files_during_backup`, `changed_files_...`, `data_transferred_during_backup`, `available_snapshots`, `last_errors`, ...), grouping `instance=<namespace>`, `cluster=<clusterName>`. `PROM_URL` <- `spec.*.promURL` else `BACKUP_PROMURL` (default `http://127.0.0.1/`, so pushes are attempted and fail by default). `statsURL` -> HTTP POST of JSON after each action; Backup/Restore only.

---

## 10. Multi-tenancy

Everything tenants touch is namespaced. Cluster-scoped: the operator Deployment and its env, the CRDs, ClusterRole `k8up-executor`. Per namespace the executor auto-creates ServiceAccount `pod-executor` and a RoleBinding to `k8up-executor` (`backup_utils.go#L128-L160`): K8up grants pod-exec in every namespace it backs up. The scheduler is a single in-process cron. No cluster-wide Schedule kind ([#1085](https://github.com/k8up-io/k8up/issues/1085), [#1247](https://github.com/k8up-io/k8up/issues/1247), [#382](https://github.com/k8up-io/k8up/issues/382)).

---

## 11. Known limitations (open upstream issues)

- [#886](https://github.com/k8up-io/k8up/issues/886) no post-backup hook. [#585](https://github.com/k8up-io/k8up/issues/585) replace PreBackupPod. [#323](https://github.com/k8up-io/k8up/issues/323) no PreBackupPod metrics. [#1108](https://github.com/k8up-io/k8up/issues/1108) PreBackupPod pod annotations ignored. [#862](https://github.com/k8up-io/k8up/issues/862) prebackup pod labels too long.
- [#1068](https://github.com/k8up-io/k8up/issues/1068) app-aware snapshots indistinguishable.
- RWO/node affinity: [#805](https://github.com/k8up-io/k8up/issues/805), [#883](https://github.com/k8up-io/k8up/issues/883), [#1182](https://github.com/k8up-io/k8up/issues/1182).
- [#550](https://github.com/k8up-io/k8up/issues/550) opt-in PVC backup.
- [#792](https://github.com/k8up-io/k8up/issues/792) extra restic flags; [#615](https://github.com/k8up-io/k8up/issues/615)/[#1064](https://github.com/k8up-io/k8up/issues/1064) no first-class S3 prefix; [#580](https://github.com/k8up-io/k8up/issues/580) no reusable repository object; [#828](https://github.com/k8up-io/k8up/issues/828) endpoint/bucket cannot come from a Secret.
- [#581](https://github.com/k8up-io/k8up/issues/581) internal scheduler (schedules live in operator memory).

**Design implications:** model `repository` (backend + password secret, per namespace), `selection` (labelSelectors; per-PVC opt-out and backupcommand are annotations the adapter cannot set), `retention` (maps to `prune.retention`; grouping is per host+path; `keepDaily` silently defaults to 14), and per-job-type schedules; do not expose `retention.hostnames` or `keepTags`; emit an explicit `check` schedule.
