## Purpose

How a definition and a consumer's values become an ordinary module instance.

## ADDED Requirements

### Requirement: A projected instance renders unchanged

Every instance of a definition, from either layer, SHALL render as a complete module instance through the render path unchanged. The render SHALL observe nothing that distinguishes a projected instance from a hand-written one.

#### Scenario: Both layers take one path

- **WHEN** an instance arrives by a definition reference and another through a served kind
- **THEN** both render through the same render path

### Requirement: A projected and a written instance render alike

A projected instance and a hand-written module instance with the same module, name, namespace and values SHALL render identical output.

#### Scenario: Identical output

- **WHEN** the same module, name, namespace and values are given once projected and once hand-written
- **THEN** the two renders are identical

### Requirement: A projected instance gets ordinary diagnostics

A render diagnostic for a projected instance SHALL be the one a hand-written instance would receive for the same input.

#### Scenario: The same failure, the same message

- **WHEN** projected and hand-written instances fail on the same input
- **THEN** both receive the same diagnostic

### Requirement: The projection yields name, module and values

The projected instance SHALL take its name and namespace from the consumer's instance and its module from the definition. Its values SHALL be the unification of the definition's bound values with the consumer's values.

#### Scenario: Bound and consumer values meet

- **WHEN** a definition binds one field and the consumer sets another
- **THEN** the projected instance holds both values
- **AND** its name and namespace are the consumer's

### Requirement: A value clash is refused

A consumer value that conflicts with a bound value SHALL be refused. Neither side SHALL override the other.

#### Scenario: The consumer sets a bound field

- **WHEN** a consumer sets a field that the definition binds to another value
- **THEN** the projection is refused
- **AND** the bound value is not replaced

### Requirement: The projection is the same offline

The same definition, instance and module SHALL project to the same module instance offline and in a cluster, so a render is reproducible with no cluster.

#### Scenario: Offline equals in-cluster

- **WHEN** the CLI projects a definition and an instance with no cluster
- **THEN** the result equals the operator's projection of the same inputs

### Requirement: A config default reaches the values

A default of the configuration schema SHALL reach the projected values when neither the definition nor the consumer sets the field.

#### Scenario: An untouched field

- **WHEN** neither the definition nor the consumer sets a field that has a default
- **THEN** the projected values hold the default

### Requirement: Only the bound module projects

A module supplied to the projection that is not the bound one, by registry path or by version, SHALL be refused.

#### Scenario: A different version

- **WHEN** the projection receives a module at a version other than the bound release
- **THEN** the projection is refused
