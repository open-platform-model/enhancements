# Migration map: 0007

source: 0007 @ 18705155d2c7312029132c30d2b106ca59e57125

The old text stays in git at that commit: `git show 18705155d2c7312029132c30d2b106ca59e57125:0007/03-decisions.md`. The 12 requirements are the lines of that file that start `- Rn:` under a `**Requirements:**` heading. Every `kept` target is `capability/Requirement name` in `specs/` of this folder. 0007 has no cut, repo or moved requirement: each old requirement is one new requirement, so there is no `cut-requirements.md`. A decision row names one target for each of its dispositions, written `<disposition>: <name>`. A free note goes in the Note column.

## Requirements

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |
| 0007:D1:R1 | kept | passthrough-declaration/A module cannot declare side manifests |  |
| 0007:D1:R2 | kept | passthrough-lifecycle/The kernel render holds no side object |  |
| 0007:D3:R1 | kept | passthrough-lifecycle/A side object carries the ownership labels |  |
| 0007:D3:R2 | kept | passthrough-lifecycle/A side object joins the one inventory |  |
| 0007:D3:R3 | kept | passthrough-lifecycle/Side objects are pruned like rendered ones |  |
| 0007:D3:R4 | kept | passthrough-lifecycle/A side object carries a provenance marker |  |
| 0007:D3:R5 | kept | passthrough-lifecycle/Side objects stage in the same order |  |
| 0007:D4:R1 | kept | passthrough-drivers/Both drivers produce the same object set |  |
| 0007:D4:R2 | kept | passthrough-drivers/A CLI build shows the side objects |  |
| 0007:D5:R1 | kept | passthrough-declaration/An instance declares its own side manifests |  |
| 0007:D5:R2 | kept | passthrough-declaration/A source is either raw or Kustomize |  |
| 0007:D5:R3 | kept | passthrough-declaration/A source path stays inside the source tree |  |

Totals: kept 12, cut 0, repo 0, moved 0 (merged 0). Sum 12, equal to the 12 old ids (D1 2, D3 5, D4 2, D5 3; D2 has none by its own statement). Each of the 12 new requirements has exactly one `kept` row.

## Decisions

Every `### Dn:` heading of the old log. The full reasoning and the alternatives of each decision are in `decision-log.md`. The design keeps one line for each rejected option. No decision is dropped.

| Old heading | Disposition | Target | Note |
| --- | --- | --- | --- |
| D1: Passthrough lives at the apply layer, not in core or the kernel | design | design: Passthrough lives in the apply layer | the two rejected options are in Considered and rejected |
| D2: Kustomize is rendered by an embedded library, not by shelling out | design | design: Kustomize runs as a library | it has no requirement; the 2026-09-29 measurement of the dependency is in the theme |
| D3: Side manifests reuse the existing ownership, inventory, and prune machinery | design | design: Side objects join the rendered set | |
| D4: Available in both the CLI and the operator with identical semantics | design | design: Both drivers, one result | |
| D5: Passthrough is declared via a release-spec side-channel, not woven into the component model | design | design: The declaration is a side field | |

## Open questions

| Old id | Disposition | Target |
| --- | --- | --- |
| OQ1 | proposal | Open questions |
| OQ2 | proposal | Open questions |
| OQ3 | proposal | Open questions |
| OQ4 | proposal | Open questions |
| OQ5 | proposal | Open questions |
| OQ6 | proposal | Open questions |
| OQ7 | proposal | Open questions |

Counts: 7 questions. None is answered in the old text, so all 7 stay in the proposal. OQ1, OQ2, OQ3, OQ6 and OQ7 are `- Blocking:` (the old register says "Blocking: acceptance"). OQ4 and OQ5 are `- Not blocking:` (the old register says "Blocking: deferrable"). The old register is in `questions.md`.
