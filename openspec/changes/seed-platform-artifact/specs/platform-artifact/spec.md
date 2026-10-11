## Purpose

State the platform as a typed artifact. A platform is a CUE package that imports its catalogs. The artifact holds that package as built, its metadata decoded from it, the source it renders from, and its contract inventory read once at construction. Acquisition from a directory refuses a package that is not a complete platform. Reading the inventory refuses one that predates a report.

## ADDED Requirements

### Requirement: A platform holds its package, metadata and source

A platform SHALL hold the built platform package, the platform's metadata decoded from it, and the source tree the package was loaded from. The package is the source of truth: the metadata is a decoded copy, and where the two differ the package wins. A platform SHALL NOT decode the composed transformers; the render build reads them from the package.

#### Scenario: Metadata carries the platform's identity

- **WHEN** a platform value declares a name, a description, labels, annotations and a root-level type
- **THEN** the platform's metadata holds all five, with the root-level type read as the metadata type

#### Scenario: The composed transformers are not decoded

- **WHEN** a consumer looks at what a platform holds
- **THEN** it finds the package, the metadata and the source, and no decoded copy of the composed transformers

### Requirement: A platform is built from a bare value

A platform SHALL be buildable from its evaluated value alone. Building SHALL decode the metadata from the value's metadata and its root-level type, keep the value unchanged as the package, and leave the source absent. It SHALL detect no API version and look up no binding. A value with no metadata, undecodable metadata, or a root-level type that is not a string SHALL be refused, and no partial platform returned.

#### Scenario: A complete value builds a platform

- **WHEN** a platform is built from a value with a name, a description, labels, annotations and the root-level type "kubernetes"
- **THEN** its metadata holds those fields with the type "kubernetes", its package equals the value, and its source is absent

#### Scenario: A value without metadata is refused

- **WHEN** a platform is built from a value that has no metadata
- **THEN** the build is refused with an error stating that platform metadata is required, and no platform is returned

#### Scenario: A root-level type that is not a string is refused

- **WHEN** a platform is built from a value whose root-level type is a number
- **THEN** the build is refused with an error about the platform type, and no platform is returned

### Requirement: A directory-acquired platform carries its source

Acquiring a platform from a directory SHALL load the platform package there and return a platform whose source names the enclosing module root and the package directory relative to it. The root is the nearest ancestor that holds a module file, else the directory itself. The relative directory is empty for the root package. The source describes files on disk, with no in-memory copy.

#### Scenario: A module root directory is its own root

- **WHEN** a platform is acquired from a directory that holds a module file and a valid platform package
- **THEN** the platform has decoded metadata and the built package, the source root is that directory's absolute path, the relative package directory is empty, and the source holds no in-memory copy

#### Scenario: A subdirectory names its module root

- **WHEN** a platform is acquired from a subdirectory of a module
- **THEN** the source root is the module root's absolute path and the relative package directory is the subdirectory's slash-separated path

#### Scenario: A directory with no module is its own root

- **WHEN** a platform is acquired from a directory that has no enclosing module
- **THEN** the source root is that directory and the relative package directory is empty

### Requirement: Acquisition resolves catalogs through the configured registry

Acquisition SHALL resolve the platform's catalog imports through the registry mapping the kernel was configured with. It takes no per-call override and SHALL NOT change the process environment.

#### Scenario: The configured mapping resolves the imports

- **WHEN** a kernel configured with a registry mapping acquires a platform whose module requires catalogs under the project's own domain
- **THEN** the catalog imports resolve through the mapping, with no mapping passed to the call

#### Scenario: The process environment is left alone

- **WHEN** a kernel configured with a registry mapping acquires a platform
- **THEN** the environment variables of the process are the same after the call as before

### Requirement: Acquisition refuses a package that is no platform

Before it builds a platform, acquisition SHALL check that the package is one struct of kind Platform whose name and type are present, non-empty and concrete. A name or type left as a choice with a default SHALL be refused, naming the default and saying identity fields must be concrete literals. A refusal returns no platform and tells apart: not a package, wrong kind, missing field.

#### Scenario: Another kind is refused

- **WHEN** a platform is acquired from a directory whose package is a module
- **THEN** acquisition is refused as the wrong kind, naming the kind expected and the kind found, and no platform is returned

#### Scenario: A missing name or type is refused

- **WHEN** a platform is acquired from a package that has no name, or no type
- **THEN** acquisition is refused as a missing required field, naming the field

#### Scenario: A defaulted name is refused

- **WHEN** a platform's name is written as a choice whose default is "main"
- **THEN** acquisition is refused as a missing required field, naming the default "main" and saying identity fields must be concrete literals

#### Scenario: A package that is not a struct is refused

