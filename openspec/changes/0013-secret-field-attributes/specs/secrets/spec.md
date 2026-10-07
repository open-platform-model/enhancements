<!-- MOCKUP EXCERPT. The scenarios are unreviewed drafts. See openspec/MOCKUP.md. -->

## Purpose

Let a module declare which of its config fields are secrets, let the deployer choose how each one is supplied, and keep plaintext out of the render.

## ADDED Requirements

### Requirement: 0013:D10:R1

A sensitive `#config` field SHALL be declared with type `#Secret`, which accepts exactly two struct forms, `{value}` and `{ref, key}`, and rejects a bare scalar.

- Decision: `0013`, D10

#### Scenario: a bare string is rejected

- **WHEN** a deployer sets a `#Secret` field to the bare string `"hunter2"`
- **THEN** validation fails at that field

### Requirement: 0013:D10:R2

Routing (group, key, type) SHALL be stated only in the attribute; a value that carries routing fields is rejected.

- Decision: `0013`, D10

#### Scenario: routing inside the value

- **WHEN** a value at a `#Secret` field carries a routing field beside `value`
- **THEN** validation fails at that field

### Requirement: 0013:D10:R3

The deployer SHALL choose the form per environment in the instance values; moving an environment from a literal to a reference needs no republish of the module.

- Decision: `0013`, D10

#### Scenario: two environments, one module version

- **WHEN** one environment supplies `{value}` and another supplies `{ref, key}` for the same field
- **THEN** both render from the same published module version

### Requirement: 0013:D11:R1

At render, every secret path SHALL hold the `{ref, key}` form whichever form the deployer wrote, and a deployer-written reference passes through unchanged.

- Decision: `0013`, D11

#### Scenario: a literal becomes a reference

- **WHEN** the deployer supplies `{value: "hunter2"}`
- **THEN** the render-time value at that path is a `{ref, key}` that names the Secret OPM creates

#### Scenario: a reference passes through

- **WHEN** the deployer supplies `{ref: "existing-db-creds", key: "password"}`
- **THEN** the render-time value at that path is identical

### Requirement: 0013:D11:R2

The supplied plaintext SHALL appear in no rendered manifest other than the created Secret's own data.

- Decision: `0013`, D11

#### Scenario: plaintext stays in the Secret

- **WHEN** an instance with a literal secret is rendered
- **THEN** the literal appears only in the data of the Secret object

### Requirement: 0013:D11:R3

A module that interpolates a secret into a string SHALL fail validation at authoring time, with no kernel involved.

- Decision: `0013`, D11

#### Scenario: a secret inside a config file string

- **WHEN** a module writes `"password=\(#config.db.password)"`
- **THEN** plain `cue vet` of the module fails

### Requirement: 0013:D13:R1

A `#config` field typed `#Secret` with no attribute SHALL be discovered and resolved with default routing.

- Decision: `0013`, D13

#### Scenario: a forgotten attribute

- **WHEN** a field is typed `#Secret` and carries no attribute
- **THEN** it is resolved like any marked secret, and its literal does not reach the render

### Requirement: 0013:D13:R2

A field that carries the secret marker and is not typed `#Secret` SHALL be rejected at discovery.

- Decision: `0013`, D13

#### Scenario: the marker on a plain string

- **WHEN** a field typed `string` carries the secret marker
- **THEN** discovery fails and names the field

### Requirement: 0013:D25:R1

An authored instance package that carries a literal at a secret path SHALL fail with an error naming that path and the allowed alternatives.

- Decision: `0013`, D25

#### Scenario: a literal in an authored package

- **WHEN** an instance package's own files set `{value: "hunter2"}` at a secret path
- **THEN** the render fails
- **AND** the error names the path, and offers a reference or a values source

### Requirement: 0013:D25:R2

The same literal supplied through a CR's values or a values file SHALL render normally.

- Decision: `0013`, D25

#### Scenario: a literal in a values file

- **WHEN** the same literal arrives in a values file given alongside the instance
- **THEN** the render succeeds
