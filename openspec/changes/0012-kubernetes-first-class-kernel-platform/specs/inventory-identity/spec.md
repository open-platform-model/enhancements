## Purpose

What makes two objects, two inventories and two renders the same for OPM: one stale-set relation, one inventory digest and one render digest, shared by both frontends.

## ADDED Requirements

### Requirement: The stale set ignores component and version

An object whose group, kind, namespace and name appear in the current render SHALL never be in the stale set, whichever component rendered it before or now and at whichever API version. The one exception is an inventory object the apply verdict refuses as adopted elsewhere: it SHALL be in the stale set, and the deletion plan SHALL skip it.

#### Scenario: A component rename

- **WHEN** an object moves from one component to another
- **THEN** it is not stale

#### Scenario: An object handed over

- **WHEN** an inventory object is refused as adopted elsewhere
- **THEN** it is stale and the deletion plan skips it

### Requirement: The inventory digest depends on field values only

The inventory digest SHALL depend only on the entries' field values. It SHALL NOT depend on the order of the entries or on how either frontend serialises an entry.

#### Scenario: A serialisation change

- **WHEN** a frontend changes how it serialises an entry and keeps every field value
- **THEN** the digest is unchanged

### Requirement: Different inventories give different digests

Two inventories that differ in their set of entries, or in any field of an entry, SHALL produce different inventory digests.

#### Scenario: One field differs

- **WHEN** two inventories differ in one field of one entry
- **THEN** their digests differ

### Requirement: A digest change ships a migration note

The release of each frontend that first records the new inventory digest SHALL ship a migration note naming the one-time change of the stored digest.

#### Scenario: Upgrade

- **WHEN** a user upgrades a frontend to the release that first records the new inventory digest
- **THEN** that release's migration note says the stored inventory digest changes once

### Requirement: Labels are stamped by the CUE render

Every OPM label on a rendered object SHALL be present in the output of the CUE render, before any frontend code handles the object.

#### Scenario: A rendered object

- **WHEN** a module renders an object
- **THEN** it already carries every OPM label before a frontend touches it

### Requirement: The render digest ignores the runtime name

For the same rendered objects, the CLI and the operator SHALL compute the same render digest, whichever runtime name each stamped.

#### Scenario: One render, two runtimes

- **WHEN** the CLI and the operator render the same module and stamp their own runtime names
- **THEN** the render digests are equal

### Requirement: Any other difference changes the render digest

Two renders that differ in any other label, or in any other content of an object, SHALL produce different render digests.

#### Scenario: A label differs

- **WHEN** two renders differ in a label other than the runtime name
- **THEN** their render digests differ
