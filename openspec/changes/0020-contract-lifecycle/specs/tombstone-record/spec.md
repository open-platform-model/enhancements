## Purpose

The tombstone record of a catalog: that it is cumulative, and the rules for its fields. The removed map itself is stated with the catalog's other maps. A consumer holding one build reads there where a key went.

## ADDED Requirements

### Requirement: Every build carries the full tombstone history

Every published catalog build SHALL carry the catalog's complete tombstone history, not the change since the previous build. A consumer holding one build SHALL be able to learn what happened to a key from that build alone.

#### Scenario: A key retired several builds ago

- **WHEN** a key was tombstoned in an earlier build and a consumer holds only the newest build
- **THEN** the newest build's own record holds that key's tombstone

### Requirement: A dropped tombstone is refused

The publish gate SHALL refuse a build that lacks a tombstone that its predecessor carried.

#### Scenario: A quiet cleanup

- **WHEN** a build omits a tombstone that the previous build carried
- **THEN** the publish is refused

### Requirement: A tombstone repeats its own key

Each tombstone's key field SHALL equal its map key. An entry that authors a different key SHALL be rejected.

#### Scenario: A mismatch

- **WHEN** an entry under one versioned contract key carries the key of another
- **THEN** the catalog is rejected

### Requirement: A catalog without tombstones stays valid

A catalog with no removed map, or an empty one, SHALL remain valid.

#### Scenario: A catalog that never removed anything

- **WHEN** a catalog carries no removed map
- **THEN** it validates

### Requirement: A tombstone states a reason

A tombstone with no reason, or an empty one, SHALL be rejected.

#### Scenario: An empty reason

- **WHEN** an author writes a tombstone with an empty reason
- **THEN** the tombstone is rejected

### Requirement: A missing replacement is not warned about

A tombstone without `replacedBy` SHALL publish with no warning, because a contract removed as a mistake has no successor.

#### Scenario: A mistake retired

- **WHEN** an author retires a contract that was a mistake and names no replacement
- **THEN** the publish continues with no warning

### Requirement: A tombstone cannot name itself as its replacement

A tombstone that names its own key as `replacedBy` SHALL be rejected.

#### Scenario: A self reference

- **WHEN** a tombstone for one key names the same key as its replacement
- **THEN** the tombstone is rejected
