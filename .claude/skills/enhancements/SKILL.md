---
name: enhancements
description: Workflow protocol for the OPM enhancements repo. Load before you create an entry, edit anything under openspec/changes/ in enhancements (config.yaml, proposal.md, design.md, specs/, tasks.md, evidence/), accept, re-sample, deliver, reject, withdraw or supersede an entry, make a seed, tick a task line, or run any task other than a read-only one. Skip it only when you read an existing entry to learn it: open its README.md, then proposal.md and design.md.
user-invocable: true
---

# Enhancements Workflow

This skill is the protocol for the entries under `openspec/changes/` in the `enhancements` repo. `AGENTS.md` orients you and holds the rules. This skill gives the steps. The commands are `task` names, each a call to `enh` (`tools/enh/`). `enh help <command>` lists the flags of one.

## When this skill applies

Load it when you:

- make a new entry or a seed (`task new`, `task seed:new`);
- edit `config.yaml`, `proposal.md`, `design.md`, `specs/`, `tasks.md` or `evidence/` of an entry;
- accept or re-sample an entry, deliver it, or end it without delivery;
- tick a task line, or cut a change in another repo that delivers a line;
- run any `task` other than `list`, `show`, `questions`, `stale`, `history`, `links` or `fresh`.

Sibling skills:

- `enhancement-experiments`: load before you add or change an experiment in an entry's `evidence/experiments/`.
- `enhancement-diagrams`: load before you draw a diagram, and whenever you touch the `## How it works` diagram of a `design.md`.
- `core-schema-edit` (in `core/.claude/skills/`): load when a change touches `core/*.cue`.

## The shape of an entry

One entry is one OpenSpec change, `openspec/changes/<id>-<slug>/`. A human owns the intent. An agent writes the detail. The checker refuses what a rule forbids.

| File | Reader's question | Owner | Advice |
| --- | --- | --- | --- |
| `config.yaml` | What are the facts? | the human gives facts; commands write state | none |
| `README.md` | Where do I start? | `task index` (generated) | none |
| `proposal.md` | What changes, and why? | the proposer, word for word; an agent drafts only from the proposer's words | about 300 words |
| `design.md` | How does it work, and why this way? | the proposer decides; an agent drafts | about 1,500 words |
| `specs/<capability>/spec.md` | Exactly what must hold? | an agent writes; the human approves in the accept sample | with the total |
| `tasks.md` | Which repo still has work? | an agent writes and ticks | none |
| `evidence/` | What is the proof? | an agent or the human | none |

The total of proposal, design and requirement text is about 3,000 words. All caps are advice: the checker warns and never refuses. `openspec/config.yaml` states the rule for each file, and the templates are in `openspec/schemas/enhancement/templates/`. Read them before you write.

## Step 0: decide whether it is an entry

An entry is a new feature or the rework of one: something consumers can rely on that OPM does not give them today. It is not a chore, a dependency bump or a note to self. Run `task list -- --archived` first. If the idea restates a rejected or withdrawn entry, say what changed, in the new proposal's Why, and name the old id.

An idea that cannot yet name the capability becomes a GitHub issue labelled `idea` (`.github/ISSUE_TEMPLATE/idea.yml`). `task ideas` lists them.

## Step 1: make the draft

```bash
task new SLUG=my-slug TITLE="My Title" SUMMARY="OPM gains X." CATEGORY=schema AFFECTS=core,cli
```

`SLUG`, `TITLE`, `SUMMARY`, `CATEGORY` and `AFFECTS` are all required. The task takes the lowest free id, runs `openspec new change <id>-<slug> --schema enhancement`, writes `config.yaml` and runs `task index`. It refuses a used, reserved or blocked id and a slug that is not kebab-case. `AFFECTS` takes repo names from `#EntryRepo` in `schema.cue`, such as `catalog_opm`. Add `-- --author a@b.c` to set the authors.

## Step 2: write the entry

Write in this order, and run `task vet ID=NNNN` after each file.

