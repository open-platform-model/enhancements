# Source note: seed-catalog-contracts

This is a seed. It records behaviour `core` ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `catalog-contracts`. Full seed (6 requirements). Written 2026-10-11 from `core` at commit `f3b7ecd`. The three files read (`openspec/specs/catalog-contracts/spec.md`, `src/catalog.cue`, `src/pins/catalog_pins.cue`) last changed in `ac82707`, so nothing newer than that commit is missing.

## Sources

All read at the commit named. The requirement text is rewritten at intent level: no field path, file path or error text as the spec quotes it. Published definitions (`#Catalog`) are named. The requirement name "A member's key equals its fully qualified name" spells out the word the spec abbreviates.

| Requirement here | Source requirement in `core`'s spec | Code read |
| --- | --- | --- |
| A catalog lists the contracts it defines | `core` `openspec/specs/catalog-contracts/spec.md` at `f3b7ecd`, "A catalog publishes its contracts as members" | `core` `src/catalog.cue` at `f3b7ecd` (three pattern-constrained maps, no required entry; each value unified with the primitive of its kind); `src/pins/catalog_pins.cue` (a catalog listing one member of each kind; the provider-fulfilled trait read back by key) |
| Contract members are keyed by contract key | same file, "Contract members are keyed by their contract FQN" | `src/catalog.cue` (each map is keyed `#ContractFQNType`; a key of another form matches no pattern, so it is a field not allowed) |
| A member's key equals its fully qualified name | same file, "A contract member's key equals its fqn" | `src/catalog.cue` (the pattern binds the member's `metadata.fqn` to the key; the transformer map has no such bind); `src/pins/catalog_pins.cue` (three read-backs that fill an unset name from the key, and the commented must-fail case of a mis-keyed trait) |
| The catalog stamps provenance on every member | same file, "The catalog stamps provenance onto every listed member" | `src/catalog.cue` (module path is the major-free registry path, the kind segment, then the member's own api version read through a label alias; build is the catalog's version); `src/pins/catalog_pins.cue` (stamped values read back for one member of each kind) |
| Publishing a contract requires no adapter | same file, "Publishing a contract requires no adapter" | `src/pins/catalog_pins.cue` (a catalog with a provider-fulfilled trait and empty transformers) |
| A catalog derives the provider-fulfilled contracts it implements | same file, "A catalog derives the provider-fulfilled contracts it implements" | `src/catalog.cue:180-183` (a set built from each transformer's required resources and required traits whose fulfilment reads "provider"; the optional demand maps are not read, so an optional demand does not count; a transformer that requires only catalog-fulfilled contracts adds nothing, scenario "Defining a provider contract is not providing it"), `:197` (sorted ascending; unified with any authored list) |

## Where the code and the spec word it differently

- No contradiction found. The spec and `src/catalog.cue` agree on every rule above. The spec's scenario error texts (for example "incompatible list lengths") are CUE messages; the requirements say only that validation fails.
- The spec's fifth requirement carries a line `Source: library ADR-012 (...). The set is what 0015:D11's claim check compares against.` The seed keeps no source line in the requirement. The link is stated here: the derived list is what the capability `registration-acceptance` re-derives and compares.
- The spec's sixth requirement carries `Source: owner decision, beta.1 kernel plan walkthrough (2026-10-03)`. It is not an enhancement decision. It is recorded here only.

## Where this capability touches the other seeds

- `registration-acceptance` (delivered): its "The provider set is re-derived and compared" requirement compares a claim's list with the list derived from the catalog. Here the derivation is stated. There the comparison is. Neither sentence is restated.
- `contract-fulfilment`: it states that a contract declares its fulfilment as "catalog" or "provider". Here the word "provider-fulfilled" is used for that declaration and nothing restates it. Its single-provider count, and the rule that an optional demand is not provision, live there; here only the derivation of the list is stated.
- `platform-registry`: it states that an entry's transformers are derived from the embedded catalog whole. Here the catalog's contract maps are stated. They do not restate that rule.
- `transformer-registration`: its claim carries a list of provided contracts. This seed states where that list comes from.
- `single-build-render`, `platform-module-generation`: no overlap found.

## Left out

- Behaviour a live entry owns. Enhancement 0020 adds a fourth member map for tombstones (decision 8, `0020/03-decisions.md:196`) and so will MODIFY the first requirement, which says "three". Enhancement 0026 changes the claim's fields and the per-resolution provider count; I found no line in either that changes a rule stated here.
- The first requirement of 0015:D1, "a platform's contract inventory reports which defined contracts are required by which transformers". It belongs to the capability `platform-contract-inventory` (map row 15), not to this one.
- The publish gate that checks each member's fully qualified name against the catalog's identity package at publish. The spec mentions it in a clause; `cli` runs it in its publish pass (`internal/publish/catalog_gates.go` at `HEAD`, which unifies each member with `#CatalogMemberFQNGate`). The publish gates are outside this seed; map T4.1b (rows 27 to 29) lists their capabilities.
- The rationale and the design comments in `src/catalog.cue` (why the stamp reads the api version through a label alias, why transformer keys are not bound): they explain the build, and no consumer observes them.
- Everything of 0006 that 0021 changed: none of it touches this capability.
- The placement rules inside the `pins` package (hidden fields, why a pin forces evaluation): library-internal test mechanics.

## Consolidation (T4.3c, 2026-10-11)

One rule lives in one seed (DECISIONS.md 2026-10-11 10:00). What this seed gave up, and where each rule now lives:

- The transformer map is not bound to the transformer's key: `primitive-keying` holds that rule ("Demand and transformer keys are form-checked"). The clause and its scenario are gone from "A member's key equals its fully qualified name".
