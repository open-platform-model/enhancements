# Mockup: enhancements as an OpenSpec store

This branch (`openspec-store-design`) tries out a new structure for enhancements. Nothing here is live. The real entries (`0013/` and the rest) are untouched.

## What is here

| Path | What it is |
| --- | --- |
| `.openspec-store/store.yaml` | Makes this repo the store `opm-enhancements` |
| `openspec/schemas/enhancement/` | The schema and its five templates |
| `openspec/specs/` | The contract by capability: every accepted requirement, delivered or not |
| `openspec/changes/0013-secret-field-attributes/` | 0013 in the new structure: accepted, so ready to implement |
| `openspec/changes/archive/` | Empty. Only delivered and rejected enhancements go here |

## One enhancement

| File | Reader's question | Cap |
| --- | --- | --- |
| `README.md` | Where do I start? | Generated |
| `proposal.md` | What changes, and why? | 300 words |
| `design.md` | How does it work, and why this way? | 7 themes, 120 words a theme, 10 alternatives |
| `specs/<capability>/spec.md` | Exactly what must hold? | 8 words a requirement name |
| `tasks.md` | Which repo still has work? | One line per repo change |
| `config.yaml`, `evidence/` | Metadata, and the proof behind a claim | |

## Decided so far

1. This repo becomes an OpenSpec store. An enhancement is a change in it.
2. One feature is one id and one folder, however large.
3. Accepted means ready to implement. The folder stays in `changes/`. Archive means delivered or rejected.
4. Requirements live only in the specs, by capability. Their names are plain statements, not ids.
5. Delivery is `tasks.md`: one line per repo change. A repo change names the line it delivers in its own proposal. No `delivery.yaml`, no `enhancement.yaml`, no ids in code comments.

## On trial, not decided

- **The design in the style of a Kubernetes enhancement proposal.** `design.md` is one explanation by theme, with the rejected options in one list at the end. It has no numbered decisions. Earlier trials used a 100-word card per decision, and one file per part.

## Still open

- **Docs generation.** The site builds this repo's pages through docs-kit, whose `enhancements` source reads the `NNNN/` seven-document layout (`docs-kit.cue`). It must learn the new layout, or the pages disappear from `opmodel.dev/enhancements/`.
- **The accept step.** OpenSpec has no command that syncs delta specs without archiving. `task promote` needs its own sync.
- **`task index`.** It must generate each `README.md`. `task vet` must enforce the caps.
- **Migration.** 18 live and 10 archived entries use the old layout. A migration needs a check that every old requirement lands in a spec; the `- Was:` lines make that mechanical. About 3,050 code comments in four repos cite old ids; they are to be removed.
- **The old ids.** A migrated requirement keeps a `- Was:` line with its old id, so an old citation can still be found.

## What is real in the 0013 mock

- It is an **excerpt**: five of the 36 decisions (D10, D11, D13, D25, D26) with all 16 of their requirements. A `- Was:` line on each requirement names the original.
- The third way to supply a secret, a named source (D18), is in the proposal but outside the excerpt, so the specs show two.
- `design.md` is rewritten from `0013/03-decisions.md`. Reasoning too long for it is condensed into two notes in `evidence/`.
- A comparison pass on 2026-10-07 found the first mock had dropped five requirements, weakened four, and contradicted itself in the proposal. Those are fixed. The pass also found that 0014's export warning now disagrees with 0013; the design lists it as an open question.
- The requirement text follows the original closely. The **names and scenarios are new drafts**. Nobody has reviewed them.
- In `tasks.md`, the three ticked lines are real landed changes from `0013/delivery.yaml`. The open lines are illustrative.
- `README.md` is hand-written; `task index` does not generate it yet.
- `openspec/specs/instance-export/spec.md` was seeded with two requirements of 0014, as if 0014 were already accepted, so that 0013 has something to modify.
- The specs were synced by running `openspec archive` and moving the folder back.
- The real experiments and research were not copied into `evidence/`, and neither were `schemas/`, which hold the exact types.
