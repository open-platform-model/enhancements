# Source note: seed-artifact-identity

This is a seed. It records behaviour that `core` ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `artifact-identity`. Full seed (18 requirements). Written 2026-10-11 from `core` at commit `f3b7ecd`. Cli and library were read at `09b0b812` and `a87fdda` to find the edges only. The requirement text is rewritten at intent level: no file path, Go symbol or CLI flag. It names published CUE definitions (`#Module`, `#Catalog`, `#Resource`, `#Trait`, `#Blueprint`, `#ComponentTransformer`, `#ArtifactRef`, `#IdentityPackage`) and the metadata fields of those definitions.

## Sources

Specs are `core` `openspec/specs/artifact-identity/spec.md` (A, 10 requirements) and `openspec/specs/identity-package/spec.md` (P, 5 requirements) at `f3b7ecd`. Code is under `core` `src/` at `f3b7ecd`. Pins are `src/pins/identity_pins.cue` and `src/pins/identity_package_pins.cue`.

| Requirement here | Source requirement | Code read |
| --- | --- | --- |
| An artifact declares its complete module path | A: "An artifact declares its complete CUE module path" | `types.cue:75` (module path type), `module.cue:23`, `catalog.cue:96` |
| A primitive declares a package path | A: "A primitive declares a package path, not a module path" (the sentence "accepts exactly the values the module path type accepted before this change" is history and is left out) | `types.cue:92`, `resource.cue:16`, `trait.cue:15`, `blueprint.cue:28`, `transformer.cue:43` |
| A module path decomposes in exactly one place | A: "A module path decomposes in exactly one place" | `types.cue:156-172`; `grep` for `SplitN` in `src/*.cue` finds one path split (`types.cue:159`) and one version split (`identity_package.cue:103`) |
| A module exposes its major-free registry path | `core` `openspec/specs/instance-identity/spec.md:7-19` at `f3b7ecd`, "A module exposes its major-free registry path" (the `instance-identity` seed leaves it out, so this seed holds it) | `module.cue:45`; pins `identity_pins.cue:95-96` (`_pinRegistryPathStableAcrossMajor`) |
| An artifact's FQN is its module path | A: "An artifact's FQN is its module path" | `module.cue:37`, `catalog.cue:106`; `grep` finds no `#ModuleFQNType` or `#CatalogFQNType` in `src/`; pin `_failFqnCarriesVersion` (`identity_pins.cue`, MUST-FAIL block) |
| Module identity distinguishes majors and nothing finer | A: "Module artifact identity distinguishes majors and nothing finer" | `module.cue:73`; pins `identity_pins.cue:84-92` |
| A module's name has one spelling | A: "A module's name has one spelling, and the path's leaf equals it" (first paragraph) | `module.cue:21`, `module.cue:54-55`, `types.cue:51`; `grep` finds no `nameSnakeCase` or `#KebabToSnake` in `src/` |
| Catalog primitives keep kebab-case names | A: same requirement, second paragraph (first sentence only) | `resource.cue:14`, `trait.cue:13`, `blueprint.cue:15` |
| A module declares a keyless version | A: "A module declares a version that reaches no key" | `module.cue:24`, `module.cue:82` |
| The schema asserts no version-path agreement | A: "`core` asserts no agreement between a declared version's major and its path's" | `module.cue:57-68`, `catalog.cue:112-121`; pins `_pinModuleMajorSkewAccepted`, `_pinCatalogMajorSkewAccepted` (`identity_pins.cue:378-392`); `grep` finds no version-major field in `module.cue` or `catalog.cue` |
| A catalog declares a concrete version | A: "A catalog declares a concrete version with no development default" | `catalog.cue:98-101` |
| A catalog stamps a package path on transformers | A: "A catalog stamps a package path onto its transformers" (the catalog-version stamp is added from code) | `catalog.cue:199-210` |
| The schema ships the identity-package shape | P: "`core` ships the conformant identity-package shape" | `identity_package.cue:37-44`; header comment `identity_package.cue:7-31` |
| Two fields are authored and the rest derive | P: "Exactly two fields are authored; the rest derive" | `identity_package.cue:42-58`, `:103-104` |
| The version's major must equal the path's major | P: "The declared version's major must equal the path's" | `identity_package.cue:60-104`; the prerelease and two-digit scenarios come from pins `_pinIdentityPrerelease`, `_pinIdentityDoubleDigitMajor` (`identity_package_pins.cue:74-91`) |
| The identity package imports nothing from core | P: "The identity package carries no intra-module import" | `identity_package.cue:3-5` (`strings` only), header comment `:17-31` |
| One path prefix per catalog member kind | P: "One path prefix per catalog member kind" (scenario "No grouping segment is admitted" left out, see below) | `identity_package.cue:134-139`; pin `_pinKindPrefixCarriesNoMajor` (`identity_package_pins.cue:93-99`) |
| The identity file is committed with real values | none in the repo specs; archived decisions 0010 D5 and D6 and code comments | `catalog.cue:30-38` (committed file, no placeholder), `identity_package.cue:11-13` (fields located by schema names), `identity_package.cue:42,46` (required fields) |

