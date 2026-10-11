## Purpose

How publish keeps the block honest: it checks every repeated value against the module file and the identity package, and how a missing block is phased from a warning to a refusal.

## ADDED Requirements

### Requirement: Publish refuses a stale identity

Publish SHALL refuse a block whose identity module path differs from the module file's module path, or whose identity version differs from the identity package's version.

#### Scenario: A stale version

- **WHEN** the identity package says 2.0.2 and the block says 2.0.1
- **THEN** publish refuses

### Requirement: Publish refuses a wrong core line

Publish SHALL refuse a block whose core version differs from the pinned version of the core dependency at the declared major. Publish SHALL also refuse a block whose core major names a line the module file does not depend on.

#### Scenario: A stale pin

- **WHEN** a dependency update moves the core pin and the block keeps the old version
- **THEN** publish refuses

#### Scenario: A major with no dependency

- **WHEN** the block names core major v2 and the module file has no core v2 dependency
- **THEN** publish refuses

### Requirement: Publish refuses a wrong catalog list

Publish SHALL refuse a block whose catalogs omit a first-party catalog dependency, list one at a different version, or list a path that is not a dependency.

#### Scenario: A catalog left out

- **WHEN** the module file depends on a first-party catalog the block does not list
- **THEN** publish refuses

### Requirement: A refusal names both values and the repair

A refusal SHALL name the conflicting field with both values and SHALL name the writer command that repairs the tree.

#### Scenario: A readable refusal

- **WHEN** publish refuses a stale block
- **THEN** the message shows the block's value, the implied value and the command that fixes the tree

### Requirement: A missing block warns first

Publish SHALL warn on a module, catalog or template artifact without the block, from the release that ships the writer.

#### Scenario: The first release

- **WHEN** an author publishes a tree without the block in that release
- **THEN** publish succeeds and prints a warning

### Requirement: A dated release refuses a missing block

From a later release, dated in the CLI changelog, publish SHALL refuse an artifact without the block.

#### Scenario: After the date

- **WHEN** an author publishes a tree without the block after that release
- **THEN** publish refuses

### Requirement: The module check reports a missing block

The module check SHALL report a missing block as the same condition that publish warns or refuses on.

#### Scenario: Check before publish

- **WHEN** an author runs the module check on a tree without the block
- **THEN** it reports the missing block

### Requirement: Published artifacts are never affected

An artifact already published without the block SHALL NOT be affected by the warning or the refusal.

#### Scenario: An old release

- **WHEN** the refusal date has passed
- **THEN** every artifact published earlier still resolves and installs
