# OPM Enhancements

Design proposals for the Open Platform Model (OPM). Before a significant change lands in any OPM repo, its design is written up here first, as one numbered entry.

This repo is a design record, not a task tracker. It says what OPM will do and why. Each repo decides how to build it.

## Start here

| You want to | Do this |
| --- | --- |
| See what exists | Open [`INDEX.md`](INDEX.md), or run `task list` |
| Understand one entry | Follow [Reading an enhancement](#reading-an-enhancement) |
| Propose a change | Follow [Proposing an enhancement](#proposing-an-enhancement) |
| Record that a change landed | Run `task tick`; see [Delivery](#delivery) |
| Check your edits before a PR | Run `task check` |

All `task` commands run from this directory. From the workspace root, prefix them: `task enhancements:list`.

## What an enhancement is

- One significant change to OPM: schema, kernel, catalog, controller, CLI, docs, or several of those together.
- One feature, one id, one folder, however large. The id has four digits and is never reused.
- An OpenSpec change in `openspec/changes/<id>-<slug>/`. The title lives in its `config.yaml`.
- A contract, not a build plan. It states what consumers can rely on. It never tells a repo how to name files or structure code.

An idea that is not ready to be an entry goes in a GitHub issue labelled `idea`. Use the [issue form](.github/ISSUE_TEMPLATE/idea.yml). `task ideas` lists the open ones.

## Reading an enhancement

1. Pick an entry in [`INDEX.md`](INDEX.md).
1. Read its `README.md`: the summary, the status and what is still to do.
1. Read `proposal.md`, then `design.md`, then `specs/` as far as you need.

| File | Answers |
| --- | --- |
| `proposal.md` | What changes, and why. Two minutes. Ends with its open questions |
| `design.md` | How it works, and why this way: one diagram, themes, risks, rejected options |
| `specs/<capability>/spec.md` | Exactly what must hold: requirements, each with a scenario |
| `tasks.md` | Which repo still has work |
| `evidence/` | The proof: notes, experiments, research, compilable CUE |
| `config.yaml` | The facts: id, status, category, affects, dates |

The `README.md` of an entry is generated. Do not edit it.

A design has themes, not numbered decisions. Point at a theme by its heading. A requirement has a name, not a number. Cite another entry by its id, in words: "enhancement 0013".

## Proposing an enhancement

Make the entry:

```bash
task new SLUG=platform-context TITLE="Platform Context" \
  SUMMARY="Platforms project a typed context that modules read at render time." \
  CATEGORY=schema AFFECTS=core,library
```

| Argument | What to write |
| --- | --- |
| `SLUG` | Short kebab-case name |
| `TITLE` | Human-readable title, at most 80 characters |
| `SUMMARY` | One line, at most 200 characters: the capability OPM will have and does not have today |
| `CATEGORY` | The one dominant type of work: `schema`, `runtime`, `distribution`, `tooling` or `misc` |
| `AFFECTS` | Comma-separated repos that ship changes. The list is `#EntryRepo` in `schema.cue` |

If you cannot write `SUMMARY` in one line, the idea is not ready. File an idea issue instead.

Then, in order:

1. Write `proposal.md` in plain words. Mark each open question `- Blocking:` or `- Not blocking:`.
1. Write `design.md`: one diagram, a few themes, risks and rejected options.
1. Write the delta specs under `specs/`. Every requirement has a `SHALL` or `MUST` sentence and a scenario.
1. Write `tasks.md`: one line per repo change.
1. Run `task check` until it is quiet.
1. Accept the entry: run `task accept ID=NNNN`, read the sample and the collision list, then run `CONFIRM=1 task accept ID=NNNN`.

Agents load [`.claude/skills/enhancements/SKILL.md`](.claude/skills/enhancements/SKILL.md) before step 1. It is the binding workflow.

## Lifecycle

```text
draft --> accepted --> delivered
  |          |
  +----------+--> rejected (draft only), withdrawn, superseded
```

| Status | Meaning | Where | Set by |
| --- | --- | --- | --- |
| `draft` | Being written. Everything may change. | `openspec/changes/` | `task new` |
| `accepted` | The owner agreed the design. The entry stays editable, and an edited requirement needs a re-sample. | `openspec/changes/` | `task accept` |
| `delivered` | Every task line is ticked. The delta specs now reach `openspec/specs/`. | `openspec/changes/archive/` | `task deliver` |
| `rejected` | A draft that was not accepted, with a reason. | `openspec/changes/archive/` | `task reject` |
| `withdrawn` | A draft or accepted entry the owner stopped, with a reason. | `openspec/changes/archive/` | `task withdraw` |
| `superseded` | Replaced by one or more newer entries, which name it. | `openspec/changes/archive/` | `task supersede` |

An archived folder gets a date prefix: `<YYYY-MM-DD>-<id>-<slug>`. The id is kept forever, so a citation keeps resolving. The ten entries of the old layout (0001, 0002, 0003, 0006, 0010, 0011, 0015, 0016, 0018 and 0019) sit in `archive/NNNN/`, outside `openspec/`.

## Delivery

An entry never stores "done". Its `tasks.md` has one line per repo change:

```markdown
- [ ] 2.1 core: A package refuses a literal secret.
```

Each repo delivers its line in its own OpenSpec change. That change's proposal says which line it delivers, in a section `## Enhancement`:

```markdown
Delivers 0013, task 2.1.
```

When the change is archived, tick the line in a PR on this repo:

```bash
task tick ID=0013 LINE=2.1 REF=change-name
```

`REF` is the change name without its date, `PR <n>` for a repo with no OpenSpec change, or `commit <sha>`. When every line is ticked, run `task deliver ID=0013`. It validates, archives and indexes the entry in one commit. Only a delivery changes `openspec/specs/`. `task reconcile` compares the `Delivers` lines of the sibling repos with the ticks.

A seed is the other way into `openspec/specs/`. `task seed:new CAP=name` makes a change `seed-name` that records behaviour OPM already ships, so a later entry can modify it. A seed has no number.

## Checks

- `task vet` is the hard gate. It checks every `config.yaml` against `schema.cue`, the shape of each file and the requirements, and it blocks a PR. Most rules get stricter in accept and deliver mode. It runs `cue vet` on the CUE modules in `evidence/` as a warning.
- `task links` fails on a broken link or a path link between entries.
- `task fresh` fails when `README.md` of an entry, `INDEX.md` or `GRAPH.md` is stale.
- `task check` runs the three in that order.
- `task specs-rule` is the CI rule for `openspec/specs/`. It is not part of `task check`, because it needs the PR base and the OpenSpec CLI.

Run `task check` before you open a PR. Run `task index` after any edit under an entry that changes its `config.yaml`, `proposal.md`, `design.md`, `tasks.md`, or whether it has `specs/` or `evidence/`.

## Commands

| Command | Purpose |
| --- | --- |
| `task list`, `task show ID=NNNN` | Status table; the facts of one entry |
| `task new ...`, `task seed:new CAP=name` | Make an entry; make a seed |
| `task check`, `task vet` | The gate; the checker alone |
| `task accept ID=NNNN`, `task resample ID=NNNN` | Accept a draft; re-sample an accepted entry. `CONFIRM=1` writes |
| `task tick`, `task deliver ID=NNNN` | Tick a line; deliver the entry |
| `task reject`, `task withdraw`, `task supersede` | End an entry without delivery, with a reason |
| `task index`, `task fresh`, `task links` | Write the generated files; check them; check links |
| `task questions ID=NNNN`, `task stale ID=NNNN`, `task history REQ="Name"` | Open questions; stale-base flags; the history of a requirement |

`task --list` shows the rest. `AGENTS.md` has the full table.

## Layout

```text
enhancements/
├── README.md               this file
├── AGENTS.md               repository rules and agent orientation
├── INDEX.md                generated: every entry with status and summary
├── GRAPH.md                generated: Mermaid diagrams of how entries relate, one per category
├── schema.cue              what config.yaml may contain; the repo list; reserved ids
├── Taskfile.yml            the task commands
├── docs-kit.cue            the site bundle
├── tools/enh/              the Go program behind the tasks
├── tests/schema/           fixtures for schema.cue
├── .github/                ci.yml, docs.yml, ISSUE_TEMPLATE/idea.yml
├── .claude/skills/         the workflow protocols agents follow
├── archive/NNNN/           the ten old-layout entries, frozen
└── openspec/
    ├── config.yaml         the rules of the store
    ├── schemas/            the enhancement and seed schemas, with templates
    ├── specs/              delivered behaviour, one folder per capability
    └── changes/
        ├── <id>-<slug>/    one live entry
        │   ├── .openspec.yaml
        │   ├── config.yaml     the facts
        │   ├── README.md       generated
        │   ├── proposal.md
        │   ├── design.md
        │   ├── specs/<capability>/spec.md
        │   ├── tasks.md
        │   └── evidence/       proof; README.md has one line per file
        ├── seed-<capability>/  a seed: source.md and an ADDED-only spec
        └── archive/<date>-<id>-<slug>/   a closed entry
```

## Glossary

| Term | Meaning |
| --- | --- |
| Entry | One enhancement: the folder `openspec/changes/<id>-<slug>/` and everything in it |
| Capability | A lasting area of behaviour, such as "secrets". It has one folder in `openspec/specs/` |
| Requirement | One `SHALL` statement a consumer can observe, with at least one scenario |
| Delta spec | The requirements an entry adds, modifies, removes or renames, kept in the entry until delivery |
| Seed | A change that records behaviour OPM already ships, so an entry can modify it |
| Sample | The requirements a human reads at accept: every modified and removed one, and a random share of the added ones |
| Re-sample | The same review after an accepted entry's requirements change |
| Tick | A checked line of `tasks.md`, ending with the name of the repo change that delivered it |

## Where the full rules live

- [`AGENTS.md`](AGENTS.md): repository rules and agent orientation.
- [`.claude/skills/enhancements/SKILL.md`](.claude/skills/enhancements/SKILL.md): the binding workflow, step by step.
- [`openspec/config.yaml`](openspec/config.yaml): the rules of the store, by artifact.
- [`schema.cue`](schema.cue): the metadata contract, with rationale in comments.
- Sibling skills under `.claude/skills/`: `enhancement-experiments`, `enhancement-diagrams`.

## Related repos

The `affects` values map to workspace repos:

| Value | Repo | What it is |
| --- | --- | --- |
| `core` | `core/` | The OPM schema, pure CUE, `opmodel.dev/core@v2` |
| `library` | `library/` | The Go kernel that implements the schema |
| `catalog_opm` | `catalog_opm/` | Resources, traits, blueprints and transformers |
| `cli` | `cli/` | The `opm` command |
| `opm-controller` | `opm-controller/` | The Kubernetes controller |
| `opmodel.dev` | `opmodel.dev/` | The public docs site |
| `modules` | `modules/` | Workspace OPM module definitions |
| `opm` | `opm/` | The meta repo: authored documentation prose, internal specs, benchmarks |
| `opm-portal` | `opm-portal/` | The web portal: a versioned read API with an HTMX UI over OPM modules and instances |
| `docs-kit` | `docs-kit/` | The tool that builds each repo's docs into a signed bundle |
| `enhancements` | `enhancements/` | This repo |
| `opm-suite-installer` | `opm-suite-installer/` | A proof of concept that installs a suite of applications from one container image |
| `.github` | `.github/` | The org meta repo |

`opm-operator` is the former name of the `opm-controller` repo. The schema still accepts it, because closed entries cannot be edited and nine of them list it. A new entry lists `opm-controller`.

Delivery crosses several of these. The design of an entry states what must land before what.
