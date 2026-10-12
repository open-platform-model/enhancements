## Purpose

How a transformer serves more than one level of a contract. A transformer names each level it serves, and a catalog says which levels those are.

## ADDED Requirements

### Requirement: A transformer is declared once per level

A transformer that serves more than one level of a resource or trait SHALL be declared once for each level. Each declaration SHALL name that level's exact contract key in its required or optional contracts.

#### Scenario: Two levels of one resource

- **WHEN** a transformer serves two levels of a resource
- **THEN** the catalog holds two declarations, each naming one level's key

### Requirement: A differing level carries a projection

When two served levels differ in shape, each per-level declaration SHALL carry its own projection into the shared canonical shape. A level with no projection SHALL be a level the transformer does not serve.

#### Scenario: A level without a projection

- **WHEN** a level differs in shape and has no projection
- **THEN** the transformer does not serve it

### Requirement: A catalog states the levels it serves

A catalog SHALL state which levels each of its transformers serves, in a place a consumer can read.

#### Scenario: A consumer asks which levels are served

- **WHEN** a consumer reads the catalog's published information
- **THEN** it finds the levels each transformer serves
