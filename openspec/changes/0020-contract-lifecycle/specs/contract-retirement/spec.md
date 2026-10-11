## Purpose

How a contract leaves a catalog. A beta or stable key that stops shipping must be declared removed, a removal is never blocked, and a replacement must have been available for a minimum time first.

## ADDED Requirements

### Requirement: A removal without a tombstone is refused

The publish gate SHALL refuse a build that omits a contract which an earlier build published at beta or stable, unless the same build carries a tombstone for that key.

#### Scenario: A silent drop

- **WHEN** a build omits a stable contract and carries no tombstone for it
- **THEN** the publish is refused

#### Scenario: A declared drop

- **WHEN** a build omits a stable contract and carries a tombstone for it
- **THEN** the publish continues

### Requirement: A tombstone records what went and why

A tombstone SHALL record the key of the retired contract, the catalog build it went in and the reason it went. It MAY record the key that replaced it.

#### Scenario: A tombstone with a successor

- **WHEN** an author retires a beta contract in favour of a stable one
- **THEN** the tombstone holds the beta key, the build, the reason and the stable key

### Requirement: A removal itself is never refused

A build that carries a tombstone for every omitted beta or stable contract SHALL publish. The gate SHALL refuse the missing record and SHALL NOT refuse the removal.

#### Scenario: A deliberate removal

- **WHEN** an author wants a stable contract gone and writes a tombstone for it that names no replacement
- **THEN** the build publishes and the contract is gone

### Requirement: A tombstone dates the build that carries it

A tombstone's build SHALL be the version of the build that carries the tombstone, and not the last build that carried the member.

#### Scenario: A removal several builds after the last use

- **WHEN** a contract was last present in an earlier build and a later build tombstones it
- **THEN** the tombstone names the later build

### Requirement: An alpha contract is never tombstoned

The publish gate SHALL refuse a tombstone for an alpha-level key.

#### Scenario: Tombstoning an alpha contract

- **WHEN** a build carries a tombstone for an alpha key
- **THEN** the publish is refused

### Requirement: A withdrawal waits for the seasoning floor

The publish gate SHALL refuse a tombstone that names a replacement unless that replacement has been in the catalog's published history for at least the seasoning floor.

#### Scenario: A withdrawal that comes too soon

- **WHEN** a build tombstones a beta key and names a stable replacement that has been published for less than the floor
- **THEN** the publish is refused

#### Scenario: A withdrawal after the floor

- **WHEN** the replacement has been published for at least the floor
- **THEN** the tombstone is accepted
