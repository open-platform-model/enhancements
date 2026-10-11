# Migration map: 0009

source: 0009 @ 18705155d2c7312029132c30d2b106ca59e57125

The old text stays in git at that commit: `git show 18705155d2c7312029132c30d2b106ca59e57125:0009/03-decisions.md`. The 25 requirements are the lines of that file that start `- Rn:` under a `**Requirements:**` heading. Every `kept` target is `capability/Requirement name` in `specs/` of this folder. 0009 restarts as a draft, so its open questions stay in the proposal. A decision row names one target for each of its dispositions, written `<disposition>: <name>` and separated by a semicolon; a free note goes in the Note column.

## Requirements

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |
| 0009:D1:R1 | kept | operational-plan/Operational declarations leave the render unchanged |  |
| 0009:D1:R2 | kept | operational-plan/A module yields an ordered plan of steps |  |
| 0009:D2:R1 | kept | operational-constructs/Four core constructs declare operations |  |
| 0009:D2:R2 | kept | operational-constructs/Authors compose operation kinds but cannot add one |  |
| 0009:D2:R3 | kept | operational-constructs/An action identity derives from its coordinates |  |
| 0009:D2:R4 | kept | operational-constructs/A workflow runs only when invoked by name |  |
| 0009:D2:R5 | kept | operational-constructs/A step orders itself only against siblings |  |
| 0009:D3:R1 | kept | step-advance/One advance returns at most one action |  |
| 0009:D3:R2 | kept | step-advance/A stored run state advances identically |  |
| 0009:D3:R3 | kept | step-advance/The library decides what happens next |  |
| 0009:D3:R4 | kept | step-advance/The library keeps no run state between calls |  |
| 0009:D4:R1 | kept | op-dispatch/A frontend runs only the backends it registered |  |
| 0009:D4:R2 | kept | op-dispatch/An unregistered protocol refuses the plan |  |
| 0009:D5:R1 | kept | op-dispatch/Every operation kind names its backend and artifact |  |
| 0009:D5:R2 | kept | op-dispatch/The dispatch attribute does not change the value |  |
| 0009:D6:R1 | kept | op-catalog/A catalog publishes operations beside transformers |  |
| 0009:D6:R2 | kept | op-catalog/An actions entry is keyed by action identity |  |
| 0009:D6:R3 | kept | op-catalog/A platform gains an operation by subscription |  |
| 0009:D7:R1 | kept | lifecycle-phases/A lifecycle accepts exactly nine phases |  |
| 0009:D7:R2 | kept | lifecycle-phases/Steps in a phase run in authored order |  |
| 0009:D7:R3 | kept | lifecycle-phases/An absent phase does nothing |  |
| 0009:D8:R1 | kept | op-catalog/The HTTP operation accepts five methods |  |
| 0009:D8:R2 | kept | op-catalog/The HTTP operation returns the raw response |  |
| 0009:D10:R1 | kept | operational-plan/Operational traits attach on a named aspect |  |
| 0009:D10:R2 | kept | operational-plan/Operational traits render no resource |  |

Totals: kept 25, cut 0, repo 0, moved 0 (merged 0). Sum 25, equal to the 25 old ids (D1 2, D2 5, D3 4, D4 2, D5 2, D6 3, D7 3, D8 2, D10 2; D9 has none by design). No requirement is cut, so there is no `cut-requirements.md`. The old texts are intent level already; each is one new requirement with its scenarios.

## Decisions

Every `### Dn:` heading of the old log. The full reasoning and the alternatives of each decision are in `decision-log.md`. The design keeps one line for each rejected option someone would propose again. No decision is dropped.

| Old heading | Disposition | Target | Note |
| --- | --- | --- | --- |
| D1: Add a second kernel half for execution; do not extend the render pipeline | design | design: A second half over the same module | alternatives are in Considered and rejected |
| D2: Four operational constructs in `core`, keep the names | design | design: Four constructs, a closed vocabulary |  |
| D3: The library plans and advances one step per call; the caller runs the loop and performs every action | design | design: The library plans and advances, the caller acts | the reversed option and two others are in Considered and rejected; the full reasoning is in decision-log.md |
| D4: Executor backends ship in the library's opt-in layer; frontends compose them à la carte | design | design: Dispatch by attribute, backends by choice | the dispatch attribute and the registry share one theme |
| D5: Dispatch via a CUE `@op(...)` attribute (eval-invisible, SDK-readable) | design | design: Dispatch by attribute, backends by choice |  |
| D6: Executable op code is catalog-sourced, not hardcoded in the library | design | design: Operation code comes from the catalog |  |
| D7: `#Lifecycle` exposes a fixed nine-phase vocabulary | design | design: Four constructs, a closed vocabulary |  |
| D8: The HTTP Op exposes full CRUD and returns the raw response; parsing is done in CUE | design | design: Operation code comes from the catalog |  |
| D9: The execution half owns cancellation inside a stage and introduces its own injection surface | design | design: Cancellation and the injection surface | the design keeps the removal of the slots and the standalone entry checks in one theme; the three rejected options are in decision-log.md |
| D10: `#Lifecycle` and `#Workflow` attach at module root as module traits on an aspect | design | design: Attachment on a module aspect | the rejected options are in Considered and rejected |

## Open questions

| Old id | Disposition | Target |
| --- | --- | --- |
| OQ1 | proposal | Open questions |
| OQ2 | proposal | Open questions |
| OQ3 | proposal | Open questions |
| OQ4 | design (answered by D10) | Attachment on a module aspect |
| OQ5 | proposal | Open questions |
| OQ6 | proposal | Open questions |
| OQ7 | proposal | Open questions |

Counts: 7 questions. OQ4 was resolved in the old text by the attachment decision and moves into the design as an answer. OQ1, OQ2, OQ3, OQ5, OQ6 and OQ7 stay in the proposal: OQ1 and OQ7 as blocking, the others as not blocking. The old register is in `questions.md`.
