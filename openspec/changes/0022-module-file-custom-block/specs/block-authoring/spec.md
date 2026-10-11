## Purpose

How tooling writes and updates the block in the committed source, so that publish only reads it and published bytes remain committed bytes.

## ADDED Requirements

### Requirement: Scaffolding seeds the block

Scaffolding a module SHALL seed the block in the same step that seeds the identity package.

#### Scenario: A new module

- **WHEN** an author scaffolds a module
- **THEN** the new tree holds both the identity package and the block

### Requirement: A version write updates the block

Writing a new version to the identity package SHALL write the same version to the block's identity in the same operation, so the two never differ after a write.

#### Scenario: A version bump

- **WHEN** an author sets version 2.1.0
- **THEN** the identity package and the block both read 2.1.0

### Requirement: A block write keeps comments and is idempotent

A block write SHALL preserve comments and SHALL be a no-op when the value already matches.

#### Scenario: Writing the same value

- **WHEN** the writer runs on a tree whose block already matches
- **THEN** the file is unchanged

### Requirement: A block write keeps unowned keys

A block write SHALL preserve every key in the block that it does not itself write, including a key that a later entry defines.

#### Scenario: An unowned key

- **WHEN** the writer updates the version in a block that holds a key it does not write
- **THEN** that key is unchanged