1. **`proposal.md`.** The lede (three sentences at most), Why, What Changes (3 to 5 observable bullets), What this is not, Example, Capabilities, Impact, Open questions. Plain words. No decision numbers and no requirement ids. Capabilities name the link to `specs/`: every capability named has a delta spec, and every delta spec has a capability named. Read `openspec/specs/` first and reuse a capability before you create one. After the design and specs exist, read the proposal again and make sure it still agrees.
1. **`design.md`.** One explanation, top to bottom: How it works (one diagram of at most 7 boxes, three sentences at most), Design (at most 7 themes of about 120 words), Risks (one line each), Considered and rejected (one line each, at most 10). A theme is a lasting area, never a phase. Stances and policy live in a theme and need no requirement. No numbered decisions, no history ("we first tried"), no repo-level mechanism. Put long comparisons and measurements in a note in `evidence/` and link to it from the sentence it supports.
1. **`specs/<capability>/spec.md`.** Delta specs against `openspec/specs/`: ADDED, MODIFIED, REMOVED, RENAMED. The rules:
   - The requirement name is a plain statement of at most 8 words, with no numbers and no ids.
   - One `SHALL` or `MUST` sentence of at most 500 characters, and at least one `#### Scenario:` with WHEN and THEN.
   - The admission test: a consumer can observe it from outside one repo. No Go symbol, no CLI flag, no file path. A published CUE definition may be named. An internal definition may not.
   - An ADDED name is not already in `openspec/specs/`. A MODIFIED, REMOVED or RENAMED target is there. An entry that needs an undelivered entry stays a draft.
   - A MODIFIED requirement keeps its name and every scenario of the main spec that still holds. To reverse a shipped scenario, write a REMOVED whose `**Migration**` line reads `Replaced by "<new name>"`, and an ADDED under the new name.
   - A REMOVED has `**Reason**` and `**Migration**`.
   - A delta that creates a capability opens with a `## Purpose` of at least 50 characters that does not start with `TBD` or `TODO`.
   - An entry with no requirements has no `specs/` folder and sets `skip_specs: true` in `.openspec.yaml`. An entry with a `specs/` folder does not.
   - A REMOVED that takes the last requirement of a capability needs `retire_capabilities: true` in `.openspec.yaml`.
1. **`tasks.md`.** One line per repo change, under `## <n>. <Theme>`: `- [ ] <n>.<m> <repo>: <outcome>`. Name the outcome, never the method. The sections run in order, as advice. At accept, every repo in `affects` has a line.
1. **`evidence/`.** Anything that proves a claim. Keep a `README.md` with one line per file. A CUE module in it keeps its `cue.mod`, and `task vet` runs `cue vet` on it as a warning.

Do not write a key of your own in `.openspec.yaml`. OpenSpec ignores unknown keys and the checker refuses them. The keys in use are `schema`, `created`, `skip_specs` and `retire_capabilities`.

### Open questions

Each question in the proposal is one line, marked `- Blocking:` or `- Not blocking:`. `task questions ID=NNNN` prints them. To resolve them with the owner:

1. Take one question at a time. Give the context, the options with their cost, and a recommendation with its evidence.
1. Wait for the owner's answer. A question without an answer stays open.
1. Mark the line `- Answered: <answer>`, then move it into the `design.md` theme it settles and delete it from the proposal. A new theme is allowed if none fits.
1. Run `task vet ID=NNNN`.

Accept refuses while a `- Blocking:` or an `- Answered:` line stays in the proposal.

## Step 3: accept

The human decides. An agent runs the commands.

```bash
task vet ID=NNNN MODE=accept
task accept ID=NNNN                  # plain run: prints the sample and the collision list
CONFIRM=1 task accept ID=NNNN        # writes status: accepted and accepted: "<date> <commit>"
```

The checker covers: `breaking` is set; every MODIFIED, REMOVED or RENAMED target is in `openspec/specs/`; the admission test; no blocking question left in the proposal; one line in `tasks.md` for every repo in `affects`; `openspec validate` passes. The plain `task accept` run prints, and the human and the agent read:

