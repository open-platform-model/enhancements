## Purpose

State how a published module or catalog declares who it is. An artifact carries its complete CUE module path with a major, the primitives of a catalog carry a major-free package path, one construct splits a module path, and a committed identity file holds the two values a release moves. Identity distinguishes majors and nothing finer: a release keeps an artifact's identity, a major bump changes it.

## ADDED Requirements

### Requirement: An artifact declares its complete module path

A `#Module` and a `#Catalog` SHALL declare a module path that ends in a major suffix, `@v` and digits. The value SHALL be the same string that the CUE module file, the registry coordinate and an import statement carry. Path segments MAY hold underscores, because the leaf is the module's snake_case name. Non-leaf segments MAY hold hyphens, so that an organisation such as `github.com/open-platform-model` stays expressible.

#### Scenario: A module path with a major suffix is accepted

- **WHEN** a module declares the path `opmodel.dev/modules/postgres@v2`
- **THEN** the value validates

#### Scenario: A module path without a major suffix is refused

- **WHEN** a module declares the path `opmodel.dev/modules/postgres`
- **THEN** validation fails against the module path type

#### Scenario: Underscores are legal in a module path leaf

- **WHEN** a module declares the path `opmodel.dev/modules/cert_manager@v1`
- **THEN** the value validates

#### Scenario: Hyphens stay legal in non-leaf segments

- **WHEN** a catalog declares the path `github.com/open-platform-model/catalogs/opm@v1`
- **THEN** the value validates

### Requirement: A primitive declares a package path

A `#Resource`, a `#Trait`, a `#Blueprint` and a `#ComponentTransformer` SHALL declare a package path that carries no major suffix. A primitive path that carries a major SHALL be refused. The package path set SHALL be the module path set without the major.

#### Scenario: A primitive path without a major is accepted

- **WHEN** a resource declares the path `opmodel.dev/catalogs/opm/resources/v1beta1`
- **THEN** the value validates

#### Scenario: A transformer path without a major is accepted

- **WHEN** a transformer declares the path `opmodel.dev/catalogs/opm/transformers`
- **THEN** the value validates

#### Scenario: A primitive path that carries a major is refused

- **WHEN** a resource declares the path `opmodel.dev/catalogs/opm/resources@v1`
- **THEN** validation fails against the package path type

### Requirement: A module path decomposes in exactly one place

The schema SHALL provide one construct, `#ArtifactRef`, that splits a module path into a major-free registry path, a major and an import path that is the module path verbatim. No other construct SHALL split a module path. The registry path SHALL carry no major, and the major SHALL be `v` followed by digits.

#### Scenario: A module path splits into repository and major

- **WHEN** `#ArtifactRef` is given the path `opmodel.dev/modules/postgres@v2`
- **THEN** the registry path is `opmodel.dev/modules/postgres`, the major is `v2` and the import path is `opmodel.dev/modules/postgres@v2`

#### Scenario: A malformed major is refused

- **WHEN** `#ArtifactRef` is given a path whose suffix is not `v` followed by digits
- **THEN** validation fails

### Requirement: A module exposes its major-free registry path

A `#Module` SHALL expose the registry path of its module path, read through the one decomposition. The registry path SHALL be the OCI repository the module's versions are published under. Every major of one module SHALL share one registry path.

#### Scenario: Two majors share one registry path

- **WHEN** two modules declare `opmodel.dev/modules/postgres@v2` and `opmodel.dev/modules/postgres@v3`
- **THEN** both expose the registry path `opmodel.dev/modules/postgres`

### Requirement: An artifact's FQN is its module path

A `#Module` and a `#Catalog` SHALL have an `fqn` equal to their module path, typed as a module path. The `fqn` SHALL NOT interpolate the name or the version. The schema SHALL define no separate key type for a module or a catalog.

#### Scenario: A module's FQN is its path verbatim

- **WHEN** a module declares the path `opmodel.dev/modules/postgres@v2`, the name `postgres` and the version `2.4.1`
- **THEN** its `fqn` is `opmodel.dev/modules/postgres@v2`, with neither the name segment nor the version added

#### Scenario: A version in the FQN is refused

- **WHEN** a module also sets its `fqn` to `opmodel.dev/modules/postgres@2.4.1`
- **THEN** validation fails with conflicting values

### Requirement: Module identity distinguishes majors and nothing finer

