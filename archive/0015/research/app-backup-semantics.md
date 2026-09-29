# Application backup semantics: MariaDB, Minecraft, PostgreSQL, Redis

Gathered 2026-09-12 by a research agent from the cited sources; verified where marked, otherwise a vendor-doc summary. Input to the engine-neutral backup trait design (`backup-trait-design.md`). Snapshot, not canon.

Scope: what a backup engine must be *told to do* per application, so an abstraction can express it as (pre-hook, capture, post-hook, restore).

---

## A. MariaDB 11.x/12.x

### A.1 Logical dump (`mariadb-dump`)

Recommended invocation for a consistent InnoDB dump:

```
mariadb-dump --host=mariadb --user=backup --password=... \
  --single-transaction --quick \
  --all-databases --system=all \
  --routines --events --triggers \
  --source-data=2 \
  > dump.sql
```

- `--single-transaction` "sends a `START TRANSACTION` SQL statement to the server before dumping data": consistent snapshot for InnoDB only. ([mariadb-dump, MariaDB KB](https://mariadb.com/kb/en/mariadb-dump/))
- **Caveat, load-bearing for a hook design:** while `--single-transaction` runs, "no other connection should use the following statements: `ALTER TABLE`, `CREATE TABLE`, `DROP TABLE`, `RENAME TABLE`, or `TRUNCATE TABLE`". DDL breaks the snapshot. Non-transactional tables (MyISAM, MEMORY, Aria non-transactional) are **not** covered. ([same](https://mariadb.com/kb/en/mariadb-dump/))
- `--routines`, `--events`, `--triggers` are **not** implied. ([mariadb-dump docs](https://mariadb.com/docs/server/clients-and-utilities/backup-restore-and-import-clients/mariadb-dump))
- **Users/grants are NOT captured by a plain `--all-databases`.** Use `--system=all` (dumps `mysql` system tables as portable SQL: `CREATE USER`, `GRANT`, ...). Values: `all, users, plugins, udfs, servers, stats, timezones`. ([same](https://mariadb.com/docs/server/clients-and-utilities/backup-restore-and-import-clients/mariadb-dump))
- `--source-data=2` appends the binlog file+position as a comment: the PITR anchor. ([mariadb-dump](https://mariadb.com/kb/en/mariadb-dump/))
- **Streams to stdout: yes.** **Runs from another pod over TCP: yes** (`--host`). The dump user needs `SELECT`, `SHOW VIEW`, `TRIGGER`, `EVENT`, `LOCK TABLES`, plus `RELOAD`/`BINLOG MONITOR` for `--source-data`, and `SELECT` on `mysql.*` for `--system=all`.
- **Restore:** `mariadb db_name < backup-file.sql`. Single-threaded SQL replay; roughly 3 to 10x the dump wall time.
- Uncertain: whether `--system=all` combines cleanly with `--all-databases` in every 11.x point release (ordering bugs where `CREATE USER` lands after data). Verify on the pinned version.

### A.2 Physical hot backup (`mariadb-backup`)

```
mariadb-backup --backup --target-dir=/backup/base --user=backup --password=...
mariadb-backup --prepare --target-dir=/backup/base
# restore, datadir must be EMPTY:
mariadb-backup --copy-back --target-dir=/backup/base && chown -R mysql:mysql /var/lib/mysql
```

- Output is a **directory** unless `--stream=xbstream` (stdout; extract with `mbstream -x`). ([mariadb-backup options](https://mariadb.com/kb/en/mariabackup-options/))
- `--prepare` is mandatory before restore. ([same](https://mariadb.com/kb/en/mariabackup-options/))
- **Must have filesystem access to the datadir**: "mariadb-backup has to read MariaDB's files from the file system". In Kubernetes: same pod (sidecar/ephemeral container) or a pod mounting the same PVC (RWO: same node, and many CSI drivers refuse a second mount). ([mariadb-backup overview](https://mariadb.com/docs/server/server-usage/backup-and-restore/mariadb-backup/mariadb-backup-overview))
- **Version matching is a hard constraint.** Newer binary than server: `Upgrade after a crash is not supported`; older: `Unsupported redo log format` at `--prepare`. ([MDEV-23718](https://jira.mariadb.org/browse/MDEV-23718), [MDEV-32994](https://jira.mariadb.org/browse/MDEV-32994))
- Restore precondition: the data directory must be empty. Physical backups "cannot be imported on significantly different hardware, a different DBMS, or potentially even a different MariaDB version." ([backup & restore overview](https://mariadb.com/docs/server/server-usage/backup-and-restore/backup-and-restore-overview))

### A.3 Snapshot consistency (CSI / block snapshot of the datadir)

- A crash-consistent snapshot of a **single** volume holding the whole datadir *is* recoverable for InnoDB (redo replay, like a power cut). MariaDB's own framing is cautionary: block snapshots are "database-blind", and "**Without flushing buffers and locking tables, snapshots risk torn pages and permanent corruption.**" ([backup & restore overview](https://mariadb.com/docs/server/server-usage/backup-and-restore/backup-and-restore-overview))
- The supported way to make it *application*-consistent, MariaDB 10.4+ ([BACKUP STAGE](https://mariadb.com/kb/en/backup-stage/), [Storage Snapshots and BACKUP STAGE](https://mariadb.com/kb/en/storage-snapshots-and-backup-stage-commands/)):

  **pre-hook (one session, kept open):**
  ```sql
  BACKUP STAGE START;
  BACKUP STAGE BLOCK_COMMIT;  -- this is the backup point
  ```
  **-> trigger the CSI VolumeSnapshot ->**

  **post-hook (same session):**
  ```sql
  BACKUP STAGE END;
  ```
- `BLOCK_COMMIT` "lock[s] the binary log and commit/rollback to ensure that no changes are committed to any tables". Design goal: "a very short block of new commits". ([BACKUP STAGE](https://mariadb.com/kb/en/backup-stage/))
- **If the post-hook never runs:** "A disconnect automatically releases backup stages." A `kubectl exec ... -e 'BACKUP STAGE START; BACKUP STAGE BLOCK_COMMIT'` that exits immediately releases the lock the instant the exec session ends. **The stage is useless unless the session stays alive across the snapshot.** The pre-hook must be a *long-lived* process (e.g. `... ; SELECT SLEEP(n)` or a held pipe). A crashed hook pod fails safe: the server unblocks on TCP teardown.
- Legacy `FLUSH TABLES WITH READ LOCK`: same session-scoped release; MariaDB says to prefer `BACKUP STAGE BLOCK_COMMIT`. ([FLUSH](https://mariadb.com/kb/en/flush/))
- Multi-volume caveat: datadir, binlogs and redo on separate PVCs make a per-PVC snapshot set **not** atomic and not a valid backup.

### A.4 Why a file-level copy (restic/rsync walking a live datadir) is invalid

- A file walker copies files over seconds to minutes while InnoDB writes `ibdata1`, `.ibd`, the redo log and the doublewrite buffer. Each file is captured at a *different* instant, so the copied redo LSN does not correspond to the copied pages. Crash recovery cannot reconcile them. Worse than a crash-consistent snapshot, which captures one instant.
- Rule for the abstraction: **restic/rsync over a live RDBMS datadir must be blocked outright.** Valid only against a stopped server or a mounted snapshot.

### A.5 PITR

- Requires `log_bin` and retention covering base-backup age plus restore lag (`binlog_expire_logs_seconds`). Binlogs must be backed up too, preferably from a different volume.
- `mariadb-backup` writes `mariadb_backup_binlog_info`; `mariadb-dump --source-data` records the position in the dump header.
- Replay: `mariadb-binlog --start-position=<pos> --stop-datetime="..." binlog.00000N | mariadb`. ([PITR with mariadb-backup](https://mariadb.com/docs/server/server-usage/backup-and-restore/mariadb-backup/point-in-time-recovery-pitr-mariadb-backup))
- An abstraction that captures only the datadir or dump, not the binlog stream, **cannot** offer PITR.

---

## B. Minecraft Java (Paper/Purpur/Fabric on `itzg/minecraft-server`)

Primary source read in full: `itzg/docker-mc-backup/scripts/opt/backup-loop.sh` and `scripts/bin/backup`.

### B.1 The itzg/docker-mc-backup sidecar

**Exact sequence** (`backup-loop.sh:676-721`, `do_backup`):

1. optional `PRE_SAVE_ALL_SCRIPT`
2. `retry $RCON_RETRIES $RCON_RETRY_INTERVAL rcon-cli save-off`; on failure: `exit 1`, no backup taken
3. **immediately** installs `trap 'retry 5 5s rcon-cli save-on' EXIT`
4. if `ENABLE_SAVE_ALL` (default true): `rcon-cli save-all flush`, then if `ENABLE_SYNC` (default true): `sync`
5. optional `PRE_BACKUP_SCRIPT`
6. `"${BACKUP_METHOD}" backup` (status captured, non-fatal)
7. optional `PRE_SAVE_ON_SCRIPT`
8. `rcon-cli save-on`, then clears the trap
9. optional `POST_BACKUP_SCRIPT`

The loop also runs `rcon-cli save-on` *before* each cycle as an RCON-readiness probe, and takes a `flock` on `$DEST_DIR/.mc-backup-lock`.

**Defaults, verbatim from `backup-loop.sh:17-64`:**

| Var | Default |
|---|---|
| `SRC_DIR` / `DEST_DIR` | `/data` / `/backups` |
| `BACKUP_NAME` | `world` |
| `INITIAL_DELAY` | `2m` (skipped in one-shot mode) |
| `BACKUP_INTERVAL` | `24h` |
| `BACKUP_ON_STARTUP` | `true` |
| `PAUSE_IF_NO_PLAYERS` | `false` |
| `BACKUP_METHOD` | `tar` (also `restic`, `rsync`, `rclone`) |
| `PRUNE_BACKUPS_DAYS` | `7` |
| `PRUNE_RESTIC_RETENTION` | `--keep-within 7d` |
| `RCON_RETRIES` / `RCON_RETRY_INTERVAL` | `5` / `10s` |
| **`EXCLUDES`** | **`*.jar,cache,logs,*.tmp`** |
| `RESTIC_ADDITIONAL_TAGS` | `mc_backups` |
| `RESTIC_HOST` | `${RESTIC_HOSTNAME:-$(hostname)}` |
| `ONE_SHOT` | `false` |

**restic invocation** (`backup-loop.sh:552-568`): `--tag` per tag, `--exclude` per pattern, `restic backup ... .` from `$SRC_DIR`. Prune: `restic forget --tag "<tags>" $PRUNE_RESTIC_RETENTION --prune` when a dry run shows something to remove.

**On-demand trigger: yes, first-class.** `scripts/bin/backup now` (`ONE_SHOT=true`). `kubectl exec <sidecar> -- backup now` is a supported manual backup. `${SRC_DIR}/.paused` skips the RCON dance.

**If the sidecar dies between save-off and save-on:** the `EXIT` trap covers normal exits, `set -e` failures and SIGTERM. It does **not** cover SIGKILL (OOM-kill, grace-period expiry, node loss). The server then stays in `save-off` indefinitely, queueing level changes in memory; a later crash loses everything since the last flush. **The single most important failure mode for an abstraction to model.** Mitigation: the loop's pre-cycle `save-on` self-heals on sidecar restart.

### B.2 Why save-off/save-all is needed

- `save-off`: "Disables the server writing to the level files ... All level changes are temporarily queued." `save-all flush`: "All the players and chunks are saved to the data storage device immediately, freezing the server for a short time." Plain `save-all` only *marks* chunks. ([Minecraft Wiki](https://minecraft.wiki/w/Commands/save-all))
- A copy can catch an `.mca` region file mid-write (4 KiB sectors, header table); a half-written chunk yields unreadable chunks. ([Host Havoc](https://hosthavoc.com/blog/minecraft-server-backup-recovery), [GameTeam](https://gameteam.io/blog/minecraft-server-world-corruption-backup-recovery-guide/))
- **Crash-consistent block snapshot without save-off: not equivalent.** Minecraft has no redo log and no crash-recovery pass. Recovery from a torn region needs Region Fixer, which deletes corrupt chunks so they regenerate. ([Minecraft-Region-Fixer](https://github.com/whensonZWS/Minecraft-Region-Fixer)) Paper's `flush-regions-on-save` has regressed at least once ([PaperMC/Paper#11933](https://github.com/PaperMC/Paper/issues/11933)).
- Corollary: a CSI snapshot *with* `save-off` + `save-all flush` + `sync` pre-hook and `save-on` post-hook is sound, and the lock window is seconds rather than the whole copy.

### B.3 Safe exclusions

- itzg default: `EXCLUDES=*.jar,cache,logs,*.tmp`. Glob patterns, comma-separated.
- Site-specific candidates: `bluemap/web/maps/**`, `plugins/dynmap/web/tiles/**`, `libraries/`, `versions/`, `crash-reports/`, `plugins/*/update/`.
- **Do not exclude CoreProtect's database as a cache.** It is authoritative forensic state. If SQLite and held open, it tears like any DB file while the world is saved-off. Treat it as an independent target (SQLite `.backup`/`VACUUM INTO`, or point CoreProtect at MariaDB and back that up via A). (northbyte note: the fleet's `coreprotect-db` is deliberately not backed up by policy; the exclusion there is a decision, not a cache assumption.)

### B.4 rcon-cli inside the server container

- Yes. `itzg/docker-minecraft-server` installs `itzg/rcon-cli` (`RCON_CLI_VERSION=1.7.7`). `kubectl exec <mc-pod> -c minecraft -- rcon-cli save-off` is a valid pre-hook with no sidecar.
- `rcon-cli` reads `RCON_PASSWORD`, `RCON_HOST`, `RCON_PORT` directly. The server image writes `password=${RCON_PASSWORD}` to `$HOME/.rcon-cli.env` at startup, so **`rcon-cli` inside the server container authenticates with no arguments**. The sidecar sources `${SRC_DIR}/.rcon-cli.env`; they coincide only when `HOME=/data`, the itzg arrangement. Flag as a coupling to assert. ([itzg/rcon-cli](https://github.com/itzg/rcon-cli))

### B.5 Sizes, cadence, restore

- Paper SMP worlds: 1 to 20 GB after a year; 50 to 200+ GB with large overworlds or rendered maps. `save-all flush` on 10 GB freezes well under a second to a few seconds.
- Common cadence: hourly restic, `--keep-within 7d` plus a forget policy.
- Restore is **offline only**: scale to 0, move aside `/data` world dirs, `restic restore <snap> --target /data`, `chown` to UID 1000, start. Restoring into a running server is overwritten by the next autosave.

---

## C. Generalization check: PostgreSQL and Redis

**PostgreSQL.** Logical dump is `pg_dump`/`pg_dumpall` over TCP from any pod (`pg_dumpall --globals-only` is the roles analogue of `--system=all`), streams to stdout. Quiesce hook is `pg_backup_start`/`pg_backup_stop` (PG15+), and **"the connection calling `pg_backup_start` must be maintained until the end of the backup, or the backup will be automatically aborted"**: the same long-lived-session constraint as MariaDB's `BACKUP STAGE`. Unlike MariaDB, Postgres explicitly blesses crash-consistent snapshots (WAL replay), single filesystem only: "snapshots *must* be simultaneous". PITR = base backup + archived WAL. ([backup-file.html](https://www.postgresql.org/docs/current/backup-file.html), [continuous-archiving.html](https://www.postgresql.org/docs/current/continuous-archiving.html))

**Redis.** The RDB file is the artefact: "copying the RDB file is completely safe while the server is running" (atomic rename). Pre-hook is `BGSAVE`, poll `rdb_bgsave_in_progress` until done, then copy: **no lock, no post-hook**. Redis is the odd one out in a paired-hook model. With AOF (7.0+ multi-part), the documented quiesce is `CONFIG SET auto-aof-rewrite-percentage 0` ... copy ... restore the value: a paired hook whose unrun post-hook leaves auto-rewrite disabled (unbounded AOF growth), and it does **not** self-heal on session loss, unlike MariaDB/Postgres. Redis 8.10+ adds `BACKUP START/LIST/SEAL/CLEANUP/ABORT`. ([Redis persistence](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/))

---

## Design implications

1. **Hook sessions must outlive the capture.** MariaDB `BACKUP STAGE` and Postgres `pg_backup_start` release on disconnect. "Run pre, snapshot, run post" as three separate execs is wrong for both unless the pre-hook process is held open for the snapshot's duration. Minecraft is the opposite: `save-off` persists across RCON disconnect, so fire-and-forget works, and that is why it can get stuck.
2. **Two failure semantics for a missing post-hook.** Fail-safe (MariaDB, Postgres) versus fail-stuck (Minecraft `save-off`, Redis AOF rewrite). The abstraction needs a *compensating action*: an idempotent, unconditionally-runnable recovery step (`save-on`, restore the rewrite percentage) invoked on operator/sidecar startup, not only on backup completion.
3. **Locality is a capability.** Logical dumps run from anywhere over TCP; physical tools (`mariadb-backup`) require datadir filesystem access: same pod or same PVC, which constrains scheduling.
4. **Snapshot validity is per-engine, not universal.** Postgres: documented-valid crash-consistent, single filesystem. MariaDB: recoverable but warned against without `BACKUP STAGE`. Minecraft: no recovery, quiesce mandatory. Redis: mostly fine, bounded loss.
5. **Restore-target version is part of the artefact.** `mariadb-backup` is prepare-locked to a major version; Minecraft worlds are forward-migrated irreversibly by a newer server. Record the engine version in backup metadata.
