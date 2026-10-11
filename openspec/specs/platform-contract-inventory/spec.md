# platform-contract-inventory Specification

## Purpose
State what a platform derives about the contracts its enabled catalogs define and its enabled transformers require: which contracts exist, who requires and who provides them, which keys collide, and which transformers cannot be told apart. The inventory is a report. It names every problem and refuses none.

## Requirements

### Requirement: A platform derives its contract inventory

A `#Platform` SHALL derive a `#ContractInventory` from its enabled registry entries and the transformers their catalogs carry. The inventory is a pure derivation: no runtime step fills it. A disabled entry SHALL contribute nothing to it. A platform with no enabled entry SHALL derive an empty inventory in which the fulfilled, routable and discriminated verdicts all read true, and the definition SHALL evaluate with no registry at all.

#### Scenario: A disabled entry contributes nothing

- **WHEN** a platform declares an entry switched off whose catalog lists members and ships transformers
- **THEN** none of that catalog's contracts is defined and none of its transformers appears in any required-by list

#### Scenario: A platform with no entries is trivially sound

- **WHEN** a platform declares a name and a type and no registry entry
- **THEN** every map and list of the inventory is empty and all three verdicts read true

#### Scenario: The bare definition evaluates

- **WHEN** the platform definition is evaluated with no registry value at all
- **THEN** it evaluates and reads as the empty platform does

### Requirement: Defined contracts name their defining catalog

The inventory SHALL hold every resource, trait and blueprint that exactly one enabled catalog lists, keyed by the contract's fully qualified name and carrying the member as that catalog lists it. It SHALL map each such contract to the registry key of its catalog, which is the catalog path with its major. A contract that more than one enabled catalog lists SHALL appear in neither the contracts nor the map, because it is a collision.

#### Scenario: Listed members of an enabled catalog are defined

- **WHEN** an enabled entry embeds a catalog that lists one resource, two traits and one blueprint
- **THEN** the inventory defines exactly those four contracts and maps each to that entry's registry key

#### Scenario: A defined contract keeps its own fulfilment

- **WHEN** an enabled catalog lists a trait that declares provider fulfilment
- **THEN** the defined contract carries that declaration as the catalog lists it

### Requirement: Required demands are counted per contract

For every defined contract the inventory SHALL list the transformers of enabled entries that require it as a resource or a trait. Optional demands SHALL NOT count, because tolerating a contract is not fulfilling it. A transformer that declares no demand of one kind SHALL be read as demanding nothing of that kind. A defined contract nothing requires SHALL have an empty list.

#### Scenario: A contract required from two catalogs lists both transformers

- **WHEN** a transformer of one enabled catalog and a transformer of another both require the same resource
- **THEN** the list for that resource names both transformers

#### Scenario: A transformer without trait demands names no trait

- **WHEN** an enabled transformer requires a resource and declares no required traits
- **THEN** the inventory evaluates and no trait's list names that transformer

#### Scenario: An optional demand is not counted

- **WHEN** a transformer names a contract only among its optional demands
- **THEN** that contract's list does not name the transformer

### Requirement: Unfulfilled contracts have no provider

The inventory SHALL list as unfulfilled every defined resource or trait that is provider-fulfilled and that no enabled entry provides. A blueprint SHALL never appear, and neither SHALL a contract that no enabled catalog defines. The fulfilled verdict SHALL read true exactly when nothing is unfulfilled.

#### Scenario: A provider-fulfilled trait with no provider is unfulfilled

- **WHEN** an enabled catalog lists a provider-fulfilled trait and no enabled transformer requires it
- **THEN** that trait is the only unfulfilled contract and the fulfilled verdict reads false

#### Scenario: A catalog-fulfilled trait nothing requires is not unfulfilled

- **WHEN** an enabled catalog lists a trait with the default fulfilment and nothing requires it
- **THEN** nothing is unfulfilled and the fulfilled verdict reads true

#### Scenario: A contract no enabled catalog defines is not unfulfilled

- **WHEN** the catalog defining a provider-fulfilled trait is disabled and an enabled transformer requires the trait
- **THEN** nothing is unfulfilled and the fulfilled verdict reads true

### Requirement: A match predicate is the required demands