- **WHEN** a platform is acquired from a package that evaluates to a scalar or a list
- **THEN** acquisition is refused as an invalid package, and no platform is returned

### Requirement: Acquisition refuses an incomplete registry entry

Acquisition SHALL refuse a platform whose registry holds an entry with any field still incomplete, such as an entry that embeds no catalog or embeds a catalog without a stamped version. The refusal SHALL name the entry and the incomplete field, and return no platform. A platform with no registry entry passes this check.

#### Scenario: An entry with no embedded catalog is refused

- **WHEN** a platform is acquired whose registry entry declares only an enable switch and a version
- **THEN** acquisition is refused as a missing required field naming the entry and its version

#### Scenario: The same entry with its catalog imported passes

- **WHEN** the entry embeds the imported catalog
- **THEN** acquisition succeeds

#### Scenario: A catalog without a stamped version is refused

- **WHEN** a platform is acquired whose registry entry embeds a catalog that carries no version
- **THEN** acquisition is refused as a missing required field naming the entry

### Requirement: A platform records its contract inventory at construction

Building a platform SHALL read its contract inventory, and whether its core carries the provider count, from the package once and record both, or the refusal in place of the inventory. A missing or failing inventory SHALL NOT fail building; only the metadata can. A later read SHALL return the recorded result without reading the package, and each read SHALL return a copy no other read shares.

#### Scenario: An older-core platform is built and refused when read

- **WHEN** a platform pinning a core that predates the provider count is acquired
- **THEN** acquisition succeeds, reading the inventory returns no inventory and an error naming the platform, and the core check reports the core as too old for the provider count

#### Scenario: An inventory that does not evaluate still builds

- **WHEN** a platform is built from a value whose inventory fails to evaluate but carries the provider count
- **THEN** the platform is built, reading the inventory returns no inventory and an error saying it did not evaluate, and the core check passes

#### Scenario: A later change to the package is not followed

- **WHEN** the package of an acquired platform is replaced by an empty value and the inventory is read again
- **THEN** the read returns the inventory recorded at construction

#### Scenario: Each read is independent

- **WHEN** a caller changes a map entry and truncates a list in the inventory it read, then reads again
- **THEN** the second inventory equals the first as it was first returned

### Requirement: The inventory is read as a decoded view

A platform SHALL return its contract inventory as one decoded value holding every report: who defines, requires and provides each contract; the unfulfilled, over-subscribed, comparable and colliding contracts; and the three verdicts. It SHALL NOT hold the listed members, which a caller reads from the package. A platform that is not fulfilled, routable or discriminated, or that has collisions, SHALL be read without error.

#### Scenario: A healthy platform reads with every report

- **WHEN** a platform embedding one enabled catalog with a provider-fulfilled trait and one transformer requiring it is acquired
- **THEN** the read returns the definer, the requiring transformer and the one provider of the trait, empty unfulfilled, over-subscribed, comparable and colliding lists, and all three verdicts true

#### Scenario: The listed members are not decoded

- **WHEN** a caller reads the inventory
- **THEN** it holds no member schemas, and the same members are readable from the package

#### Scenario: An over-subscribed platform is reported, not refused

- **WHEN** a platform embeds two enabled catalogs whose transformers both require one provider-fulfilled contract
- **THEN** the platform is acquired, the read lists the contract as over-subscribed with both registry keys as its providers, the routable verdict is false, and no error is returned

### Requirement: An inventory that predates a report is refused

Reading the inventory of a platform whose core predates a report SHALL be refused with an error naming the missing field and the first core release carrying it. It SHALL NOT return a partial inventory or default the report. A platform with no inventory at all is refused the same way. The collision reports are the one exception: absent, they read as empty, because a core without them cannot evaluate a colliding platform. A present collision report that fails to decode is refused.

#### Scenario: Missing comparable-predicate reports are refused

- **WHEN** a platform value built against core 2.0.0-alpha.9 is read, carrying six report fields and neither the comparable list nor the discriminated verdict
- **THEN** the read returns no inventory and an error naming the missing field and the first release carrying it

#### Scenario: A missing provider count is refused with the core-too-old error

- **WHEN** a platform value built against core 2.0.0-alpha.11 or older is read
- **THEN** the read returns no inventory and a core-too-old error naming the provider count and the release 2.0.0-alpha.12

#### Scenario: A value with no inventory is refused

- **WHEN** a platform value carries no inventory at all
- **THEN** the read returns no inventory and a core-too-old error naming the inventory field

#### Scenario: An absent collision report reads as no collision

- **WHEN** a platform pinning core 2.0.0-alpha.12 is read
- **THEN** the read returns no error, empty collision lists, and every other report as the platform derives it
