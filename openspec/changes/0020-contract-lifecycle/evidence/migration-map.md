# Migration map: 0020

source: 0020 @ 18705155d2c7312029132c30d2b106ca59e57125

The old text stays in git at that commit: `git show 18705155d2c7312029132c30d2b106ca59e57125:0020/03-decisions.md`. The 22 requirements are the lines of that file that start `- Rn:` under a `**Requirements:**` heading. Every `kept` target is `capability/Requirement name` in `specs/` of this folder. No old requirement is cut, merged, moved to another entry or left for a repo, so there is no `cut-requirements.md`. 0020 restarts as a draft, so its open questions stay in the proposal. The decisions D4, D5, D11 and D12 have no requirement. A decision row names one target for each of its dispositions; a free note goes in the Note column.

## Requirements

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |
| 0020:D1:R1 | kept | contract-promotion/A promoted contract names its origin |  |
| 0020:D1:R2 | kept | contract-promotion/The origin lies strictly below the level |  |
| 0020:D1:R3 | kept | contract-promotion/The origin stays on the published contract |  |
| 0020:D1:R4 | kept | contract-promotion/The origin never enters a contract key |  |
| 0020:D2:R1 | kept | artifact-publishing/The compatibility gate compares against history | a MODIFIED of the seeded requirement of that name: its predecessor selection gains the origin level; the old requirement's scenario is the last scenario of the MODIFIED |
| 0020:D2:R2 | kept | contract-promotion/A broken promotion is refused with a path |  |
| 0020:D3:R1 | kept | contract-promotion/A promotion changes no shape |  |
| 0020:D3:R2 | kept | contract-promotion/A refused mixed promotion names the remedy |  |
| 0020:D6:R1 | kept | contract-retirement/A removal without a tombstone is refused |  |
| 0020:D6:R2 | kept | contract-retirement/A tombstone records what went and why |  |
| 0020:D6:R3 | kept | contract-retirement/A removal itself is never refused |  |
| 0020:D6:R4 | kept | contract-retirement/A tombstone dates the build that carries it |  |
| 0020:D6:R5 | kept | contract-retirement/An alpha contract is never tombstoned |  |
| 0020:D7:R1 | kept | tombstone-record/Every build carries the full tombstone history |  |
| 0020:D7:R2 | kept | tombstone-record/A dropped tombstone is refused |  |
| 0020:D8:R1 | kept | catalog-contracts/A catalog lists the contracts it defines | a MODIFIED of the seeded requirement of that name: the catalog gains a fourth map beside the three member maps; the old requirement's scenario is its last scenario |
| 0020:D8:R2 | kept | tombstone-record/A tombstone repeats its own key |  |
| 0020:D8:R3 | kept | tombstone-record/A catalog without tombstones stays valid |  |
| 0020:D9:R1 | kept | tombstone-record/A tombstone states a reason |  |
| 0020:D9:R2 | kept | tombstone-record/A missing replacement is not warned about |  |
| 0020:D9:R3 | kept | tombstone-record/A tombstone cannot name itself as its replacement |  |
| 0020:D10:R1 | kept | contract-retirement/A withdrawal waits for the seasoning floor |  |

Counts: kept 22, merged 0, cut 0, repo 0, moved 0. Total 22. Two of the 22 kept rows (0020:D2:R1 and 0020:D8:R1) point at a MODIFIED requirement of a seeded capability, so the entry's own capabilities hold 20 ADDED requirements.

## Decisions

Every `### Dn:` heading of the old log. The full reasoning and the alternatives of each decision are in `decision-log.md`. The design keeps one line for each rejected option. No decision is dropped.

| Old heading | Disposition | Target | Note |
| --- | --- | --- | --- |
| D1: A contract reaches a higher level by promotion, and a promotion is declared | design | A promotion is declared, not inferred |  |
| D2: A promotion is refused unless it is compatible with the level it promotes from | design | A promotion is checked against its origin |  |
| D3: A build may promote a contract or change its shape, never both | design | A promotion is checked against its origin | the one-intent rule is its second paragraph |
| D4: Levels coexist by aliasing, and dual-shipping is the sanctioned promotion mechanism | design | Promotion ships two keys in one build | no requirement: authoring posture; the identical-shape consequence is a requirement of the promotion check |
| D5: Skipping a rung is permitted and discouraged | design | A promotion is checked against its origin | no requirement: permission plus guidance; rung-skipping is its third paragraph |
| D6: A published beta or GA member that stops shipping must be tombstoned | design | A removal is declared, never blocked |  |
| D7: The tombstone record is cumulative and append-only across builds | design | The record is cumulative and sits on the catalog |  |
| D8: The tombstone map lives on `#Catalog`, beside the contract member maps | design | The record is cumulative and sits on the catalog |  |
| D9: `replacedBy` is optional; `reason` is required | design | A removal is declared, never blocked | the optional replacement and required reason are in its second paragraph |
| D10: A key may not be withdrawn until its replacement has been published for a minimum seasoning | design | The clock is a floor on the producer |  |
| D11: Alpha members are never tombstoned, and transformers cannot be | design | A removal is declared, never blocked | no requirement: the alpha and transformer carve-outs are its last paragraph; the alpha refusal is a requirement of the retirement capability |
| D12: Blocking a withdrawal that would strand live instances is out of scope and belongs to the controller | evidence; design | evidence: delivery-log.md; design: The controller owns the stranding guard | the old `delivery.yaml` recorded D12 as no work; the note is in delivery-log.md |

## Open questions

| Old id | Disposition | Target |
| --- | --- | --- |
| OQ1 | proposal (still open, blocks acceptance) | Open questions |
| OQ2 | proposal (still open, blocks acceptance) | Open questions |
| OQ3 | proposal (still open, does not block) | Open questions |
| OQ4 | proposal (still open, blocks acceptance) | Open questions |
| OQ5 | proposal (still open, does not block) | Open questions |
| OQ6 | proposal (still open, blocks acceptance) | Open questions |
| OQ7 | proposal (still open, does not block) | Open questions |
| OQ8 | proposal (still open, does not block) | Open questions |

Counts: 8 questions, all still open, so all eight stay in the proposal. The old register is in `questions.md`. The old register marks OQ1, OQ2, OQ4 and OQ6 as blocking acceptance, so the proposal marks them `- Blocking:`. It marks OQ3, OQ5, OQ7 and OQ8 as deferrable, so the proposal marks them `- Not blocking:`. OQ3 is also called contract-level in the old text, which says contract-level questions must resolve before acceptance; the proposal follows the explicit blocking mark. The proposal lists them in the order OQ1, OQ2, OQ3, OQ4, OQ5, OQ6, OQ7, OQ8.
