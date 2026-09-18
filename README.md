# OPM Enhancements

Design proposals for the Open Platform Model (OPM). Before a significant change lands in any OPM repo, its design is written up here first, as one numbered entry.

This repo is a design record, not a task tracker. It says what OPM will do and why. Each repo decides how to build it.

## Start here

| You want to | Do this |
| --- | --- |
| See what exists | Open [`INDEX.md`](INDEX.md), or run `task list` |
| Understand one entry | Follow [Reading an enhancement](#reading-an-enhancement) |
| Propose a change | Follow [Proposing an enhancement](#proposing-an-enhancement) |
| Record that a change landed | Run `task delivery:log`; see [Delivery](#delivery) |
| Check your edits before a PR | Run `task vet`, then `task check` |

All `task` commands run from this directory. From the workspace root, prefix them: `task enhancements:list`.

## What an enhancement is

- One significant change to OPM: schema, kernel, catalog, operator, CLI, docs, or several of those together.
- One design question at its heart. Two questions means two entries.
- A folder named by a four-digit id, such as `0015/`. The id is never reused. The title lives inside the folder, in `config.yaml`.
- A contract, not a build plan. It states what consumers can rely on. It never tells a repo how to name files or structure code.

An idea that is not ready to be an entry goes in a GitHub issue labelled `idea`. Use the [issue form](.github/ISSUE_TEMPLATE/idea.yml). `task ideas` lists the open ones.

## Reading an enhancement

1. Pick an entry in [`INDEX.md`](INDEX.md).
1. Read its `README.md` for the summary and the scope.
1. Read the seven numbered documents in order.

| File | Answers |
| --- | --- |
| `01-problem.md` | What is wrong today, with a concrete example |
| `02-design.md` | What changes, and what deliberately does not |
| `03-decisions.md` | Each design choice, the alternatives, and why this one won |
| `04-graduation.md` | What must be true before the draft is accepted |
| `05-risks.md` | What could go wrong, and what this costs |
| `06-operational.md` | Rollout, versioning, rollback, cross-repo ordering |
| `07-questions.md` | What is still undecided |

Two notations appear everywhere:

- `D4` is decision 4 in `03-decisions.md`. `0010:D4` is decision 4 of entry 0010.
- `OQ9` is open question 9 in `07-questions.md`.

Decision and question numbers never change and are never reused, because other repos cite them. A retired number keeps a one-line tombstone saying where its content went.

An entry can also carry code and evidence, in folders the prose links to:

- `schemas/`: the proposed change to the core CUE schema. Present only when the entry changes `opmodel.dev/core`.
- `contracts/`: other compilable CUE, such as decision procedures or behaviour contracts.
- `experiments/`: runnable proofs of a design claim. Each has a README with hypothesis, setup, run steps and outcome.
- `research/`: external evidence the design rests on, cited and dated.

## Proposing an enhancement

Scaffold the entry:

```bash
task new SLUG=platform-context TITLE="Platform Context" \
  SUMMARY="Platforms project a typed context that modules read at render time" \
  NOT="a templating language; a runtime config store" \
  CATEGORY=schema AFFECTS=core,library
```

| Argument | What to write |
| --- | --- |
| `SLUG` | Short kebab-case name |
| `TITLE` | Human-readable title |
| `SUMMARY` | One line: the capability OPM will have and does not have today |
| `NOT` | One line: what this entry is explicitly not |
| `CATEGORY` | The one dominant type of work: `schema`, `runtime`, `distribution`, `tooling` or `misc` |
| `AFFECTS` | Comma-separated repos that ship changes: `core`, `library`, `catalog`, `cli`, `opm-operator`, `opmodel.dev`, `modules` |

Add `CORE_SCHEMA=true` when the entry changes the core CUE schema. That scaffolds `schemas/`. Add `ISSUE=<n>` when the entry grew out of an idea issue.

If you cannot write `SUMMARY` and `NOT` in one line each, the idea is not ready. File an idea issue instead.

Then, in order:

1. Write `01-problem.md` and `02-design.md` in full prose.
1. Add a decision to `03-decisions.md` each time you settle a design choice. Give every open question in `07-questions.md` a `Blocking:` line.
1. Run `task vet` and `task check` until both are quiet.
1. Run `task gate ID=NNNN`. Answer its questions with the `enhancement-gates` skill, which records the verdict. Then run `task promote ID=NNNN`.

Agents load [`.claude/skills/enhancements/SKILL.md`](.claude/skills/enhancements/SKILL.md) before step 1. It is the binding workflow.

## Lifecycle

```text
draft --> accepted --> delivered
  |          |
  v          v
rejected   superseded
```

| Status | Meaning | Set by |
| --- | --- | --- |
| `draft` | Being written. Decisions are edited in place. | `task new` |
| `accepted` | Design agreed. Decision bodies are now protected; a change is a new decision that amends an old one. | `task promote` |
| `delivered` | Every decision has landed and the design is closed. | `task close` |
| `rejected` | Killed, with a reason. A later entry may revive it. | `task reject` |
| `superseded` | Replaced by a newer entry, which names it. | `task supersede` |

`delivered`, `rejected` and `superseded` entries move to `archive/NNNN/`. The id is kept forever so citations keep resolving.

## Delivery

An entry never stores "done". It stores a log, `delivery.yaml`, with one line per change that landed: the date, a summary, the change's coordinates (an OpenSpec change, a PR or a commit), and the decision numbers it carried.

```bash
task delivery                                              # not-started | in-progress | implemented, per entry
task delivery ID=0015                                      # coverage for one entry
task delivery:log FROM=<archived-change-dir> SUMMARY="…"   # log a landed change
```

An entry counts as implemented when every live decision is carried by a logged change or excused in `no_work` with a reason. A forgotten log line under-reports; it can never produce a false "implemented". Load the `delivery-log` skill before logging.

## Checks

- `task vet` is the hard gate and blocks a PR. It validates every `config.yaml` against `schema.cue`, checks that cross-references resolve, compiles the CUE, refuses leftover placeholders, and checks that terminal entries sit in `archive/`.
- `task check` is the soft gate. It reports prose conventions per status, unresolved blocking questions, and dependencies cited in prose but not declared.

Run both before opening a PR. Run `task index` after editing any `config.yaml`, and `task graph` after changing `category`, `depends_on`, `amends`, `supersedes` or `revives`.

## Commands

| Command | Purpose |
| --- | --- |
| `task list` | Status table |
| `task show ID=NNNN` | Metadata, history and documents of one entry |
| `task new ...` | Scaffold an entry (see above) |
| `task vet` / `task check` | Hard gate / soft gate |
| `task gate ID=NNNN` / `task promote ID=NNNN` | Admission walk / draft to accepted |
| `task delivery` / `task delivery:log` | Derived delivery state / log a landed change |
| `task reject`, `task supersede`, `task close` | Move an entry to a terminal status |
| `task index` / `task graph` | Regenerate `INDEX.md` / `GRAPH.md` |

`task --list` shows the rest.

## Layout

```text
enhancements/
├── README.md               this file
├── CLAUDE.md               repository rules and agent orientation
├── INDEX.md                generated: every entry with status, delivery state and summary
├── GRAPH.md                generated: Mermaid diagrams of how entries relate, one per category
├── schema.cue              what config.yaml may contain
├── gates.cue               the six admission questions
├── Taskfile.yml            the task commands (list, new, vet, gate, promote, ...)
├── scripts/                helpers the tasks call (delivery state, dependency edges, entry hash)
├── .github/                ISSUE_TEMPLATE/idea.yml, the idea issue form
├── .claude/skills/         the workflow protocols agents follow
├── 0000/                   template; task new copies it
├── archive/                delivered, rejected and superseded entries; id kept forever
│   └── NNNN/               same layout as a live entry
└── NNNN/                   one entry per enhancement (id-only folder name)
    ├── config.yaml         metadata: id, slug, title, summary, status, category, affects, links, history
    ├── delivery.yaml       log of landed changes; task delivery derives the state from it
    ├── README.md           summary, document list, scope, cross-references
    ├── 01-problem.md       what is wrong today
    ├── 02-design.md        what changes
    ├── 03-decisions.md     the decision log (D1, D2, ...)
    ├── 04-graduation.md    what must hold before draft becomes accepted
    ├── 05-risks.md         risks, drawbacks, alternatives not taken
    ├── 06-operational.md   rollout, versioning, rollback, cross-repo ordering
    ├── 07-questions.md     the open-questions register (OQ1, OQ2, ...)
    ├── schemas/            core schema delta; only when config.yaml says core_schema: true
    │   ├── cue.mod/module.cue
    │   ├── target.cue      the proposed opmodel.dev/core definitions
    │   ├── examples.cue    concrete instances that must unify; the test (required from accepted)
    │   └── spec.md         the matching SPEC.md change for core (required from accepted)
    ├── contracts/          optional: other compilable CUE (procedures, behaviour contracts, taxonomies)
    │   ├── cue.mod/module.cue
    │   └── *.cue
    ├── experiments/        optional: runnable proofs of a design claim
    │   ├── README.md       index of experiments and their status
    │   └── NN-{concept}/   one folder per experiment, with its own README
    └── research/           optional: external evidence, cited and dated
        ├── findings.md     the primary dossier
        └── {topic}.md      further write-ups
```

## Glossary

| Term | Meaning |
| --- | --- |
| Entry | One enhancement: the folder `NNNN/` and everything in it |
| Decision (`DN`) | A numbered design choice in `03-decisions.md`, with alternatives and rationale |
| Open question (`OQN`) | A numbered unresolved point in `07-questions.md`, with a `Blocking:` line |
| Live decision | A decision whose number has not been retired to a tombstone |
| Delivery log | `delivery.yaml`: the record of changes that landed, per decision |
| Gate | A question an entry must answer before it is admitted or accepted; see `gates.cue` |
| Compaction | The controlled edit of an accepted entry's decision bodies, under the `enhancement-compaction` skill |

## Where the full rules live

- [`CLAUDE.md`](CLAUDE.md): repository rules and agent orientation.
- [`.claude/skills/enhancements/SKILL.md`](.claude/skills/enhancements/SKILL.md): the binding workflow, phase by phase.
- [`schema.cue`](schema.cue) and [`gates.cue`](gates.cue): the metadata contract and the admission rubric, with rationale in comments.
- [`0000/README.md`](0000/README.md): the template, which is the shape of an entry README and nothing else.
- Sibling skills under `.claude/skills/`: `delivery-log`, `enhancement-gates`, `enhancement-compaction`, `enhancement-open-questions`, `enhancement-experiments`, `enhancement-diagrams`.

## Related repos

The `affects` values map to workspace repos:

| Value | Repo | What it is |
| --- | --- | --- |
| `core` | `core/` | The OPM schema, pure CUE, `opmodel.dev/core@v2` |
| `library` | `library/` | The Go kernel that implements the schema |
| `catalog` | `catalog_opm/` | Resources, traits, blueprints and transformers |
| `cli` | `cli/` | The `opm` command |
| `opm-operator` | `opm-operator/` | The Kubernetes controller |
| `opmodel.dev` | `opmodel.dev/` | The public docs site |
| `modules` | `modules/` | Workspace OPM module definitions |

Delivery crosses several of these. `06-operational.md` in each entry states what must land before what.
