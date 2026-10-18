# Tasks: the commands of the enhancements store

Covers the `task` commands of this repo and the lifecycle step each one serves. Every task is a one-line call to `enh`, the Go program in `tools/enh/`. `enh help` and `enh help <command>` list every flag. The `enhancements` skill gives the steps and the checklist of each lifecycle row.

## Run a task

Run from `enhancements/` (`cd enhancements && task <name>`) or from the workspace root through the include (`task enhancements:<name>`). The Taskfile quotes values with spaces.

## Tasks

| Task | Purpose |
| --- | --- |
| `task check` | The gate of this repo: `vet` (with `--cue`, `ENH_FINAL=1`), `links`, then `fresh`. CI runs the same, plus the specs rule and the docs checks. |
| `task vet [ID=0013] [MODE=accept\|deliver] [BASE=origin/main]` | Every checker rule on the entries and seeds. `MODE` adds the rules of accept and deliver. `task vet ID=0013 MODE=accept -- --openspec` also runs `openspec validate` (accept and deliver mode only); add `--strict` for `--strict`. |
| `task new SLUG=foo TITLE="Foo Bar" SUMMARY="OPM gains X." CATEGORY=tooling AFFECTS=core,cli` | Take the lowest free id and make a draft entry with `openspec new change --schema enhancement`. |
| `task seed:new CAP=registration-acceptance` | Make the seed change `seed-registration-acceptance`. |
| `task accept ID=0013` | Check a draft in accept mode. Print the sample and the collision list. Then `CONFIRM=1 task accept ID=0013` writes `status: accepted` and `accepted:`. For a seed, it writes `sampled:`. The plain run comes first, always. |
| `task resample ID=0013` | The same for an accepted entry whose requirements changed. `CONFIRM=1` rewrites `accepted:`. |
| `task deliver ID=0013` | Refuse an unticked line or a stale flag. Set `status: delivered`, archive with OpenSpec, run `task index` and make one commit. Only a delivery changes `openspec/specs/`. |
| `task reject\|withdraw ID=0013 REASON="..."` | End a draft (reject) or a draft or accepted entry (withdraw). Write the record and archive with `--skip-specs`. |
| `task supersede ID=0013 BY=0033 REASON="..."` | End an entry that one or more others replace. `BY` is a comma-separated list. |
| `task tick ID=0013 LINE=1.1 REF=change-name` | Tick one line of `tasks.md` and append `(REF)`. `REF` is a change name, `PR <n>` or `commit <sha>`. |
| `task index` / `task fresh` | Write `README.md` of each entry, `INDEX.md` and `GRAPH.md` / fail when one is missing or stale. |
| `task links` | Check the links in the entries and the generated files. Fail on a broken link or a path link between entries. |
| `task list [-- --archived]`, `task show ID=0013`, `task questions ID=0013`, `task stale ID=0013`, `task history REQ="Name"` | Read-only views: entries, the facts of one, its open questions, its stale-base flags, the history of a requirement. |
| `task reconcile` | Compare the `Delivers` lines of the sibling repos with the ticks of `tasks.md`. Needs sibling checkouts. |
| `task cite-lint` | Flag decision numbers and lone ids in Go and CUE comments. |
| `task test` | The checker's own tests: `go test` of `tools/enh` and the `tests/schema` fixtures. Not part of `task check`. CI runs it as the `test` job. The specs rule tests skip without the pinned openspec CLI on `PATH`. |
| `task specs-rule [BASE=ref]` | The CI rule for `openspec/specs/`: one delivery, one seed or a Purpose correction. Needs the pinned openspec CLI and full git history. |
| `task ideas` | List open idea issues on GitHub (needs `gh`). |
| `task docs:bundle` / `task docs:bundle:check` | Build the enhancements bundle into `out/enhancements/` / build and lint it without writing `out/`. |
| `task docs:pins:check` | Refuse a docs-kit `publish.yml` ref that names another release than `.opm-docs-version` (offline; CI runs it). |
| `task tools:opm-docs` | Install or reuse `.bin/opm-docs`, the release `.opm-docs-version` names. |

## Lifecycle

```text
draft --> accepted --> delivered
  |          |
  +----------+--> rejected (draft only), withdrawn, superseded
```

| Step | Command | What happens |
| --- | --- | --- |
| Admit | none | Decide whether the idea is an entry. Run `task list -- --archived` to see rejected and withdrawn entries. An idea that is not ready is an issue labelled `idea`. |
| Draft | `task new` | A draft entry with `proposal.md` and `design.md` to write. |
| Accept | `task accept`, then `CONFIRM=1 task accept` | The human reads the sample and the collision list. Then the command writes `accepted:`. The human merges the PR. |
| Edit while accepted | `task resample` | Review the edited requirements, then confirm. |
| Deliver | `task tick` per line, then `task deliver` | Each repo delivers its line in its own change. A tick PR records it. When every line is ticked, `task deliver` archives the entry. |
| End without delivery | `task reject`, `task withdraw`, `task supersede` | Archive with a reason. The deltas never reach `openspec/specs/`. |

## Pitfalls

- Running `CONFIRM=1 task accept` first: run the plain command first, read the sample and the collision list, then confirm.
- Ticking a task line in the delivering PR of the other repo: tick it in a later PR on this repo.
- Editing a generated file to fix `task fresh`: run `task index`.
- Running `task specs-rule` on a shallow clone: it needs full git history.

## Check before you finish

- [ ] `task check` passes.
- [ ] After a `config.yaml` change, `task index` ran and the generated files are in the commit.
- [ ] After a requirement edit of an accepted entry, `task resample` ran and was confirmed.
