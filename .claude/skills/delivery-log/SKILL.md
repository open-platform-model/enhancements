---
name: delivery-log
description: Protocol for the per-entry delivery log (NNNN/delivery.yaml), the append-only record of landed changes from which delivery state is derived. Load before running task delivery:log (FROM mode after archiving an OpenSpec change, or explicit mode for PR/commit landings), before editing any delivery.yaml or its no_work map, before writing an enhancement.yaml declaration into a target repo's OpenSpec change, or when interpreting task delivery / delivery:uncovered / delivery:deferred / delivery:reconcile output.
user-invocable: true
---

# Delivery Log

`NNNN/delivery.yaml` is the entry's implementation log: an append-only record of changes that have **landed** (an OpenSpec change archived, a PR merged, a commit pushed), each carrying the entry's decision numbers it implemented. It is a log of facts, never a forecast: no slices, no phases, no dependency graph, and nothing is written before the work lands. A forecast has to be right about the future; a log only has to be true about the past. The right time to decompose work is when an OpenSpec change is cut in the target repo, with source in context; sequencing constraints, where real, stay design prose in `06-operational.md ## Cross-Repo Coordination`.

Schemas live in `enhancements/schema.cue`: `#Delivery` (the file), `#LogEntry`, `#ChangeRef`, and `#ChangeDeclaration` (the target-repo declaration). Validate one file directly with `cue vet -d '#Delivery' schema.cue NNNN/delivery.yaml`; `task vet` does this for every entry.

## When this skill applies

- You just archived an OpenSpec change in a target repo and its archive guidance points at `task delivery:log`.
- A PR merged or a commit landed in a repo without an OpenSpec workspace and it implemented an entry's decisions.
- You are creating an OpenSpec change in a target repo for an enhancement (the `enhancement.yaml` declaration is written now, not at archive time).
- You are adding or reviewing a `no_work` claim.
- You are reading `task delivery` output and need to know what the states mean.

## Rules

1. **Append only when the work has landed.** A logged-but-unfinished change would count its decisions as covered prematurely and corrupt the derivation. One log entry per landed change: date, a one-line summary (240-rune cap; decision citations go in `decisions`, not the summary), a structured change ref, the decisions it carried, optional `resolves`.
2. **Change refs are structured, never paths and never URLs.** Paths break when an OpenSpec change is archived (the directory moves); URLs rot. The (repo, key) pair is permanent:
   - `{kind: openspec, repo: <area>, change: <slug>}`, slug **without** the archive date prefix, so the ref survives the `changes/` to `changes/archive/YYYY-MM-DD-<slug>` move.
   - `{kind: pr, repo: <area>, number: N}` for repos without an OpenSpec workspace.
   - `{kind: commit, repo: <area>, sha: <sha>}` for work landing without a PR; log only after merge, since rebases invalidate pre-merge shas.
   - `{kind: retrospective, repo: <area>, note: "..."}` strictly for pre-tracking landings, where per-change archaeology would invent precision the record never had. Never for new work.
3. **Decision and OQ refs are local.** `D4`, `OQ9`, with no `NNNN:` prefix: the file lives inside the entry it describes. Numbers are immutable, so a ref resolves for the life of the repo. `decisions` is optional; a change may legitimately implement no numbered decision (a mechanical retarget, a release cut).
4. **`no_work` is a reviewed claim, not a suppression list.** It maps a decision number to the reason it genuinely needs no change (one that only deletes something, a documentation holding, one superseded before any work carried it). Each entry is a claim on the record, reviewed like any other line. A decision is **carried or excused, never both**; `task vet` fails a `no_work` key that a log entry also carries. Tombstoned numbers need no entry; they are excluded from coverage automatically.
5. **Cross-entry carriage.** When one change implements decisions of two entries, log the same change ref in **both** entries' `delivery.yaml`, each side with its own local `decisions` list. (Real case: 0011's `core-identity-package` and `cli-catalog-gates` also carried 0010 decisions.) `task check` warns when a log entry's `change.repo` is outside the entry's `affects[]`; carriage is the legitimate exception, a typo is the usual cause.
6. **Delivery state is derived, never stored.** `task delivery` (scripts/delivery.sh) computes per entry:
   - `implemented`: every live decision (tombstones excluded) is carried by a log entry or excused in `no_work`
   - `in-progress`: the log is non-empty but coverage is incomplete
   - `not-started`: no `delivery.yaml`, or an empty log
   - `rejected` / `superseded`: terminal statuses pass through; delivery was never owed
   The failure direction is safe by construction: a forgotten log entry under-reports (the entry stays `in-progress`) and can never produce a false `implemented`.
7. **Appending never voids a gate verdict.** `delivery.yaml` is deliberately outside the gate-verdict content hash (`scripts/entry_hash.sh` covers `*.md`/`*.cue` only), because the log records execution, not design. Conversely, nothing in the log ever substitutes for a gate verdict.
8. **History stays design-milestones-only.** What landed where goes in the log, structurally; a `config.yaml.history` event narrating delivery is the logbook this repo removed. `history[].slice` is legacy: kept so old events validate, never written in new ones.

## Appending a log entry

