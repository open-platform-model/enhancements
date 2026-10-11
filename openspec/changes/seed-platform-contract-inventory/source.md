# Source note: seed-platform-contract-inventory

This is a seed. It records behaviour `core` ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `platform-contract-inventory`. Full seed (12 requirements; the source spec has 12). Written 2026-10-11 from `core` at commit `f3b7ecd`.

## Sources

All read at the commit named. The requirement text is rewritten at intent level: no Go symbol, field path or file path. The published definitions `#Platform` and `#ContractInventory` are named. The inventory fields are described in words (the defined contracts, the required-by lists, the provider map, the over-subscription and collision reports, the three verdicts). Requirement names are shortened where the source name had more than 8 words.

The source spec is `core` `openspec/specs/platform-contract-inventory/spec.md` at `f3b7ecd`. The code read is `core` `src/platform.cue` at `f3b7ecd` (lines 61 to 140 for the inventory definition and its three verdicts, 185 to 337 for the derivation) and `src/pins/platform_contracts_pins.cue` at `f3b7ecd`, which pins the readouts of every scenario named below.

| Requirement here | Source requirement in the spec | Code read |
| --- | --- | --- |
| A platform derives its contract inventory | "A platform derives its contract inventory from its enabled entries" (first and last sentences), "An empty registry yields an empty inventory" | `src/platform.cue:238` (a pure comprehension over the enabled entries, no runtime step); pins at 714 to 715 (the bare definition) and 509 to 522 (the empty platform) |
| Defined contracts name their defining catalog | same first requirement (the defined and defining-catalog sentences) | `src/platform.cue:242` to `:262` (single-definer keys fold into the contracts and the map); pins at 524 to 548 |
| Required demands are counted per contract | "Required demands are counted per contract across enabled transformers" | `src/platform.cue:269` to `:280` (required resources and traits only; presence guards); pins at 652 to 695 |
| Unfulfilled contracts have no provider | "Unfulfilled contracts are the provider-fulfilled ones nothing requires" | `src/platform.cue:287`, `:129` (the fulfilled verdict); pins at 524 to 558 and 631 to 651 |
| A match predicate is the required demands | "A transformer's match predicate is every required demand it declares" | `src/platform.cue:296` to `:307` (three required kinds, label key and value together; the predicate is held in the hidden field `_predicates`, which no consumer reads, so the scenarios read it through the comparable report at `:311` to `:335`: the subset test `_aSubB` and `_bSubA` at `:318` to `:320`, the broader transformer at `:323`). The optional-demand scenario pairs a required label with an optional trait so that a predicate which counted optional demands would be incomparable (T4.R37); the required-trait scenario fixes the sort order so that a predicate which dropped the trait would mark the wrong transformer (`:323`); pins at 1210 |
| Comparable predicates are reported | "Comparable predicates over a shared catalog-fulfilled contract are reported" | `src/platform.cue:311` to `:337` (subset by union size, one row per sorted pair, contracts accumulate on the row); pins at 1181 to 1237 |
| Comparability covers catalog-fulfilled contracts only | "The comparability report covers catalog-fulfilled contracts only" | `src/platform.cue:314` (the loop runs over defined non-blueprint contracts with catalog fulfilment); pins at 1224 |
| Discriminated reads true when nothing is comparable | "Discriminated is true exactly when no pair is comparable" | `src/platform.cue:139` |
| Providers are named per registry entry | "The inventory names the registry entries providing each contract" | `src/platform.cue:282` to `:286` (each enabled entry's catalog provider set, folded by registry key); `src/catalog.cue:177` to `:197` (that set); pins at 559 to 662 and 902 to 936 |
| Over-subscription lists contracts with several providers | "Over-subscription counts providing registry entries, not transformers" (the report and the routable sentence) | `src/platform.cue:288`, `:134`; pins at 584 to 651 |
| Contract keys defined twice are reported as collisions | "Contract keys defined by more than one enabled entry are reported as collisions" | `src/platform.cue:242` to `:263`; pins at 723 to 793, the limitation pin at 756 to 757 |
| The inventory reports and never refuses | "The inventory reports and never refuses" | `src/platform.cue:194` to `:226` (the comments) and the derivation, which holds no assertion; pins at 584 to 600 (evaluates when over-subscribed), 723 to 735 (evaluates when colliding) |

## Where the code and the spec word it differently

- The spec says the inventory "MUST NOT be authorable". The code derives it by comprehension and has one comment saying it is never authored (`src/platform.cue:55` to `:60`). No constraint in the code refuses an authored value, and I did not test one. The seed says the inventory is a pure derivation and that no runtime step fills it, which the code shows.
- The spec says a consumer "MUST treat a non-empty collision report as overriding" the fulfilled and discriminated verdicts. That is an obligation on callers, which nothing in `core` enforces. The seed states only the observable readings, in a scenario: the two verdicts can read true beside a collision, and only the routable verdict shows the problem. The code pins this on purpose (`pins:756` to `:757`, "LIMITATION PIN").
- The spec says the generation step (operator, CLI) refuses on the discriminated verdict "in the same way it already refuses on routable". The code comment names `opm platform check` and the operator as readers (`src/platform.cue:136`). Neither reading is checked here. The seed says only that the platform definition refuses nothing and that the consuming gate decides.
- The spec says a transformer written on an entry's own readout, outside its catalog, is outside the provider fold. I did not verify this, and the seed does not state it.
- The provider map in the spec reads "per entry, over the transformers". The code folds each entry's catalog provider set (`src/platform.cue:282` to `:286`). The two agree, and the seed says the map agrees with the provider set each enabled catalog states for itself.

## Where this seed touches the others

- `contract-fulfilment` holds the rule that a provider-fulfilled contract admits exactly one provider, the counting unit (a registry entry, major included), and the scenarios for two majors and an absent definer. This seed does not restate the rule. It holds the report only: the provider map as a shape, the over-subscription list as a read of that map, and the routable verdict. The scenarios "One provider entry through two adapters is one key" and "Providers of an undefined contract are listed" describe the map, not the count, and are the closest to the other seed's scenarios.
- `single-build-render` holds the render's reading of the inventory: that the render refuses an over-subscribed or colliding platform and that its rows equal the inventory's. This seed holds the reports being read. It states no refusal.
- `platform-registry` holds the composed transformers and the rule that a platform carries no reverse index. This seed reads the composed transformers and does not state them. The pin for the inert reverse index (`pins:697` to `:710`) belongs to that seed.
- `catalog-contracts` (T4.1b row 14) will hold how a catalog derives the provider-fulfilled contracts it implements. The provider map here says only that it agrees with that set.
- `platform-module-generation` holds when a platform package is generated and the operator gate holds what it refuses (T4.1b rows 6 and 16). This seed states no gate.

## Left out

- That an unfulfilled contract gates nothing. The seed `platform-contract-gates` holds it ("An unfulfilled contract is reported, not failed"), so this seed states the report only. Review T4.R12, S1.
- The "Source:" provenance lines of the spec ("corrects the delivery of 0015:D2" and the like). They are history, not behaviour.
- Three scenarios of the source that the other seeds hold in their own words: "Two majors of one catalog are two keys" and the over-subscription scenarios for two majors and for an absent definer (the counting unit, `contract-fulfilment`), and "An over-subscribed platform still evaluates" (reported, never refused, `contract-fulfilment` and `single-build-render`). The text of "The inventory reports and never refuses" still lists the over-subscribed platform.
- The scenario "Three majors" of the pins: it repeats the two-major rule with a third definer.
- The order of the two names in a row of equal predicates. It follows the sort order of the names and no consumer is documented to rely on it.
- What enhancement 0026 changes. Its decision 9 (requirement 3) builds the platform's module-less view once per admitted major of a catalog, which replaces the collision report's interim role (`0026/03-decisions.md:84`, `:277`, `:288`). T4.1 (`explore/T4.1.md`, question 2) also records that 0026 changes the provider count to one per resolution. The seed holds the delivered collision and provider-count reports.
- What enhancement 0025 adds. Its decision 14 (requirement 1, `0025/03-decisions.md:159` to `:169`) makes the inventory list module traits and module transformers. The source spec states none of it, so the seed does not.
- Enhancements 0007, 0013 and 0027 are in the map as word matches only. I grepped them for the inventory terms; the hits are about other things (a discriminated union, unfulfilled secrets, name collisions). They own no sentence of this capability.

## Consolidation (T4.3c, 2026-10-11)

One rule lives in one seed (DECISIONS.md 2026-10-11 10:00). What this seed gave up, and where each rule now lives:

- "Providers are named per registry entry" no longer says an optional demand is not provision, and its scenario is gone. `catalog-contracts` holds that rule ("A catalog derives the provider-fulfilled contracts it implements"); the inventory map agrees with the provider set each catalog states for itself.
- The counting unit (an entry with its major) is `contract-fulfilment`'s; the map and the reports stay here.
