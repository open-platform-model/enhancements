## Purpose

Which layer decides the value of a component field when several layers state one. The order is instance values, then config defaults, then blueprint defaults, then transformer fallbacks.

## ADDED Requirements

### Requirement: An instance value beats every default

A component field that the instance values set concretely SHALL render with that value, whatever default a config schema, a blueprint or a transformer states for the same field.

#### Scenario: The deployer overrides the blueprint

- **WHEN** a blueprint defaults a field to one value and the instance values set another
- **THEN** the field renders with the instance value

#### Scenario: The deployer overrides the config default

- **WHEN** the config schema defaults a field and the instance values set a different value
- **THEN** the field renders with the instance value

### Requirement: A config default beats a blueprint default

A config default for a field SHALL render over a blueprint default for the same field, and the render SHALL NOT report an unresolved disjunction.

#### Scenario: Two defaults meet

- **WHEN** the config schema defaults a field to one value and the blueprint defaults it to another, and the instance values are silent
- **THEN** the field renders with the config default and the render succeeds

### Requirement: A blueprint default renders when nothing above speaks

A blueprint default SHALL render when neither the instance values nor the config schema speak for the field.

#### Scenario: A fresh module

- **WHEN** a module composes a workload blueprint and sets no update strategy
- **THEN** the rendered workload carries the blueprint's strategy

### Requirement: A field no layer speaks for stays absent

A field that no layer above the transformer speaks for SHALL be absent on the composed component spec. The transformer's per-kind fallback, or the platform's own default when the transformer has none, SHALL supply the value.

#### Scenario: A transformer fallback fires

- **WHEN** no instance value, config default or blueprint default sets a field that a transformer defaults per kind
- **THEN** the field is absent on the component spec and the rendered object carries the transformer's fallback

#### Scenario: The platform default applies

- **WHEN** no layer including the transformer speaks for a field
- **THEN** the rendered object omits the field and the platform applies its own default
