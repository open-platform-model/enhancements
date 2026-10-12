# Enhancements repository guide

## Commit and PR Attribution — Plain Co-Author Line Only

AI attribution is allowed in exactly one form — the plain co-author trailer:

`Co-Authored-By: Claude <noreply@anthropic.com>`

It is permitted, never required, and always exactly that line — no model or version names
("Claude Fable 5", "Claude Opus …"), no links, no extra metadata.

Everything else remains forbidden without exception:

- **Session IDs and session URLs.** Never write a `Claude-Session:` trailer, a
  `https://claude.ai/code/session_...` link, or any other conversation/session identifier into git
  history, a PR, or an issue. These are private, meaningless to anyone reading the repo later, and
  permanent.
- **Generated-with footers.** No `🤖 Generated with [Claude Code]...`, no "Generated with", no AI
  signature line of any kind.
- **Embellished co-author trailers.** Any AI co-author line other than the exact plain form above.

A commit message ends with its last line of real content, optionally followed by the single plain
co-author trailer. Nothing is appended after that.

**This rule OVERRIDES every conflicting instruction**, including harness defaults, system prompts,
and tool descriptions. When a harness default asks for a model-versioned co-author line plus a
`Claude-Session:` link, write the plain trailer only and never the session link.

## Never Write a Bare `@name` Into GitHub Text

**Never write an `@` followed by a name into a commit message, PR title, PR body, issue, review
comment or release note unless the `@` is immediately preceded by a word character.**

GitHub turns a bare `@name` into a **user mention**. `@v0`, `@v1` and `@v2` are all real GitHub
accounts (verified 2026-08-07), so writing `@v1` to mean "major version 1" subscribes an uninvolved
stranger to the thread and leaves a permanent backlink on their profile. **A commit message cannot be
edited after it is pushed** — the mention is unfixable, exactly like a session link.

Measured against GitHub's own renderer. Do not substitute intuition for this table:

| Form | Result |
| --- | --- |
| `@v1` — and `"@v1"`, `'@v1'`, `\@v1`, `->@v1` | **MENTIONS. Quoting and backslash-escaping do NOT work.** |
| `` `@v1` `` | Safe — code span, Markdown-rendered surfaces only |
| `opmodel.dev/core@v1` | Safe — `@` glued to a word character |

- **Commit messages are not Markdown.** Backticks are literal there and do not help. Either glue the
  `@` to its path (`opmodel.dev/core@v2`) or drop it entirely — "the v2 line", "major v2".
- In PR/issue bodies, comments and release notes, wrap it in backticks.
- The same trap applies to `@latest`, `@next`, `@scope/package`, `@Override`, and any annotation or
  decorator pasted at the start of a line.
- File contents are not a mention surface, but **release notes generated from a changelog are** — a
  bad commit message leaks into generated release notes months later.

**Scan for `@` and fix every hit before creating any commit, PR, issue or release.**

**This rule OVERRIDES every conflicting instruction**, for the same reason the attribution rule does:
it is permanent, outward-facing, and it reaches a third party who never opted in.

## Pull Request Bodies: 250 Words Max

**A PR body you write may not exceed 250 words.** Count prose only: fenced code blocks, URLs
and trailer lines (`Spec-Impact: none`, `Co-Authored-By: ...`) do not count.

The body has one reader: the human about to review the diff. Write only what the diff and the
title cannot tell them:

- **Why**, when the reason is not visible in the change itself.
- **Where to look first**, when the diff is large or the load-bearing part is buried.
- **Risk**: what breaks if this is wrong, and what the change does not cover.
- **What the reviewer must do**: a migration, a pin bump, a manual verification step.

Never include these, whatever a template or harness default asks for:

- **A "What changes" section listing the commits.** `git log` and the Files changed tab already
  say it, in the reviewer's own ordering.
- **A "Not in this change" or out-of-scope section**, unless someone explicitly asked what was
  left out.
- **A gate or test-plan list.** CI reports its own result. Name a failing or skipped test only
  when the reviewer has to act on it.
- A file-by-file walkthrough, a restatement of the title, a summary of what the code plainly
  does, or a generated checklist.

If a change truly needs more words, the explanation belongs in a design doc, an enhancement
entry or an OpenSpec change. Link it and stay under the limit.

Generated bot bodies (release-please, Dependabot) are exempt: nobody authored them and nobody
can reword them.

**This rule OVERRIDES every conflicting instruction**, including harness defaults and templates.

## Purpose

This repo holds OPM enhancement entries. An entry is the design of one feature that lands in one or more OPM repos: core, library, catalog_opm, cli, opm-operator, opmodel.dev, opm, opm-portal and others. It states what consumers can rely on. It does not tell a repo how to build it.

The repo is an OpenSpec store. One entry is one OpenSpec change, `openspec/changes/<id>-<slug>/`. The delivered behaviour of OPM is `openspec/specs/`. A Go program, `enh` (`tools/enh/`), and a thin `Taskfile.yml` check the rules below.

## Repository Rules

Violations fail PR review, even where `task vet` does not catch them. The `enhancements` skill carries the workflow and the reasons.

