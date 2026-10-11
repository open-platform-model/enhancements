## MODIFIED Requirements

### Requirement: A registry entry carries its catalog by import

Each entry in the registry of a `#ResolvedPlatform` SHALL carry the admitted catalog's value whole, obtained by importing the catalog module in the platform module, together with an enable switch that defaults to true. An entry SHALL NOT assemble the catalog inline, and SHALL NOT name its catalog build by an authored version alone.

#### Scenario: An entry embedding an imported catalog is accepted

- **WHEN** a platform module imports a catalog module and declares a registry entry that embeds the imported value
- **THEN** the platform validates and the entry's derived fields can be read

#### Scenario: An entry without a catalog is incomplete

- **WHEN** a registry entry declares only the enable switch and no catalog
- **THEN** evaluation reports the entry's version as incomplete, because the derived readout has no source

#### Scenario: A version-only entry cannot stand in for a catalog

- **WHEN** a registry entry declares only an authored version, as the removed subscription form did
- **THEN** the entry's version stays incomplete, because an authored version does not replace an embedded catalog

### Requirement: Composed transformers are derived from enabled entries

A `#ResolvedPlatform` SHALL derive its composed transformers as every enabled entry's transformers, copied entry by entry. The composed set SHALL exist without any runtime step. An entry whose enable switch is false SHALL contribute nothing and SHALL stay in the file.

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

A `#ResolvedPlatform` SHALL hold at most one entry per catalog module path, and the path includes the major version. A platform SHALL NOT express two builds of one catalog major. Entries of different majors of one catalog are different entries.

#### Scenario: The map key enforces uniqueness

- **WHEN** a platform declares two registry entries under the same catalog module path
- **THEN** they are one entry, so two distinct builds of one catalog major cannot be expressed

#### Scenario: Two majors are two entries

- **WHEN** a platform declares entries for the same catalog at two different majors, each embedding a catalog that declares its own path
- **THEN** the registry holds both entries

### Requirement: A platform carries no reverse index

A `#ResolvedPlatform` SHALL NOT declare an authored index from contracts to transformers for matching. A value that declares one SHALL have no effect: no derived field of the platform reads it. A consumer that needs such an index SHALL derive it from the composed transformers. The derived readiness index `#contracts.requiredBy` is not a matching index: it lists implementation names only, and matching SHALL NOT read it.

#### Scenario: A declared matching index is inert

- **WHEN** a platform value declares an authored index from contracts to transformers, of any shape
- **THEN** the composed transformers and every other derived field are the same as without it, because nothing reads the declared index

#### Scenario: The readiness index is not a matching index

- **WHEN** a platform derives the readiness index for a contract that two transformers require
- **THEN** the entry lists the two implementation names and no transformer or primitive value, and the composed transformers are unchanged by it