An enabled transformer's match predicate SHALL be the union of its required resources, its required traits and its required labels, a label counting as its key and its value together. Optional demands SHALL NOT contribute. A transformer that declares no demand of one kind SHALL be read as declaring none of that kind. Two transformers that require one label key with different values SHALL declare different demands.

#### Scenario: A required trait is part of the predicate

- **WHEN** two enabled transformers require one catalog-fulfilled resource, one of them also requires a trait, and the transformer with the trait has the name that sorts first
- **THEN** the comparable report holds one row for the pair and marks the transformer without the trait as the broader

#### Scenario: An optional demand does not widen the predicate

- **WHEN** two enabled transformers require one catalog-fulfilled resource, one of them also requires a label value, and the other names a trait only among its optional demands
- **THEN** the comparable report holds one row for the pair and marks the transformer with the optional trait as the broader

### Requirement: Comparable predicates are reported

The inventory SHALL report each unordered pair of enabled transformers where one predicate is a subset of the other and both require at least one defined catalog-fulfilled contract. A row SHALL name both transformers, mark the broader one, whose smaller predicate matches every component the other matches, and name every shared catalog-fulfilled contract. Equal predicates SHALL give one row. Pairs with incomparable predicates SHALL NOT appear.

#### Scenario: Two catalogs shipping the same adapter are comparable

- **WHEN** transformers of two enabled catalogs require the same catalog-fulfilled resource and nothing else
- **THEN** the report holds one row that names both transformers and the resource

#### Scenario: A strictly narrower predicate is comparable

- **WHEN** one enabled transformer requires a catalog-fulfilled resource and a second requires that resource plus a label
- **THEN** the report holds one row that names both and marks the first as the broader

#### Scenario: A pair sharing two contracts is one row

- **WHEN** two comparable transformers both require two catalog-fulfilled contracts
- **THEN** the report holds one row that names both contracts

#### Scenario: Different label values are not comparable

- **WHEN** two enabled transformers require one catalog-fulfilled resource and one label key with different values
- **THEN** the report is empty

#### Scenario: A distinct required trait is not comparable

- **WHEN** two enabled transformers require one catalog-fulfilled resource, and one also requires a trait while the other also requires a label
- **THEN** the report is empty

#### Scenario: A disabled entry is never paired

- **WHEN** a disabled entry ships a transformer whose predicate equals that of an enabled transformer
- **THEN** the report is empty

### Requirement: Comparability covers catalog-fulfilled contracts only

A pair whose only shared required contracts are provider-fulfilled SHALL NOT be reported as comparable, whichever catalogs the two transformers come from. Several providers of one contract are reported by the over-subscription report alone. A blueprint SHALL never be the shared contract that qualifies a pair, because it carries no fulfilment.

#### Scenario: Two adapters of one provider catalog are not comparable

- **WHEN** two transformers of one enabled catalog require the same provider-fulfilled trait and nothing else
- **THEN** the comparable report is empty and nothing is over-subscribed

#### Scenario: A provider bucket shared by two catalogs is over-subscribed only

- **WHEN** transformers of two enabled catalogs require the same provider-fulfilled trait and nothing else
- **THEN** the over-subscription report names that trait and the comparable report is empty

### Requirement: Discriminated reads true when nothing is comparable

The inventory SHALL read as discriminated exactly when no pair is comparable. The verdict is a value for a consumer to read. The platform definition SHALL refuse nothing on it, and whether a platform that is not discriminated is withheld is the decision of the consuming gate.

#### Scenario: A platform with one comparable pair is not discriminated

- **WHEN** the inventory reports one comparable pair
- **THEN** the discriminated verdict reads false and the platform still evaluates

#### Scenario: A platform with no comparable pair is discriminated

- **WHEN** no two enabled transformers have comparable predicates
- **THEN** the discriminated verdict reads true

### Requirement: Providers are named per registry entry

The inventory SHALL map each provider-fulfilled contract that some enabled entry's transformers require to the sorted registry keys of those entries, each key once. The map SHALL hold the contract whether or not an enabled catalog defines it, and SHALL NOT hold one that is only required by a disabled entry. It SHALL agree with the provider set each enabled catalog states for itself.

#### Scenario: One provider entry through two adapters is one key

- **WHEN** one enabled entry ships two transformers that require the same provider-fulfilled trait and no other entry requires it
- **THEN** the map holds that trait with the one registry key of that entry