- The sample: every MODIFIED and REMOVED requirement, and `max(3, 10 percent)` of the ADDED ones drawn at random. The random seed is printed, so the draw can be repeated. Each requirement shows its scenarios. Ask the admission question the checker cannot: does it describe behaviour a consumer observes, not one repo's internals? The outcome is fine, or refine (unclear, wrong, problematic). After a refinement, show every changed requirement again.
- The collision list: for each ADDED requirement, the 3 nearest requirements across all of `openspec/specs/`, by shared words. Read it for duplicates in meaning.

An entry with no requirements has no sample. The human reads the proposal and design instead.

A refused plain run still prints the sample and the list, headed "refused: fix the errors first". `CONFIRM=1` refuses before a plain run, and refuses when `HEAD` or the files of the entry changed after the plain run. The accept PR is merged by the human.

## Step 4: edit while accepted

The entry stays editable. An edit to `proposal.md` or `design.md` needs only PR review. An edit to a requirement needs a re-sample:

```bash
task resample ID=NNNN                # prints stale flags and every edited requirement
CONFIRM=1 task resample ID=NNNN      # rewrites accepted:
```

The plain run prints each stale-base flag with both texts, then each edited requirement with its 3 nearest requirements. There is no random draw: every edited requirement is shown. The confirmation is the reconciliation. The checker refuses an edited requirement in a PR until it runs. `task stale ID=NNNN` prints the flags alone.

## Step 5: deliver

Nothing is implemented in this repo. Each line of `tasks.md` is delivered by an OpenSpec change in the repo it names.

1. In that repo, cut the change with its own OpenSpec skills. Its `proposal.md` has a section `## Enhancement` with one line per task: `Delivers 0013, task 2.1.` The rule is in the repo's `openspec/config.yaml`.
1. When the repo change is archived, tick the line in a PR on this repo: `task tick ID=0013 LINE=2.1 REF=<change-name>`. `REF` is the change name without its date, `PR <n>` for a repo with no OpenSpec change, or `commit <sha>` for a direct commit.
1. `task reconcile` compares the `Delivers` lines with the ticks. It needs sibling checkouts. It flags an archived change whose line is not ticked, a tick that names a missing change, and a line for an unknown task.
1. When every line is ticked, run `task deliver ID=NNNN`. It refuses an unticked line and a stale flag. It sets `status: delivered`, runs `openspec archive <n> --yes`, runs `task index` and makes one commit. Only this commit may change `openspec/specs/`.

In code and comments in other repos, cite the entry by id beside the reason in words: `(enhancement 0013)`. Several ids are written `(enhancements 0010 and 0026)`. `task cite-lint` flags a lone id and a decision number.

## Step 6: end without delivery

| Command | For | Writes |
| --- | --- | --- |
| `task reject ID=NNNN REASON="..."` | A draft that will not be accepted. Refuses an accepted entry. | `rejected: {date, reason}` |
| `task withdraw ID=NNNN REASON="..."` | A draft or accepted entry the owner stops. Ticked lines do not block it. | `withdrawn: {date, reason}` |
| `task supersede ID=NNNN BY=MMMM REASON="..."` | An entry that one or more others replace. `BY` is a comma-separated list; the successor must exist, and it names the old id in its Why. | `superseded_by: {date, ids, reason}` |

Each sets `status`, archives with `--skip-specs`, runs `task index` and makes one commit. The deltas never reach `openspec/specs/`. A draft that never validated needs `-- --no-validate`. If an accepted entry shipped some lines, its shipped behaviour reaches `openspec/specs/` through a seed or a later entry.

A reason is required. A rejected idea may return as a new entry that names the old id in its Why.

## Seeds

`openspec/specs/` fills only through deliveries and seeds. A seed records behaviour OPM already ships, so an entry can modify it. It has no number, never shows on the site as an enhancement, and has two files: `specs/<capability>/spec.md` (ADDED only) and `source.md`.

