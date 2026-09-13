# 02-policy-and-command — One Policy With an Executor Switch, One Command Contract

Status: Concluded

## Hypothesis

Two traits cover every backup a module can ask for. `backup` is the policy every engine implements, and one field on it, `executor: platform | module`, says who carries it out. `backup-command` is the one thing a module can hand the platform: a shell command that writes a consistent artefact to stdout with any quiesce inside it. With those two, one MariaDB module and one Minecraft module render on a k8up platform and on a Velero platform with no engine-specific arm: k8up consumes the command's stdout from a PreBackupPod that mounts the workload's volumes read-only beside it, Velero runs the same command as a pre-hook into a landing volume and captures only that volume, and under `executor: module` both adapters project the policy into a ConfigMap the module's own tool reads while k8up alone adds prune and check. The repository stays a platform name; volume scope rests on the per-volume PVC label (P1).

### Earlier cuts of this experiment

Three earlier cuts, since deleted, measured what this one replaces. The first split the engine-specific half into a `backup-command` contract with an inline S3 repository: a Velero platform refused it at demand resolution naming exactly that contract, and a k8up catalog carrying two transformers requiring two different provider contracts raised no over-subscription, so the exactly-one-provider rule counts catalogs, not transformers. The second added `backup-hooks` and gave the command two output arms: k8up refused hooks outright (it has no exec hook of any kind), and an output arm the engine lacked failed as an opaque transformer error naming neither contract nor field. The third replaced both with `backup-producer` and a catalog-fulfilled `backup-owned`, which rendered on both engines but named two runtime facts (who owns the capture) where an author thinks in offers (a command, or a tool they already run); its projection transformer also had to read `backup` without requiring it, or the declaring catalog became a second provider. `research/backup-trait-design.md`, addenda, records the reasoning.

## Setup

Seeded from experiment 01 and re-pathed to `testing.opmodel.dev/experiments/0015/exp02/`. Fixtures beyond 01:

| Path | Role | Copied from |
| --- | --- | --- |
| `catalog_opm/` | catalog_opm v4.0.1 with ONE edit, prerequisite P1: `transformers/pvc_transformer.cue` stamps `volume.opmodel.dev/name: <volume key>` on every PVC. Served by `--replace` on platform and consumer modules | cue cache `opmodel.dev/catalogs/opm@v4.0.1` |
| `contracts/traits/v1alpha1/backup.cue` | Policy: `schedule`, `retention` (+ `keepWithin`), `executor`, `repository` (platform name), `volumes`, advisory `method`, `excludes`, `maintenance`, and `projection.envKeys` for the module-executed case. Provider-fulfilled | `research/backup-traits-proposal.cue` |
| `contracts/traits/v1alpha1/backup_command.cue` | `container`, `command` (bare shell line, no single quotes), `volumes` to mount, `landing?: {volume, path}`, `fileExtension`, `compensate?`. Provider-fulfilled | authored |
| `contracts/projection/projection.cue` | The `executor: module` projection as a plain CUE function, defined once and called by both adapters: ConfigMap `<component>-backup-config` with `RESTIC_REPOSITORY`, `RESTIC_HOSTNAME` (the namespace), schedule, `restic forget` flags and excludes under the module's keys. Not a transformer, so the declaring catalog provides nothing | authored |
| `contracts/config/repositories.cue` | ONE stand-in platform table (OQ2): name to s3 backend, Secret name, Velero storage location. Imported by both providers | authored |
| `k8up/transformers/backup_schedule_transformer.cue` | Three modes: `executor: module` -> projection plus prune and check only; a `backup-command` sibling -> the PreBackupPod stream only; otherwise -> PVCs by P1 label or all. Excludes as a ConfigMap through `backend.envFrom`; `keepWithin` -> `keepHourly` | 01 |
| `k8up/transformers/pre_backup_pod_transformer.cue` | PreBackupPod from the named container, `volumes` mounted read-only from the PVC names the base catalog renders, pod affinity to the workload on `kubernetes.io/hostname`, `sh -c` wrapping | authored; shape from the Schedule transformer |
| `velero/transformers/backup_schedule_transformer.cue` | Command -> pre-hook `command > <mount>/<path>`, scope = the landing volume, compensate as a `Continue` post hook; `executor: module` -> the projection only; plus the volume policy | 01 |
| `webapp/`, `mariadb/`, `minecraft/` (+ `values/command.cue`) | Policy only; policy + command (one module, no arms); policy with `executor: module` and the itzg sidecar declared by the module, or policy + command with `-f` | 01, authored |

