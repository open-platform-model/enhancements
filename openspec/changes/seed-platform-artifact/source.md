# Source note: seed-platform-artifact

This is a seed. It records behaviour the library ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `platform-artifact`. Full seed (9 requirements, 28 scenarios). Written 2026-10-11 from the library at commit `a87fdda` (inventory fields checked against core `f3b7ecd`). The spec has 5 requirements; "Platform Type Shape" and "Platform acquisition from a directory" held several rules each, so they split into 9. The requirement text is rewritten at intent level: no Go symbol, field path, sentinel name, flag or file path. The published CUE definition `#Platform` is not named; "kind Platform" is the platform's published kind.

## Sources

All read at the commit named. Spec means `library` `openspec/specs/platform-artifact/spec.md` at `a87fdda`.

| Requirement here | Source requirement in the library's spec | Code read |
| --- | --- | --- |
| A platform holds its package, metadata and source | "Platform Type Shape" (the struct fields, the metadata fields, no decoded derived view); "Platform carries its render source" (first sentence) | `opm/platform/platform.go:19-63`, `opm/platform/metadata.go`; `opm/kernel/acquire.go:293-308` (a directory-acquired platform holds all three) |
| A platform is built from a bare value | "Platform constructor takes a bare value" | `opm/platform/platform.go:74-111` (`NewPlatformFromValue`, `decodePlatformMetadata`) |
| A directory-acquired platform carries its source | "Platform acquisition from a directory returns a source-carrying artifact" (source half and three scenarios) | `opm/kernel/acquire.go:293-308`, `acquire.go:139-156`, `acquire.go:558-578` (`sourceForDir`) |
| Acquisition resolves catalogs through the configured registry | same requirement, the last two sentences; scenario "Registry override honored" | `opm/kernel/acquire.go:293-308`, `opm/internal/cueenv` (`Override`: a copy of the environment, never `os.Setenv`) |
| Acquisition refuses a package that is no platform | same requirement, scenario "Shape-gate failures propagate" (wrong kind, missing name or type); the shape-gate rules of `artifact-types` "Acquisition shape gate" (the Platform lines, the defaulted-field rule, the non-struct rule) | `opm/internal/loader/shape.go:89-94` (`PlatformSpec`), `:116-146` (`gate`), `:180-196` (`checkKind`), `:207-231` (`requireConcrete`), `opm/internal/loader/load.go:119` |
| Acquisition refuses an incomplete registry entry | same scenario ("incomplete `#registry` entry"); `artifact-types` scenario "Registry entry with no embedded catalog rejected" | `opm/internal/loader/shape.go:152-178` (`requireCompleteEntries`) |
| A platform records its contract inventory at construction | "A platform records its core floor and contract inventory at construction" (all scenarios but the two left out below) | `opm/platform/contracts.go:169-198` (`Contracts`, `CoreFloor`), `:228-296` (`decodeFacts`), `:300-316` (`clone`) |
| The inventory is read as a decoded view | "Platform Type Shape": the accessor sentences and the scenarios "The inventory of a healthy platform...", "An over-subscribed platform is reported, not refused", "An unlisted demand leaves the inventory empty" (the member-schema half) | `opm/platform/contracts.go:62-140` (`ContractInventory`), `:150-168` |
| An inventory that predates a report is refused | "Platform Type Shape": the sentences on a report the value does not carry, the collision exception, and the scenarios "An inventory that predates the comparable-predicate report is refused", "...the provider count is refused", "...the collision report reads no collision" | `opm/platform/contracts.go:228-296` (`decodeFacts`: the per-field release table and the collision loop); the provider count is the last entry of the table, `:255`, read after every other field, so the first missing field is the one named (`:258-261`); `:193` and `opm/schema/paths.go:50` for alpha.12 |

## Where the code wins over the spec

