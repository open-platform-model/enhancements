// Proposal: engine-neutral backup traits for catalog_opm. Companion to
// backup-trait-design.md (2026-09-12). Plain package, no imports, so it
// vets standalone: `cue vet -c backup-traits-proposal.cue`. The #Trait
// wrappers (fulfilment: "provider", optional, appliesTo) are as in
// experiments/02; only the spec schemas are proposed here.
package proposal

#Cron: string & =~"^(\\S+\\s+){4}\\S+$"

// ── 1. backup: the policy. Two-engine core, six-engine intersection. ────────
#BackupSchema: {
	// Five-field cron. Engine tokens are not admitted.
	schedule!: #Cron

	// At least one tier. Engines without tiered retention map the whole
	// block to one span under the keep-more rule (Velero ttl, Longhorn
	// retain): keep at least as long and as many as any tier asks.
	retention!: #RetentionSchema

	// A repository the PLATFORM registered, by name. Never inline object
	// storage: on Velero a location is an admin object in the velero
	// namespace, on Longhorn it is cluster-wide, on k8up it is inline but
	// its Secret must be in the instance namespace. The provider resolves
	// the name from platform configuration; the adapter derives a
	// per-instance prefix or path so instances never share a retention
	// group. Absent: the platform default repository.
	repository?: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"

	// Which of the component's persistent volumes are in scope. Absent:
	// all of them. Names are the component's own volume keys. Needs the
	// base catalog to stamp `volume.opmodel.dev/name` on PVCs (P1 in the
	// design doc); without it no adapter can tell two volumes apart.
	volumes?: [string, ...string]

	// ADVISORY preference. `any` lets the engine pick; an engine without
	// the preferred mode uses what it has. Both modes are valid captures
	// of a volume; application consistency comes from the hook or command
	// contracts, not from this field.
	capture: *"any" | "snapshot" | "filesystem"

	// ADVISORY under the keep-more rule: an engine that cannot exclude
	// (Velero, Longhorn) backs up MORE, never less. restic-style globs,
	// relative to the volume root.
	excludes?: [...string & !=""]

	// ADVISORY. Engine-side maintenance cadence for engines with discrete
	// prune and check jobs (k8up). Absent: engine default with jitter.
	// Ignored by TTL-driven engines; retention still holds in full.
	maintenance?: {
		pruneSchedule?: #Cron
		checkSchedule?: #Cron
	}
}

#RetentionSchema: {
	keepLast?:    int & >0
	keepHourly?:  int & >0
	keepDaily?:   int & >0
	keepWeekly?:  int & >0
	keepMonthly?: int & >0
	keepYearly?:  int & >0
	// Rolling window (restic --keep-within, Velero ttl). Engines with
	// tiers only (k8up) map it to keepHourly = hours, which keeps at least
	// the window whenever backups run at most hourly.
	keepWithin?: string & =~"^([0-9]+[hdwmy])+$"
	matchN(>=1, [
		{keepLast!: _}, {keepHourly!: _}, {keepDaily!: _}, {keepWeekly!: _},
		{keepMonthly!: _}, {keepYearly!: _}, {keepWithin!: _},
	])
}

// ── 2. backup-hooks: quiesce and release around a volume capture. ───────────
// Provider-fulfilled, optional: false. Attaching it is what makes a
// volume capture application-consistent. Implemented by engines that
// exec into the live pod around the capture (Velero, KubeStash, Kanister).
// Refused at demand resolution by engines without hooks (k8up, Longhorn,
// VolSync): "nothing on this platform implements this contract".
#BackupHooksSchema: {
	// The component container the commands run in.
	container!: string

	// Runs to completion BEFORE the capture starts. NOT held open across
	// the capture: a lock that releases on disconnect (MariaDB BACKUP
	// STAGE, Postgres pg_backup_start) needs the command itself to
	// background a session and `post` to release it; see the design doc.
	pre!: [#HookExec, ...#HookExec]

	// Runs AFTER the capture completes, success or failure.
	post?: [...#HookExec]

	// Idempotent release that the engine or platform MAY run at ANY time:
	// after a failed pre, after a lost post, on instance start. Required
	// whenever `pre` leaves the application in a state that does not
	// self-heal on disconnect (Minecraft save-off, Redis AOF rewrite off).
	// Engines that cannot schedule it out of band still run it after
	// every post; the module's own startup is the last resort.
	compensate?: #HookExec
}

#HookExec: {
	// No shell is implied by any engine: write ["sh", "-c", "..."].
	command!: [string, ...string]
	timeout: string & =~"^[0-9]+[smh]$" | *"30s"
	// fail: the backup fails. continue: the capture proceeds.
	onError: *"fail" | "continue"
}

