## Purpose

What a module version promises. The compatibility surface of a module is its config schema, and a release moves the version by what the schema accepts.

## ADDED Requirements

### Requirement: A config break carries a new major

A module release whose config schema stops accepting a value the previous release accepted SHALL carry a new major version.

#### Scenario: A removed field

- **WHEN** a release removes a config field that the previous release accepted
- **THEN** the release is a new major

### Requirement: A wider config carries at least a minor

A module release whose config schema accepts a strict superset of the previous release's values SHALL carry at least a minor version. An optional field, a field with a default and a loosened constraint are such changes.

#### Scenario: An optional field

- **WHEN** a release adds an optional config field and changes nothing else
- **THEN** the release carries at least a minor

### Requirement: An unchanged config carries at least a patch

A module release whose config schema accepts exactly the values the previous release accepted SHALL carry at least a patch version.

#### Scenario: A documentation-only fix

- **WHEN** a release changes only the documentation of a config field
- **THEN** the release carries at least a patch

### Requirement: The bump is the largest change class

A module release's bump SHALL be the largest change class found anywhere in the config schema.

#### Scenario: Two changes in one release

- **WHEN** a release adds one optional field and removes one required field
- **THEN** the release is a new major

### Requirement: A new required field is breaking

Adding a required field to the config schema SHALL be a breaking change, because the previous release accepted values without it.

#### Scenario: A required field is added

- **WHEN** a release adds a field that a value must set
- **THEN** the release is a new major
