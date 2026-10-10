# Mockup: enhancements as an OpenSpec store

This branch builds the new structure for enhancements, the design's step M0. Nothing here is live. The real entries (`0004/` to `0027/` and `archive/`) are untouched and keep validating under the old rules.

The design was decided at the design gate of 2026-10-10 (rounds 13 to 17): a format (what a folder holds, what `config.yaml` says, the lifecycle) and a system around it (one Go tool, a thin Taskfile, CI, docs-kit, the other repos). This file says what the branch holds today and what is still open. It cites decisions by their round, not by a path.

## What is here

| Path | What it is |
| --- | --- |
| `.openspec-store/store.yaml` | Makes this repo the store `opm-enhancements` |
| `openspec/config.yaml` | The repo's own rules for writers: context, rules per artifact, advice for apply and archive. No OpenSpec skill file carries a patch |
| `openspec/schemas/enhancement/` | The schema of an enhancement and its four templates: proposal, design, delta spec, tasks |
| `openspec/schemas/seed/` | The lighter schema of a seed change: a source note and ADDED requirements, no proposal, no design |
| `openspec/specs/` | The contract by capability. It holds **delivered work only**. It is empty now; it fills by seed and by archive |
| `openspec/changes/0013-secret-field-attributes/` | The mock of 0013 in the new structure. It stays until 0013 is converted for real |
| `openspec/changes/archive/` | Empty. Delivered, rejected, superseded and withdrawn entries go here |
| `schema.cue` | `#EntryConfig`, the new-layout `config.yaml`, beside the old definitions that stay until the migration ends. Also `reservedIds` and `blockedIds` |
| `tests/schema/` | Valid and invalid `config.yaml` fixtures, and `run.sh` to check them with `cue vet` |

## One enhancement

| File | Reader's question | Owner | Soft cap |
| --- | --- | --- | --- |
| `config.yaml` | What are the facts? | human gives facts; commands write state | none |
| `README.md` | Where do I start? | generated | none |
| `proposal.md` | What changes, and why? | human, word for word | 300 words, not counting "Open questions" |
| `design.md` | How does it work, and why this way? | human decides; agent drafts | 1,500 words |
| `specs/<capability>/spec.md` | Exactly what must hold? | agent writes; human approves in a sample | with the 3,000 total |
| `tasks.md` | Which repo still has work? | agent writes and ticks | none |
| `evidence/` | What is the proof? | agent or human | none; outside the total |

All caps are advice: the checker warns and never refuses. The total of proposal, design and requirement text is 3,000 words.

## The life of an entry

Draft, then accepted (both in `changes/`), then archived as delivered. An entry can also end rejected, superseded or withdrawn, each with a reason in `config.yaml`. `status` is stored there.

- **Draft.** Everything may change. The human gives the intent.
- **Accepted.** The agent prints a sample of the requirements and a collision list; the human says "fine" or "refine"; a PR records `accepted`. The entry stays in `changes/` and stays editable. An edited requirement needs a re-sample.
- **Delivered.** Every line of `tasks.md` is ticked. One command validates, archives and indexes in one commit. Only then does `openspec/specs/` change.
- **Rejected, superseded, withdrawn.** Archived with `--skip-specs`. The deltas never reach `specs/`.

## Decided

1. This repo is an OpenSpec store. An enhancement is a change in it. One feature is one id and one folder, however large.
2. `specs/` holds delivered work only. Until an entry is archived, its requirements live in its own delta specs. A seed change fills `specs/` with behaviour that already ships.
3. A requirement has a plain name, a SHALL sentence a consumer can observe, and at least one scenario written with it. No Go symbol, CLI flag or file path (a published CUE definition may be named). No `- Design:` line and no `- Changed by:` line: the history tool gives provenance.
4. Delivery is `tasks.md`: one line per repo change, and every repo in `affects` has one. A repo change names the line it delivers in its own proposal (`Delivers NNNN, task X.Y.`). A code comment may name an enhancement id only beside the reason in words, and never a decision number.
5. `config.yaml` holds facts only: no `updated` (docs-kit derives the date from git), no `semver` (replaced by `breaking`, true or false). Ids 0000, 0028 and 0029 are reserved; 0030 and 0031 are blocked until the last phase has stripped every `0030:` citation.

## Still open

The counts below are the design's own.

- **The tools.** `enh`, one Go program, will hold the checker and the commands (`new`, `accept`, `resample`, `deliver`, `index`, `history`). The Taskfile only calls it. CI and the docs-kit reader follow.
- **The migration.** The 17 live entries convert, with 441 requirements in all, and a map proves that none is lost. The 10 archived entries (68 requirement lines) stay as they are. 0004 and 0013 restart as drafts, and 0013 shrinks from about 100 requirements to about 20. About 10 seed changes fill `specs/` first. The migration costs about 50 agent runs and 4 hours of the owner's time.
- **The last phase.** About 950 code comments in four repos, and the other repos' specs, archives and docs, are rewritten to cite an id beside a reason. It costs about 30 agent runs.
- **Docs generation.** The site builds this repo's pages through docs-kit, which reads the old `NNNN/` layout. It must learn the new one, or the pages disappear from `opmodel.dev/enhancements/`.

## What is real in the 0013 mock

- It is an **excerpt**: five of the 36 decisions (D10, D11, D13, D25, D26) with all 16 of their requirements. It still carries the dropped `- Design:`, `- Changed by:` and `- Was:` lines, and it still has a MODIFIED requirement against a spec that no longer exists in `specs/`. `openspec validate` reports that as information.
- The requirement text follows the original closely. The names and scenarios are drafts. Nobody has reviewed them.
- In `tasks.md`, the three ticked lines are real landed changes from `0013/delivery.yaml`. The open lines are illustrative.
- `README.md` is hand-written; `task index` does not generate it yet.
- The mock is replaced when 0013 is converted for real (about 20 requirements, restarted as a draft).