// ── 3. backup-command: the backup IS a command's output. ────────────────────
// Provider-fulfilled, optional: false. The component's volumes are NOT
// captured unless `backup.volumes` names one (the dump volume).
#BackupCommandSchema: {
	// Image and env come from this component container; the engine runs
	// the command in a pod of its own (k8up PreBackupPod, KubeStash Job,
	// Kanister KubeTask) or in the live container (Velero pre-hook).
	container!: string
	command!:   string & !=""

	// Where the output goes. `stream`: stdout is the artefact (k8up,
	// KubeStash, Kanister). `file`: the command writes into one of the
	// component's volumes and that volume is captured (Velero: hook then
	// fs-backup or snapshot). An engine implements one arm; the other is a
	// value-level refusal the contract model cannot place at matching
	// today (design doc, OQ1).
	output!: "stream" | {file: {volume!: string, path!: string & =~"^[^/].*"}}

	// Retention-group identity suffix; the adapter prefixes instance and
	// component.
	fileExtension: string & =~"^\\.[a-z0-9]+(\\.[a-z0-9]+)*$" | *".sql"
}

// ── Worked instances ────────────────────────────────────────────────────────

// luckperms-db on k8up (today's fleet shape) or KubeStash/Kanister:
// logical dump streamed, own repository by name, Sunday window.
mariadbStream: {
	backup: #BackupSchema & {
		schedule:   "0 2 * * *"
		retention:  {keepDaily: 7, keepWeekly: 4, keepMonthly: 6}
		repository: "mc-backup"
		// No volumes named: the datadir is never file-copied. The dump is
		// the only artefact.
		volumes?: _
		maintenance: {pruneSchedule: "0 3 * * 0", checkSchedule: "0 4 * * 0"}
	}
	backupCommand: #BackupCommandSchema & {
		container: "mariadb"
		command:   "sh -c 'mariadb-dump --single-transaction --routines --events --triggers --system=all --all-databases -h luckperms-db-mariadb -uroot -p\"$MARIADB_ROOT_PASSWORD\"'"
		output:    "stream"
	}
}

// The same database on Velero: the dump lands in a second volume, and
// only that volume is captured. Needs P1 (per-volume PVC label).
mariadbFile: {
	backup: #BackupSchema & {
		schedule:   "0 2 * * *"
		retention:  {keepDaily: 7, keepWeekly: 4, keepMonthly: 6}
		repository: "mc-backup"
		volumes: ["dumps"]
	}
	backupCommand: #BackupCommandSchema & {
		container: "mariadb"
		command:   "sh -c 'mariadb-dump --single-transaction --routines --events --triggers --system=all --all-databases -uroot -p\"$MARIADB_ROOT_PASSWORD\" > /dumps/all.sql'"
		output: file: {volume: "dumps", path: "all.sql"}
	}
}

// A Minecraft world on Velero (or KubeStash/Kanister): hourly filesystem
// capture with save-off/save-on around it, compensate = save-on, excludes
// advisory. Refused on k8up (no hooks): the module keeps the itzg sidecar.
minecraft: {
	backup: #BackupSchema & {
		schedule:  "0 * * * *"
		retention: {keepWithin: "20d"}
		capture:   "filesystem"
		excludes: ["*.jar", "cache", "logs", "*.tmp", "bluemap/web/maps/**"]
	}
	backupHooks: #BackupHooksSchema & {
		container: "minecraft"
		pre: [{command: ["sh", "-c", "rcon-cli save-off && rcon-cli save-all flush && sync"], timeout: "120s"}]
		post: [{command: ["rcon-cli", "save-on"], onError: "continue"}]
		compensate: {command: ["rcon-cli", "save-on"]}
	}
}

// MariaDB on a snapshot engine with an application-consistent point:
// the pre hook holds BACKUP STAGE in a backgrounded session until post
// releases it or the timeout expires (disconnect releases the stage).
mariadbSnapshot: {
	backup: #BackupSchema & {
		schedule:  "0 2 * * *"
		retention: {keepDaily: 7}
		capture:   "snapshot"
	}
	backupHooks: #BackupHooksSchema & {
		container: "mariadb"
		pre: [{
			command: ["sh", "-c", "mkfifo /tmp/bs 2>/dev/null; (mariadb -uroot -p\"$MARIADB_ROOT_PASSWORD\" -e 'BACKUP STAGE START; BACKUP STAGE BLOCK_COMMIT; SELECT SLEEP(90);' </tmp/bs &) ; sleep 2"]
			timeout: "30s"
		}]
		post: [{command: ["sh", "-c", "echo >/tmp/bs; rm -f /tmp/bs"], onError: "continue"}]
	}
}
