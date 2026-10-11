# Migration map: 0026

source: 0026 @ 18705155d2c7312029132c30d2b106ca59e57125

The old text stays in git at that commit: `git show 18705155d2c7312029132c30d2b106ca59e57125:0026/03-decisions.md`. The 36 requirements are the lines of that file that start `- Rn:` under a `**Requirements:**` heading. Every target is a requirement in `specs/` of this folder, an ADDED or a MODIFIED one. The REMOVED requirements have no row of their own: each is named in the Note column of the row whose ADDED requirement replaces it. The notation follows the map of 0013.

## Requirements

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |
| 0026:D1:R1 | kept | catalog-version-selection/A module's catalog pin is the version held; single-build-render/The render list promotes the module's catalog pins |  |
| 0026:D1:R2 | kept | single-build-render/The render list promotes the module's catalog pins | REMOVED "The render's dependency list is derived by promotion" in single-build-render is replaced by this requirement |
| 0026:D1:R3 | kept | catalog-version-selection/A render records the catalog versions it held |  |
| 0026:D1:R4 | merged | catalog-version-selection/A module's catalog pin is the version held | second scenario |
| 0026:D2:R1 | kept | authored-platform/A platform is pure data naming admitted lineages; platform-module-generation/The Platform spec is the authored platform | the second target replaces "The Platform spec names type and pinned subscriptions" |
| 0026:D2:R2 | kept | catalog-version-selection/An unadmitted catalog is refused |  |
| 0026:D2:R3 | kept | catalog-version-selection/A pin outside the platform's range is refused |  |
| 0026:D2:R4 | kept | catalog-version-selection/An open ceiling admits later releases |  |
| 0026:D2:R5 | kept | authored-platform/Prereleases are admitted only by opt-in | pin refusal and bound rejection in one requirement |
| 0026:D2:R6 | kept | authored-platform/An entry needs a floor in its major; platform-module-generation/The Platform spec is the authored platform |  |
| 0026:D2:R7 | kept | authored-platform/The readiness build holds one major per catalog | with D9:R3; how the build is split is a blocking question |
| 0026:D3:R1 | kept | catalog-version-selection/The resolved platform is generated, never authored; platform-registry/A registry entry carries its catalog by import; platform-registry/Composed transformers are derived from enabled entries; platform-registry/One registry entry per catalog path; platform-registry/A platform carries no reverse index; platform-module-generation/Generation is pure and deterministic; platform-contract-inventory/A platform derives its contract inventory | MODIFIED: the rename of the shipped registry from `#Platform` to `#ResolvedPlatform` in the six seed requirements that name it |
| 0026:D3:R2 | kept | catalog-version-selection/The resolved platform holds only the build's catalogs |  |
| 0026:D3:R3 | kept | authored-platform/One platform value serves cluster and offline |  |
| 0026:D3:R4 | kept | catalog-version-selection/Identical resolutions share one generated package; platform-module-generation/The package depends on spec and active claims; platform-module-generation/Platform status names the package and its registry | the last two are MODIFIED: the package is keyed by the resolved catalog set |
| 0026:D3:R5 | kept | catalog-version-selection/A render without a platform holds its pins |  |
| 0026:D5:R1 | kept | catalog-version-selection/A provider catalog follows the same pin rule | with D6:R6 |
| 0026:D5:R2 | kept | catalog-version-selection/A provider catalog defaults to the registration's version |  |
| 0026:D5:R3 | kept | transformer-registration/A provider may state a compatibility window |  |
| 0026:D5:R4 | kept | transformer-registration/Every claim field is required at admission | MODIFIED: the rendered claim carries the window with its defaults filled |
| 0026:D6:R1 | kept | registration-acceptance/A registration alone admits its provider catalog |  |
| 0026:D6:R2 | kept | registration-acceptance/A platform entry replaces the provider's window whole |  |
| 0026:D6:R3 | kept | transformer-registration/Claim status separates acceptance from activation | MODIFIED: the status reports the effective window and its source |
| 0026:D6:R4 | kept | registration-acceptance/A platform range wider than the window warns |  |
| 0026:D6:R5 | kept | registration-acceptance/A platform range excluding the version is refused |  |
| 0026:D6:R6 | merged | catalog-version-selection/A provider catalog follows the same pin rule | render-time half of the provider window |
| 0026:D7:R1 | kept | catalog-version-selection/A provider's requirements are checked against pins | with D7:R3 |
| 0026:D7:R2 | kept | registration-acceptance/A build-incompatible provider is refused at acceptance | MODIFIED: the comparison uses the floor of the admitted entry of the provider's own major |
| 0026:D7:R3 | merged | catalog-version-selection/A provider's requirements are checked against pins | last sentence |
| 0026:D9:R1 | kept | authored-platform/Several majors of one catalog may be admitted |  |
| 0026:D9:R2 | kept | catalog-version-selection/A resolution holds one major per catalog |  |
| 0026:D9:R3 | merged | authored-platform/The readiness build holds one major per catalog | with D2:R7 |
| 0026:D9:R4 | kept | catalog-version-selection/A provider joins only resolutions of its major |  |
| 0026:D9:R5 | kept | registration-acceptance/A contract has one provider per declaring major; contract-fulfilment/A provider-fulfilled contract admits one provider per resolution; contract-fulfilment/Two providers of one major are refused; single-build-render/The single-provider guard counts per resolution | three REMOVED and ADDED pairs: "A contract has one provider", "A provider-fulfilled contract admits exactly one provider", "The single-provider guard runs inside the build" |
| 0026:D9:R6 | kept | catalog-version-selection/A module importing two majors is refused | the case with no platform is a blocking question, so no scenario states it |
| 0026:D9:R7 | kept | registration-acceptance/A contract has one provider per declaring major; registration-acceptance/A build-incompatible provider is refused at acceptance | conflict half and shared-path half |

