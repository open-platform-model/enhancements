## Purpose

How the kernel turns a module's validated config into plain values before composition, so that a config default is a commitment and cannot collide with a blueprint default.

## ADDED Requirements

### Requirement: A broken config default fails the render

A config default that violates a downstream constraint SHALL fail the render at the config boundary and name the config field. The render SHALL NOT replace the default with a surviving disjunct.

#### Scenario: A default meets a constraint

- **WHEN** a config field defaults to 80 or 8080 and a downstream constraint requires a value above 1000
- **THEN** the render fails and names the config field, and it does not ship 8080

### Requirement: Every values path finalizes the same way

Config finalization SHALL give the same outcome whether values arrive as instance values, as layered value sources or as debug values.

#### Scenario: The same module through three paths

- **WHEN** one module and one set of values reach the kernel as instance values, as layered sources and as debug values
- **THEN** all three renders succeed with the same result or fail with the same error

### Requirement: Finalization never creates an unset field

An optional config field that the values leave unset SHALL stay absent after finalization. Finalization SHALL NOT create a field that nobody set.

#### Scenario: An optional field stays unset

- **WHEN** a config schema has an optional field with no default and the values omit it
- **THEN** the field is absent from the values that reach the composition