Archived decisions behind the requirements, for orientation (not claims of this note): 0010 D1 (module path and package path), D2 (module version and the identity subpackage), D3 (catalog version), D5 and D6 (committed file, open field), D8 (snake_case name), D40, D43, D45 (where the major relation is asserted) and 0011 D21 (validation by unification). 0010 D7 is superseded by D2 and is not used. 0003 is history only and is not used.

## Disagreements between spec and code

Where they differ, the code wins.

- The last scenario of the spec requirement "One path prefix per catalog member kind" says the member gate refuses a path with a grouping segment. The code puts that refusal in `#CatalogMemberFQNGate` (`identity_package.cue:172-`), which belongs to the capability `catalog-member-gate`. The scenario is left out here.
- The spec example of a primitive path is `opmodel.dev/catalogs/opm/resources`. The code examples and the catalog stamp for contracts add the member's own apiVersion as a last segment (`resource.cue:16`, `catalog.cue:140-171`). The scenario here uses the filed form `opmodel.dev/catalogs/opm/resources/v1beta1`, so it agrees with `catalog-member-gate`, which refuses a contract member filed flat. The flat path is still a package path without a major; the filing rule belongs to `catalog-member-gate`.
- The spec `artifact-identity` does not state that a catalog stamps its version onto a transformer. The code does (`catalog.cue:209`). It is added. The registry path of a module is stated by the `core` spec `instance-identity` (see the table), not by `artifact-identity`.

## Left out

- The removal lists of the spec ("`#ModuleFQNType` and `#CatalogFQNType` MUST be removed", "`nameSnakeCase` and `#KebabToSnake` MUST be removed", "`#KebabToPascal` and `#KebabToCamel` MUST be retained"). They describe history of the schema. The observable result is kept: no separate key type, no second spelling of a name. The retained name-conversion helpers build internal keys and no consumer observes them.
- The scenario "No grouping segment is admitted" (see Disagreements) and everything about the member gate: what a catalog member must declare against its catalog identity. Row 10 `catalog-member-gate` holds it.
- How an instance derives its identity from the registry path: row 11 `instance-identity`. The requirement "A module exposes its major-free registry path" states only the value a module exposes.
- The commands that read and write the identity file (publish, `version set`, scaffold, repair, vet) and the coordinate derivation: rows 27 `artifact-publishing`, 28 `module-authoring` and the module vet spec of the cli. This seed states what the schema accepts and derives, not what a command does with it. The cli spec `artifact-publishing` says that publish unifies the identity package with `#IdentityPackage` and that what is published is exactly the committed tree. This seed does not restate that. In particular, "tooling writes the two authored fields in place" and "a checkout and a published artifact agree" are left to those seeds.
- The contract maps of `#Catalog` (`#resources`, `#traits`, `#blueprints`), their stamping with the apiVersion segment and the derived `provides` list: `catalog-contracts` and `catalog-member-gate`.
- The `#ArtifactRef` major-free registry path in platform entries and in the registry key of a platform (the seed `platform-registry` holds "Each registry key is a catalog module path with its major" and "One registry entry per catalog path"). This seed states only that a catalog declares a complete module path with a major.
- Behaviour a live entry owns. Nothing in the 15 requirements of the two repo specs is a target of a live entry at `origin/main` `1870515`: 0022 adds a new publish gate beside `#IdentityPackage` (`0022/02-design.md:44, 62-65`) and a manifest block that repeats `ModulePath` and `Version`; it does not change a rule stated here. 0025 and 0026 name module paths in their schemas and experiments (`0025/schemas/target.cue:46`, `0026/experiments/01-one-major-per-build`) but do not change the identity rules. A converted 0022 may MODIFY "Two fields are authored and the rest derive" if the identity package gains a field. This is a hint, not a claim.
- Everything of 0006 that 0021 changed (DECISIONS.md 2026-10-11 06:40 (3)): no 0006 spec is among the sources of this capability, so nothing is left out for that reason.

## Judgement calls

- 18 requirements, not 15: the 15 of the two repo specs, plus "A module exposes its major-free registry path" (a requirement of the `core` spec `instance-identity`, held here because the `instance-identity` seed leaves it out), "The identity file is committed with real values" (code and archived decisions, no repo spec), plus "Catalog primitives keep kebab-case names", which the spec holds as a second paragraph of the name requirement and which is split out to keep each requirement under 500 characters.
- "The identity file is committed with real values" rests on comments in `catalog.cue` and `identity_package.cue` and on 0010 D5 and D6, plus the schema's required fields. The requirement states the schema side only: the committed file, the fixed field names, and an unfilled field as an absent value. The tooling that writes the fields and the check of a checkout against a published artifact are command and publish behaviour; they are left out (see Left out).
- The requirement "The schema asserts no version-path agreement" keeps the spec's sentence that it pins an accepting behaviour on purpose. This guards against a later fix that restores the check.
- Requirement "The identity package imports nothing from core" keeps the rule at intent level: a file may stay at the bottom of its module's import graph. The package name `core` is the name of a published module, not a Go symbol.
