# Migration map: 0024

source: 0024 @ 18705155d2c7312029132c30d2b106ca59e57125

The old text stays in git at that commit: `git show 18705155d2c7312029132c30d2b106ca59e57125:0024/03-decisions.md`. The 7 requirements are the lines of that file that start `- Rn:` under a `**Requirements:**` heading. Every `kept` target is `capability/Requirement name` in `specs/` of this folder. A `cut` target is the line of `cut-requirements.md` that starts with the old id. The two cut lines are tombstones of the old entry. Decisions D1, D3, D5 and D6 had no requirement of their own, and the new entry adds none for them. A decision row names its theme in `design.md`. 0024 restarts as a draft, so its open questions stay in the proposal, except OQ3, which the old entry had already retired.

## Requirements

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |
| 0024:D2:R1 | kept | conformance-record/An accepted input records its rendered output | |
| 0024:D2:R2 | kept | conformance-record/A refused input records its message lines | |
| 0024:D2:R3 | kept | conformance-record/A changed refusal message is drift | |
| 0024:D4:R1 | kept | upstream-conformance/Rendered objects satisfy their upstream definition | |
| 0024:D4:R2 | cut | cut-requirements.md: 0024:D4:R2 | tombstone: the raw Kubernetes catalog family is retired |
| 0024:D4:R3 | cut | cut-requirements.md: 0024:D4:R3 | tombstone: the raw Kubernetes catalog family is retired |
| 0024:D4:R4 | kept | upstream-conformance/The suite checks upstream conformance across snapshots | |

Totals: kept 5, cut 2, repo 0, moved 0 (merged 0). Sum 7, equal to the 7 old ids (D2 3, D4 4; D1, D3, D5 and D6 have none). The new entry has 5 requirements, because two of the old 7 lines are tombstones with no behaviour.

## Decisions

Every `### Dn:` heading of the old log. The full reasoning and the alternatives of each decision are in `decision-log.md`. The design keeps one line for each rejected option. No decision is dropped.

| Old heading | Disposition | Target | Note |
| --- | --- | --- | --- |
| D1: CUE behaviour is verified at two layers, and the conformance layer lives outside every product repo | design | Two layers, one question each | |
| D2: A refusal's diagnostic text is part of the recorded behaviour | design | A refusal's text is part of the record | |
| D3: Outcomes are recorded per version cell, and drift fails unless a release explains it | design | Outcomes are recorded per version cell | |
| D4: Rendered Kubernetes objects conform to upstream definitions, verified outside the catalog | design | Rendered objects conform to upstream | |
| D5: The conformance suite renders through the pure-CUE oracle | design | The suite renders through the pure-CUE oracle | |
| D6: In-package assertions state rejection as well as acceptance | design | In-package assertions state rejection | |

## Open questions

| Old id | Disposition | Target |
| --- | --- | --- |
| OQ1 | proposal | Open questions |
| OQ2 | proposal | Open questions |
| OQ3 | dropped | retired on 2026-10-02: the raw catalog family it asked about is retired, so no coverage report is left to gate |
| OQ4 | proposal | Open questions |
| OQ5 | proposal | Open questions |
| OQ6 | proposal | Open questions |
| OQ7 | proposal | Open questions |
| OQ8 | proposal | Open questions |
| OQ9 | proposal | Open questions |

Counts: 9 question headings. OQ1, OQ2 and OQ4 to OQ9 are open and stay in the proposal, 8 questions. OQ2, OQ5 and OQ9 are marked `- Blocking:` because the old text says they block acceptance. The others are marked `- Not blocking:`: the old text defers them or hands them to the implementing change. The old register is in `questions.md`.
