## Purpose

Read a catalog into the kernel: fetched from a registry by module path and version, or loaded from a directory. The kernel also reports two facts about the catalog, the provider-fulfilled contracts it implements and the dependency requirements it committed. It reads and derives. It renders no verdict: whether a reported set matches a claim, whether a version is compatible, and what a refusal says belong to the consumer.

## ADDED Requirements

### Requirement: A catalog is acquired by path and version

The kernel SHALL acquire a published catalog from a registry by its major-qualified module path and a version, written bare or with a leading v. It SHALL return a typed catalog that carries its evaluated package and its source, staged in memory. The catalog's dependencies SHALL resolve through the kernel's configured registry, and a coordinate that registry cannot resolve SHALL fail the acquisition.

#### Scenario: A published catalog is acquired

- **WHEN** acquisition is asked for the path and version of a published catalog
- **THEN** the catalog is returned with its package evaluated and its source carried
- **AND** no staging directory is left on disk

#### Scenario: Both spellings of a version give one catalog

- **WHEN** the same catalog is acquired once with a bare version and once with a leading v
- **THEN** both calls return the same catalog

#### Scenario: A coordinate the registry cannot resolve fails

- **WHEN** acquisition is asked for a coordinate that the kernel's registry does not serve
- **THEN** it fails and returns no catalog

### Requirement: A catalog is acquired from a directory

The kernel SHALL acquire a catalog from a directory that holds its package, and SHALL return the same typed catalog as the registry route. It SHALL stage the source in memory from the whole module root: the nearest enclosing directory that holds a module file, or the directory itself. It SHALL NOT write to the caller's directory.

#### Scenario: A catalog directory is acquired

- **WHEN** acquisition is asked for a directory that holds a catalog package
- **THEN** the catalog is returned with its package evaluated and its source carried
- **AND** the caller's directory holds the same files as before

#### Scenario: A package in a subdirectory keeps its module root

- **WHEN** the catalog package sits in a subdirectory of its module
- **THEN** the carried source names the enclosing module root and the package's place inside it

### Requirement: A non-catalog artifact is refused by shape

Acquisition SHALL accept an artifact only if it carries the concrete kind Catalog and a concrete module path and version. A kind that differs, is missing or is not a concrete string SHALL be refused as the wrong kind, naming what was expected and what was found. A missing identity field SHALL be refused as a missing field. Acquisition SHALL NOT validate the whole schema and SHALL NOT return a partial catalog. Both routes SHALL refuse alike.

#### Scenario: A module artifact is refused

- **WHEN** acquisition resolves an artifact whose kind is Module, from a registry or from a directory
- **THEN** it is refused as the wrong kind, naming Catalog as expected and Module as found
- **AND** no catalog is returned

#### Scenario: An artifact without a usable kind is refused

- **WHEN** the artifact has no kind, or a kind that is not a concrete string
- **THEN** it is refused as the wrong kind

#### Scenario: A catalog without its identity is refused

- **WHEN** the artifact has the kind Catalog but no concrete version
- **THEN** it is refused as a missing required field, and no catalog is returned

#### Scenario: A defaulted version is not concrete

- **WHEN** the artifact has the kind Catalog and its version is a disjunction with a default
- **THEN** it is refused as a missing required field, and no catalog is returned

### Requirement: A catalog reports its provider-fulfilled contracts

The kernel SHALL report the provider-fulfilled contracts a catalog implements: the list that core derives for the catalog from the contracts its own transformers require. It SHALL read that list from the catalog when core derived it, and otherwise derive the same list from the transformers. The result SHALL be the same list in either case. A catalog that implements none SHALL yield an empty list and no error.

#### Scenario: A provider catalog's contracts are reported

- **WHEN** the report runs over a catalog whose transformers require a provider-fulfilled contract and a catalog-fulfilled one
- **THEN** the list equals the one core derives for that catalog

#### Scenario: A catalog that implements none reports an empty list

- **WHEN** none of a catalog's transformers requires a provider-fulfilled contract
- **THEN** the list is empty and there is no error, because implementing none is a fact about the catalog

#### Scenario: Both sources give one list

- **WHEN** a catalog is built against a core that derives the list
- **THEN** the list the catalog carries equals the list derived from its transformers

#### Scenario: A catalog from an older core is derived

- **WHEN** a catalog's committed module file pins a core older than the one that derives the list, and the catalog authors a list of its own
- **THEN** the list comes from its transformers and the authored list is not read

### Requirement: An unreadable provider set is an error

A provider set that cannot be read SHALL be an error with no partial set, from either source. The causes are: transformers that do not evaluate, even beside a well-formed list; a list that is not a concrete list of strings; a required contract whose fulfilment is present but not a concrete string; and, for a catalog that carries its source, a module file that cannot be read or names a core version that is not valid. The error SHALL name the failing part.

#### Scenario: A list that is not a list of strings is reported

- **WHEN** the catalog carries a provider list that is not a concrete list of strings
- **THEN** the report fails with an error naming the list, and no set is returned

#### Scenario: Transformers that do not evaluate are reported

- **WHEN** the catalog carries a well-formed provider list but its transformers do not evaluate
- **THEN** the report fails with an error naming the transformers, and no set is returned

### Requirement: A catalog's committed requirements are readable

The kernel SHALL expose the dependency requirements a catalog committed in its own module file, as module path to version, so a consumer can compare them with another resolution. It SHALL report what is written and judge nothing. It SHALL read the file with the reader that the render uses for its input modules, so a file the render refuses is refused here, naming the file. A dependency listed with no version SHALL map to an empty version.

#### Scenario: Declared requirements are readable

- **WHEN** a catalog whose module file requires a core version and a catalog version is acquired
- **THEN** both requirements are readable, each as a path and a version
- **AND** the kernel gives no verdict on whether either is acceptable

#### Scenario: Both routes give the same answer

- **WHEN** one catalog is acquired from a registry and from a directory
- **THEN** its requirements read the same

#### Scenario: A module file the render would refuse is refused

- **WHEN** an acquired catalog's module file lists a dependency that carries a replacement
- **THEN** reading its requirements fails with an error naming the module file, and returns no requirements
