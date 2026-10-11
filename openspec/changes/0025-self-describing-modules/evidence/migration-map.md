# Migration map: 0025

source: 0025 @ 18705155d2c7312029132c30d2b106ca59e57125

The old text stays in git at that commit: `git show 18705155d2c7312029132c30d2b106ca59e57125:0025/03-decisions.md`. The 18 requirements are the lines of that file that start `- Rn:` under a `**Requirements:**` heading. They are all in decisions D11 to D14. Decision D15 states `Requirements: none` (a scope decision), and D1 to D10 are tombstones of decisions that moved to entry 0027 on 2026-09-20, so they have no requirement lines. Every `kept` target is `capability/Requirement name` in `specs/` of this folder. 0025 restarts as a draft, so its three live open questions stay in the proposal. A row of the decision table names one target for each of its dispositions, written `<disposition>: <name>`; a `dropped` row gives its reason in the Target column.

## Requirements

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |
| 0025:D11:R1 | kept | module-aspects/A module without aspects is unchanged | |
| 0025:D11:R2 | kept | module-aspects/An aspect attaches at least one module trait | |
| 0025:D11:R3 | kept | module-aspects/An aspect carries no resource or blueprint | |
| 0025:D11:R4 | kept | module-aspects/An aspect's matching labels are derived | |
| 0025:D11:R5 | kept | module-aspects/An aspect renders under an instance-qualified name | |
| 0025:D11:R6 | kept | module-aspects/An aspect spec may read module configuration | |
| 0025:D11:R7 | kept | module-aspects/An aspect spec accepts only declared keys | |
| 0025:D12:R1 | kept | module-traits/A catalog publishes module traits like traits | |
| 0025:D12:R2 | kept | module-traits/Module traits and traits do not mix | |
| 0025:D12:R3 | kept | module-traits/An attachment may narrow optionality | |
| 0025:D13:R1 | kept | module-transformers/A module transformer runs once per matched aspect | |
| 0025:D13:R2 | kept | module-transformers/A module transformer outputs resources only | |
| 0025:D13:R3 | kept | module-transformers/A module transformer never reads rendered output | |
| 0025:D13:R4 | kept | module-transformers/A render is component and aspect output | |
| 0025:D14:R1 | kept | platform-contract-inventory/Defined contracts name their defining catalog | a MODIFIED of the seeded requirement of that name: the inventory also lists module traits and the module transformers that require them; the old requirement's two scenarios are the last two scenarios of the MODIFIED |
| 0025:D14:R2 | kept | aspect-demand/A required unhandled aspect trait fails the render | |
| 0025:D14:R3 | kept | aspect-demand/An optional unhandled aspect trait is reported | |
| 0025:D14:R4 | kept | aspect-demand/A disabled catalog contributes nothing | |

Totals: kept 18, cut 0, repo 0, moved 0 (merged 0). Sum 18, equal to the 18 old ids (D11 7, D12 3, D13 4, D14 4; D1 to D10 and D15 have none). Each old requirement has its own new requirement, one for one, so the new entry has 17 ADDED requirements in 4 capabilities (module-aspects 7, module-traits 3, module-transformers 4, aspect-demand 3) and 1 MODIFIED requirement in platform-contract-inventory. No old requirement is cut, so the entry has no `cut-requirements.md`. One of the 18 (0025:D14:R1) points at the MODIFIED requirement of a seeded capability.

## Decisions

Every `### Dn:` heading of the old log. The full reasoning and the alternatives of each decision are in `decision-log.md`. The design keeps one line for each rejected option. Ten decisions are dropped: D1 to D10 are tombstones. Their text lives in entry 0027 under the same numbers, so nothing is lost here.

