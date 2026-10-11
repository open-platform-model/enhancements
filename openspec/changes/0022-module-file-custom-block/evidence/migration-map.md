# Migration map: 0022

source: 0022 @ 18705155d2c7312029132c30d2b106ca59e57125

The old text stays in git at that commit: `git show 18705155d2c7312029132c30d2b106ca59e57125:0022/03-decisions.md`. The 28 requirements are the lines of that file that start `- Rn:` under a `**Requirements:**` heading. Every `kept` target is `capability/Requirement name` in `specs/` of this folder. No requirement is cut, sent to a repo or moved, so this entry has no `cut-requirements.md`. 0022 stays a draft, so all six open questions stay in the proposal. A decision row names one target for each of its dispositions; a free note goes in the Note column.

## Requirements

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |
| 0022:D1:R1 | kept | module-file-block/The block sits under a reserved key |  |
| 0022:D1:R2 | kept | module-file-block/Adding a key keeps the key suffix |  |
| 0022:D1:R3 | kept | module-file-block/A reader ignores unknown block keys |  |
| 0022:D1:R4 | kept | module-file-block/Every block value is concrete |  |
| 0022:D1:R5 | kept | module-file-block/The block survives dependency tidying | the old text said byte-verbatim before the 2026-10-04 measurement; it now says values intact |
| 0022:D2:R1 | kept | module-file-block/The block carries four required facts |  |
| 0022:D2:R2 | kept | module-file-block/The kind is module, catalog or template |  |
| 0022:D2:R3 | kept | module-file-block/The identity repeats the path and version |  |
| 0022:D2:R4 | kept | module-file-block/The core line names major and version |  |
| 0022:D2:R5 | kept | module-file-block/The catalogs map each dependency to its pin |  |
| 0022:D2:R6 | kept | module-file-block/The block carries no toolchain fact |  |
| 0022:D2:R7 | kept | module-file-block/A block may carry keys this entry omits | added 2026-10-04 when the block opened |
| 0022:D4:R1 | kept | block-publish-gate/Publish refuses a stale identity |  |
| 0022:D4:R2 | kept | block-publish-gate/Publish refuses a wrong core line |  |
| 0022:D4:R3 | kept | block-publish-gate/Publish refuses a wrong catalog list |  |
| 0022:D4:R4 | kept | block-publish-gate/A refusal names both values and the repair | the writer command is named in the message |
| 0022:D5:R1 | kept | block-authoring/Scaffolding seeds the block |  |
| 0022:D5:R2 | kept | block-authoring/A version write updates the block; module-authoring/Version set changes only the version value | the first is the general rule for every version write; the second is a MODIFIED of the seeded requirement of that name, whose "nothing else" clause the first would otherwise contradict |
| 0022:D5:R3 | kept | module-authoring/Init scaffolds by fetch and re-identification | a MODIFIED of the seeded requirement of that name: the re-identified items gain the block's identity module path; the old requirement's scenario is its last scenario |
| 0022:D5:R4 | kept | block-authoring/A block write keeps comments and is idempotent |  |
| 0022:D5:R5 | kept | block-authoring/A block write keeps unowned keys | added 2026-10-04 with the open tail |
| 0022:D7:R1 | kept | published-module-resolution/No selector selects the highest core-compatible major | a MODIFIED of the seeded requirement of that name: the walk skips a non-module release; the old requirement's scenario is its sixth scenario |
| 0022:D7:R2 | kept | published-module-resolution/No selector selects the highest core-compatible major | the dependency fallback; the same MODIFIED as 0022:D7:R1, whose last scenario is this requirement's scenario |
| 0022:D7:R3 | kept | block-reader/Block and dependency verdicts agree |  |
| 0022:D8:R1 | kept | block-publish-gate/A missing block warns first |  |
| 0022:D8:R2 | kept | block-publish-gate/A dated release refuses a missing block |  |
| 0022:D8:R3 | kept | block-publish-gate/The module check reports a missing block |  |
| 0022:D8:R4 | kept | block-publish-gate/Published artifacts are never affected |  |

Totals: kept 28, cut 0, repo 0, moved 0 (merged 0). Sum 28, equal to the 28 old ids (D1 5, D2 7, D4 4, D5 5, D7 3, D8 4; D3 and D6 have none). Each of the 28 old requirements has one `kept` row. Four of them (0022:D5:R2, 0022:D5:R3, 0022:D7:R1, 0022:D7:R2) point at a MODIFIED requirement of a seeded capability. 0022:D5:R2 also keeps its ADDED requirement, so the entry's own capabilities hold 25 ADDED requirements. Check: kept + moved + cut + repo = 28.

## Decisions

Every `### Dn:` heading of the old log. The full reasoning and the alternatives of each decision are in `decision-log.md`. The design keeps one line for each rejected option someone would propose again. No decision is dropped.

| Old heading | Disposition | Target | Note |
| --- | --- | --- | --- |
| D1: The block lives at `custom."opmodel.dev@v0"` in `cue.mod/module.cue`, and the suffix is the block's schema major | design | One block under a reserved key | the full alternatives and the measurement are in decision-log.md |
| D2: The block carries `kind`, `identity`, `core` and `catalogs`, and nothing about toolchains | design | One block under a reserved key | the open tail and its measurement are in decision-log.md |
| D3: Module, catalog and template artifacts carry the block; `core` and `library` do not | design | One block under a reserved key | a scope decision with no requirement; the bounds are stated in the first theme |
| D4: A core-shipped publish gate asserts every duplicated value, and a mismatch refuses | design | The block cannot lie | the open catalog rule (OQ1) and the kind-against-path rule (OQ2) stay in the proposal |
| D5: Tooling authors the block in the tree; publish never writes it | design | Tooling writes the block, publish never does | the amendment of the 0011 writer decision is OQ4, in the proposal |
| D6: Push-time provenance lives in OCI manifest annotations, never in the tree | design | Push-time facts go to annotations | a policy with no requirement; the key set is OQ3, in the proposal |
| D7: 0016's major walk is the first reader, and a missing block falls back to parsing `deps` | design | The first reader falls back |  |
| D8: A missing block is a warning first and a refusal only from a dated release | design | A missing block warns before it refuses |  |

## Open questions

| Old id | Disposition | Target |
| --- | --- | --- |
| OQ1 | proposal (still open, blocks acceptance) | Open questions |
| OQ2 | proposal (still open, blocks acceptance) | Open questions |
| OQ3 | proposal (still open, deferrable) | Open questions |
| OQ4 | proposal (still open, blocks acceptance) | Open questions |
| OQ5 | proposal (still open, blocks implementation only) | Open questions |
| OQ6 | proposal (still open, blocks acceptance) | Open questions |

Counts: 6 questions. None was answered in the old text, so all six stay in the proposal as questions. OQ3 and OQ5 are `Not blocking`: the old register gives them `deferrable` and `implementation`, and neither holds acceptance. The old register is in `questions.md`.
