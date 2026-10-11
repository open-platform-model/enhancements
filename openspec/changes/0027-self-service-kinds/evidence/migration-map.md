# Migration map: 0027

source: 0027 @ 18705155d2c7312029132c30d2b106ca59e57125

The old text stays in git at that commit: `git show 18705155d2c7312029132c30d2b106ca59e57125:0027/03-decisions.md`. The 30 requirements are the lines of that file that start `- Rn:` under a `**Requirements:**` heading. Every `kept` target is `capability/Requirement name` in `specs/` of this folder. No old requirement is cut, merged, moved to another entry or left for a repo, so there is no `cut-requirements.md`. A decision row names its target as a theme of the design, or a section of the proposal; a free note goes in the Note column. 0027 restarts as a draft, so all 26 open questions stay in the proposal.

## Requirements

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |
| 0027:D1:R1 | kept | module-binding/A definition binds one module |  |
| 0027:D1:R2 | kept | module-binding/A consumer supplies values alone |  |
| 0027:D1:R3 | kept | module-binding/Rebinding re-renders every instance |  |
| 0027:D1:R4 | kept | module-binding/A definition may bind without a kind | the layering question stays open in the proposal |
| 0027:D2:R1 | kept | served-kinds/The served schema is the module's own |  |
| 0027:D2:R2 | kept | served-kinds/A bad instance is refused at admission |  |
| 0027:D2:R3 | kept | served-kinds/A non-structural schema is refused | the refused shapes and the narrowing list stay in the requirement text; the open questions on secrets, unions and computed fields fill them |
| 0027:D2:R4 | kept | served-kinds/A module never served is unaffected |  |
| 0027:D3:R1 | kept | instance-projection/A projected instance renders unchanged |  |
| 0027:D3:R2 | kept | instance-projection/A projected and a written instance render alike |  |
| 0027:D3:R3 | kept | instance-projection/A projected instance gets ordinary diagnostics |  |
| 0027:D5:R1 | kept | definition-authoring/Only a platform identity creates a definition |  |
| 0027:D5:R2 | kept | definition-authoring/A product module ships definitions as output |  |
| 0027:D5:R3 | kept | definition-authoring/A declaration is readable without a cluster |  |
| 0027:D5:R4 | kept | definition-authoring/A declaration alone offers nothing |  |
| 0027:D5:R5 | kept | definition-authoring/A disagreeing definition is reported | reported, not refused |
| 0027:D5:R6 | kept | definition-authoring/A declaration renders no object |  |
| 0027:D6:R1 | kept | instance-projection/The projection yields name, module and values |  |
| 0027:D6:R2 | kept | instance-projection/A value clash is refused |  |
| 0027:D6:R3 | kept | instance-projection/The projection is the same offline |  |
| 0027:D6:R4 | kept | instance-projection/A config default reaches the values |  |
| 0027:D6:R5 | kept | instance-projection/Only the bound module projects |  |
| 0027:D7:R1 | kept | served-kinds/A served version is the module major |  |
| 0027:D7:R2 | kept | served-kinds/A release outside the major is refused |  |
| 0027:D7:R3 | kept | served-kinds/Rebinding inside a major keeps instances valid |  |
| 0027:D9:R1 | kept | served-kinds/A served instance is namespaced |  |
| 0027:D9:R2 | kept | served-kinds/The consumer's object mirrors status |  |
| 0027:D11:R1 | kept | offering-declaration/A catalog publishes the offering trait |  |
| 0027:D11:R2 | kept | offering-declaration/The offering trait selects no transformer |  |
| 0027:D11:R3 | kept | offering-declaration/A declaring aspect renders nothing | carried through the render unchanged |

Totals: kept 30, merged 0, cut 0, repo 0, moved 0. Sum 30, equal to the 30 old ids (D1 4, D2 4, D3 3, D5 6, D6 5, D7 3, D9 2, D11 3; D4, D8 and D10 have none).

Each of the 30 new requirements has exactly one `kept` row. Check: kept + moved + cut + repo = 30.

## Decisions

Every `### Dn:` heading of the old log. The full reasoning and the alternatives of each decision are in `decision-log.md`. The design keeps one line for each rejected option. No decision is dropped.

