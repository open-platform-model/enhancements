## Purpose

What the OPM metadata block holds, where it sits in an artifact's module file, and how it stays readable across versions of its own shape. A reader learns an artifact's kind, identity and compatibility from the module file alone.

## ADDED Requirements

### Requirement: The block sits under a reserved key

An artifact's metadata block SHALL be the struct under the module file's `custom` field at the key `opmodel.dev@v0`. A reader holding the module file SHALL need no other file or layer to find it.

#### Scenario: Read from the module file alone

- **WHEN** a reader fetches only an artifact's module file
- **THEN** it finds the block at that key without fetching the zip

### Requirement: Adding a key keeps the key suffix

Adding a key to the block SHALL leave the key suffix at `v0`. The suffix SHALL change only when an existing key changes meaning or is removed.

#### Scenario: A new optional key

- **WHEN** a later release adds an optional key to the block
- **THEN** the block stays under `opmodel.dev@v0`

#### Scenario: A key changes meaning

- **WHEN** an existing key changes meaning
- **THEN** the block moves to a new suffix

### Requirement: A reader ignores unknown block keys

A reader SHALL ignore any block key it does not know, so a block written for a newer shape stays readable by an older reader.

#### Scenario: A newer block

- **WHEN** an older reader reads a block with a key it does not define
- **THEN** it reads the keys it knows and raises no error

### Requirement: Every block value is concrete

Every value in the block SHALL be concrete. A block that holds a reference, a definition or a default SHALL NOT parse as a module file.

#### Scenario: A reference in the block

- **WHEN** a block value is a reference to another field
- **THEN** the module file does not parse

### Requirement: The block survives dependency tidying

The block SHALL keep every value after dependency tidying, though tidying may drop comments and sort keys. Publish SHALL ship the module file as it stands after tidying, byte for byte, so the registry holds the values the tree holds.

#### Scenario: Tidy then publish

- **WHEN** an author tidies the dependencies and publishes
- **THEN** the registry's module file holds every block value of the tidied tree

### Requirement: The block carries four required facts

The block SHALL carry the kind, the identity, the core line and the catalogs. A block missing any of the four SHALL fail validation.

#### Scenario: A missing fact

- **WHEN** a block has no core line
- **THEN** validation fails and names the missing fact

### Requirement: The kind is module, catalog or template

The kind SHALL be one of module, catalog or template. Any other value SHALL fail validation.

#### Scenario: An unknown kind

- **WHEN** a block declares the kind index
- **THEN** validation fails

### Requirement: The identity repeats the path and version

The identity SHALL carry the identity package's module path and version as two named fields.

#### Scenario: Two named fields

- **WHEN** a reader looks at the identity
- **THEN** it finds a module path field and a version field

### Requirement: The core line names major and version

The core line SHALL name the core major and the exact core version pinned in the module file's dependencies.

#### Scenario: A core v2 module

- **WHEN** a module depends on core at major v2 with an exact pin
- **THEN** the block names major v2 and that exact version

### Requirement: The catalogs map each dependency to its pin

The catalogs SHALL map every catalog dependency, keyed by module path with major, to its pinned version. The map MAY be empty.

#### Scenario: A module with no catalog

- **WHEN** a module depends on no catalog
- **THEN** the block carries an empty catalogs map and is valid

### Requirement: The block carries no toolchain fact

The block SHALL carry no fact about the toolchain that authored it.

#### Scenario: Who wrote the file

- **WHEN** a reader looks for the tool version in the block
- **THEN** it finds none

### Requirement: A block may carry keys this entry omits

A block that carries a key this entry does not define SHALL pass this entry's validation. Only the entry that defines the key SHALL validate it.

#### Scenario: A reserved listing key

- **WHEN** a block carries a listing key beside the four required facts
- **THEN** validation of the four facts passes and the listing key is not checked
