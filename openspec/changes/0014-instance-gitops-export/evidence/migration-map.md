# Migration map: 0014

source: 0014 @ 18705155d2c7312029132c30d2b106ca59e57125

The old text stays in git at that commit: `git show 18705155d2c7312029132c30d2b106ca59e57125:0014/03-decisions.md`. The 14 requirements are the lines of that file that start `- Rn:` under a `**Requirements:**` heading. Every `kept` target is `capability/Requirement name` in `specs/` of this folder. 0014 restarts as a draft, so its six open questions stay in the proposal. A decision row names one target for each of its dispositions, written `<disposition>: <name>`; a free note goes in the Note column.

## Requirements

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |
| 0014:D1:R1 | kept | instance-export/An export is one directory per instance |  |
| 0014:D1:R2 | kept | instance-export/The exported directory applies on its own |  |
| 0014:D1:R3 | kept | instance-export/No repo-level Flux wiring is exported |  |
| 0014:D1:R4 | kept | instance-export/Exporting an unchanged instance is byte-stable |  |
| 0014:D1:R5 | kept | instance-export/The exported module version keeps its v prefix |  |
| 0014:D1:R6 | kept | instance-export/Completed fields are named in the output |  |
| 0014:D2:R1 | kept | export-verification/Export writes only a reproduced render |  |
| 0014:D2:R2 | kept | export-verification/A failed precondition aborts with nothing written |  |
| 0014:D2:R3 | kept | export-verification/A forced export skips only the digest check |  |
| 0014:D2:R4 | kept | export-verification/The report states both digests and the outcome |  |
| 0014:D3:R1 | kept | instance-export/Exported values are copied byte for byte | the text adds one sentence: where a path is marked secret, the encryption requirement governs |
| 0014:D3:R2 | kept | instance-export/Every export that writes values warns |  |
| 0014:D4:R1 | kept | instance-export/The live instance is the only input |  |
| 0014:D4:R2 | kept | instance-export/A bulk export writes one directory per instance |  |

Totals: kept 14, merged 0, cut 0, repo 0, moved 0. Sum 14, equal to the 14 old ids (D1 6, D2 4, D3 2, D4 2).

Moved in from 0013. Three requirements of 0013 moved into this entry, as 0013's own map records (the rows for D14 R4, D26 R1 and D26 R2, each `moved`, target `0014 instance-export/<name>`). They are written in `specs/instance-export/spec.md` under exactly those names, from 0013's old text (`0013/03-decisions.md` at the source commit above), and they are not rows of this table because they have no old id in 0014:

- 0013's D14 R4 is now "Secret-bearing export output can be SOPS-encrypted". Old text: "When an instance is exported for GitOps consumption, its Secret-bearing output can be SOPS-encrypted on write for cluster-side decryption."
- 0013's D26 R1 is now "Exported secret values are encrypted". Old text: "An exported instance carries no plaintext secret value, and every other field of it stays readable and diffable."
- 0013's D26 R2 is now "An exported instance renders as the original". Old text: "The exported instance, once decrypted by the GitOps tool, renders exactly as the unexported one."

0013 decision D26 amends its own D14 and the old verbatim-values decision of this entry ("Amends: D14, 0014:D3"). The design says so, and all three requirements stay ADDED. The new count of this entry is 14 + 3 = 17 requirements.

## Decisions

Every `### Dn:` heading of the old log. The full reasoning and the alternatives of each decision are in `decision-log.md`. The design keeps one line for each rejected option. No decision is dropped.

| Old heading | Disposition | Target | Note |
| --- | --- | --- | --- |
| D1: The exported unit is the instance's apply envelope, not the bare CR | design | design: The export is the apply envelope | the field split of the same decision is the theme "Fields are copied, completed or dropped"; the measured 2026-09-29 fields are in decision-log.md |
| D2: Export refuses to write unless the published module reproduces the deployed render | design | design: Nothing is written unless the module reproduces the render | |
| D3: `spec.values` is written verbatim, with a warning | design | design: Values are copied unchanged, with a warning | 0013's moved requirements narrow it where a path is marked secret |
| D4: The live CR is the sole input | design | design: The live instance is the only input | |

## Open questions

| Old id | Disposition | Target |
| --- | --- | --- |
| OQ1 | proposal (still open, blocks acceptance) | Open questions |
| OQ2 | proposal (still open, blocks acceptance) | Open questions |
| OQ3 | proposal (still open, blocks acceptance) | Open questions |
| OQ4 | proposal (still open, blocks acceptance) | Open questions |
| OQ5 | proposal (still open, blocks acceptance) | Open questions |
| OQ6 | proposal (still open, does not block) | Open questions |

Counts: 6 questions, all six stay in the proposal, in the old order: five `- Blocking:` and one `- Not blocking:` (OQ6, marked deferrable in the old text). The old register is in `questions.md`.
