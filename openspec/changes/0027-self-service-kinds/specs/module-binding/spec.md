## Purpose

Which module a platform offers and at which release, and how that one choice reaches every instance of the offering.

## ADDED Requirements

### Requirement: A definition binds one module

A definition SHALL be cluster-scoped. It SHALL bind one module lineage by its major-free registry path, one major, one bound release and an update policy, and it MAY carry platform-bound values.

#### Scenario: The platform writes a definition

- **WHEN** a platform team writes a definition for a module
- **THEN** the definition holds the lineage path, one major, one release and an update policy
- **AND** it is cluster-scoped

### Requirement: A consumer supplies values alone

A consumer SHALL instantiate a definition by supplying values alone. No consumer-facing object SHALL carry a module path or a version.

#### Scenario: An instance names no module

- **WHEN** a consumer creates an instance of a definition
- **THEN** the object holds values and no module path or version

### Requirement: Rebinding re-renders every instance

Rebinding a definition to another release SHALL re-render every instance of it under the definition's update policy, with no per-instance edit.

#### Scenario: The platform moves the release

- **WHEN** the platform rebinds a definition from one release to another
- **THEN** every instance of the definition re-renders under its update policy
- **AND** no consumer edits an instance

### Requirement: A definition may bind without a kind

A definition without an API group and kind SHALL be valid and SHALL bind only. No served-kind instance SHALL exist for it.

#### Scenario: A binding-only definition

- **WHEN** a definition names no API group and kind
- **THEN** the definition is accepted
- **AND** no kind is served for it
