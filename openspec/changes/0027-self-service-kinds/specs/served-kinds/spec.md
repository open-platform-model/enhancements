## Purpose

What the API server sees of an offered module: a kind with the module's own configuration schema, versioned by the module's major, a namespaced object with no cluster-scoped object on its behalf.

## ADDED Requirements

### Requirement: The served schema is the module's own

Where a definition names an API group and kind, the schema of the served kind SHALL be the bound module's configuration schema and nothing else. No schema SHALL be authored on the definition.

#### Scenario: The kind carries the module's fields

- **WHEN** a definition names a group and kind for a module
- **THEN** the served kind accepts the fields of the module's configuration schema
- **AND** it accepts no field that the schema lacks

### Requirement: A bad instance is refused at admission

An instance of a served kind whose values violate the served schema SHALL be refused at admission, before it is stored.

#### Scenario: A misspelt field

- **WHEN** a consumer applies an instance with a field the schema does not define
- **THEN** the API server refuses the object and stores nothing

### Requirement: A non-structural schema is refused

A definition that names a kind SHALL be refused at acceptance when the bound module's configuration schema does not encode as a structural schema. The refusal SHALL name the module and the reason. The requirement holds the list of refused shapes and of every served-kind narrowing that an accepted open-question answer allows; the narrowing list is empty until such an answer is accepted.

#### Scenario: A schema that cannot be encoded

- **WHEN** a definition names a kind for a module whose configuration schema cannot encode as a structural schema
- **THEN** acceptance refuses the definition
- **AND** the refusal names the module and the reason

### Requirement: A module never served is unaffected

A module that is never bound as a served kind SHALL publish and render as before. The structural requirement SHALL NOT apply to it.

#### Scenario: A module with a free-form schema

- **WHEN** a module whose configuration schema cannot encode is deployed as an ordinary instance
- **THEN** it publishes and renders as it did before this entry

### Requirement: A served version is the module major

A served kind SHALL carry one API version per bound module major, spelled `v` followed by the major. The version SHALL be derived from the definition and never authored.

#### Scenario: Major 1 serves v1

- **WHEN** a definition binds major 1 of a module
- **THEN** the served kind has API version `v1`

### Requirement: A release outside the major is refused

A definition whose bound release lies outside its bound major SHALL be rejected.

#### Scenario: A mismatched release

- **WHEN** a definition binds major 1 and release 2.0.0
- **THEN** the definition is rejected

### Requirement: Rebinding inside a major keeps instances valid

Rebinding a definition to another release inside the same major SHALL regenerate the served schema in place, and every existing instance SHALL stay valid.

#### Scenario: A patch release

- **WHEN** the platform rebinds a definition from release 1.4.1 to 1.4.2
- **THEN** the served schema is regenerated in place
- **AND** instances stored before the rebind remain valid

### Requirement: A served instance is namespaced

An instance of a served kind SHALL be namespaced, and no cluster-scoped object SHALL be created on its behalf.

#### Scenario: No cluster-scoped object

- **WHEN** a consumer creates an instance in a namespace
- **THEN** no cluster-scoped object is created on its behalf

### Requirement: The consumer's object mirrors status

The consumer's object SHALL carry a status mirrored from the projected instance: at least its conditions and a reference to it.

#### Scenario: A render failure is visible

- **WHEN** the projected instance fails to render
- **THEN** the consumer's own object shows the failure in its conditions
- **AND** it holds a reference to the projected instance