| Old heading | Disposition | Target | Note |
| --- | --- | --- | --- |
| D1: A platform-owned, cluster-scoped definition binds the module; the consumer never names a module path or version | design | The platform binds the module |  |
| D2: The consumer-facing schema is the module's `#config`, enforced at the API server; a non-structural `#config` is refused as a definition target | design | The served schema is the module's own | revised in place on 2026-10-04 to drop the encoder dependency; the measurements are summarised in the theme and kept in full in decision-log.md and experiments/ |
| D3: An instance of a definition is a projected `#ModuleInstance`; there is no second render path | design | One render path, one pure projection |  |
| D4: Two layers, binding then kinds; the kind layer is a pure projection onto the binding layer | design | Two layers, binding then kinds | has no requirement; the layering question is open in the proposal |
| D5: The platform authors the binding; the module may declare its offering through an aspect, and never emits the definition | design | The platform writes the definition, the module may declare | revised 2026-09-20 to rest on the aspect map of enhancement 0025 |
| D6: The projection from definition and instance to `#ModuleInstance` is a pure CUE function in core | design | One render path, one pure projection |  |
| D7: A served kind's API version is the bound module's major | design | A served kind is one namespaced object at the module's major |  |
| D8: Replacing Crossplane means its composition layer; managed-resource controllers stay external | proposal | What this is not | has no requirement; the boundary is a bullet of What this is not |
| D9: No composite-and-claim pair; the served-kind instance is namespaced and is the only consumer-facing object | design | A served kind is one namespaced object at the module's major |  |
| D10: Operational primitives attach at the projected instance's transitions; a served kind adds no hook surface | design | One render path, one pure projection | has no requirement; operational primitives attach to module-instance transitions |
| D11: catalog_opm publishes the `offering` module trait; this entry is its only consumer | design | The platform writes the definition, the module may declare | ships the trait that enhancement 0025 left to this entry |

## Open questions

| Old id | Disposition | Target |
| --- | --- | --- |
| OQ1 | proposal (still open, blocks acceptance) | Open questions |
| OQ2 | proposal (still open, blocks acceptance) | Open questions |
| OQ3 | proposal (still open, blocks acceptance) | Open questions |
| OQ4 | proposal (still open, blocks acceptance) | Open questions |
| OQ5 | proposal (still open, blocks acceptance) | Open questions |
| OQ6 | proposal (still open, does not block) | Open questions |
| OQ7 | proposal (still open, blocks acceptance) | Open questions |
| OQ8 | proposal (still open, blocks acceptance) | Open questions |
| OQ9 | proposal (still open, does not block) | Open questions |
| OQ10 | proposal (still open, blocks acceptance) | Open questions |
| OQ11 | proposal (still open, does not block) | Open questions |
| OQ12 | proposal (still open, does not block) | Open questions |
| OQ16 | proposal (still open, does not block) | Open questions |
| OQ17 | proposal (still open, does not block) | Open questions |
| OQ18 | proposal (still open, blocks acceptance) | Open questions |
| OQ19 | proposal (still open, blocks acceptance) | Open questions |
| OQ20 | proposal (still open, blocks acceptance) | Open questions |
| OQ21 | proposal (still open, blocks acceptance) | Open questions |
| OQ22 | proposal (still open, blocks acceptance) | Open questions |
| OQ23 | proposal (still open, does not block) | Open questions |
| OQ24 | proposal (still open, blocks acceptance) | Open questions |
| OQ25 | proposal (still open, blocks acceptance) | Open questions |
| OQ26 | proposal (still open, blocks acceptance) | Open questions |
| OQ27 | proposal (still open, does not block) | Open questions |
| OQ28 | proposal (still open, does not block) | Open questions |
| OQ29 | proposal (still open, does not block) | Open questions |

Counts: 26 questions, all still open, so all stay in the proposal: 16 blocking and 10 not blocking. The old numbers run OQ1 to OQ12 and OQ16 to OQ29; OQ13 to OQ15 belong to enhancement 0025 and never existed here. The old text marks a question `Blocking: acceptance` or `Blocking: deferrable`; the proposal marks the second kind `- Not blocking:`. The proposal lists the questions in the old order. The old register is in `questions.md`.
