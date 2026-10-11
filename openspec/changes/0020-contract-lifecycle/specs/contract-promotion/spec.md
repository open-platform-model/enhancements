## Purpose

How a contract moves up the API level ladder. A promoted contract declares the level it came from, and the publish gate checks the promotion against that level.

## ADDED Requirements

### Requirement: A promoted contract names its origin

A contract that a build publishes at a higher level than the one it was born at SHALL carry `metadata.promotedFrom`, naming the level it came from. A contract born at its level SHALL carry no such field.

#### Scenario: A promoted contract

- **WHEN** a catalog publishes a contract at stable that was born at beta
- **THEN** the stable contract names beta as its origin

#### Scenario: A contract born at its level

- **WHEN** a catalog publishes a new contract at stable with no earlier level
- **THEN** the contract carries no origin

### Requirement: The origin lies strictly below the level

The level named by `promotedFrom` SHALL lie strictly below the contract's own level, in the order alpha, beta, stable within a major. The publish gate SHALL refuse an equal or higher origin.

#### Scenario: An origin that is not lower

- **WHEN** a contract at beta names beta as its origin
- **THEN** the publish is refused

#### Scenario: A skipped rung

- **WHEN** a contract at stable names alpha as its origin
- **THEN** the origin is accepted and the promotion check runs against alpha

### Requirement: The origin stays on the published contract

`promotedFrom` SHALL stay on the contract in every later build. The publish SHALL NOT consume it and drop it, so a reader of the artifact can see where the contract came from.

#### Scenario: A later build

- **WHEN** a catalog publishes a build after the promotion, with the promoted contract unchanged
- **THEN** the contract still names its origin

### Requirement: The origin never enters a contract key

`promotedFrom` SHALL NOT enter a contract key. A promoted contract SHALL match only at its own level.

#### Scenario: A module demands the old level

- **WHEN** a module demands the contract at its origin level
- **THEN** it matches the origin key and not the promoted contract

### Requirement: A broken promotion is refused with a path

The publish gate SHALL refuse a promotion that is not additive over its origin. The refusal SHALL name both contract keys and the offending path.

#### Scenario: A dropped field

- **WHEN** a promoted contract drops a field of its origin
- **THEN** the publish is refused, naming both keys and the path of the field

### Requirement: A promotion changes no shape

A contract that carries `promotedFrom` SHALL be structurally identical to the predecessor that the promotion check resolves. A build that moves a contract to a new level and changes its shape in the same release SHALL be refused.

#### Scenario: An additive change rides the promotion

- **WHEN** a build promotes a contract and also adds an optional field to it
- **THEN** the publish is refused

#### Scenario: A pure promotion

- **WHEN** a build promotes a contract with the same shape as its origin
- **THEN** the publish passes the check

### Requirement: A refused mixed promotion names the remedy

The refusal of a promotion that changes shape SHALL tell the author to publish the change at the origin level first and to promote in a later build.

#### Scenario: The message

- **WHEN** a mixed promotion is refused
- **THEN** the refusal says to publish the change at the origin level first and promote in a later build
