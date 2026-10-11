## Purpose

How a catalog publishes a word that means something about a module rather than a workload. A module trait is a sibling of a component trait, with the same identity, gates and posture.

## ADDED Requirements

### Requirement: A catalog publishes module traits like traits

A catalog SHALL publish a module trait under the same identity, fully qualified name and optionality gates as a component trait.

#### Scenario: A module trait passes the catalog gates

- **WHEN** a catalog publishes a module trait with a valid identity and an optionality default
- **THEN** the catalog validates

### Requirement: Module traits and traits do not mix

A module trait SHALL NOT attach to a component, and a component trait SHALL NOT attach to an aspect.

#### Scenario: A module trait on a component

- **WHEN** a component attaches a module trait
- **THEN** module validation fails

#### Scenario: A component trait on an aspect

- **WHEN** an aspect attaches a component trait
- **THEN** module validation fails

### Requirement: An attachment may narrow optionality

A catalog SHALL state a module trait's optionality as a default. An attachment SHALL be allowed to narrow it from optional to required and SHALL NOT widen or pin it.

#### Scenario: Narrowing to required

- **WHEN** an aspect attaches an optional module trait and marks it required
- **THEN** the module validates and the trait is required for that aspect

#### Scenario: Widening to optional

- **WHEN** an aspect attaches a required module trait and marks it optional
- **THEN** module validation fails
