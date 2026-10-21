# Migration map: 0021

source: 0021 @ 18705155d2c7312029132c30d2b106ca59e57125

The old text stays in git at that commit: `git show 18705155d2c7312029132c30d2b106ca59e57125:0021/03-decisions.md`. The 57 requirements are the lines of that file that start `- Rn:` under a `**Requirements:**` heading. Every `kept` target is `capability/Requirement name` in `specs/` of this folder. The `cut` target is the line of `cut-requirements.md` that starts with the old id. 0021 amends 0006 in two decisions (the old D9 and D11). The converted entry has no seed of 0006 to modify, so those requirements are `kept` as ADDED, and the design says so. Decisions D1, D3, D4 and D5 had no requirement of their own, and the new entry adds none for them. A decision row names its theme in `design.md`. 0021 restarts as a draft, so its open questions stay in the proposal, except OQ9, which the old register had already resolved. The old `delivery.yaml` is in `delivery-log.md`.

## Requirements

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |
| 0021:D2:R1 | kept | module-compatibility/A config break carries a new major | |
| 0021:D2:R2 | kept | module-compatibility/A wider config carries at least a minor | |
| 0021:D2:R3 | kept | module-compatibility/An unchanged config carries at least a patch | |
| 0021:D2:R4 | kept | module-compatibility/The bump is the largest change class | |
| 0021:D2:R5 | kept | module-compatibility/A new required field is breaking | |
| 0021:D6:R1 | kept | transformer-levels/A transformer is declared once per level | |
| 0021:D6:R2 | kept | transformer-levels/A differing level carries a projection | |
| 0021:D6:R3 | kept | transformer-levels/A catalog states the levels it serves | |
| 0021:D7:R1 | kept | beta-release-line/A beta release carries a rising counter | |
| 0021:D7:R2 | kept | beta-release-line/A beta break carries a migration note | |
| 0021:D7:R3 | kept | beta-release-line/A beta break keeps the module path | |
| 0021:D7:R4 | kept | beta-release-line/A stable line breaks as a new major | |
| 0021:D7:R5 | kept | beta-release-line/A core beta break needs owner sign-off | |
| 0021:D7:R6 | kept | beta-release-line/Moving to beta leaves contract levels alone | |
| 0021:D7:R7 | kept | beta-release-line/The first GA drops only the suffix | |
| 0021:D8:R1 | kept | ga-exit-criteria/The announced breaking change lands before GA | |
| 0021:D8:R2 | kept | ga-exit-criteria/Draft entries that would break GA are named | |
| 0021:D8:R3 | kept | ga-exit-criteria/The controller's CRD version is decided before GA | |
| 0021:D8:R4 | kept | ga-exit-criteria/The library records a migration note per break | |
| 0021:D8:R5 | cut | cut-requirements.md: 0021:D8:R5 | tombstone: the raw Kubernetes catalog is retired, no behaviour to carry |
| 0021:D8:R6 | kept | ga-exit-criteria/Latest resolves to the GA release | |
| 0021:D8:R7 | kept | ga-exit-criteria/No new pin names a GA line's prerelease | |
| 0021:D8:R8 | kept | ga-exit-criteria/Templates and the quickstart follow GA | |
| 0021:D8:R9 | kept | ga-exit-criteria/GA releases are cut in dependency order | |
| 0021:D8:R10 | kept | ga-exit-criteria/A GA line can cut a release branch | |
| 0021:D8:R11 | kept | library-ga-bar/Render output is plain data | |
| 0021:D8:R12 | kept | library-ga-bar/Fetch and resolution failures are typed | |
| 0021:D8:R13 | kept | library-ga-bar/Specs and documents match the code | |
| 0021:D8:R14 | kept | library-ga-bar/Three quiet betas are a guideline | |
| 0021:D9:R1 | kept | controller-version-ceiling/The ceiling compares MAJOR.MINOR only | |
| 0021:D9:R2 | kept | controller-version-ceiling/No controller release needs a newer CLI | |
| 0021:D9:R3 | kept | controller-version-ceiling/Install is not refused by the running controller | |
| 0021:D9:R4 | kept | controller-version-ceiling/Install refuses a module with a newer controller | |
| 0021:D10:R1 | kept | immutable-release-tags/A tag keeps its commit | |
| 0021:D10:R2 | kept | immutable-release-tags/A broken release is fixed forward | |
| 0021:D10:R3 | kept | immutable-release-tags/A version-named registry tag keeps its content | |
| 0021:D10:R4 | kept | immutable-release-tags/Documentation pins name fixed refs | |
| 0021:D10:R5 | kept | release-branches/A maintenance branch comes from the cut action | |
| 0021:D10:R6 | kept | immutable-release-tags/Rulesets refuse tag changes | |
| 0021:D10:R7 | kept | immutable-release-tags/Only the release app creates tags | |
| 0021:D10:R8 | kept | immutable-release-tags/Immutable releases are staged | |
| 0021:D10:R9 | kept | release-branches/Main and a branch never release one version | |
| 0021:D10:R10 | kept | release-branches/No cut before the automation is proven | |
| 0021:D10:R11 | kept | release-branches/A branch pull request runs main's checks | |
| 0021:D10:R12 | kept | release-branches/A failed cut never strands a branch | |
| 0021:D11:R1 | kept | controller-install-module/Install resolves the controller module from a registry | |
| 0021:D11:R2 | kept | controller-install-module/A mirror gives the same install | |
| 0021:D11:R3 | kept | controller-install-module/The module has its own version train | |
| 0021:D11:R4 | kept | controller-install-module/The module major stays v0 until controller GA | |
| 0021:D11:R5 | kept | controller-install-module/One module version deploys one controller version | |
| 0021:D11:R6 | kept | controller-install-module/Each CLI release names its module and controller | |
| 0021:D11:R7 | kept | controller-install-module/The CRDs-only form uses the same render | |
| 0021:D11:R8 | kept | controller-install-module/Install leaves an existing Platform alone | |
| 0021:D11:R9 | kept | controller-install-module/The controller never touches its own instance | |
| 0021:D11:R10 | kept | controller-install-module/Install does not depend on the cluster Platform | |
| 0021:D11:R11 | kept | controller-install-module/Uninstall removes what the inventory holds | |
| 0021:D11:R12 | kept | controller-install-module/No module release is marked latest | |

