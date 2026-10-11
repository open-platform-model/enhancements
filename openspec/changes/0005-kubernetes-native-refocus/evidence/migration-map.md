# Migration map: 0005

source: 0005 @ 18705155d2c7312029132c30d2b106ca59e57125

The old text stays in git at that commit: `git show 18705155d2c7312029132c30d2b106ca59e57125:0005/03-decisions.md`. The old entry has no requirement lines. Each of its three decisions says `Requirements: none` and gives a reason: the entry states a posture and a boundary, and the observable shapes rest on open questions that have no decision yet. So the entry is `skip_specs: true`, has no `specs/` folder, and the Requirements table below has no row. A decision row names one target for each of its dispositions, written `<disposition>: <name>` and separated by a semicolon; a free note goes in the Note column.

## Requirements

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |

Totals: kept 0, merged 0, cut 0, repo 0, moved 0. Sum 0, equal to the 0 old ids (D1, D2 and D3 each say `Requirements: none`). The posture of each decision is in the design, in the theme named in the next table.

## Decisions

Every `### Dn:` heading of the old log. The full reasoning and the alternatives of each decision are in `decision-log.md`. No decision is dropped.

| Old heading | Disposition | Target | Note |
| --- | --- | --- | --- |
| D1: Kubernetes is the first-class lowest common denominator; one generated type source feeds both catalogs | design; evidence | design: One generated source of Kubernetes types; evidence: decision-log.md | the rejected options are in the design's Considered and rejected; the measurement of 2026-09-29 stays in decision-log.md |
| D2: Catalog-on-catalog composition is supported, not forced | design | design: Catalogs compose on top, never underneath | |
| D3: No core change in this enhancement; multi-phase lowering is a staged, evidence-gated follow-on | design | design: Core does not change | |

## Open questions

| Old id | Disposition | Target |
| --- | --- | --- |
| OQ1 | proposal (still open, blocks acceptance) | Open questions |
| OQ2 | proposal (still open, blocks acceptance) | Open questions |
| OQ3 | proposal (still open, blocks acceptance) | Open questions |
| OQ4 | proposal (still open, does not block) | Open questions |
| OQ5 | proposal (still open, blocks acceptance) | Open questions |
| OQ6 | proposal (still open, does not block) | Open questions |

Counts: 6 questions, all open. The six lines of the proposal's Open questions section follow the order of the old register. OQ4 and OQ6 carry no `Blocking` marker in the old text, so they are `Not blocking`. The old register is in `questions.md`.

## Where the rest of the old text went

These parts are not decisions, requirements or questions, so no table has a row for them.

- `01-problem.md`: the proposal's Why and Impact keep the short form. The whole text, with the file and line evidence, is `problem.md`.
- `02-design.md`: the design themes keep the goals, the two renderings, the lifecycle block, the trapdoor, composition and the integration points per repo. The whole text, with the before and after examples, is `design-notes.md`. The non-goals are the proposal's "What this is not".
- `04-graduation.md`: replaced by the accept checklist of the new layout. The old text is `graduation.md`.
- `05-risks.md`: the design keeps the risks and drawbacks as one line each and the alternatives as Considered and rejected. The whole text is `risks.md`.
- `06-operational.md`: the design's last theme keeps the order, deprecation and rollback. The whole text, with the observability and semver answers, is `operational.md`.
- `contracts/`: moved to `contracts/` here, with its `cue.mod`.
- `README.md`: regenerated. The old scope lists and cross-references table are `old-readme.md`.
- `config.yaml`: the facts moved to `../config.yaml`. The old `history` stays in git at the commit above. The old key `core_schema: false` has no new place: it only said that `schemas/` was not a core delta.