A module's `uuid` SHALL be derived from its `fqn` and the OPM namespace. Because the `fqn` is the module path, the `uuid` SHALL stay equal when only the version changes. The `uuid` SHALL change when the major of the path changes.

#### Scenario: A release does not move the module UUID

- **WHEN** two modules differ only in version, `2.4.1` and `2.9.9`, under one module path
- **THEN** their `fqn` values are equal and their `uuid` values are equal

#### Scenario: A major bump moves the module UUID

- **WHEN** two modules differ only in the major of their path, `@v2` and `@v3`
- **THEN** their `uuid` values differ

### Requirement: A module's name has one spelling

A `#Module` name SHALL be snake_case, and the leaf of its registry path SHALL equal it. Only the leaf SHALL be constrained. A kebab-case module name SHALL be refused. The schema SHALL offer no second spelling of a module name.

#### Scenario: A name that matches the path leaf is accepted

- **WHEN** a module declares the name `cert_manager` and the path `opmodel.dev/modules/cert_manager@v1`
- **THEN** the value validates

#### Scenario: A name that disagrees with the path leaf is refused

- **WHEN** a module declares the name `postgres` and the path `opmodel.dev/modules/mysql@v1`
- **THEN** validation fails on the leaf

#### Scenario: A kebab-case module name is refused

- **WHEN** a module declares the name `cert-manager`
- **THEN** validation fails against the snake_case name type

#### Scenario: A module name has no second spelling

- **WHEN** a module declares the name `cert_manager`
- **THEN** its metadata `name` and its `module.opmodel.dev/name` label both read `cert_manager`
- **AND** no metadata field holds `cert-manager` or another spelling of the name

### Requirement: Catalog primitives keep kebab-case names

A `#Resource`, a `#Trait` and a `#Blueprint` SHALL keep a kebab-case name. They are not CUE packages, so the module rule that a name is the path leaf does not apply to them.

#### Scenario: A kebab-case primitive name is accepted

- **WHEN** a resource declares the name `config-maps`
- **THEN** the name validates

### Requirement: A module declares a keyless version

A `#Module` SHALL declare a `version` typed as a SemVer string. The version SHALL NOT be an input to the `fqn` or the `uuid`. The version SHALL be the source of the module's version label.

#### Scenario: The declared version is present and keyless

- **WHEN** a module declares the version `2.4.1`
- **THEN** its version label is `2.4.1`, and neither the `fqn` nor the `uuid` depends on it

### Requirement: The schema asserts no version-path agreement

Neither a `#Module` nor a `#Catalog` SHALL assert that its version's major equals its path's major, and neither SHALL expose a version-major field. That relation is asserted only by the identity package. The rule pins an accepting behaviour on purpose, so that restoring the assertion reads as a change.

#### Scenario: A module whose version major disagrees with its path is accepted

- **WHEN** a module declares the path `opmodel.dev/modules/postgres@v2` and the version `3.0.0`
- **THEN** the value validates

#### Scenario: A catalog with the same skew is accepted

- **WHEN** a catalog declares the path `opmodel.dev/catalogs/opm@v1` and the version `2.0.0`
- **THEN** the value validates

### Requirement: A catalog declares a concrete version

A `#Catalog` SHALL declare its version, typed as a SemVer string, and SHALL have no default version. A catalog with no declared version SHALL be an incomplete value that names the field. It SHALL NOT render as a catalog with a development version.

#### Scenario: An unfilled catalog version is incomplete

- **WHEN** a catalog is evaluated with no version
- **THEN** evaluation reports an incomplete value at the version field, and no `0.0.0-dev` value is supplied

### Requirement: A catalog stamps a package path on transformers

A `#Catalog` SHALL set each transformer's package path to its own major-free registry path followed by `/transformers`. It SHALL NOT append the major again. It SHALL set each transformer's catalog version to its own version.

#### Scenario: The stamped transformer path carries no major

- **WHEN** a catalog declares the path `opmodel.dev/catalogs/opm@v1` and lists a transformer
- **THEN** the transformer's path is `opmodel.dev/catalogs/opm/transformers`

#### Scenario: The transformer carries the catalog's version

- **WHEN** a catalog declares the version `1.2.0` and lists a transformer
- **THEN** the transformer's catalog version is `1.2.0`

### Requirement: The schema ships the identity-package shape

