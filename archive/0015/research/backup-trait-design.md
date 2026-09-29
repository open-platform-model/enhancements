# Engine-neutral backup traits: synthesis and proposal

Written 2026-09-12 from the four research files beside it (`velero.md`, `k8up.md`, `other-engines.md`, `app-backup-semantics.md`) and from experiments 01 and 02. The compilable shape is `backup-traits-proposal.cue`. This is a design proposal for discussion, not a decision; the decisions it argues for belong in a successor entry to 0015 or in catalog_opm's own change.

## 1. The question

Can one set of catalog_opm traits describe the backup of a MariaDB instance and of a Minecraft server so that a k8up platform, a Velero platform, and ideally KubeStash, Kanister, Longhorn or VolSync platforms each render it into their own objects, refusing loudly what they cannot do and never silently doing less?

## 2. What the engines agree on, and where they split

**The intersection** (all six engines, `other-engines.md` section 8): a cron schedule, a retention policy of at least keep-N attached to it, a target that resolves to PVCs, a status. That is the whole of experiment 01's `backup` trait, and it is why that trait rendered on both engines unchanged.

**The four splits that matter for the two applications:**

| Concern | Velero | k8up | KubeStash / Kanister | Longhorn / VolSync |
| --- | --- | --- | --- | --- |
| Quiesce hooks in the live pod | pre/post exec in Schedule spec, no annotation needed; **exec returns before the capture** | **none** (open #886) | HookTemplate / Blueprint phases | none |
| Logical dump | hook writes a file into a volume that is then captured | PreBackupPod, **stdout streamed** | separate Job, **stdout streamed** | none |
| Repository | admin BSL in `velero` ns, credential there too | inline per Schedule, Secret in the instance ns | namespaced storage CR with a sharing policy | cluster-wide target / tenant Secret |
| Retention | **TTL only** | tiered counts | TTL + last + tiered | keep-N / restic passthrough |

Two more facts change the design more than any field:

- **A hook's exec session is not held across the capture on any engine.** MariaDB `BACKUP STAGE` and Postgres `pg_backup_start` release on disconnect (`app-backup-semantics.md` A.3, C). A three-step "pre, capture, post" is therefore wrong for both unless the pre command itself backgrounds a session that post releases. Minecraft `save-off` is the opposite: it persists, which is why it can get stuck when the post never runs.
- **Nothing an adapter renders may annotate or label objects another transformer rendered** (0015 D1 premise, experiment 01). Every per-PVC or per-pod annotation mechanism the engines offer (k8up `k8up.io/backup`, `backupcommand`, `backup-restic-args`; Velero `backup.velero.io/backup-volumes`, `exclude-from-backup`, hook annotations) is out of reach. What remains is label **selection** of objects the base catalog already labelled, plus objects the adapter owns.

## 3. Three traits, not one

An earlier cut of experiment 02 established the rule: a capability one engine cannot implement whole is a **second provider-fulfilled contract**, so the refusal lands at demand resolution naming the contract, not inside an adapter's CUE where it fires at platform build. Applied to the splits above:

1. **`backup`**: the policy. Schedule, retention, repository by name, volume scope, capture preference, excludes, maintenance. Every engine implements it. Three of its fields are advisory (section 5).
2. **`backup-hooks`**: quiesce and release around a volume capture. `container`, `pre[]`, `post[]`, `compensate`. Implemented by Velero, KubeStash, Kanister. Refused by k8up, Longhorn, VolSync. Attaching it is what makes a volume capture application-consistent; there is no `consistency` field, because a value cannot be refused at matching but a contract can.
3. **`backup-command`**: the backup is a command's output. `container`, `command`, `output: stream | file{volume,path}`, `fileExtension`. Implemented by k8up (stream), KubeStash and Kanister (stream), Velero (file). Refused by Longhorn and VolSync.

`backup-hooks` and `backup-command` both presume `backup` on the same component for schedule and retention. A provider's transformer for either requires only that contract plus the container resource, which keeps the contracts independently countable under the exactly-one-provider rule (an earlier cut of experiment 02).

## 4. The two applications under the three traits

**MariaDB** has three valid shapes; a module picks by which traits it attaches and what `output` it declares.

| Shape | Traits | Engines | Notes |
| --- | --- | --- | --- |
| Logical dump, streamed | `backup` (no `volumes`), `backup-command` `output: stream` | k8up, KubeStash, Kanister | Today's fleet shape. Datadir never captured. Restorable with plain restic + mysql. |
| Logical dump to a dump volume | `backup` `volumes: [dumps]`, `backup-command` `output: file` | Velero | Needs P1. Datadir PVC skipped by a volume policy the adapter renders. |
| Snapshot with a held `BACKUP STAGE` | `backup` `capture: snapshot`, `backup-hooks` | Velero (CSI + data mover), KubeStash pvc-addon | `pre` backgrounds a session holding `BLOCK_COMMIT` with a `SELECT SLEEP(n)` ceiling; `post` releases it. Disconnect releases the stage, so a lost post fails safe. A crash-consistent snapshot without the hook is recoverable but MariaDB warns against it. |

**Minecraft** has one valid shape: filesystem or snapshot capture of the world volume with `save-off`, `save-all flush`, `sync` before and `save-on` after, plus `compensate: save-on`. That is `backup` + `backup-hooks`, and it renders on Velero, KubeStash and Kanister. **It is refused on k8up**, correctly: k8up cannot quiesce, and a file walk over an un-quiesced world tears region files with no recovery path. The itzg sidecar stays for k8up platforms. Excludes (`*.jar`, `cache`, `logs`, map tiles) are advisory: Velero ignores them and backs up more; k8up honours them job-wide through a ConfigMap the adapter renders into `spec.backend.envFrom` (`RESTIC_EXCLUDE`), which with a label-scoped Schedule is per component in effect.

`rcon-cli` exists in the server image and authenticates from `$HOME/.rcon-cli.env` with no arguments, so the hook needs nothing the sidecar had.

## 5. Advisory fields and the keep-more rule

Experiment 01 introduced keep-more for retention: a lossy mapping keeps at least as long as any tier asks. Three fields of `backup` are advisory under the same rule, and each is safe in exactly one direction:

- **`excludes`**: an engine that cannot exclude backs up more. Safe.
- **`capture`**: `any | snapshot | filesystem`. Both are complete captures of the volume; the difference is cost and restore mechanics, not what survives. Safe.
- **`maintenance`**: changes when prune and check run, never what survives. Safe.

A field is **not** advisory when ignoring it captures less or captures something invalid. That is why `volumes` is a hard requirement with a prerequisite (P1), why the datadir exclusion in command mode is structural (no `volumes` entry, so nothing selects it), and why quiesce is a contract and not a flag.

## 6. Repository: the platform owns it

An earlier cut of experiment 02 put inline S3 into `backup-command`. The research overturns that: a Velero location and its credential Secret live in the `velero` namespace, a Longhorn target is cluster-wide, a KubeStash storage is namespaced but shared by policy. The only shape every engine can honour is **a name the platform resolves**. The instance says `repository: "mc-backup"`; the provider catalog maps the name to a backend from platform configuration; the adapter derives a per-instance prefix or path so instances never share a retention group (k8up: `bucket/<prefix>/<instance>`; Velero: BSL `prefix` plus the backup name; KubeStash: `directory`).

Cost against the fleet's current declarations: "own credentials per release" stops being a module decision and becomes a platform one. The fleet's three databases already share one credential set and one bucket, so nothing is lost there. What the fleet does need is the per-release prefix for chain continuity across renames, and the adapter derives that.

Open (OQ2): 0015 has no surface for provider configuration yet. The k8up provider needs a table of repository names to backends; the Velero provider needs the BSL names. Registration (0015 D9 to D12) carries a catalog and a version, not values.

## 7. Prerequisites outside the traits

- **P1: per-volume PVC labels in catalog_opm.** The PVC transformer stamps `volume.opmodel.dev/name: <volume key>` on every PVC it renders. Without it no adapter can select one of a component's volumes, and `backup.volumes` is unimplementable. Small, additive, and the whole Velero MariaDB path depends on it. The Velero adapter then renders a resource-policy ConfigMap in the `velero` namespace with one `skip` rule per unselected volume (`pvcLabels` condition, v1.16+).
- **P2: Velero output is admin-scoped.** Every Velero object the adapter renders lives in the `velero` namespace. Under tenant impersonation a tenant module cannot apply it. Velero is a tenant-usable provider only if the platform applies its objects on the tenant's behalf (the OADP non-admin controller pattern) or the render is platform-run. This is a 0015 tenancy question, not a trait question, and it is the same for Longhorn.
- **P3: compensate needs a runner.** No engine schedules an out-of-band idempotent release. Velero and KubeStash can run it as a post hook with `onError: continue`; the last resort is the module's own startup. For Minecraft that is already how the sidecar self-heals (a `save-on` before every cycle). The trait names the action; who runs it besides the post is platform policy.

## 8. What the current contract model cannot express

- **OQ1: value-level capabilities.** `backup-command.output` has two arms and each engine implements one. `capture` is a preference an engine may lack. The contract model refuses at the trait level only; a wrong arm is a render-time bottom, which an earlier cut of experiment 02 showed fires at platform build if written as `error()`. 02-design already names capability-based routing as the successor entry. Until then: the design keeps `capture` advisory, and documents that `output` must match the platform's engine. If that is unacceptable, `output` splits into two contracts (`backup-command` for stream, `backup-dump-file` for file), which is honest but fragments the catalog.
- **OQ2: provider configuration** (section 6).
- **OQ3: restore.** No trait. Restore is an operational act, engine-specific (k8up Restore, Velero Restore with namespace mapping, VolSync ReplicationDestination), and for the two applications here it is offline either way. A restore trait would be a contract nobody renders on a schedule. Left out deliberately.
- **OQ4: k8up snapshot identity.** Stream snapshots are `/<namespace>-<container><fileExtension>` (upstream #1068). The adapter must prefix `fileExtension` with instance and component (experiment 02 does). A future k8up fix could make the suffix unnecessary.

## 9. Recommendation

Adopt the three-trait shape. Land P1 in catalog_opm first, because both the Velero database path and the general `volumes` scope depend on it and it is the cheapest change in this document. Then cut catalog_opm's `backup` trait against `backup-traits-proposal.cue` sections 1 to 3, with the k8up provider implementing `backup` and `backup-command` (the earlier cut's adapter minus inline S3, plus job-wide excludes) and a Velero provider implementing all three under P2. Kanister or KubeStash would be the generality check for `backup-hooks`, the way Velero was for `backup` in experiment 01.

The fleet outcome: the three MariaDB releases move to `backup` + `backup-command` and drop every hand-authored k8up annotation and the `ownSchedule`/`dump` mechanics; the game servers keep the sidecar until a hook-capable engine is on the platform.

## Addendum (2026-09-12, later the same day): the engine is the wrong owner of the quiesce

The first cut of the experiment now numbered 02 implemented sections 3 to 9 as written and measured two things that overturn section 3's split. k8up refuses `backup-hooks` outright (it has no exec hook of any kind), so a quiesced world was simply unavailable on the fleet's own engine. And a `backup-command` output arm the engine does not implement failed as an opaque transformer error naming neither contract nor field (OQ1). Both point the same way: consistency has to be produced by the application side, and the engine has to be handed something it can consume.

**Revised shape, measured in the third cut of experiment 02:**

1. `backup` (policy): unchanged.
2. `backup-producer` (provider-fulfilled) replaces both `backup-hooks` and `backup-command`. The command produces a consistent artefact on stdout with any quiesce inside it. k8up runs it in a PreBackupPod that mounts the named volumes read-only beside the workload and streams stdout. Velero runs it as a pre-hook in the live container with a redirect into a `landing` volume and captures only that volume. One module, both engines, no arm.
3. `backup-owned` (catalog-fulfilled) is new: the module captures with its own tool (the itzg restic sidecar), the declaring catalog projects the policy into a ConfigMap the tool reads, and an engine that can maintain the tool's repository format adds prune and check (k8up for restic). Velero adds nothing and renders nothing.

**Why two capture contracts and not one.** The producer stream costs the whole artefact through `pods/exec` every run on k8up (a 20 GB world hourly is 10 to 60 minutes of apiserver streaming) and a landing volume as large as the artefact on Velero. That is fine for the three databases and wrong for the game servers. The owned shape keeps the sidecar's incremental upload and local quiesce, and turns the trait into the thing that configures it instead of the thing that replaces it.

Sections 7 (P1, P2) and 8 (OQ2) stand. OQ1 is closed by construction: the producer contract has no arm. `backup-traits-proposal.cue` in this directory is the pre-addendum shape and is kept as the record; the measured shape is the experiment's `contracts/`.

## Second addendum (2026-09-13): the offer is the contract, the ownership is a field

`backup-producer` and `backup-owned` both named who owns the capture, a runtime fact. An author thinks in offers: a command, or a tool they already run. Measured in the final cut of experiment 02 (`experiments/02-policy-and-command`), the shape is:

1. `backup` (policy) gains `executor: *"platform" | "module"`. Under `module`, every provider adapter projects the policy into a ConfigMap the module's own tool reads (a plain CUE function in the declaring catalog, not a transformer) and adds maintenance where it can (k8up: prune and check). Velero projects and stops. `capture` is renamed `method` so it no longer reads like a sibling of `executor`.
2. `backup-command` is the producer contract renamed: `container`, `command`, `volumes`, `landing`, `fileExtension`, `compensate`.
3. `backup-owned` is deleted.

`executor` is a value, not a contract, so an engine cannot refuse it by name. That is safe: an adapter that ignored `module` would take an extra crash-consistent copy on top of the module's own, which is the keep-more direction. The same test that makes `method`, `excludes` and `maintenance` advisory. Moving the projection into a function also removes the previous cut's awkwardness, where a declaring-catalog transformer had to read `backup` without requiring it to avoid becoming a second provider.

Sections 7 (P1, P2) and 8 (OQ2) still stand. `backup-traits-proposal.cue` is the pre-addenda shape and is kept as the record; the measured shape is the experiment's `contracts/`.
