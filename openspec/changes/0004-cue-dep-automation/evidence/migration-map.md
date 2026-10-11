# Migration map: 0004

source: 0004 @ 18705155d2c7312029132c30d2b106ca59e57125

The old text stays in git at that commit: `git show 18705155d2c7312029132c30d2b106ca59e57125:0004/03-decisions.md`. The 13 requirements are the lines of that file that start `- Rn:` under a `**Requirements:**` heading. Every `kept` target is `capability/Requirement name` in `specs/` of this folder. 0004 restarts as a draft with one new requirement for each old one, so nothing is cut, merged, moved to a repo or moved to another entry. All six old open questions were resolved in the old text, so they move into the design as answers and the proposal keeps none. A decision row names one target for each of its dispositions, written `<disposition>: <name>` and separated by a semicolon; a free note goes in the Note column.

## Requirements

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |
| 0004:D7:R1 | kept | cue-dependency-bump/Every module under a directory is bumped |  |
| 0004:D7:R2 | kept | cue-dependency-bump/A bumped module is consistent |  |
| 0004:D7:R3 | kept | cue-dependency-bump/Registries come from the CUE registry mapping |  |
| 0004:D7:R4 | kept | cue-dependency-bump/A run reports every bump |  |
| 0004:D8:R1 | kept | cue-dependency-bump/A bump stays inside the pinned major |  |
| 0004:D8:R2 | kept | cue-dependency-bump/A newer major is not offered |  |
| 0004:D9:R1 | kept | local-dependency-sweep/Local and scheduled runs share one implementation |  |
| 0004:D9:R2 | kept | local-dependency-sweep/The local sweep keeps its invocation |  |
| 0004:D10:R1 | kept | dependency-update-pr/A run opens at most one pull request |  |
| 0004:D10:R2 | kept | dependency-update-pr/A later run updates the open pull request |  |
| 0004:D10:R3 | kept | dependency-update-pr/A run with no remaining difference closes it |  |
| 0004:D10:R4 | kept | dependency-update-pr/The scheduled run happens daily |  |
| 0004:D11:R1 | kept | cue-dependency-bump/Test-fixture modules are bumped |  |

Totals: kept 13, cut 0, repo 0, moved 0 (merged 0). Sum 13, equal to the 13 old ids (D7 4, D8 2, D9 2, D10 4, D11 1; D1 to D6, D12 and D13 state "Requirements: none" with a reason). Each of the 13 new requirements has one `kept` row. No `cut-requirements.md` exists, because no requirement is cut. Check: kept + moved + cut + repo = 13.

## Decisions

Every `### Dn:` heading of the old log. The full reasoning and the alternatives of each decision are in `decision-log.md`. The design keeps one line for each rejected option someone would propose again. No decision is dropped. D1, D2, D3 and D4 are the superseded decisions of the first, Renovate-based design; they stay in `decision-log.md` with their reasons.

| Old heading | Disposition | Target | Note |
| --- | --- | --- | --- |
| D1: Self-hosted Renovate via `renovatebot/github-action` | evidence; design | evidence: decision-log.md; design: Considered and rejected | superseded by D7; the rejected options are lines in the design |
| D2: Uniform OCI (`docker`) datasource for all CUE deps | evidence; design | evidence: decision-log.md; design: Considered and rejected | superseded by D7; the rejected options are lines in the design |
| D3: Major version pinned, no auto cross-major bumps | evidence; design | evidence: decision-log.md; design: The major is never crossed | the mechanism was superseded by D8; the property of never crossing a major is kept |
| D4: Renovate augments, does not replace, `task update-deps` | evidence; design | evidence: decision-log.md; design: Considered and rejected | superseded by D9; the coexistence posture no longer holds |
| D5: Design home is enhancement 0004 | evidence | evidence: decision-log.md | records where the design lives; a consumer observes nothing |
| D6: Scope locked to CUE modules only | design | design: CUE only, other ecosystems parked | reaffirmed by D13 |
| D7: Path-driven Dagger module replaces self-hosted Renovate | design | design: One path-driven function, not a hosted bot | |
| D8: Major-version pinning is inherent to `cue mod get <mod>@v<major>` | design | design: The major is never crossed | |
| D9: `task update-deps` is reimplemented over the Dagger function | design | design: Local and scheduled runs share one implementation | |
| D10: One grouped PR per repo per run, on a fixed branch, daily | design | design: One grouped pull request per repo per run | |
| D11: Test-fixture modules are included | design | design: Everything is bumped, fixtures too | |
| D12: Dagger module in `daggerverse`, reusable workflow in `.github` | design | design: Shared parts live once | |
| D13: Multi-ecosystem parked, deferred to a separate enhancement after investigating Renovate-in-Dagger | design | design: CUE only, other ecosystems parked | Architecture B stays the recorded starting point of a successor entry |

## Open questions

| Old id | Disposition | Target |
| --- | --- | --- |
| OQ1 | design (answered by D7) | One path-driven function, not a hosted bot |
| OQ2 | design (answered by D7) | One path-driven function, not a hosted bot |
| OQ3 | design (answered by D10) | One grouped pull request per repo per run |
| OQ4 | design (answered by D12) | Shared parts live once |
| OQ5 | design (answered by D11) | Everything is bumped, fixtures too |
| OQ6 | design (answered by D10) | One grouped pull request per repo per run |

Counts: 6 questions. All six were resolved in the old text and move into the design as answers. The proposal keeps no open question. The old register is in `questions.md`.
