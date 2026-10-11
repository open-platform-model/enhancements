# Migration map: 0017

source: 0017 @ 18705155d2c7312029132c30d2b106ca59e57125

The old text stays in git at that commit: `git show 18705155d2c7312029132c30d2b106ca59e57125:0017/03-decisions.md`. The 23 requirements are the lines of that file that start `- Rn:` under a `**Requirements:**` heading. Every `kept` target is `capability/Requirement name` in `specs/` of this folder. No old requirement is cut, merged, moved to another entry or left for a repo, so there is no `cut-requirements.md`. A decision row names one target for each of its dispositions; a free note goes in the Note column. 0017 restarts as a draft, so its open questions stay in the proposal.

## Requirements

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |
| 0017:D1:R1 | kept | default-precedence/An instance value beats every default |  |
| 0017:D1:R2 | kept | default-precedence/A config default beats a blueprint default |  |
| 0017:D1:R3 | kept | default-precedence/A blueprint default renders when nothing above speaks |  |
| 0017:D1:R4 | kept | default-precedence/A field no layer speaks for stays absent |  |
| 0017:D2:R1 | kept | primitive-bounds/A primitive marks no default |  |
| 0017:D2:R2 | kept | primitive-bounds/A primitive admits what any kind accepts |  |
| 0017:D2:R3 | kept | primitive-bounds/A defaulted primitive is refused at publish |  |
| 0017:D3:R1 | kept | blueprint-defaults/A blueprint narrows only by subtraction | the publish refusal of a widening narrowing is in the second scenario |
| 0017:D3:R2 | kept | blueprint-defaults/A blueprint marks one leaf default per field |  |
| 0017:D3:R3 | kept | blueprint-defaults/A blueprint default yields to the author | the unset, override and invalid cases are the three steps of one scenario |
| 0017:D4:R1 | kept | config-finalization/A broken config default fails the render |  |
| 0017:D4:R2 | kept | config-finalization/Every values path finalizes the same way |  |
| 0017:D4:R3 | kept | config-finalization/Finalization never creates an unset field |  |
| 0017:D5:R1 | kept | trait-optionality/An optional trait leaves its field absent |  |
| 0017:D5:R2 | kept | trait-optionality/An author's value is enforced and present |  |
| 0017:D5:R3 | kept | trait-optionality/A required trait makes its field required |  |
| 0017:D5:R4 | kept | trait-optionality/A trait with no stated posture fails everywhere |  |
| 0017:D5:R5 | kept | trait-optionality/The composed spec stays closed |  |
| 0017:D5:R6 | kept | trait-optionality/A trait spec carries one top-level field |  |
| 0017:D7:R1 | kept | primitive-bounds/The retired defaults definitions are gone |  |
| 0017:D8:R1 | kept | plain-cue-compatibility/Plain vet passes every valid package |  |
| 0017:D8:R2 | kept | plain-cue-compatibility/The kernel never silently differs from plain CUE |  |
| 0017:D8:R3 | kept | plain-cue-compatibility/Exactly two divergences exist; render-parity/A divergence closes by removing kernel behaviour | the second target is a MODIFIED of the seeded requirement of that name: the closing rule gains the two accepted divergences |

Totals: kept 23, cut 0, repo 0, moved 0 (merged 0). Sum 23, equal to the 23 old ids (D1 4, D2 3, D3 3, D4 3, D5 6, D7 1, D8 3; D6 has none). Each of the 23 new requirements has exactly one `kept` row; one of them, 0017:D8:R3, also has the MODIFIED render-parity requirement as a second target. Check: kept + moved + cut + repo = 23.

## Decisions

Every `### Dn:` heading of the old log. The full reasoning and the alternatives of each decision are in `decision-log.md`. The design keeps one line for each rejected option someone would propose again. No decision is dropped.

| Old heading | Disposition | Target | Note |
| --- | --- | --- | --- |
| D1: Four-layer precedence chain, composed from lattice behavior rather than a precedence feature | design | The order falls out of CUE | the first alternative is in the first line of Considered and rejected; the single transformer-only layer is the last line |
| D2: Primitives publish bounds, never defaults | design | Primitives publish bounds |  |
| D3: The blueprint is the single catalog-side defaulting layer (field-level defaults plus subtractive narrowing) | design | The blueprint is the one defaulting layer | the update strategy posture is OQ1, which stays in the proposal |
| D4: The kernel finalizes validated `#config` to concrete data before composition | design | The kernel finalizes config to data | the mechanism is OQ3, which stays in the proposal |
| D5: Core's component projection honors trait optionality | design | Core honours trait optionality | the dependency on 0010 D28 is history: 0010 is archived and the design names enhancement 0010 in words |
| D6: The layer contract is specification with citable rules, enforced by the toolchain | design | The contract is specification, enforced by tools | it has no requirement; the refusals it assigns are stated in the primitive and blueprint requirements and in the config requirement; the rule data is in `contracts/` |
| D7: The retired `#*Defaults` definitions are removed | design | Primitives publish bounds | landed in the catalog; ticked as task 3.1 |
| D8: Plain-CUE compatibility is a hard constraint on every mechanism | design | Plain CUE stays the floor | the gate question is OQ5, which stays in the proposal |

## Open questions

| Old id | Disposition | Target |
| --- | --- | --- |
| OQ1 | proposal (still open, blocks acceptance) | Open questions |
| OQ2 | proposal (still open, does not block) | Open questions |
| OQ3 | proposal (still open, blocks acceptance) | Open questions |
| OQ4 | proposal (still open, blocks acceptance) | Open questions |
| OQ5 | proposal (still open, does not block) | Open questions |

Counts: 5 questions, all still open, so all five stay in the proposal. The old register is in `questions.md`. The old text marks OQ2 as deferrable and gives OQ5 no blocking mark, so the proposal marks both `- Not blocking:`. The other three wait on acceptance in the old text and are marked `- Blocking:`. The proposal lists them in the order OQ1, OQ2, OQ3, OQ5, OQ4.
