# Migration map: 0023

source: 0023 @ 18705155d2c7312029132c30d2b106ca59e57125

The old text stays in git at that commit: `git show 18705155d2c7312029132c30d2b106ca59e57125:0023/03-decisions.md`. The 8 requirements are the lines of that file that start `- Rn:` under a `**Requirements:**` heading. Every `kept` target is `capability/Requirement name` in `specs/` of this folder. 0023 restarts as a draft, so its eight open questions stay in the proposal. A decision row names one target for each of its dispositions. No old requirement is cut, moved or sent to a repo: the old text was already at intent level and each requirement is kept one for one.

## Requirements

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |
| 0023:D1:R1 | kept | artifact-claims/A claim names a manifest digest |  |
| 0023:D1:R2 | kept | artifact-claims/Attaching a claim leaves the artifact unchanged |  |
| 0023:D1:R3 | kept | artifact-claims/A claim follows the digest, not the tag |  |
| 0023:D1:R4 | kept | artifact-claims/A claim declares its kind |  |
| 0023:D2:R1 | kept | platform-trust-policy/A platform declares whom it trusts |  |
| 0023:D2:R2 | kept | platform-trust-policy/Every materialized artifact is verified first |  |
| 0023:D2:R3 | kept | platform-trust-policy/The CLI and controller reach one verdict |  |
| 0023:D2:R4 | kept | platform-trust-policy/The controller enforces and the CLI reports |  |

Totals: kept 8, cut 0, repo 0, moved 0 (merged 0). Sum 8, equal to the 8 old ids (D1 4, D2 4). Check: kept + moved + cut + repo = 8. Each of the 8 new requirements has one `kept` row.

## Decisions

Every `### Dn:` heading of the old log. The full reasoning and the alternatives of each decision are in `decision-log.md`. The design keeps one line for each rejected option. No decision is dropped. The two decisions are the only ones the old entry recorded; the rest of the old design was a sketch held by open questions.

| Old heading | Disposition | Target | Note |
| --- | --- | --- | --- |
| D1: Provenance and signatures attach as OCI referrers to the artifact's manifest digest | design | design: Claims attach beside the artifact | the four rejected options are lines of Considered and rejected |
| D2: The trust policy is the platform's | design | design: The platform owns the trust policy | the three rejected options are lines of Considered and rejected; D2 depended on 0019:D5, now the `after` hint 0019 |

## Open questions

| Old id | Disposition | Target |
| --- | --- | --- |
| OQ1 | proposal (still open, blocks acceptance) | Open questions |
| OQ2 | proposal (still open, blocks acceptance) | Open questions |
| OQ3 | proposal (still open, blocks acceptance) | Open questions |
| OQ4 | proposal (still open, blocks acceptance) | Open questions |
| OQ5 | proposal (still open, blocks acceptance) | Open questions |
| OQ6 | proposal (still open, does not block) | Open questions |
| OQ7 | proposal (still open, does not block) | Open questions |
| OQ8 | proposal (still open, does not block) | Open questions |

Counts: 8 questions, all open, all in the proposal in the order of the old register: OQ1 capability manifest, OQ2 advisories, OQ3 trust-policy shape and home, OQ4 SLSA level, OQ5 online or offline and default mode, OQ6 recursive verification, OQ7 local registry and demo, OQ8 verification by rebuild. The old register is in `questions.md`.
