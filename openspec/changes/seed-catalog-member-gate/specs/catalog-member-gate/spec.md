## Purpose

State what a catalog member must declare relative to its catalog identity: where it is filed, which build it names, how its key is built and which API version it carries. The rule is stated so that unification refuses a member and the author reads CUE's own error. It covers resources, traits, blueprints and transformers.

## ADDED Requirements

### Requirement: A member is unified against its catalog identity

The schema SHALL ship `#CatalogMemberFQNGate`. It takes a catalog's identity (`#IdentityPackage`), a member's kind and name, and the key, package path and catalog version the catalog authored. It SHALL state each authored value a second time as the identity implies it, so that unification does the comparing. A publishing tool SHALL unify every member against it and show the author CUE's own error.

#### Scenario: A conformant resource passes

- **WHEN** the identity is `opmodel.dev/catalogs/opm@v1` at version `1.2.0`, and a resource named `backup` authors the path `opmodel.dev/catalogs/opm/resources/v1beta1`, the catalog version `1.2.0`, the API version `v1beta1` and the key `opmodel.dev/catalogs/opm/resources/backup@v1beta1`
- **THEN** unification succeeds

#### Scenario: A refusal is CUE's own error

- **WHEN** a publish run meets a member that disagrees with the identity
- **THEN** the refusal carries the error CUE reports on the field, and no hand-written comparison text

#### Scenario: A grouped member fails on its path and its key

- **WHEN** a blueprint named `stateless-workload` with the API version `v1beta1` authors the path `opmodel.dev/catalogs/opm/blueprints/workload` and the key `opmodel.dev/catalogs/opm/blueprints/workload/stateless-workload@v1beta1`
- **THEN** unification fails on the path and on the key, and the publish refusal shows both errors

### Requirement: A member's package path sits under its catalog's

A resource, trait or blueprint SHALL author its kind prefix plus one segment equal to its own API version. A transformer SHALL author its kind prefix itself. Any other path SHALL be refused: a path under another catalog, a grouping segment, or a contract member filed flat.

#### Scenario: A contract member filed under its API version passes

- **WHEN** a trait with the API version `v1beta1` authors the path `opmodel.dev/catalogs/opm/traits/v1beta1`
- **THEN** the path is accepted

#### Scenario: A contract member filed flat is refused

- **WHEN** a resource with the API version `v1beta1` authors the path `opmodel.dev/catalogs/opm/resources`
- **THEN** unification fails on the path

#### Scenario: A grouping segment is refused

- **WHEN** a blueprint with the API version `v1beta1` authors the path `opmodel.dev/catalogs/opm/blueprints/workload`
- **THEN** unification fails on the path

#### Scenario: A path under another catalog is refused

- **WHEN** a resource authors the path `example.com/catalogs/other/resources/v1beta1` under the identity `opmodel.dev/catalogs/opm@v1`
- **THEN** unification fails on the path

#### Scenario: A transformer is filed at its prefix

- **WHEN** a transformer authors the path `opmodel.dev/catalogs/opm/transformers`
- **THEN** the path is accepted, and the path `opmodel.dev/catalogs/opm/transformers/v1` is refused

### Requirement: A member's provenance names its catalog's build

A member's authored catalog version SHALL equal the version in its catalog's identity.

#### Scenario: A stale provenance value is refused

- **WHEN** the identity's version is `1.2.0` and a member authors the catalog version `1.1.0`
- **THEN** unification fails on the catalog version, naming `1.2.0` and `1.1.0`

### Requirement: A key is built from level or build

A resource, trait or blueprint key SHALL be its kind prefix, a slash, its name, an at-sign and its own API version. A transformer key SHALL end in the catalog's build version in the same place. The filing segment SHALL NOT enter a key, and the kind segment SHALL stay.

#### Scenario: A contract keys on its API version

- **WHEN** a trait named `scaling` has the API version `v1beta1` under the identity `opmodel.dev/catalogs/opm@v1` at version `1.2.0`
- **THEN** its key must be `opmodel.dev/catalogs/opm/traits/scaling@v1beta1`

#### Scenario: A transformer keys on the build

- **WHEN** a transformer named `configmap-transformer` is in the same catalog
- **THEN** its key must be `opmodel.dev/catalogs/opm/transformers/configmap-transformer@1.2.0`

#### Scenario: A stale transformer key is refused

- **WHEN** a transformer authors a key ending in `@1.1.0` in a catalog at version `1.2.0`
- **THEN** unification fails on the key

#### Scenario: A resource and a trait of one name keep distinct keys

- **WHEN** a catalog ships a resource and a trait that are both named `backup` at `v1beta1`
- **THEN** their keys are `opmodel.dev/catalogs/opm/resources/backup@v1beta1` and `opmodel.dev/catalogs/opm/traits/backup@v1beta1`

#### Scenario: A key that carries the filing segment is refused

- **WHEN** a trait authors the key `opmodel.dev/catalogs/opm/traits/v1beta1/scaling@v1beta1`
- **THEN** unification fails on the key

### Requirement: The API version is needed by contracts only

A resource, trait or blueprint SHALL author its API version. A transformer SHALL NOT need to, because it has none. The gate SHALL NOT check the API version against the identity, since a contract level is its author's judgement and is independent of the catalog's major and release version.

#### Scenario: A transformer without an API version passes

- **WHEN** a transformer authors no API version
- **THEN** the key resolves from the build, with no error about the absent field

#### Scenario: A contract without an API version is refused

- **WHEN** a resource authors no API version and the gate is evaluated concretely
- **THEN** evaluation reports the API version as a required field that is not present

#### Scenario: A contract level is independent of the catalog version

- **WHEN** a resource with the API version `v1beta1` is in a catalog at version `1.2.0`
- **THEN** the gate accepts the API version

### Requirement: The gate covers all four member kinds

The gate SHALL accept the kinds resources, traits, blueprints and transformers, and SHALL refuse any other kind.

#### Scenario: An unknown kind is refused

- **WHEN** the kind is `components`
- **THEN** validation fails against the closed set of four kinds
