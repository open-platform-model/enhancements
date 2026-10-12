## Purpose

How a module states a fact about itself as a whole. A module carries named aspects beside its components, and each aspect attaches module traits that a catalog publishes.

## ADDED Requirements

### Requirement: A module without aspects is unchanged

A module that declares no aspect SHALL be valid and SHALL mean what it meant before aspects existed.

#### Scenario: A module with components only

- **WHEN** a module declares components and no aspect
- **THEN** the module validates and renders as it did before

### Requirement: An aspect attaches at least one module trait

An aspect SHALL attach at least one module trait. A module with an aspect that attaches none SHALL be rejected at module validation.

#### Scenario: An empty aspect

- **WHEN** a module declares an aspect with no module trait
- **THEN** module validation fails

#### Scenario: An aspect with one trait

- **WHEN** a module declares an aspect that attaches one module trait
- **THEN** module validation accepts it

### Requirement: An aspect carries no resource or blueprint

An aspect SHALL NOT declare a resource or a blueprint. A module whose aspect declares one SHALL be rejected at module validation.

#### Scenario: A resource on an aspect

- **WHEN** an aspect declares a resource
- **THEN** module validation fails

#### Scenario: A blueprint on an aspect

- **WHEN** an aspect declares a blueprint
- **THEN** module validation fails

### Requirement: An aspect's matching labels are derived

An aspect's matching labels SHALL be derived from its attached module traits. A module whose aspect sets a matching label of its own that differs from the derived set SHALL be rejected at module validation.

#### Scenario: A self-contributed label

- **WHEN** an aspect authors a matching label that no attached trait declares
- **THEN** module validation fails

#### Scenario: Labels follow the traits

- **WHEN** an aspect attaches two module traits that each declare a matching label
- **THEN** the aspect's matching labels are derived from the labels of the two traits

### Requirement: An aspect renders under an instance-qualified name

An aspect's rendered object name SHALL default to the instance-qualified name, and an author MAY set it per aspect.

#### Scenario: A default name

- **WHEN** an aspect sets no rendered object name
- **THEN** the object renders under the instance-qualified name

#### Scenario: A name set per aspect

- **WHEN** an author sets the rendered object name on an aspect
- **THEN** the object renders under that name

### Requirement: An aspect spec may read module configuration

An aspect's spec SHALL be allowed to read the module configuration and the computed names of the module's components, as a component spec does.

#### Scenario: A spec reads configuration

- **WHEN** an aspect spec takes a value from the module configuration
- **THEN** each instance renders the value it supplied

### Requirement: An aspect spec accepts only declared keys

A key in an aspect's spec that no attached module trait declares SHALL be rejected at module validation.

#### Scenario: An undeclared key

- **WHEN** an aspect spec sets a key that none of its traits declares
- **THEN** module validation fails
