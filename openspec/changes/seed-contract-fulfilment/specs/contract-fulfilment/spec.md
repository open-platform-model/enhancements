## Purpose

State where a contract's implementation is expected to come from, and what a component's demands oblige a platform to supply. A contract is fulfilled by its own catalog or by a provider in another catalog, a provider-fulfilled contract admits exactly one provider, every declared resource is a required demand, and a trait's optionality is stated by its catalog and overridden at the attachment. What a render does with these rules is stated by the render capability.

## ADDED Requirements

### Requirement: A contract declares where its fulfilment comes from

A `#Resource` and a `#Trait` SHALL each declare their fulfilment as either the declaring catalog ("catalog", the default) or a transformer in another catalog ("provider"). No third value SHALL be accepted. A provider-fulfilled contract is one whose declaring catalog deliberately ships no transformer for it.

#### Scenario: An existing primitive is unchanged

- **WHEN** a resource is declared without mentioning its fulfilment
- **THEN** its fulfilment is "catalog" and nothing about the primitive's behaviour changes

#### Scenario: A provider-fulfilled contract is declarable

- **WHEN** a resource declares its fulfilment as "provider"
- **THEN** the declaration validates

#### Scenario: A third mode is refused

- **WHEN** a trait declares its fulfilment as "external"
- **THEN** validation fails against the closed set of two values

### Requirement: A blueprint declares no fulfilment

A `#Blueprint` SHALL NOT carry a fulfilment declaration. A transformer can demand resources and traits but not blueprints, so a blueprint is never demanded and the field would be unreachable.

#### Scenario: Fulfilment on a blueprint is inexpressible

- **WHEN** a blueprint declares a fulfilment of "provider"
- **THEN** validation fails because the field is not allowed on a blueprint

### Requirement: A provider-fulfilled contract admits exactly one provider

A platform SHALL carry exactly one provider of a provider-fulfilled contract: an enabled registry entry, keyed by catalog path with its major, whose transformers require the contract. Two majors of one catalog are therefore two providers, and several transformers of one entry are one. Core SHALL compute this count once, in the platform's contract inventory, which the inventory capability states; consumers read that one count and keep none of their own.

#### Scenario: Two majors of one catalog are two providers

- **WHEN** a platform enables two majors of one catalog and a transformer of each requires the same provider-fulfilled contract
- **THEN** the contract has two providers, one per major, and does not meet the exactly-one rule

#### Scenario: Several transformers of one entry are one provider

- **WHEN** one enabled entry ships two transformers that require the same provider-fulfilled contract and no other entry requires it
- **THEN** the contract has one provider and meets the exactly-one rule

### Requirement: Every declared resource is a required demand

Every resource a component declares SHALL be a demand the platform must satisfy. What the render does with a demand that nothing supplies is stated by the render capability. A resource SHALL NOT have a demand-side optionality marker, and a partly satisfied component SHALL NOT render the satisfied part.

#### Scenario: A partly satisfied component does not render

- **WHEN** a component declares two resources and the platform supplies a transformer for only one
- **THEN** no output is emitted for the supplied resource of that component

### Requirement: A trait states its own optionality

A `#Trait` SHALL carry an optionality flag with no default from core: the declaring catalog states it as a default. A component SHALL be able to override it at the attachment site in either direction without conflict, and SHALL carry no optionality field of its own. What an unhandled trait does at render follows from this value and is stated by the render capability.

#### Scenario: A module overrules the catalog in either direction

- **WHEN** a component attaches a trait the catalog declared load-bearing and sets it optional at the attachment site
- **THEN** the resolved value is optional with no conflict, and the catalog's own definition is unchanged
- **AND** the same holds in reverse for a trait the catalog declared advisory

### Requirement: A catalog cannot pin a trait's posture

Publishing a catalog SHALL refuse a `#Trait` whose optionality is never stated, or is pinned to a concrete value that no module could override. Core SHALL ship the rule as a definition, `#TraitOptionalGate`, that a publishing tool unifies against, so the diagnostic is CUE's own. The schema alone cannot express this, so the rule is checked at publish.

#### Scenario: A posture stated as a default is accepted

- **WHEN** a catalog publishes a trait whose optionality is a default that can still be overridden
- **THEN** the gate passes

#### Scenario: A pinned posture is refused

- **WHEN** a catalog publishes a trait whose optionality is a concrete value
- **THEN** publish fails, because no module could override it

#### Scenario: An unstated posture is refused

- **WHEN** a catalog publishes a trait that never states its optionality
- **THEN** publish fails under concrete evaluation, naming the field
