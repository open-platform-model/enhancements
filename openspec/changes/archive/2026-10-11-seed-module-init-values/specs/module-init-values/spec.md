## Purpose

Lets a module author state, in the module itself, the values a freshly initialized instance of the module starts from, apart from the `debugValues` the author tests with. The field is optional and open, it is not checked against the module's config contract, and it changes neither the test values nor any identity.

## ADDED Requirements

### Requirement: A module may declare initValues

A `#Module` SHALL accept an optional field `initValues` beside `debugValues`, holding the values a freshly initialized instance starts from. The field is open: any CUE value is accepted, concrete or not, struct or not. A module without it SHALL stay valid and unchanged in meaning. `#Module` SHALL stay closed, so no other new field becomes legal.

#### Scenario: Module sets concrete initValues

- **WHEN** a `#Module` value sets `initValues: {replicas: 2, logLevel: "info"}`
- **THEN** it validates, and `initValues` reads back as written

#### Scenario: Module sets non-concrete initValues

- **WHEN** a `#Module` value sets `initValues: {replicas: *2 | int, logLevel: "info" | "debug", port?: int}`
- **THEN** it validates, and `initValues.logLevel` reads back as the disjunction `"info" | "debug"`

#### Scenario: Module without initValues

- **WHEN** a `#Module` value that validated before the field existed is evaluated again
- **THEN** it validates, and `initValues` is absent

#### Scenario: A misspelled sibling is still refused

- **WHEN** a `#Module` value sets `initValuez: {}`
- **THEN** evaluation fails with `field not allowed` naming `initValuez`

### Requirement: initValues is not checked against #config

The schema SHALL NOT assert that `initValues` satisfies the module's `#config`. A module whose `initValues` does not satisfy its `#config` SHALL still validate as a module. The mismatch surfaces only where the value is consumed.

#### Scenario: Non-conforming initValues still validates

- **WHEN** a module declares `#config: {replicas: int}` and `initValues: {replicas: "two"}`
- **THEN** the module validates

### Requirement: initValues is inert for debugValues and identity

Adding `initValues` SHALL change nothing about `debugValues`: its field, meaning and constraint stay as they were, and a module MAY carry both with different content. `initValues` SHALL NOT be an input to the module's `metadata.fqn` or `metadata.uuid`, nor to the `metadata.uuid` of any `#ModuleInstance` that deploys the module. An instance whose `#module` sets `initValues` SHALL evaluate exactly as one whose `#module` does not.

#### Scenario: Both fields with different content

- **WHEN** a module sets `debugValues: {logLevel: "debug"}` and `initValues: {logLevel: "info"}`
- **THEN** it validates, and each field reads back its own content

#### Scenario: Module identity does not move

- **WHEN** two modules differ only in that one sets `initValues`
- **THEN** their `metadata.fqn` values are equal, and so are their `metadata.uuid` values

#### Scenario: Instance identity does not move

- **WHEN** two instances share a name and a namespace and deploy two modules that differ only in that one sets a non-concrete `initValues`, with `values` that satisfy `#config`
- **THEN** both instances validate, and their `metadata.uuid`, `metadata.fqn` and `metadata.labels` are equal
