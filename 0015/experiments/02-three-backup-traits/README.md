# 02-three-backup-traits — Policy, Producer, Owned: One Module Per Application on Both Engines

Status: Concluded

## Hypothesis

Stop asking the engine to quiesce. With three contracts, `backup` (policy), `backup-producer` (a command that PRODUCES a consistent artefact with any quiesce inside it) and `backup-owned` (the module captures with its own tool and the platform projects the policy into it), one MariaDB module and one Minecraft module render on a k8up platform and on a Velero platform without a per-engine arm: k8up consumes the producer's stdout from a PreBackupPod that mounts the workload's volumes read-only beside it, Velero runs the same command as a pre-hook into a landing volume and captures only that volume, and for an owned backup the declaring catalog projects the policy on both platforms while k8up alone adds prune and check for the module's restic repository. Repository stays a platform name, volume scope stays on the P1 label.

### Earlier cuts of this experiment

Two earlier cuts, since deleted, measured what this one replaces. The first split the engine-specific half into a `backup-command` contract (stdout dump, inline S3 repository) beside `backup`: a Velero platform refused it at demand resolution naming exactly that contract, and a k8up catalog carrying two transformers requiring two different provider contracts raised no over-subscription, so the exactly-one-provider rule counts catalogs, not transformers. The second added `backup-hooks` and gave `backup-command` two output arms: k8up refused hooks outright (it has no exec hook of any kind), and an output arm the engine lacked failed as an opaque transformer error naming neither contract nor field. Both pointed the same way: the engine is the wrong owner of the quiesce. `research/backup-trait-design.md`, addendum, records the reasoning; this README records the replacement.

## Setup

Seeded from experiment 01 and re-pathed to `testing.opmodel.dev/experiments/0015/exp02/`. Fixtures beyond 01:

| Path | Role | Copied from |
| --- | --- | --- |
| `catalog_opm/` | catalog_opm v4.0.1 with ONE edit, prerequisite P1: `transformers/pvc_transformer.cue` stamps `volume.opmodel.dev/name: <volume key>` on every PVC. Served by `--replace` on platform and consumer modules | cue cache `opmodel.dev/catalogs/opm@v4.0.1` |
| `contracts/traits/v1alpha1/backup.cue` | Policy: `schedule`, `retention` (+ `keepWithin`), `repository` (platform name), `volumes`, advisory `capture`, `excludes`, `maintenance` | `research/backup-traits-proposal.cue` |
| `contracts/traits/v1alpha1/backup_producer.cue` | `container`, `command` (bare shell line, no single quotes), `volumes` to mount, `landing?: {volume, path}`, `fileExtension`, `compensate?`. Provider-fulfilled | authored |
| `contracts/traits/v1alpha1/backup_owned.cue` | `format: "restic"`, `envKeys` (the module's tool's own env names). **Catalog-fulfilled** | authored |
| `contracts/transformers/backup_config_transformer.cue` | The projection: ConfigMap `<component>-backup-config` with `RESTIC_REPOSITORY`, `RESTIC_HOSTNAME` (the namespace), schedule, `restic forget` flags and excludes under the module's keys. Requires only `backup-owned`; reads `backup` without requiring it | authored; shape from 01's transformers |
| `contracts/config/repositories.cue` | ONE stand-in platform table (OQ2): name to s3 backend, Secret name, Velero storage location. Imported by the projection and both providers | authored |
| `k8up/transformers/backup_schedule_transformer.cue` | Three modes by sibling contract: owned -> prune + check only; producer -> the PreBackupPod stream only; neither -> PVCs by P1 label or all | 01 |
| `k8up/transformers/pre_backup_pod_transformer.cue` | PreBackupPod from the named container, `volumes` mounted read-only from the PVC names the base catalog renders, pod affinity to the workload on `kubernetes.io/hostname`, `sh -c` wrapping | authored; shape from the Schedule transformer |
| `velero/transformers/backup_schedule_transformer.cue` | Producer -> pre-hook `command > <mount>/<path>`, scope = the landing volume, compensate as a `Continue` post hook; owned -> empty output; plus the volume policy | 01 |
| `webapp/`, `mariadb/`, `minecraft/` (+ `values/producer.cue`) | Policy only; policy + producer (one module, no arms); policy + owned by default with the itzg sidecar declared by the module, or policy + producer with `-f` | 01, authored |

Modifications forced during the run: a sidecar mount cannot unify `readOnly: true` onto the volume declared `readOnly: false` (restated instead); `check.py` needs PyYAML for the Velero policy ConfigMap.

## Run

```bash
bash run.sh
```

Seven cases, 16 rows. Scratch trees under `_out/<case>/`.