Modifications forced during the run: `#context.componentLabels` is closed (label maps by comprehension); a sidecar mount cannot unify `readOnly: true` onto the volume declared `readOnly: false` (restated instead); `check.py` needs PyYAML for the Velero policy ConfigMap.

## Run

```bash
bash run.sh
```

Seven cases, 16 rows. Scratch trees under `_out/<case>/`.

| Case | Platform | Consumer | Expected |
| --- | --- | --- | --- |
| P1 | (B's output) | | both PVCs labelled with their volume key |
| A | k8up | webapp | backend `mc-backup/web-demo` from the repository name, excludes ConfigMap via `envFrom`, selector == component labels |
| B | k8up | mariadb | PreBackupPod streams the dump over the service name, no mounts (no command volumes); Schedule selects only the command pod; Sunday window |
| C | Velero | **same mariadb** | pre-hook `mariadb-dump ... > /dumps/app.sql` in the live container; policy ConfigMap skips `data` by P1 label and matches it, not `dumps`; `ttl: 4464h` |
| D | k8up | minecraft, command | PreBackupPod mounts `mc-demo-server-data` read-only at `/data`, pod affinity to the workload, `fileExtension: -mc-demo-server.tar`, the quiesce-tar-release sequence as one command; `keepHourly: 480` |
| E | Velero | **same minecraft, command** | pre-hook = the sequence `> /backups/world.tar`, post `save-on` with `Continue` (compensate), policy skips `data`, `ttl: 480h` |
| F | k8up | minecraft, `executor: module` | projection ConfigMap under the itzg keys; Schedule with **no `backup` section**, prune + check against `mc-backup/mc-demo`; sidecar reads the ConfigMap and the repository Secret by name; no PreBackupPod |
| G | Velero | **same minecraft, `executor: module`** | projection only; no Schedule, no policy; no warning |

## Outcome

`run.sh` last run 2026-09-13: **16 passed, 0 failed**. `cue v0.17.1`, `opm v1.0.0-alpha.19-11-g7ae324f` (cli `7f11993`), core `v2.0.0-alpha.7`, catalog_opm `v4.0.1` + P1.

**Case D, the world command on k8up** (labels elided):

```yaml
apiVersion: k8up.io/v1
kind: PreBackupPod
metadata: {name: mc-demo-server-command, namespace: demo}
spec:
  backupCommand: sh -c 'rcon-cli --host mc-demo-server save-off && rcon-cli --host mc-demo-server save-all flush && sync && tar -C /data --exclude=*.jar --exclude=cache --exclude=logs -c . ; s=$?; rcon-cli --host mc-demo-server save-on; exit $s'
  fileExtension: -mc-demo-server.tar
  pod:
    spec:
      restartPolicy: Never
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - {labelSelector: <component labels>, topologyKey: kubernetes.io/hostname}
      containers:
        - name: minecraft
          image: docker.io/itzg/minecraft-server:java25
          command: [sleep, infinity]
          env: [{name: EULA, value: "TRUE"}]
          volumeMounts: [{name: data, mountPath: /data, readOnly: true}]
      volumes:
        - {name: data, persistentVolumeClaim: {claimName: mc-demo-server-data, readOnly: true}}
```

The same module on Velero (case E) is the same command as a pre-hook with `> /backups/world.tar` appended, `save-on` as a post hook that always runs, and a policy that skips `data`. No arm, no engine-specific field in the module.

**Case F, `executor: module` on k8up:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata: {name: mc-demo-server-backup-config, namespace: demo}
data:
  RESTIC_REPOSITORY: s3:http://10.10.0.2:30304/mc-backup/mc-demo
  RESTIC_HOSTNAME: demo
  CRON_SCHEDULE: "0 * * * *"
  PRUNE_RESTIC_RETENTION: --keep-within 20d
  EXCLUDES: "*.jar,cache,logs,*.tmp,bluemap/web/maps/**"
---
apiVersion: k8up.io/v1
kind: Schedule
metadata: {name: mc-demo-server, namespace: demo}
spec:
  backend: {s3: {endpoint: http://10.10.0.2:30304, bucket: mc-backup/mc-demo, ...}, repoPasswordSecretRef: {name: mc-backup-restic, key: RESTIC_PASSWORD}}
  prune: {schedule: "@daily-random", retention: {keepHourly: 480}}
  check: {schedule: "@weekly-random"}
```

The sidecar the module declares reads the ConfigMap and the Secret `mc-backup-restic` through `envFrom`; k8up never takes a backup of this component, it prunes and checks the repository the sidecar writes, which `RESTIC_HOSTNAME: demo` makes visible to k8up's `forget --host`. On Velero (case G) only the ConfigMap renders, with no warning.

### Findings beyond the claims

- **A value-level switch is fine when the wrong reading is keep-more.** `executor` cannot be refused by contract name. An adapter that ignored `module` would take an extra crash-consistent copy on top of the module's own: wasteful, never lossy. The same test that makes `method`, `excludes` and `maintenance` advisory. A value whose wrong reading could lose data would still need a contract.
- **A shared projection is a function, not a transformer.** Defined once in the declaring catalog (`contracts/projection`) and emitted by each provider adapter. The previous cut's transformer had to read `backup` without requiring it to avoid becoming a second provider; a function has no such problem and the declaring catalog ships no transformer at all, as 0010 D37 intends.
- **`error()` in a transformer refuses the whole platform.** An earlier cut used an `error()` fallback for a container-name check; it fired at platform build, where a definition is evaluated once with no component, and refused every platform carrying the catalog. Validation inside a transformer is a unification, never a bottom (the `_nameOK` field in the PreBackupPod transformer).
- **`#context.componentLabels` is closed.** `componentLabels & {extra: v}` is `field not allowed`, surfaced only as an opaque transformer error at render. Label maps are built by comprehension.
- **Projection-only output is refusal by silence.** Velero under `executor: module` renders one ConfigMap, exits 0, and the kernel reports nothing about the missing Schedule. Correct here, indistinguishable from a forgotten render. Worth a warning-class diagnostic in the successor entry.
- **Same-node RWO mounting is rendered, not proven.** Case D pins the command pod beside the workload the way k8up's own folder backup does. A live k8up on LINSTOR has to confirm the second mount.
- **The command's cost is real and unmeasured here.** A world tar goes through `pods/exec` every hour on k8up and into a landing PVC as large as the world on Velero. `executor: module` exists because of that; the design doc addendum carries the numbers.
- **Credentials are a naming convention.** The projection cannot copy a Secret. The module's sidecar references the platform's repository Secret by the name the table declares, which couples the module to a platform convention.

### What this discharges in the design

One module per application renders on both engines through the shipped kernel with no engine-specific arm, under two contracts and one switch: the policy (provider-fulfilled, both engines, `executor` deciding who captures) and the command (provider-fulfilled, both engines). The only refusal by contract name left is `backup-command` on an engine with neither streams nor hooks; everything else renders or renders less in the keep-more direction. What remains: provider configuration (OQ2, one shared stand-in table) and tenancy for admin-scoped engines (P2).

**Hypothesis held.**
