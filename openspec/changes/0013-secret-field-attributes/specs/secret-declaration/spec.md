## Purpose

How a module author declares a sensitive config field, how a deployer supplies it, and how OPM finds every declared secret and rejects a malformed one. The author states routing once; the deployer states fulfilment per environment.

## ADDED Requirements

### Requirement: A secret is declared by type and attribute

A module author SHALL declare a sensitive config field with the core secret type and MAY add an `@opm(secret, ...)` attribute naming its group, key, Secret type, immutability and description. Every argument SHALL be optional, and the bare attribute SHALL be a complete declaration. An `@opm` attribute of another kind SHALL NOT make a field a secret.

#### Scenario: A bare attribute uses default routing

- **WHEN** a field carries the bare secret attribute
- **THEN** it joins the group named secrets, its key is derived from its config path, its Secret type is Opaque, and it is not immutable

#### Scenario: An attribute of another kind is ignored

- **WHEN** a field carries an `@opm` attribute whose first argument is not secret
- **THEN** the field is not treated as a secret

### Requirement: The deployer chooses how a secret is supplied

A deployer SHALL supply each secret per environment as a literal value or as a reference to an existing object and key, and a published module SHALL accept either without republishing. A literal SHALL cause a Secret object to be materialised; a reference SHALL cause nothing to be materialised. A values file that supplies a literal today SHALL be accepted unchanged.

#### Scenario: One module, two environments

- **WHEN** a development instance supplies a literal and a production instance supplies a reference for the same field
- **THEN** both validate against the same published module

#### Scenario: A reference materialises nothing

- **WHEN** a secret is supplied as a reference
- **THEN** no Secret object is created for it and the render wires the named object

### Requirement: An unmarked secret field is still discovered

Discovery SHALL treat a config field typed as the secret type, with no attribute, as a secret with default routing. A field that carries the secret attribute but is not typed as the secret type SHALL be an error at discovery. Forgetting the attribute SHALL NOT let a literal reach the render.

#### Scenario: A typed field without an attribute

- **WHEN** a field is typed as the secret type and carries no attribute
- **THEN** it is discovered and resolved with default routing

#### Scenario: An attribute on a plain string

- **WHEN** a field carries the secret attribute but is typed as a string
- **THEN** discovery fails, naming the field

### Requirement: A module's secrets are listable without values

The secrets a module declares, with their config path, group, key, Secret type and immutability, SHALL be listable from the published module alone, with no instance values. A declaration under a condition on a deployer value MAY appear only once values select it.

#### Scenario: Listing from the module alone

- **WHEN** a tool asks for the secrets of a module and supplies no values
- **THEN** it receives every declaration that is not under a condition on a deployer value

### Requirement: Every declared form of a secret is discovered

Discovery SHALL find a secret declared through an alias, an embedding, a pattern-constrained map entry, a list element or a conditional field, at any depth. A secret shape written in instance values at a field the module does not declare SHALL declare nothing, and a structure that merely resembles a secret SHALL NOT be discovered.

#### Scenario: A deployer-added map key

- **WHEN** a module declares an open map of secrets and the deployer adds a key
- **THEN** the new key is discovered as a secret

#### Scenario: A secret shape in values only

- **WHEN** the values carry a secret shape at a field the module declares as a plain string
- **THEN** the field is not treated as a secret

### Requirement: A malformed secret value is rejected

Plain CUE validation of an instance SHALL reject a secret value that carries both arms, a bare string, an unknown field, a routing field of the withdrawn vocabulary, or the wrong type, whether or not a component reads it. A module carrying either arm SHALL validate standalone, without the kernel.

#### Scenario: Both arms at once

- **WHEN** a value carries a literal and a reference together
- **THEN** CUE validation fails at that path

#### Scenario: A bare string

- **WHEN** a value supplies a plain string where the secret type is declared
- **THEN** CUE validation fails at that path

### Requirement: Core alone defines the secret type

Core SHALL publish the secret type and its two arms, a literal with a value and a reference with a ref and a key, and catalogs SHALL import them and define none of their own. A module written against the withdrawn secret vocabulary SHALL fail to type-check, and no alias SHALL accept it.

#### Scenario: A catalog imports the type

- **WHEN** a catalog needs the secret type
- **THEN** it imports core's definition and publishes no copy

#### Scenario: The old marker fields

- **WHEN** a module uses the withdrawn marker fields on a secret value
- **THEN** it fails to type-check against the new core
