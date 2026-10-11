## Purpose

What trait and resource schemas may contribute to a default: bounds, never a default. The kind-aware layers above them hold the defaults.

## ADDED Requirements

### Requirement: A primitive marks no default

A trait or resource spec schema SHALL NOT mark a default, so attaching a primitive alone never makes a field concrete.

#### Scenario: A trait attached alone

- **WHEN** a component attaches a trait whose field has a menu of values and no other layer speaks
- **THEN** the field is not concrete

### Requirement: A primitive admits what any kind accepts

A primitive's spec SHALL admit the union of what every target kind accepts, so the primitive never refuses a value that is legal on some kind.

#### Scenario: A value legal on one kind

- **WHEN** a value is accepted by one workload kind and refused by another
- **THEN** the primitive admits it, and the blueprint for each kind narrows it

### Requirement: A defaulted primitive is refused at publish

A catalog member whose trait or resource spec marks a default SHALL be refused at catalog publish.

#### Scenario: A defaulted trait is published

- **WHEN** a catalog author publishes a trait whose spec marks a default
- **THEN** the publish fails and names the rule

### Requirement: The retired defaults definitions are gone

The first-party catalog on the v2 line SHALL publish no `*Defaults` definition, and a module that references one SHALL fail to resolve.

#### Scenario: A stale reference

- **WHEN** a module references one of the retired defaults definitions
- **THEN** the reference fails to resolve