| Case | Platform | Consumer | Expected |
| --- | --- | --- | --- |
| P1 | (B's output) | | both PVCs labelled with their volume key |
| A | k8up | webapp | backend `mc-backup/web-demo` from the repository name, excludes ConfigMap via `envFrom`, selector == component labels |
| B | k8up | mariadb | PreBackupPod streams the dump over the service name, no mounts (no producer volumes); Schedule selects only the producer; Sunday window |
| C | Velero | **same mariadb** | pre-hook `mariadb-dump ... > /dumps/app.sql` in the live container; policy ConfigMap skips `data` by P1 label and matches it, not `dumps`; `ttl: 4464h` |
| D | k8up | minecraft producer | PreBackupPod mounts `mc-demo-server-data` read-only at `/data`, pod affinity to the workload, `fileExtension: -mc-demo-server.tar`, the quiesce-tar-release sequence as one command; `keepHourly: 480` |
| E | Velero | **same minecraft producer** | pre-hook = the sequence `> /backups/world.tar`, post `save-on` with `Continue` (compensate), policy skips `data`, `ttl: 480h` |
| F | k8up | minecraft owned | projection ConfigMap under the itzg keys; Schedule with **no `backup` section**, prune + check against `mc-backup/mc-demo`; sidecar reads the ConfigMap and the repository Secret by name; no PreBackupPod |
| G | Velero | **same minecraft owned** | projection only; no Schedule, no policy; no "unhandled trait" warning for the empty output |

## Outcome

`run.sh` last run 2026-09-12: **16 passed, 0 failed**. `cue v0.17.1`, `opm v1.0.0-alpha.19-11-g7ae324f` (cli `7f11993`), core `v2.0.0-alpha.7`, catalog_opm `v4.0.1` + P1.

**Case D, the world producer on k8up** (labels elided):

```yaml
apiVersion: k8up.io/v1
kind: PreBackupPod
metadata: {name: mc-demo-server-producer, namespace: demo}
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

**Case F, the owned world on k8up:**

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

The sidecar the module declares reads the ConfigMap and the Secret `mc-backup-restic` through `envFrom`; k8up never takes a backup of this component, it prunes and checks the repository the sidecar writes, which `RESTIC_HOSTNAME: demo` makes visible to k8up's `forget --host`. On Velero (case G) only the ConfigMap renders, with no warning: an empty transformer output is legal and silent.

### Findings beyond the claims

- **`error()` in a transformer refuses the whole platform.** An earlier cut used an `error()` fallback for a container-name check; it fired at platform build, where a definition is evaluated once with no component, and refused every platform carrying the catalog. Validation inside a transformer is a unification, never a bottom (the `_nameOK` field in the PreBackupPod transformer).
- **`#context.componentLabels` is closed.** `componentLabels & {extra: v}` is `field not allowed`, surfaced only as an opaque transformer error at render. Label maps are built by comprehension.
- **The declaring catalog may not require a provider contract.** The projection transformer first required `backup` to read schedule and retention; that made the contracts catalog a second provider of `backup` under the exactly-one-provider rule. It now requires only the catalog-fulfilled `backup-owned` and reads `backup` off the component unrequired. Matching is subset containment, so this is legal; it is also the first transformer in these experiments that depends on a field it does not declare, which a catalog linter would flag.
- **Empty output is a valid refusal-by-silence.** Velero on an owned backup renders `[]`, exits 0, and the kernel reports nothing. Honest for this case (the module backs itself up; Velero has nothing to add) but indistinguishable from a transformer that forgot to render. Worth a warning-class diagnostic in the successor entry.
- **Same-node mounting is asserted, not proven.** Case D pins the producer beside the workload so an RWO PVC can be mounted a second time on the same node. That is what k8up's own folder backup does, and most CSI drivers (LINSTOR included) allow it, but this experiment renders it; a live k8up must confirm it.
- **The producer's cost is real and unmeasured here.** A world tar goes through `pods/exec` every hour on k8up and into a landing PVC as large as the world on Velero. The owned shape exists because of that; the design doc addendum carries the numbers.
- **Credentials are a naming convention, not a projection.** The projection cannot copy a Secret. The module's sidecar references the platform's repository Secret by the name the table declares (`mc-backup-restic`), which couples the module to a platform convention. A `secretRef` the projection could hand over by value would need a Secret-copying capability nothing in OPM has.

### What this discharges in the design

One module per application renders on both engines through the shipped kernel with no engine-specific arm, under three contracts: policy (provider-fulfilled, both engines), producer (provider-fulfilled, both engines), owned (catalog-fulfilled, engine-optional). Refusals are by contract where an engine lacks the capability and by silence where it has nothing to add. What remains is unchanged: provider configuration (OQ2, now one shared stand-in table) and tenancy for admin-scoped engines (P2).

**Hypothesis held.**
