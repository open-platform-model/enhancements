# Enhancements repository guide

This repo holds OPM enhancement entries. An entry is the design of one feature that lands in one or more OPM repos. It states what consumers can rely on. It does not tell a repo how to build it.

The repo is an OpenSpec store. One entry is one OpenSpec change, `openspec/changes/<id>-<slug>/`. The delivered behaviour of OPM is `openspec/specs/`. A Go program, `enh` (in `tools/enh/`), and a thin `Taskfile.yml` check the rules below.

## Branch model

Work lands on `main` by pull request.

## Repository rules

Violations fail PR review, even where `task vet` does not catch them. The `enhancements` skill carries the workflow and the reasons for the steps.

- **One feature, one id, one folder.** The id has four digits. It is never reused and never renumbered. The ids 0000, 0028 and 0029 are reserved, and the CUE schema at the repo root lists them. The blocked list in that schema is empty.
- **`config.yaml` holds facts only.** Id, slug, title, summary, status, category, breaking, affects, authors, created, after, and the end-state records (`accepted`, `rejected`, `withdrawn`, `superseded_by`). There is no history field: history is `git log`. `status` is stored, and the checker refuses a value that disagrees with the folder.
- **`openspec/specs/` holds delivered work only.** It changes in exactly three cases: an entry is delivered, a seed is delivered, or a PR corrects a `## Purpose` and nothing else. Until then, the requirements of an entry live in its own delta specs. CI enforces this.
- **Nothing is implemented here.** `tasks.md` lists which repo still has work. The repo delivers its line in its own OpenSpec change, whose proposal says `Delivers NNNN, task X.Y.`. A tick is a PR on this repo.
- **A requirement is observable from outside one repo.** The admission test: no Go symbol, no CLI flag and no file path in a requirement. A published CUE definition may be named. An internal definition may not. Every requirement has a `SHALL` or `MUST` sentence and at least one scenario.
- **The design has themes, not numbered decisions.** Point at a theme by its heading. Do not write `D4` or `0013:D4` in a new entry. The proposal has no decision numbers and no requirement ids.
- **Cite an entry by its id, in words.** A link from one entry to another entry's folder is an error, because archive moves a folder. In code in other repos, write the id beside the reason: `// Rewrite each secret to a reference, so plaintext never reaches the render (enhancement 0013).` Never an id alone.
- **An entry never prescribes mechanism.** It never says how a repo names a file, spells an identifier, lays out a directory or structures code. Naming a path as evidence is fine. Naming one as an instruction is not. Test: would deleting the path change what an implementer must do, or only what a reader can verify?
- **Word caps are advice.** Proposal about 300 words, design about 1,500, all three of proposal, design and requirement text about 3,000. The checker warns and never refuses.
- **An accepted entry stays editable, with a re-sample.** After an edit to a requirement, run `task resample`, read what it prints, then run `CONFIRM=1 task resample ID=0013`. The checker refuses the edit in a PR until then. Edits to `proposal.md` and `design.md` need only PR review.
- **A closed entry is not edited.** An archived folder under `openspec/changes/archive/` changes only by the regeneration of its `README.md`. The checker refuses any other change.
- **Generated files are never edited by hand.** `README.md` of each entry, `INDEX.md` and `GRAPH.md` come from `task index`. `task fresh` fails when one is stale.
- **Evidence is outside every cap.** `evidence/` holds notes, experiments, research and compilable CUE, cited and dated, and the sentence it supports points at it. It has a `README.md` with one line per file. CUE modules in it keep their `cue.mod` and are run through `cue vet` as a warning. This keeps the design short.
- **The ten old-layout entries are frozen.** 0001, 0002, 0003, 0006, 0010, 0011, 0015, 0016, 0018 and 0019 stay in `archive/NNNN/` at the repo root, outside `openspec/`. Cite them by id. Do not edit them.
- **Don't hard-wrap prose in `.md` files.**
- **A human owns the intent.** The proposer owns `proposal.md` word for word. An agent drafts only from what the proposer said, and changes it only on their instruction.
- **Sequencing constraints are design prose.** State what must exist before what, and why, in a theme of `design.md`. Do not write a plan. `tasks.md` is advice on order, not a schedule.
- **Run `task vet` after any edit under an entry, and `task check` before a PR.** Run `task index` after any `config.yaml` change, and after any edit that changes a generated file.

## Source of truth precedence

When guidance conflicts, the most specific source wins: target-repo skill, then the `enhancements` skill, then target-repo `AGENTS.md`, then this `AGENTS.md`, then the workspace root `AGENTS.md`. The workspace root `CONTEXT.md` governs cross-repo routing, and its layout lists the repos that the `affects` list may use. Each target repo's own `AGENTS.md` governs its source code. When a change touches `core/`, the `core-schema-edit` skill of that repo is the binding protocol for SPEC.md co-updates.

## Layout

```text
openspec/specs/            Delivered behaviour, one folder per capability
openspec/schemas/          Schema and templates of an entry and of a seed
openspec/changes/          One folder per live entry (draft or accepted), one per seed (seed-<capability>)
openspec/changes/archive/  Closed entries: delivered, rejected, superseded or withdrawn
archive/                   The ten old-layout entries; frozen
references/                Detail files
tools/enh/                 The Go program behind the tasks
tests/schema/              Fixtures for the CUE schema of config.yaml
.tasks/                    Script fragments of the Taskfile
.github/                   CI workflows and the idea issue template
.claude/skills/            Repo-local skills
```

At the root: `README.md` (what an entry is and how to read and write one), the generated `INDEX.md` and `GRAPH.md`, the CUE schema of `config.yaml` (it holds the repo list, the reserved ids and the blocked ids), `Taskfile.yml`, `docs-kit.cue` (the docs bundle config) and `.opm-docs-version` (the docs-kit release that builds the bundle).

The docs bundle `enhancements` is published to `ghcr.io/open-platform-model/docs/enhancements` by docs-kit. The docs workflow checks every pull request and publishes each push to `main` as `edge`. A section has no release, so what `main` holds is what the site shows after its next build. The build never relaxes the page-dialect lint, so a page it refuses fails the check, and the fix goes in the entry's source. `.opm-docs-version` and every `publish.yml` ref in the workflows name the same docs-kit release and move in one PR.

## Commands

All tasks run from `enhancements/` (`cd enhancements && task <name>`) or from the workspace root (`task enhancements:<name>`). Each is a one-line call to `enh`. `enh help` lists every flag.

| Command | What it does | When |
| --- | --- | --- |
| `task check` | `vet`, `links`, then `fresh`. CI runs the same, plus the specs rule and the docs checks. | Before a PR |
| `task vet [ID=0013]` | Every checker rule on the entries and seeds. | After any edit under an entry |
| `task index` | Write the generated files. | After a `config.yaml` change |
| `task fresh` | Fail when a generated file is missing or stale. | Before a PR |
| `task links` | Fail on a broken link or a path link between entries. | Before a PR |
| `task test` | The checker's own tests. Not part of `task check`. | After a change to `tools/enh/` |

The other tasks (new, accept, resample, deliver, end an entry, tick, read-only views, docs bundle) are listed by `task --list`.

@CONTEXT.md