#### Scenario: Providers of an undefined contract are listed

- **WHEN** the catalog defining a provider-fulfilled trait is disabled or absent, and two enabled entries have transformers requiring it
- **THEN** the map names both registry keys for the trait, although the trait is not defined

#### Scenario: A contract nobody provides has no key

- **WHEN** an enabled catalog defines a provider-fulfilled trait and no enabled transformer requires it
- **THEN** the map holds no key for the trait

#### Scenario: A disabled entry provides nothing

- **WHEN** an entry switched off has a transformer requiring a provider-fulfilled trait
- **THEN** the registry key of that entry appears in no list of the map

#### Scenario: A provider-fulfilled resource is provided like a trait

- **WHEN** an enabled entry ships a transformer requiring a provider-fulfilled resource beside a provider-fulfilled trait
- **THEN** the map names that entry's registry key for both contracts

### Requirement: Over-subscription lists contracts with several providers

The inventory SHALL list as over-subscribed every contract whose provider map holds more than one registry key, whether or not an enabled catalog defines it. The routable verdict SHALL read true exactly when nothing is over-subscribed and no contract key collides.

#### Scenario: Two providers make a platform not routable

- **WHEN** the provider map holds two registry keys for one contract
- **THEN** that contract is listed as over-subscribed and the routable verdict reads false

#### Scenario: One provider leaves a platform routable

- **WHEN** the provider map holds one registry key for each contract and no key collides
- **THEN** nothing is over-subscribed and the routable verdict reads true

### Requirement: Contract keys defined twice are reported as collisions

A definer of a key SHALL be an enabled entry whose catalog lists it. The inventory SHALL list every key with more than one definer, sorted, and map each to the sorted registry keys of its definers. A colliding key SHALL be absent from the defined contracts and from every report built on them. The routable verdict SHALL read false while any key collides. A platform with no colliding key SHALL derive empty collision reports.

#### Scenario: Two majors sharing keys report every shared key

- **WHEN** a platform enables two majors of one catalog that list the same four contracts, each major shipping its own transformer
- **THEN** the platform evaluates, the four keys are listed in ascending order, each naming both majors, and the routable verdict reads false

#### Scenario: A key only one major lists is defined as before

- **WHEN** a platform enables two majors of one catalog and the second lists one further resource
- **THEN** that resource is defined by the second major's registry key alone

#### Scenario: A disabled second major defines nothing

- **WHEN** a platform enables one major of a catalog and declares a second, switched off, that lists the same keys
- **THEN** no key collides and the inventory reads as for the first major alone

#### Scenario: A collision and an over-subscription are reported together

- **WHEN** two majors of one catalog list a provider-fulfilled trait that two enabled provider entries also require
- **THEN** the trait is listed as a collision and as over-subscribed, and the provider map still names both provider entries

#### Scenario: Other verdicts can read true beside a collision

- **WHEN** two enabled majors of one catalog list a provider-fulfilled trait with no provider, and their transformers have equal predicates over a colliding resource
- **THEN** the fulfilled and discriminated verdicts read true, the routable verdict reads false and is the only verdict that shows the problem

### Requirement: The inventory reports and never refuses

No report of the inventory SHALL make the platform fail to evaluate. An unfulfilled, over-subscribed, undiscriminated or colliding platform SHALL still evaluate, with the offending contracts, transformer pairs and registry entries named in the reports and the composed transformers intact. Whether a platform that is not routable is withheld is the decision of the consuming gate.

#### Scenario: A platform with comparable predicates still evaluates

- **WHEN** two enabled catalogs ship transformers with identical predicates over one catalog-fulfilled resource
- **THEN** the platform evaluates, both transformers remain composed, and the comparable report names the pair

#### Scenario: Two majors with shared keys still evaluate

- **WHEN** a platform enables two majors of one catalog whose catalogs list the same keys at different catalog versions
- **THEN** the platform evaluates, both majors' transformers remain composed, and the collision report names the shared keys

#### Scenario: An unfulfilled platform still evaluates

- **WHEN** a platform enables a catalog that lists a provider-fulfilled trait with no provider
- **THEN** the platform evaluates, the fulfilled verdict reads false and every other report is readable
