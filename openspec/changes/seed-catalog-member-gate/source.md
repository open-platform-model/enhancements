# Source note: seed-catalog-member-gate

This is a seed. It records behaviour that `core` ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `catalog-member-gate`. Full seed (6 requirements). Written 2026-10-11 from `core` at commit `f3b7ecd`. The publish pass in `cli` was read at `09b0b812` to confirm the one consumer. The requirement text is rewritten at intent level: no file path, Go symbol or CLI flag. It names published CUE definitions (`#CatalogMemberFQNGate`, `#IdentityPackage`, `#Resource`, `#Trait`, `#Blueprint`, `#ComponentTransformer`).

## Sources

The spec is `core` `openspec/specs/catalog-member-gate/spec.md` at `f3b7ecd` (7 requirements, 6 kept here, last changed 2026-08-08, `ee3287c`). Code is `core` `src/identity_package.cue` (the gate, lines 172-233) at `f3b7ecd`. Pins are `src/pins/identity_package_pins.cue`. `SPEC.md` section 5.3 of `core` states the rule as the code has it.

| Requirement here | Source requirement | Code read |
| --- | --- | --- |
| A member is unified against its catalog identity | "`core` ships the catalog-member gate shape", plus the publish-pass sentence from `SPEC.md` 5.3 ("MUST unify every catalog member ... surface CUE's own error") | `identity_package.cue:172-180`; `cli` `internal/publish/catalog_gates.go:36-67` (`gateMemberFQN`: concrete validation, "CUE's error is the refusal"); pins `_failGateGroupedBlueprint` (`src/pins/identity_package_pins.cue:241-259`: the path and the key both fail because the segment `workload` is not the API version `v1beta1`; the depth is the same as the conformant path) |
| A member's package path sits under its catalog's | "A member's declared path must sit under its catalog's" (rewritten, see below) | `identity_package.cue:199-208`; pins `pinGateResource`, `pinGateResourceGA`, `pinGateTrait`, `pinGateBlueprint`, `pinGateTransformer`, `_failGateGroupedBlueprint`, `_failGateFlatContractMember`, `_failGateForeignPath` |
| A member's provenance names its catalog's build | "A member's provenance must name its own build" | `identity_package.cue:209`; pin `_failGateStaleCatalogVersion` |
| A key is built from level or build | "A contract key is built from the API version, an implementation key from the build" (first paragraph; second paragraph moved to the API version requirement) | `identity_package.cue:222-233`; pins `_pinKeyOmitsFilingSegment`, `_pinPrimitiveKeysOnAPIVersion`, `_pinTransformerKeysOnBuild`, `_failGateStaleTransformerFQN` |
| The API version is needed by contracts only | "The API version is required for primitives and absent for transformers", plus the sentence "`apiVersion` MUST NOT be checked against identity" from the key requirement | `identity_package.cue:182-191, 235-239`; pin `_failGateMissingAPIVersion` (measured with `cue export`, not `cue vet`); `cli` `catalog_gates.go:69-78` (`fillFromMember` leaves an absent field to the gate) |
| The gate covers all four member kinds | "The gate covers all four catalog member kinds" | `identity_package.cue:173`; pin `_failGateUnknownKind` |

Archived decisions behind the rule, for orientation (not claims of this note): 0011 D22 (the gate), 0010 D4, D17, D21, D25, D42, D44 and D49.

## Disagreements between spec and code

Where they differ, the code wins.

- **The filing rule.** The spec says `declaredModulePath` MUST equal the kind prefix, and its first scenario passes a resource at `.../resources`. The code (`identity_package.cue:205-208`, from 0010 D49, 2026-08-10) requires the prefix plus the member's own API version for resources, traits and blueprints, and the prefix itself for transformers. `SPEC.md` 5.3 agrees with the code, and the spec predates D49. I ran the gate on a scratch copy of `core/src` (cue v0.17.1): the spec's "conformant" resource fails with `conflicting values ".../resources/v1beta1" and ".../resources"`. The requirement "A member's package path sits under its catalog's" follows the code. The spec's scenario "A member one segment too deep is refused" stays true for the blueprint example, but the reason is now the API-version segment, not the depth.
- **Where `apiVersion not checked against identity` sits.** The spec puts it in the key requirement. Here it sits with the API version requirement, because it is a statement about the API version. No behaviour changes.
- **A transformer that supplies an API version.** The spec is silent. The code accepts it and ignores it (scratch probe: a transformer with `declaredAPIVersion: "v1"` unifies and its key still ends in the build). Not stated as a requirement: no consumer needs it.

## Left out