Totals: kept 56, cut 1, repo 0, moved 0 (merged 0). Sum 57, equal to the 57 old ids (D2 5, D6 3, D7 7, D8 14, D9 4, D10 12, D11 12; D1, D3, D4 and D5 have none). The new entry has 56 requirements, because the old D8 R5 is a tombstone with no behaviour. The old D10 R3 holds two promises (a version-named registry tag keeps its content, and a branch release never moves the latest pointers). Both stay in one requirement.

## Decisions

Every `### Dn:` heading of the old log. The full reasoning and the alternatives of each decision are in `decision-log.md`. The design keeps one line for each rejected option. No decision is dropped.

| Old heading | Disposition | Target | Note |
| --- | --- | --- | --- |
| D1: One versioning policy names every published artifact class | design | One policy covers every published artifact |  |
| D2: A module's compatibility surface is its `#config` schema | design | A module's surface is its config schema |  |
| D3: Settled rulings are copied verbatim into the policy, each under its source | design | Settled rules are copied word for word | the copied text moved to evidence/policy/ |
| D4: The classes the policy covers | design | One policy covers every published artifact | the class list and the exclusions; the controller module in the module class |
| D5: An alpha contract is encouraged, not required, to bump its alpha number on a break | design | An alpha contract is encouraged to bump |  |
| D6: A transformer serves a contract level by naming it: one registration per level, one shared body | design | A transformer serves a level by naming it |  |
| D7: A `-beta.N` release line is pre-stable on the path to GA, and breaks only as a declared, migrated change | design | A beta line promises a path to GA | the kernel library bar is in the next theme |
| D8: A beta line reaches GA only when its exit criteria hold | design | GA has written exit criteria | the library bar has its own theme, The kernel library has an API-quality bar |
| D9: The CLI's ceiling on controller versions compares `MAJOR.MINOR` only | design | The CLI ceiling compares MAJOR.MINOR | amends 0006; written ADDED, no seed |
| D10: Release tags are immutable | design | Release tags are immutable | the maintenance branches have their own theme, A released minor gets a lazy maintenance branch |
| D11: The controller's install artifact is a registry module on its own version train | design | The controller installs from a registry module | amends six decisions of 0006; written ADDED, no seed |

## Open questions

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |
| OQ1 | proposal | Open questions | |
| OQ2 | proposal | Open questions | |
| OQ3 | proposal | Open questions | |
| OQ4 | proposal | Open questions | |
| OQ5 | proposal | Open questions | |
| OQ6 | proposal | Open questions | |
| OQ7 | proposal | Open questions | |
| OQ8 | proposal | Open questions | |
| OQ9 | design | GA has written exit criteria | answered: the controller serves the first CRD version with no conversion at GA |
| OQ10 | proposal | Open questions | |
| OQ11 | proposal | Open questions | |
| OQ12 | proposal | Open questions | |
| OQ13 | proposal | Open questions | |
| OQ14 | proposal | Open questions | |
| OQ15 | proposal | Open questions | |
| OQ16 | proposal | Open questions | |
| OQ17 | proposal | Open questions | |

Counts: 17 question headings. OQ1 to OQ8 and OQ10 to OQ17 are open and stay in the proposal, 16 questions in the order of their old numbers. OQ1, OQ2, OQ3, OQ4, OQ7, OQ8, OQ14 and OQ15 are marked `- Blocking:` because the old text says they block acceptance. The others are marked `- Not blocking:`: the old text defers them. OQ9 is answered by the first-GA ruling of 2026-10-08 and moves to the design. The old register is in `questions.md`.