FROM mode, the archive-guidance path. Reads the change directory's `enhancement.yaml` and appends one log entry to every declared enhancement:

```bash
task delivery:log FROM=../cli/openspec/changes/archive/2026-08-24-foo SUMMARY="what landed"
```

Explicit mode, for repos without OpenSpec or manual logging:

```bash
task delivery:log ID=0019 REPO=library KIND=openspec CHANGE=foo SUMMARY="..." [DECISIONS="D1 D2"] [RESOLVES="OQ9"]
task delivery:log ID=0019 REPO=catalog KIND=pr NUMBER=42 SUMMARY="..."
task delivery:log ID=0019 REPO=modules KIND=commit SHA=abc1234 SUMMARY="..."
```

The task CUE-validates before the write sticks and restores the previous file on failure; `DATE=YYYY-MM-DD` overrides today. It refuses archived (terminal) entries. What a written entry looks like:

```yaml
log:
  - date: "2026-08-16"
    summary: >-
      One publish pipeline, two entry points: decode, read identity, derive
      coordinates, run the gates, push.
    change: { kind: openspec, repo: cli, change: cli-publish-pipeline }
    decisions: [D1, D2, D4]
    resolves: [OQ9]
```

`resolves` claims an Open Question the entry closed as `Status: deferred-to-implementation`; `task delivery:deferred` reports deferred OQs no log entry claims.

## The enhancement.yaml declaration

An OpenSpec change in a target repo declares its enhancement linkage **at creation time**, while the enhancement is in context, in `<change-dir>/enhancement.yaml`:

```yaml
implements:
  - enhancement: "0019"
    decisions: [D7]
    resolves: []
```

The shape is `#ChangeDeclaration` in `enhancements/schema.cue`. The file rides along on archive (the whole change directory moves) and is invisible to the openspec CLI. It is a claim, not proof; review of the resulting log line is what checks it. Each repo's openspec `config.yaml` `operations.archive.guidance` tells the archiving agent to run `task delivery:log FROM=<change-dir> SUMMARY="..."` from the enhancements repo, which reads this file and makes logging mechanical.

## Tasks

| Task | Use when |
| --- | --- |
| `task delivery [ID=NNNN]` | Answering "what is done?". Derived state per entry, with per-entry detail on `ID=`. `task delivery:data` is the TSV. |
| `task delivery:log FROM=<change-dir> SUMMARY="..."` | Logging an archived OpenSpec change into every enhancement it declares. |
| `task delivery:log ID= REPO= KIND= ... SUMMARY=` | Logging a PR, commit, or manual openspec ref. |
| `task delivery:uncovered [ID=NNNN]` | Live decisions classified covered / no_work / UNCOVERED. Deliberately not a gate: design legitimately runs ahead of delivery. Read it when logging and before expecting `implemented`. |
| `task delivery:deferred` | Every `deferred-to-implementation` OQ and whether a log entry claims it via `resolves`. |
| `task delivery:reconcile` | Drift detection: archived changes in sibling repos that declared an enhancement but were never logged. Report-only; the printed `task delivery:log` command is the fix. |

What `task vet` enforces on every `delivery.yaml`: the `#Delivery` schema; every cited `DN`/`OQN` resolves against `03-decisions.md`/`07-questions.md` (tombstones resolve; retired is not absent); `no_work` keys are live, not tombstoned, and not also carried by a log entry. It also fails any `plan.yaml`/`PLAN.md` inside an entry: forecast plans are retired, the delivery record is `delivery.yaml`.

## Red flags

- **Logging before the work lands.** The log is a record of the past. A "will land" entry corrupts the derivation.
- **A path or URL in a change ref.** It will break on archive or rot; use the structured kinds.
- **The archive date prefix in an openspec slug.** `change: cli-publish-pipeline`, never `2026-08-16-cli-publish-pipeline`.
- **Using `no_work` to silence `delivery:uncovered`.** An excuse without a genuine no-change reason is a suppression, and the reason text will not survive review.
- **Excusing a decision a log entry already carries.** Carried or excused, never both; `task vet` fails it.
- **A `retrospective` ref for new work.** Every change landing today has an OpenSpec change, a PR, or a commit to cite.
- **Narrating a landing in `config.yaml.history` or entry prose.** The log is the only delivery record; history events are design milestones.
- **Treating a log append as needing a gate re-walk, or a walked gate as voided by one.** The hash excludes `delivery.yaml` on purpose. Equally, no log content ever overrides a gate verdict.
- **Skipping the log because the change "obviously" landed.** A forgotten entry under-reports forever; `task delivery:reconcile` exists to catch exactly this, but only for declared OpenSpec changes.

## Cross-references

- `enhancements/schema.cue`: `#Delivery`, `#LogEntry`, `#ChangeRef`, `#ChangeDeclaration`, with the full rationale in comments.
- `enhancements/scripts/delivery.sh`: the derivation.
- `enhancements` skill (sibling): the surrounding workflow; Phase 4 is where this skill plugs in.
- `enhancement-compaction` skill (sibling): refuses entries that derive `implemented`; the last compaction pass happens before the final landings are logged.
- `openspec-archive-change` / `opsx:archive` skills (per target repo): the archive step whose guidance triggers `task delivery:log FROM=`.