- The identity-package shape: the two authored fields, the derived major and version major, the kind prefixes. Row 9 `artifact-identity` holds them (branch `refactoring-enhancements/p4-seed-artifact-identity`, "One path prefix per catalog member kind"). This seed uses the prefixes and does not restate them. The spec scenario that artifact-identity's note says it leaves to this seed ("No grouping segment is admitted") is the scenario "A grouping segment is refused" here.
- The stamps and the key binding that `#Catalog` applies to the members of its contract maps (`#resources`, `#traits`, `#blueprints`). Row 14 `catalog-contracts` holds them. That mechanism fills or conflicts at evaluation; this gate runs at publish.
- What a resource, a trait, a blueprint or a transformer declares as its own key (the contract form `path/name@vN` against the implementation form `path/name@semver`). Row 12 `primitive-keying` holds that. This seed holds only what the gate requires of a key against the identity.
- The sibling gate `#TraitOptionalGate`. The seed `contract-fulfilment` holds it ("A catalog cannot pin a trait's posture").
- The order of the publish gates, their counts in the publish plan, the headline text of a refusal, and the compatibility gate. Rows 27 `artifact-publishing` and 29 `catalog-compatibility` hold them. This seed states only that every member is unified and CUE's error is shown.
- The rationale of the spec and of `SPEC.md` (why the gate exists, the measured `2 errors in empty disjunction` wrapper, the evaluation order that spares the absent optional, why the kind segment stays in the key). It is history and mechanism. The observable result is kept in the scenarios.
- The observation that `declaredModulePath` and `declaredCatalogVersion` are marked required but carry a derived value, so the gate alone accepts a member that omits them (scratch probe: it exports with the derived values). In the publish pass the values come from the member's own required metadata. Not a requirement: no consumer observes it.
- Behaviour a live entry owns. At `origin/main` `1870515` the live entries 0020, 0021 and 0022 mention the gate. 0020 (`02-design.md:94`, `schemas/spec.md:107`) adds `#PromotionGate` and `#TombstoneGate` beside it and leaves it as it is. 0021 (`policy/02-catalog-build.md:75, 94`) records its rename and the optional API version, both delivered and stated here. 0022 (`03-decisions.md:125`, `schemas/spec.md:77`) copies its declared-beside-implied form for a new gate. None changes a rule stated here.
- Everything of 0006 that 0021 changed (DECISIONS.md 2026-10-11 06:40 (3)): no 0006 spec is among the sources.
- "A member's key is authored, not derived", with the spec's last requirement ("not part of a member's own identity shape": the gate is not embedded in `#Resource`, `#Trait`, `#Blueprint` or `#ComponentTransformer`, so a member evaluated alone keeps the key its catalog authored). The seed `primitive-keying` holds that rule ("A member's key is authored, not derived"), and the grouped review T4.R11 (finding 3) found it stated twice. The reason clause (a contract in one catalog can be fulfilled by a transformer in another on its own cadence) is for `primitive-keying` to keep or drop. The rule is still true and traces to `core` spec requirement 7, `SPEC.md` 5.3 and pin `_pinTransformerBuildSkewAccepted`; it is held there, not here.

## Judgement calls

- 6 requirements: the 7 of the source spec in the same order, less "not part of a member's own identity shape" (see Left out). The spec's second paragraph of the key requirement moved to the API version requirement, and the spec's path and shape requirements were split differently only in wording.
- The filing rule follows the code, not the spec (see Disagreements). The reviewer may want the owner to confirm that the stale spec is not meant to hold the old rule.
- Requirement 1 states that a publishing tool unifies every member and shows CUE's error. The source is `SPEC.md` 5.3 and `cli` `catalog_gates.go`, not the `core` spec. It is the point of the capability (the brief: "CUE's own diagnostic reaches the author"), so it stays here, and `artifact-publishing` should not restate it.
- Field names (`declaredFQN` and the other `declared` fields) are left out of the text; the requirements say key, package path, catalog version and API version. `#CatalogMemberFQNGate` and `#IdentityPackage` are named as published definitions (V19, D 21:30 Q5).
- The scenario "A key that carries the filing segment is refused" and "A transformer is filed at its prefix" (the refusal half) come from scratch probes and the pins' comments, not from the repo spec. The pins record the first (`_pinKeyOmitsFilingSegment`).
- The scenario "A resource and a trait of one name keep distinct keys" is moved in from `primitive-keying`, which drops its requirement "A key carries its kind segment" (T4.R11 finding 2). Its source is `SPEC.md` 5.3 Rationale ("Why the kind segment is retained in the FQN") and the key formula at `identity_package.cue:233`. The kind-segment rule stays here, in "A key is built from level or build".

sampled: 2026-10-11 18705155