The schema SHALL export `#IdentityPackage`, the shape that an artifact's identity file must match. Modules and catalogs SHALL both use it, and a module SHALL NOT need to depend on any catalog to do so. It is a publish gate: no artifact value embeds it.

#### Scenario: A conformant identity validates

- **WHEN** an identity declares the module path `opmodel.dev/catalogs/opm@v1` and the version `1.2.0`
- **THEN** unifying it with `#IdentityPackage` succeeds

### Requirement: Two fields are authored and the rest derive

`#IdentityPackage` SHALL require two authored values, `ModulePath` typed as a module path and `Version` typed as a version. The registry path, the major, the version's major and the kind prefixes SHALL be derived and SHALL NOT be authored.

#### Scenario: The derived values follow from the two authored ones

- **WHEN** an identity declares `ModulePath` `opmodel.dev/catalogs/opm@v1` and `Version` `1.2.0`
- **THEN** the registry path is `opmodel.dev/catalogs/opm`, the major is `v1` and the version's major is `v1`

#### Scenario: A module path with no major is refused

- **WHEN** an identity declares `ModulePath` `opmodel.dev/catalogs/opm`
- **THEN** validation fails against the module path type

#### Scenario: A missing authored field is reported by name

- **WHEN** an identity declares only `ModulePath`
- **THEN** evaluation reports `Version` as a required field that is not present

### Requirement: The version's major must equal the path's major

`#IdentityPackage` SHALL derive the version's major from the first dot-separated component of `Version`, and SHALL refuse an identity whose version major differs from its path major. This is the only place in the system that asserts the relation. A prerelease suffix SHALL NOT change the derived major.

#### Scenario: An agreeing pair validates

- **WHEN** an identity declares `ModulePath` `opmodel.dev/modules/postgres@v2` and `Version` `2.4.1`
- **THEN** unification succeeds and the version's major is `v2`

#### Scenario: A disagreeing pair is refused at the derived field

- **WHEN** an identity declares `ModulePath` `opmodel.dev/modules/postgres@v2` and `Version` `3.0.0`
- **THEN** unification fails with conflicting values `v2` and `v3` on the version's major

#### Scenario: A prerelease keeps the major

- **WHEN** an identity declares `ModulePath` `opmodel.dev/catalogs/opm@v1` and `Version` `1.0.0-alpha.4`
- **THEN** the version's major is `v1`

#### Scenario: A two-digit major is read whole

- **WHEN** an identity declares `ModulePath` `opmodel.dev/modules/postgres@v10` and `Version` `10.0.0`
- **THEN** the major and the version's major are both `v10`

### Requirement: The identity package imports nothing from core

`#IdentityPackage` SHALL use only CUE builtins. An identity file SHALL NOT be required to import the schema, so that the file stays at the bottom of its module's import graph. A consumer SHALL validate by unifying the loaded identity with `#IdentityPackage`.

#### Scenario: An identity conforms without importing the schema

- **WHEN** an identity file declares `ModulePath` and `Version` and imports nothing from its own module or from the schema
- **THEN** a consumer that loads it and unifies it with `#IdentityPackage` succeeds

### Requirement: One path prefix per catalog member kind

`#IdentityPackage` SHALL expose a kind prefix for exactly four kinds: resources, traits, blueprints and transformers. Each SHALL be the registry path plus one segment, with no major. The set SHALL be enumerated, so that each prefix is reachable by name.

#### Scenario: Each prefix is reachable by name

- **WHEN** an identity declares `ModulePath` `opmodel.dev/catalogs/opm@v1`
- **THEN** the resources prefix is `opmodel.dev/catalogs/opm/resources` and the blueprints prefix is `opmodel.dev/catalogs/opm/blueprints`

#### Scenario: No prefix carries a major

- **WHEN** an identity declares `ModulePath` `opmodel.dev/catalogs/opm@v1`
- **THEN** none of the four prefixes contains `@`

### Requirement: The identity file is committed with real values

An artifact SHALL keep its identity in a committed, visible identity file with its real module path and version. The two authored fields SHALL be found by the names the schema fixes. An unfilled field SHALL be an absent value that names the field, never a placeholder.

#### Scenario: A renamed authored field is refused

- **WHEN** an identity file declares `Path` in place of `ModulePath`
- **THEN** unification with `#IdentityPackage` fails