Totals: kept 32, merged 4, cut 0, repo 0, moved 0. Sum 36, equal to the 36 old ids (D1 4, D2 7, D3 5, D5 4, D6 6, D7 3, D9 7; D4 and D8 have none).

## Decisions

| Old heading | Disposition | Target |
| --- | --- | --- |
| D1: A consumer module's committed catalog pin is the version its render holds | design | The module's pin is the version |
| D2: A platform admits catalog lineages through a pure-data `#Platform` ... | design | The platform admits and bounds |
| D3: The shipped platform value moves to `#ResolvedPlatform`, unchanged in shape ... | design | The resolved platform is generated |
| D4: An admission entry admits and bounds; it never loads a catalog | design | Admission never loads |
| D5: Provider catalogs use the same entry shape ... | design | Providers follow the same rule |
| D6: An admission entry for a provider catalog is optional ... | design | Providers follow the same rule |
| D7: The shared-path requirement check runs per render ... and at acceptance | design | The checks run twice |
| D8: Matching, the transformer-set derivation, admission authority and provider routing are unchanged | proposal | What this is not |
| D9: A platform may admit several majors of one catalog; each resolution holds exactly one major per catalog | design | Several majors side by side |

The alternatives of every decision are in `design.md`, "Considered and rejected", one line each. The measured alternatives of D9 are in `experiments/`. D4 and D8 hold no requirement; their text is in the design and the proposal. Nothing is dropped.

## Open questions

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |
| OQ1 | proposal | Open questions |  |
| OQ2 | proposal | Open questions |  |
| OQ3 | proposal | Open questions |  |
| OQ4 | proposal | Open questions | not blocking |
| OQ5 | proposal | Open questions | old text: Blocking: implementation; a Blocking line by the ruling of 2026-10-11 07:55 |
| OQ6 | proposal | Open questions | not blocking |
| OQ7 | proposal | Open questions | not blocking |
| OQ8 | design (resolved by decision 3 in the old text) | The resolved platform is generated | a render with no platform stays a platform-less path |
| OQ9 | proposal | Open questions | both halves stay open |
| OQ10 | proposal | Open questions |  |
| OQ11 | proposal | Open questions |  |
| OQ12 | proposal | Open questions |  |
| OQ13 | proposal | Open questions |  |
| OQ14 | proposal | Open questions | not blocking |
| OQ15 | proposal | Open questions | not blocking |
| OQ16 | proposal | Open questions | not blocking |
| OQ17 | design (answered 2026-09-30 in the old text) | Risks | the fixes shipped ahead of this entry |
| OQ18 | proposal | Open questions |  |

Counts: 18 questions. 16 stay in the proposal (10 Blocking, 6 Not blocking). OQ8 and OQ17 were closed in the old text and moved to the design. 0026 stays a draft until the owner answers the Blocking ones at its accept.
