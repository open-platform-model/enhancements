# secrets Specification

## Purpose
Let a module declare which of its config fields are secrets, let the deployer choose how each one is supplied, and keep plaintext out of the render.

## Requirements

### Requirement: A secret is a literal or a reference

A sensitive `#config` field SHALL be declared with the type `#Secret`. It accepts a literal, `#SecretLiteral` as `{value: string}`, or a reference, `#SecretRef` as `{ref: string, key: string}`, with every field required, and it rejects a bare scalar.

- Design: 0013, Declaring a secret
- Was: `0013:D10:R1`

#### Scenario: a bare string is rejected

- **WHEN** a deployer sets a `#Secret` field to the bare string `"hunter2"`
- **THEN** validation fails at that field

#### Scenario: a reference without a key is rejected

- **WHEN** a deployer sets a `#Secret` field to `{ref: "existing-db-creds"}`
- **THEN** validation fails at that field

### Requirement: Routing lives only in the attribute

Routing (group, key, type, immutable, description) SHALL be stated only in the attribute; a value that carries a routing field is rejected.

- Design: 0013, Declaring a secret
- Was: `0013:D10:R2`

#### Scenario: an old routing field inside the value

- **WHEN** a value at a `#Secret` field carries an old routing field such as `$secretName`
- **THEN** validation fails at that field

### Requirement: The deployer chooses the form per environment

The deployer SHALL choose the form per environment in the instance values. A published module fixes neither form, and moving an environment from one form to the other needs no republish of the module.

- Design: 0013, Declaring a secret
- Was: `0013:D10:R3`

#### Scenario: two environments, one module version

- **WHEN** one environment supplies `{value}` and another supplies `{ref, key}` for the same field
- **THEN** both render from the same published module version

### Requirement: An existing literal values file still works

An instance values file that supplies a secret as `{value: "…"}` today SHALL be accepted unchanged.

- Design: 0013, Declaring a secret
- Was: `0013:D10:R4`

#### Scenario: a values file from before this change

- **WHEN** a values file written before this change supplies `{value: "hunter2"}` for a secret
- **THEN** it is accepted with no edit

### Requirement: A module with secrets checks without OPM

A module that carries either form SHALL vet standalone, without the kernel in the loop.

- Design: 0013, Declaring a secret
- Was: `0013:D10:R5`

#### Scenario: plain vet on a module

- **WHEN** plain `cue vet` runs on a module whose example values use a literal for one secret and a reference for another
- **THEN** it passes with no OPM tool involved

### Requirement: Plain vet names an unfilled secret

An unfulfilled secret SHALL be non-concrete, so plain `cue vet -c` names it by its config path with no OPM tooling involved.

- Design: 0013, Declaring a secret
- Was: `0013:D10:R6`

#### Scenario: a secret left unset

- **WHEN** a deployer leaves a `#Secret` field unset and runs `cue vet -c`
- **THEN** the error names that field's config path

### Requirement: Every secret is a reference at render

At render, every secret path SHALL hold the `{ref, key}` form whichever form the deployer wrote. A supplied value is replaced by a reference to the object OPM creates. A deployer-written reference passes through byte-identical and is never prefixed with the instance name.

- Design: 0013, Resolving secrets
- Was: `0013:D11:R1`

#### Scenario: a literal becomes a reference

- **WHEN** the deployer supplies `{value: "hunter2"}`
- **THEN** the render-time value at that path is a `{ref, key}` that names the Secret OPM creates

#### Scenario: a reference passes through

- **WHEN** the deployer supplies `{ref: "existing-db-creds", key: "password"}`
- **THEN** the render-time value at that path is byte-identical
- **AND** `ref` carries no instance prefix

### Requirement: Plaintext appears only in the Secret

No `value` field SHALL exist at any secret path in the render-time values, and the supplied plaintext appears in no rendered manifest other than the created Secret's own data.

- Design: 0013, Resolving secrets
- Was: `0013:D11:R2`

#### Scenario: no value field at render

- **WHEN** an instance with a literal secret reaches render
- **THEN** no secret path in the render-time values has a `value` field

#### Scenario: plaintext stays in the Secret

- **WHEN** an instance with a literal secret is rendered
- **THEN** the literal appears only in the data of the Secret object

### Requirement: A secret cannot be put inside a string

A module that interpolates a secret into a string SHALL fail at plain `cue vet` at authoring time, before any kernel is involved.

- Design: 0013, Resolving secrets
- Was: `0013:D11:R3`

#### Scenario: a secret inside a config file string

- **WHEN** a module writes `"password=\(#config.db.password)"`
- **THEN** plain `cue vet` of the module fails

### Requirement: Reading a secret's value gives a clear error

A module or transformer that reads a resolved secret's literal value SHALL be told so against the config path it wrote, not through an error about a missing field.

- Design: 0013, Resolving secrets
- Was: `0013:D11:R4`

#### Scenario: a module reads the value

- **WHEN** a module reads `.value` of the secret at `db.password`
- **THEN** the error names `db.password` and says that secret data is not readable during render

### Requirement: An unmarked secret field is still found

A `#config` field typed `#Secret` with no attribute SHALL be discovered and resolved with default routing, exactly as if it carried a bare `@opm(secret)`: the group `secrets`, and a key derived from the field's path.

- Design: 0013, Declaring a secret
- Was: `0013:D13:R1`

#### Scenario: a forgotten attribute

- **WHEN** a field is typed `#Secret` and carries no attribute
- **THEN** it is resolved into the group `secrets`, and its literal does not reach the render

### Requirement: The marker on a non-secret field fails

A field that carries the secret marker and is not typed `#Secret` SHALL be rejected at discovery.

- Design: 0013, Declaring a secret
- Was: `0013:D13:R2`

#### Scenario: the marker on a plain string

- **WHEN** a field typed `string` carries the secret marker
- **THEN** discovery fails

### Requirement: An authored instance package refuses literals

An authored instance package that carries a literal at a secret path SHALL fail with an error naming that path and the allowed alternatives.

- Design: 0013, Resolving secrets
- Was: `0013:D25:R1`

#### Scenario: a literal in an authored package

- **WHEN** an instance package's own files set `{value: "hunter2"}` at a secret path
- **THEN** the render fails
- **AND** the error names the path, and offers a reference or a values source

### Requirement: CR values and values files accept literals

The same literal supplied through a CR's values or a values file SHALL render normally.

- Design: 0013, Resolving secrets
- Was: `0013:D25:R2`

#### Scenario: a literal in a values file

- **WHEN** the literal arrives in a values file given alongside the instance
- **THEN** the render succeeds

#### Scenario: a literal in a custom resource

- **WHEN** the literal arrives in the values of a `ModuleInstance` CR
- **THEN** the render succeeds
