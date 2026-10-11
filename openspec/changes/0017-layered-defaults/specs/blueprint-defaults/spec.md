## Purpose

What a blueprint may do with a composed field: narrow it to what the target kind accepts and mark one default on a leaf. The blueprint is the only defaulting layer on the catalog side.

## ADDED Requirements

### Requirement: A blueprint narrows only by subtraction

A blueprint MAY narrow a composed field, and every value the narrowing admits SHALL be admitted by the primitive's schema. A narrowing that admits a value the primitive refuses SHALL be refused at catalog publish.

#### Scenario: A kind-valid narrowing

- **WHEN** a stateless blueprint narrows the update strategy to the two types a Deployment accepts
- **THEN** the catalog publishes

#### Scenario: A widening narrowing

- **WHEN** a blueprint admits a value that the primitive refuses
- **THEN** the publish fails

### Requirement: A blueprint marks one leaf default per field

A blueprint SHALL mark at most one default per field, and the default SHALL sit on a leaf. A blueprint that marks a default on a whole struct SHALL be refused at catalog publish.

#### Scenario: A whole-struct default

- **WHEN** a blueprint marks a default on a struct instead of on its leaves
- **THEN** the publish fails and names the rule

### Requirement: A blueprint default yields to the author

With the author silent the blueprint's default SHALL render. An author's concrete value SHALL win over it. A value outside the blueprint's narrowing SHALL fail at vet time and name the blueprint line.

#### Scenario: Silent, overriding and invalid authors

- **WHEN** an author sets nothing, then a legal value, then a value the kind refuses
- **THEN** the default renders, the legal value renders, and the third fails at vet naming the blueprint line