| Old heading | Disposition | Target | Note |
| --- | --- | --- | --- |
| D1: (moved to 0027:D1, 2026-09-20) | dropped | tombstone: the decision moved to entry 0027 as 0027:D1 on 2026-09-20 and the number is retired here | the tombstone repeats: A platform-owned, cluster-scoped definition binds the module and the consumer never names a module path or version |
| D2: (moved to 0027:D2, 2026-09-20) | dropped | tombstone: the decision moved to entry 0027 as 0027:D2 on 2026-09-20 and the number is retired here | the tombstone repeats: The consumer-facing schema is the module's `#config`, enforced at the API server, and a non-structural `#config` is refused as a definition target |
| D3: (moved to 0027:D3, 2026-09-20) | dropped | tombstone: the decision moved to entry 0027 as 0027:D3 on 2026-09-20 and the number is retired here | the tombstone repeats: An instance of a definition is a projected `#ModuleInstance`, and there is no second render path |
| D4: (moved to 0027:D4, 2026-09-20) | dropped | tombstone: the decision moved to entry 0027 as 0027:D4 on 2026-09-20 and the number is retired here | the tombstone repeats: Two layers, binding then kinds, with the kind layer a pure projection onto the binding layer |
| D5: (moved to 0027:D5, 2026-09-20) | dropped | tombstone: the decision moved to entry 0027 as 0027:D5 on 2026-09-20 and the number is retired here | the tombstone repeats: The platform authors the binding, the module may declare its offering through an aspect, and the module never emits the definition |
| D6: (moved to 0027:D6, 2026-09-20) | dropped | tombstone: the decision moved to entry 0027 as 0027:D6 on 2026-09-20 and the number is retired here | the tombstone repeats: The projection from definition and instance to `#ModuleInstance` is a pure CUE function in core |
| D7: (moved to 0027:D7, 2026-09-20) | dropped | tombstone: the decision moved to entry 0027 as 0027:D7 on 2026-09-20 and the number is retired here | the tombstone repeats: A served kind's API version is the bound module's major |
| D8: (moved to 0027:D8, 2026-09-20) | dropped | tombstone: the decision moved to entry 0027 as 0027:D8 on 2026-09-20 and the number is retired here | the tombstone repeats: Replacing Crossplane means its composition layer, and managed-resource controllers stay external |
| D9: (moved to 0027:D9, 2026-09-20) | dropped | tombstone: the decision moved to entry 0027 as 0027:D9 on 2026-09-20 and the number is retired here | the tombstone repeats: No composite-and-claim pair: the served-kind instance is namespaced and is the only consumer-facing object |
| D10: (moved to 0027:D10, 2026-09-20) | dropped | tombstone: the decision moved to entry 0027 as 0027:D10 on 2026-09-20 and the number is retired here | the tombstone repeats: Operational primitives attach at the projected instance's transitions, and a served kind adds no hook surface |
| D11: `#Module` gains `#aspects`, a named map of module-scoped attachment units, sibling of `#components` | design | design: A module states facts through aspects |  |
| D12: `#ModuleTrait` is a sibling of `#Trait`, not a mode of it | design | design: A module trait is a sibling of a trait |  |
| D13: `#ModuleTransformer` is `#ComponentTransformer` transposed; it renders resources and never sees rendered output | design | design: A module transformer renders an aspect and nothing more |  |
| D14: Aspects participate in the platform's matching and contract inventory; an unhandled aspect demand is never silent | design | design: An unhandled demand is never silent |  |
| D15: This entry ships the extension point and no vocabulary; the traits it shows are examples, and a module trait ships with the entry that consumes it | design | design: The extension point ships, the vocabulary does not | a scope decision with no requirement |

Counts: 15 decision headings. D11 to D15 are live and map to the design (5 `design`). D1 to D10 are tombstones (10 `dropped`). The Considered-alternative lists of D11 to D15 are the rejected options of the design, and the full lists are in `decision-log.md`.

## Open questions

| Old id | Disposition | Target |
| --- | --- | --- |
| OQ1 | dropped | deferred to entry 0027 under the same number (OQ1 there); the question is about the self-service kinds half that moved on 2026-09-20 |
| OQ2 | dropped | deferred to entry 0027 under the same number (OQ2 there); the question is about the self-service kinds half that moved on 2026-09-20 |
| OQ3 | dropped | deferred to entry 0027 under the same number (OQ3 there); the question is about the self-service kinds half that moved on 2026-09-20 |
| OQ4 | dropped | deferred to entry 0027 under the same number (OQ4 there); the question is about the self-service kinds half that moved on 2026-09-20 |
| OQ5 | dropped | deferred to entry 0027 under the same number (OQ5 there); the question is about the self-service kinds half that moved on 2026-09-20 |
| OQ6 | dropped | deferred to entry 0027 under the same number (OQ6 there); the question is about the self-service kinds half that moved on 2026-09-20 |
| OQ7 | dropped | deferred to entry 0027 under the same number (OQ7 there); the question is about the self-service kinds half that moved on 2026-09-20 |
| OQ8 | dropped | deferred to entry 0027 under the same number (OQ8 there); the question is about the self-service kinds half that moved on 2026-09-20 |
| OQ9 | dropped | deferred to entry 0027 under the same number (OQ9 there); the question is about the self-service kinds half that moved on 2026-09-20 |
| OQ10 | dropped | deferred to entry 0027 under the same number (OQ10 there); the question is about the self-service kinds half that moved on 2026-09-20 |
| OQ11 | dropped | deferred to entry 0027 under the same number (OQ11 there); the question is about the self-service kinds half that moved on 2026-09-20 |
| OQ12 | dropped | deferred to entry 0027 under the same number (OQ12 there); the question is about the self-service kinds half that moved on 2026-09-20 |
| OQ16 | dropped | deferred to entry 0027 under the same number (OQ16 there); the question is about the self-service kinds half that moved on 2026-09-20 |
| OQ13 | proposal | Open questions |
| OQ14 | proposal | Open questions |
| OQ15 | proposal | Open questions |

Counts: 16 question headings. OQ13 to OQ15 are live and stay in the proposal (OQ13 as `- Blocking:`, OQ14 and OQ15 as `- Not blocking:`, following the old `Blocking:` field: acceptance for OQ13, deferrable for the other two). OQ1 to OQ12 and OQ16 are dropped, because the old register deferred each to entry 0027 and the number is kept there. The old register is in `questions.md`.

## Not in the three tables

The four draft-to-accepted gates of the old `04-graduation.md` (see `graduation.md`) are not requirements, decisions or questions. Where each went:

- The aspect pass is exercised, including its refusals: the fixtures in `schemas/examples.cue` cover it (the module, two instances, a transformer run and four must-fail cases), and the delta specs state the refusals as scenarios.
- An unhandled aspect demand is exercised, not only asserted: not met in the old fixtures, so it is a note for the owner at accept (`notes-for-accept.md`).
- Declaration-only fulfilment is decided: OQ13, a blocking question in the proposal.
- Prior art is compared, not cited: not met, so it is a note for the owner at accept (`notes-for-accept.md`).