```bash
task seed:new CAP=registration-acceptance     # refuses a capability already in openspec/specs/
task accept ID=seed-registration-acceptance   # prints the sample of the ADDED requirements
CONFIRM=1 task accept ID=seed-registration-acceptance   # writes only the sampled: line of source.md
task deliver ID=seed-registration-acceptance  # refuses a seed with no sampled: line
```

`source.md` names the repo specs and code each requirement comes from, at the commit read, and what was left out. Behaviour a live entry owns stays out. Never write the `sampled:` line by hand. An edit to a requirement after it needs a new sample.

## Checks

| Task | Use when |
| --- | --- |
| `task vet [ID=NNNN]` | After each edit. Add `MODE=accept` or `MODE=deliver` to see the stricter rules. `MODE=accept -- --openspec` also runs `openspec validate` (accept and deliver mode only). |
| `task check` | Before a PR: `vet` (with `--cue` and `ENH_FINAL=1`), `links`, then `fresh`. |
| `task index`, `task fresh` | After any edit to `config.yaml`, `proposal.md`, `design.md` or `tasks.md`, or after adding `specs/` or `evidence/`. `README.md` of each entry, `INDEX.md` and `GRAPH.md` are generated and never edited by hand. |
| `task links` | After you add a link. A link into another entry's folder is an error: cite the id in words. |
| `task specs-rule` | CI runs it. It needs openspec 1.14.1 and full history. |
| `task list`, `task show ID=NNNN`, `task history REQ="Name"` | Read-only views. `history` follows renames and `Replaced by` removals through the archived deltas. |

## Common pitfalls

- **Hand-editing `status`.** The commands write it, and the checker refuses a value that disagrees with the folder and the markers.
- **Hand-editing a generated file.** `task index` overwrites it, and `task fresh` fails until it does.
- **Writing a decision number.** `D4` and `0013:D4` belong to the old layout. Point at a theme by its heading, and at a requirement by its name.
- **Linking to another entry's folder.** Archive moves the folder. Cite the id in words.
- **Prescribing mechanism.** An entry never says how a repo names a file, spells an identifier or structures code. Naming a path as evidence is fine. The test: would deleting the path change what an implementer must do, or only what a reader can verify?
- **A requirement in a repo's own terms.** A Go symbol, a CLI flag or a file path fails the admission test. Put it in the repo's own change.
- **Writing a plan.** Sequencing is design prose in a theme: what must exist before what, and why. `tasks.md` order is advice, not a schedule.
- **Expanding the proposal.** It is the proposer's, word for word. Detail goes in the design or the specs.
- **Skipping the plain run.** `CONFIRM=1` refuses before a plain `task accept` or `task resample` on the same commit.
- **Editing an archived entry.** The checker refuses any change in `openspec/changes/archive/` other than regenerating a `README.md`. The same holds for the ten entries in `archive/NNNN/`.
- **A bare id in a code comment.** Write the reason in words and put the id beside it.
- **Scaffolding for something that is not a feature.** Walk Step 0 first.

## Source of truth precedence

When guidance conflicts, the most specific source wins: target-repo skill, then this skill, then target-repo `AGENTS.md`, then `enhancements/AGENTS.md`, then the workspace root `AGENTS.md`. The workspace root `CONTEXT.md` governs cross-repo routing. Each target repo's own `AGENTS.md` governs its source code.

## Cross-references

- `AGENTS.md`: the rules.
- `references/tasks.md`: the full task table.
- `openspec/config.yaml`: the rules of the store, by artifact.
- `openspec/schemas/enhancement/` and `openspec/schemas/seed/`: the schemas and templates.
- `schema.cue`: the schema of `config.yaml`, the repo list, the reserved and blocked ids.
- `.github/ISSUE_TEMPLATE/idea.yml`: the idea issue form.
- `enhancement-experiments`, `enhancement-diagrams`: sibling skills in this folder.
- `core-schema-edit` (`core/.claude/skills/core-schema-edit/`): the SPEC.md co-update protocol for changes that touch `core/*.cue`.