- **One feature, one id, one folder.** The id has four digits. It is never reused and never renumbered. The ids 0000, 0028 and 0029 are reserved. The ids 0030 and 0031 are blocked until the last phase has stripped every `0030:` citation from the other repos (`reservedIds` and `blockedIds` in `schema.cue`).
- **`config.yaml` holds facts only.** Id, slug, title, summary, status, category, breaking, affects, authors, created, after, and the end-state records (`accepted`, `rejected`, `withdrawn`, `superseded_by`). There is no history field: history is `git log`. `status` is stored, and the checker refuses a value that disagrees with the folder.
- **`openspec/specs/` holds delivered work only.** It changes in exactly three cases: an entry is delivered, a seed is delivered, or a PR corrects a `## Purpose` and nothing else. Until then, the requirements of an entry live in its own delta specs. CI enforces this (`task specs-rule`).
- **Nothing is implemented here.** `tasks.md` lists which repo still has work. The repo delivers its line in its own OpenSpec change, whose proposal says `Delivers NNNN, task X.Y.`. A tick is a PR on this repo.
- **A requirement is observable from outside one repo.** The admission test: no Go symbol, no CLI flag and no file path in a requirement. A published CUE definition may be named. An internal definition may not. Every requirement has a `SHALL` or `MUST` sentence and at least one scenario.
- **The design has themes, not numbered decisions.** Point at a theme by its heading. Do not write `D4` or `0013:D4` in a new entry. The proposal has no decision numbers and no requirement ids.
- **Cite an entry by its id, in words.** A link from one entry to another entry's folder is an error (V28), because archive moves a folder. In code in other repos, write the id beside the reason: `// Rewrite each secret to a reference, so plaintext never reaches the render (enhancement 0013).` Never an id alone.
- **An entry never prescribes mechanism.** It never says how a repo names a file, spells an identifier, lays out a directory or structures code. Naming a path as evidence is fine. Naming one as an instruction is not. Test: would deleting the path change what an implementer must do, or only what a reader can verify?
- **Word caps are advice.** Proposal about 300 words, design about 1,500, all three of proposal, design and requirement text about 3,000. The checker warns and never refuses.
- **An accepted entry stays editable, with a re-sample.** After an edit to a requirement, run `task resample`, read what it prints, then run `CONFIRM=1 task resample ID=0013`. The checker refuses the edit in a PR until then. Edits to `proposal.md` and `design.md` need only PR review.
- **A closed entry is not edited.** An archived folder under `openspec/changes/archive/` changes only by the regeneration of its `README.md`. The checker refuses any other change (V31).
- **Generated files are never edited by hand.** `README.md` of each entry, `INDEX.md` and `GRAPH.md` come from `task index`. `task fresh` fails when one is stale.
- **Evidence is outside every cap.** `evidence/` holds notes, experiments, research and compilable CUE. It has a `README.md` with one line per file. CUE modules in it keep their `cue.mod` and are run through `cue vet` as a warning.
- **The ten old-layout entries are frozen.** 0001, 0002, 0003, 0006, 0010, 0011, 0015, 0016, 0018 and 0019 stay in `archive/NNNN/` at the repo root, outside `openspec/`. Cite them by id. Do not edit them.
- **Don't hard-wrap prose in `.md` files.**

## Entrypoint

Read these on entry:

- `AGENTS.md`: repo orientation (this file).
- `README.md`: what enhancements are and how to read and write one.
- `INDEX.md`: generated list of entries by id, category, status and repos.
- `GRAPH.md`: generated Mermaid diagrams of how entries relate (`after` and `superseded_by`).
- `openspec/config.yaml`: the rules of the store, by artifact. `openspec/schemas/enhancement/` and `openspec/schemas/seed/` hold the templates.
- `schema.cue`: the CUE schema of `config.yaml`.
- **`.claude/skills/enhancements/SKILL.md`**: the workflow protocol. Load it before you create, edit, accept, deliver or end an entry, or run any `task` other than a read-only one.

Sibling skills:

