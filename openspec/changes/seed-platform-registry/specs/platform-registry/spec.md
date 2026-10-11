## Purpose

Define how a platform carries the catalogs it admits. A platform holds one registry entry per catalog module path. Each entry embeds the imported catalog whole and derives its version and its transformers from it. The platform module's own dependency list alone selects which build of a catalog the platform holds.

## ADDED Requirements

### Requirement: A registry entry carries its catalog by import

Each entry in the registry of a `#Platform` SHALL carry the admitted catalog's value whole, obtained by importing the catalog module in the platform module, together with an enable switch that defaults to true. An entry SHALL NOT assemble the catalog inline, and SHALL NOT name its catalog build by an authored version alone.

#### Scenario: An entry embedding an imported catalog is accepted

- **WHEN** a platform module imports a catalog module and declares a registry entry that embeds the imported value
- **THEN** the platform validates and the entry's derived fields can be read

#### Scenario: An entry without a catalog is incomplete

- **WHEN** a registry entry declares only the enable switch and no catalog
- **THEN** evaluation reports the entry's version as incomplete, because the derived readout has no source

#### Scenario: A version-only entry cannot stand in for a catalog

- **WHEN** a registry entry declares only an authored version, as the removed subscription form did
- **THEN** the entry's version stays incomplete, because an authored version does not replace an embedded catalog

### Requirement: Entry identity is derived, never authored

An entry's version SHALL equal the version of its embedded catalog, and its transformers SHALL equal the embedded catalog's transformers, whole. A caller MAY write an expected version, which SHALL fail the build at a path naming the entry when it differs from the imported catalog's. An entry SHALL NOT select individual transformers.

#### Scenario: The version readout reflects the imported catalog

- **WHEN** an entry embeds a catalog stamped with version 4.0.1 and nothing else is written
- **THEN** the entry's version reads 4.0.1

#### Scenario: A written version that disagrees is a conflict

- **WHEN** an entry embeds a catalog stamped 4.0.1 and also writes the version 4.0.2
- **THEN** the build fails with a conflict at a path naming that entry

#### Scenario: An unstamped catalog is incomplete

- **WHEN** an entry embeds a catalog whose version is not set
- **THEN** the entry's version is reported as incomplete

### Requirement: A registry key must match its catalog

Each registry key SHALL be a catalog module path with its major version, and the embedded catalog SHALL declare that same path. A catalog whose declared path differs from its key SHALL fail the build at a path naming the entry.

#### Scenario: A matching key and import validate

- **WHEN** an entry is keyed by a catalog module path and embeds a catalog that declares that same path
- **THEN** the platform validates

#### Scenario: Key and import drift is a conflict

- **WHEN** an entry keyed by one catalog module path embeds a catalog that declares a different path
- **THEN** the build fails with a conflict on the module path at a path naming that entry

#### Scenario: A key without a major is refused

- **WHEN** a registry entry is keyed by a catalog module path that has no major version
- **THEN** the platform is refused, because the key is not a valid module path

### Requirement: Composed transformers are derived from enabled entries

A `#Platform` SHALL derive its composed transformers as every enabled entry's transformers, copied entry by entry. The composed set SHALL exist without any runtime step. An entry whose enable switch is false SHALL contribute nothing and SHALL stay in the file.

#### Scenario: Enabled entries contribute their transformers

- **WHEN** a platform declares two enabled entries whose catalogs carry different transformers
- **THEN** the composed transformers contain every transformer of both catalogs

#### Scenario: A disabled entry is excluded

- **WHEN** a platform declares an entry with its enable switch set to false
- **THEN** none of that catalog's transformers appear in the composed transformers

#### Scenario: The composed set needs no runtime step

- **WHEN** a platform declares a registry and nothing else
- **THEN** the composed transformers evaluate from the registry alone, and are empty when the registry is empty

### Requirement: One registry entry per catalog path

A `#Platform` SHALL hold at most one entry per catalog module path, and the path includes the major version. A platform SHALL NOT express two builds of one catalog major. Entries of different majors of one catalog are different entries.

#### Scenario: The map key enforces uniqueness

- **WHEN** a platform declares two registry entries under the same catalog module path
- **THEN** the two declarations unify into one entry and a disagreement between them is a conflict, so two distinct builds of one catalog major cannot be expressed

#### Scenario: Two majors are two entries

- **WHEN** a platform declares entries for the same catalog at two different majors, each embedding a catalog that declares its own path
- **THEN** the registry holds both entries

### Requirement: A platform carries no reverse index

A `#Platform` SHALL NOT declare an authored index from contracts to transformers for matching. A value that declares one SHALL have no effect: no derived field of the platform reads it. A consumer that needs such an index SHALL derive it from the composed transformers. The derived readiness index `#contracts.requiredBy` is not a matching index: it lists implementation names only, and matching SHALL NOT read it.

#### Scenario: A declared matching index is inert

- **WHEN** a platform value declares an authored index from contracts to transformers, of any shape
- **THEN** the composed transformers and every other derived field are the same as without it, because nothing reads the declared index

#### Scenario: The readiness index is not a matching index

- **WHEN** a platform derives the readiness index for a contract that two transformers require
- **THEN** the entry lists the two implementation names and no transformer or primitive value, and the composed transformers are unchanged by it

### Requirement: Catalog selection depends on committed source only

Which build of a catalog an entry holds SHALL be fixed by the platform module's own dependency list, with no step against a registry at evaluation time. A registry entry SHALL carry no lockfile, no maturity inference and no opt-in flag. A prerelease build SHALL be selected by naming it in the dependency list.

#### Scenario: Selection does not move when the registry does

- **WHEN** a platform module depends on catalog build 1.2.0 and build 1.3.0 is published
- **THEN** the platform still holds 1.2.0, with no lockfile consulted and no new resolution

#### Scenario: A prerelease is selected by naming it

- **WHEN** a platform module's dependency list names catalog build 1.0.0-alpha.2
- **THEN** the entry's version reads 1.0.0-alpha.2, with no extra flag