- The spec says the struct "has exactly three exported fields". The code adds two unexported ones (a once guard and the recorded facts, `platform.go:59-62`). The seed says what the platform holds, not a field count.
- The spec has no scenario for "a value with no inventory" beyond "The zero platform reports no contracts" (the refusal names the inventory field). The code records the refusal with the first release 2.0.0-alpha.9 (`contracts.go:230-233`). The seed's scenario matches the code.
- The first-release table (alpha.9, alpha.10, alpha.12, alpha.13) is read from the code (`contracts.go:240-253`, `schema/paths.go:50`); the seed names alpha.9, alpha.10, alpha.11 and alpha.12 in scenarios. The provider-count scenario states that every other field is present, because the code stops at the first missing field (`contracts.go:258-261`); a value built against alpha.9 is refused for the comparable list, not the provider count (review T4.R25 finding 1).

## Left out

- Behaviour a live entry owns (T2.2 section 6; `explore/T4.1.md` question 4): 0026:D3 renames the platform value to `#ResolvedPlatform` and gives the name `#Platform` to an authored value. The artifact's kind check and its name are the rows 0026 will touch. Nothing else here is a 0026 target found by a decision text.
- Everything of 0006 that 0021 changed (DECISIONS.md 2026-10-11 06:40 (3)): none of it is in this capability.
- What another seed holds. `single-build-render`: the refusal of a source-less platform at render, the old-core refusal at render, the render-time refusal of a wrong-shaped platform, "A render reads no evaluated platform value". `platform-registry`: the shape of an entry and the rule that an entry without a catalog is incomplete when core evaluates it. `platform-contract-inventory`: what each report means, the collision rules, "reports and never refuses" in core. `platform-module-generation`: whether generation withholds a platform on a verdict.
- Spec scenario "The source type has one name" and the sentence that `opm/platform` and `opm/catalog` re-export no source type: a Go package-placement rule no consumer observes.
- Spec scenario "The constructor takes one argument" and the line that no `opm/apiversion` package exists: a Go signature and a package layout.
- Spec scenario "Frontends stop composing load and construct" (no `LoadPlatformPackage` method): a Go API name, the retired spelling of the same acquisition.
- Spec scenarios "A hand-built platform keeps its results" and "The zero platform reports no contracts": behaviour of a Go struct literal, which a CUE-level consumer cannot reach. The requirement keeps the observable half: reads come from one recorded result.
- Spec scenario "Concurrent reads of one platform are race-free": a test-shaped scenario (race detector). The "each read is independent" scenario keeps its observable half.
- Spec scenario "Source-less platform cannot render" (the render half): `single-build-render` holds it.
- The sentence that the accessor's documentation says `Fulfilled` and `Discriminated` can read true beside collisions: a documentation rule. The inventory seed holds the behaviour ("Other verdicts can read true beside a collision").
- The scenarios on two majors, disabled definers and collision-plus-over-subscription from "Platform Type Shape": they test what core derives, and `platform-contract-inventory` states it.
- The spec sentence that providers are counted per registry entry: `platform-contract-inventory` ("Providers are named per registry entry") and `single-build-render` hold it.

## Where this capability touches the other seeds

- `single-build-render` (render-side): this seed states what the artifact records and what acquisition refuses; that seed states what a render does with it. The old-core error is one typed error returned from two places (the inventory read, the render). This seed owns the read, that seed owns the render's refusal. DECISIONS.md 2026-10-11 08:10 puts the acquisition-time refusal of a wrong-shaped platform here.
- `platform-registry`: it states the entry shape and that an entry without a catalog is incomplete when core evaluates the platform. This seed states that acquisition refuses such an entry, naming the entry.
- `platform-contract-inventory` (inventory): it states what the inventory reports. This seed states how the artifact carries it: once, as a copy per read, refused when it predates a report.
- `platform-module-generation`: it builds the module that acquisition loads ("validated by building it" is a generation rule). No sentence is shared.

Requirements 0026 is likely to MODIFY (a guess from D3, not a decision of 0026): "Acquisition refuses a package that is no platform" (the kind), and the wording of "A platform holds its package, metadata and source" (the name of the value).

sampled: 2026-10-11 18705155