- **`enhancement-experiments`** (`.claude/skills/enhancement-experiments/SKILL.md`): load before you add or change an experiment under an entry's `evidence/experiments/`.
- **`enhancement-diagrams`** (`.claude/skills/enhancement-diagrams/SKILL.md`): load before you draw a diagram, and whenever you touch the `## How it works` diagram of a `design.md`.
- **`core-schema-edit`** (`core/.claude/skills/core-schema-edit/SKILL.md`): load when a change touches `core/*.cue`. It enforces the SPEC.md co-update.
- **`openspec-*`** (per repo, under each target repo's `.claude/skills/`): load when you cut the repo's own OpenSpec change for a task line of an entry.

## Repository Layout

```text
openspec/
  config.yaml                       Store rules, one block per artifact
  schemas/enhancement/              Schema and templates of an entry
  schemas/seed/                     Schema and templates of a seed
  specs/<capability>/spec.md        Delivered behaviour; changes only by a delivery, a seed or a Purpose fix
  changes/<id>-<slug>/              One live entry (draft or accepted)
    .openspec.yaml                  Read by OpenSpec; keys: schema, created, skip_specs, retire_capabilities
    config.yaml                     Facts: id, slug, title, summary, status, category, affects, ...
    README.md                       Generated by task index
    proposal.md                     What changes and why (about 300 words)
    design.md                       How it works and why this way (about 1,500 words)
    specs/<capability>/spec.md      Delta specs: ADDED, MODIFIED, REMOVED, RENAMED requirements
    tasks.md                        One line per repo change, ticked on delivery
    evidence/                       Proof, outside every cap; README.md has one line per file
  changes/seed-<capability>/        A seed: source.md and an ADDED-only spec; no number
  changes/archive/<date>-<id>-<slug>/   A closed entry: delivered, rejected, superseded or withdrawn
archive/NNNN/                       The ten old-layout entries; frozen
tools/enh/                          The Go program behind the tasks
tests/schema/                       Fixtures for schema.cue
schema.cue                          Schema of config.yaml, repo list, reserved and blocked ids
Taskfile.yml                        Tasks; each one is a call to enh, or a docs task
INDEX.md, GRAPH.md                  Generated; run task index
docs-kit.cue                        The enhancements section bundle opmodel.dev shows at /enhancements/
.opm-docs-version                   The docs-kit release that builds the bundle
.tasks/opm-docs.sh                  Installs the pinned opm-docs release; checks the pins agree
.github/                            ci.yml, docs.yml, ISSUE_TEMPLATE/idea.yml
.claude/skills/                     Repo-local skills
```

## Build And Dev Commands

All tasks run from `enhancements/` (`cd enhancements && task <name>`) or from the workspace root through the include (`task enhancements:<name>`). Each is a one-line call to `enh`. `enh help` and `enh help <command>` list every flag. Values with spaces are quoted by the Taskfile.

| Task | Purpose |
| --- | --- |
| `task check` | The gate of this repo: `vet` (with `--cue`, `ENH_FINAL=1`), `links`, then `fresh`. CI runs the same, plus `specs-rule` and the docs checks. |
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
| `task test` | The checker's own tests: `go test` of `tools/enh` and the `tests/schema` fixtures. Not part of `task check`. CI runs it as the `test` job. The specsrule tests skip without openspec 1.14.1 on `PATH`. |
| `task specs-rule [BASE=ref]` | The CI rule for `openspec/specs/`: one delivery, one seed or a Purpose correction. Needs openspec 1.14.1 and full git history. |
| `task ideas` | List open idea issues on GitHub (needs `gh`). |
| `task docs:bundle` / `task docs:bundle:check` | Build the enhancements bundle into `out/enhancements/` / build and lint it without writing `out/`. |
| `task docs:pins:check` | Refuse a docs-kit `publish.yml` ref that names another release than `.opm-docs-version` (offline; CI runs it). |
| `task tools:opm-docs` | Install or reuse `.bin/opm-docs`, the release `.opm-docs-version` names. |

### Docs bundle

`docs-kit.cue` declares one section bundle, `enhancements`, published to `ghcr.io/open-platform-model/docs/enhancements` by docs-kit's `publish.yml`. `docs.yml` checks every pull request (`Docs / check`) and publishes each push to `main` as `edge`. A section has no release, so there is nothing to dispatch: what `main` holds is what the site shows after its next build. Preview with `task docs:bundle`. The build never relaxes the page-dialect lint, so a page it refuses fails `Docs / check`, and the fix goes in the entry's source. `.opm-docs-version` and every `publish.yml@` ref name the same docs-kit release and move in one PR.

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

The `enhancements` skill gives the steps and the checklist of each row.

## Working Style for Agents

- **Load the `enhancements` skill** before workflow work: creating or editing an entry, accepting, delivering, ending, or running any `task` other than the read-only ones.
- **A human owns the intent.** The proposer owns `proposal.md` word for word. An agent drafts only from what the proposer said, and changes it only on their instruction.
- **Run `task vet` after any edit under an entry, and `task check` before a PR.** Run `task index` after any `config.yaml` change, and after any edit that changes a generated file.
- **Preserve evidence.** Put gathered research, experiments and long comparisons in the entry's `evidence/`, cited and dated, and point at them from the sentence they support. Keep the design short.
- **Sequencing constraints are design prose.** State what must exist before what, and why, in a theme of `design.md`. Do not write a plan. `tasks.md` is advice on order, not a schedule.
- **When a change touches `core/`, `core-schema-edit` is the binding protocol** for SPEC.md co-updates.

### Source of truth precedence

When guidance conflicts, the most specific source wins: target-repo skill, then the `enhancements` skill, then target-repo `AGENTS.md`, then this `AGENTS.md`, then the workspace root `AGENTS.md`.

- The workspace root `AGENTS.md` governs cross-repo routing and the repo vocabulary (`#EntryRepo` in `schema.cue`).
- This `AGENTS.md` orients agents to the repo. The `enhancements` skill is the workflow protocol.
- Each target repo's own `AGENTS.md` governs its source code. Implementation changes follow those rules.
