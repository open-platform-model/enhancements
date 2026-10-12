## Purpose

How core's component honours a trait's stated posture, so that an optional trait constrains its field without forcing it present and absence can reach a transformer.

## ADDED Requirements

### Requirement: An optional trait leaves its field absent

An optional trait attached to a component SHALL constrain its field without making it present. With the author silent, the composed spec SHALL carry no such field.

#### Scenario: Attached and silent

- **WHEN** a component attaches an optional update-strategy trait and the author sets nothing
- **THEN** the composed spec has no update strategy field, and the component is concrete

### Requirement: An author's value is enforced and present

When the author sets an optional trait's field, the trait's schema SHALL be enforced and the field SHALL be present on the composed spec.

#### Scenario: A value outside the schema

- **WHEN** the author sets the field to a value the trait's schema refuses
- **THEN** validation fails

#### Scenario: A legal value

- **WHEN** the author sets the field to a legal value
- **THEN** the composed spec carries that value

### Requirement: A required trait makes its field required

A trait that is not optional SHALL make its field present and required on the composed spec, so a module that demands the trait must set the field.

#### Scenario: A demanded trait

- **WHEN** a component attaches a trait that is not optional and sets no value
- **THEN** the component is not concrete until the field is set

### Requirement: A trait with no stated posture fails everywhere

A trait that states no posture SHALL fail at every consumer of the component, and not only at the publish gate.

#### Scenario: An unstated posture

- **WHEN** a component attaches a trait that never states whether it is optional
- **THEN** evaluating the component fails

### Requirement: The composed spec stays closed

The composed component spec SHALL stay closed: a field that no attached resource, trait or blueprint declares SHALL still be rejected.

#### Scenario: A misspelled field

- **WHEN** the author sets a field that no attached definition declares
- **THEN** validation fails

### Requirement: A trait spec carries one top-level field

A trait's spec SHALL carry exactly one top-level regular field, and required or optional markers nested inside it SHALL survive projection intact.

#### Scenario: A nested marker

- **WHEN** an optional trait's schema marks one nested field required
- **THEN** the composed spec still requires that nested field once the author sets the trait's field

#### Scenario: A sibling field

- **WHEN** a trait spec declares a second top-level field
- **THEN** the definition is rejected
