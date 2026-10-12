## Purpose

How the updater finds CUE modules under a directory and bumps their dependencies: where it looks, which versions it may choose, how it keeps each module consistent, and what it reports.

## ADDED Requirements

### Requirement: Every module under a directory is bumped

Pointing the updater at a directory SHALL bump every CUE module found beneath it, at any depth. A maintainer SHALL NOT keep a list of module directories for any repo.

#### Scenario: A nested module is found

- **WHEN** the updater runs on a checkout where a module sits several directories down
- **THEN** that module's dependencies are bumped like those of a module near the root

#### Scenario: A new module needs no setup

- **WHEN** a repo gains a new CUE module
- **THEN** the next run bumps it with no configuration change

### Requirement: A bumped module is consistent

Each module the updater bumps SHALL be consistent after the run: a later tidy of that module SHALL change nothing.

#### Scenario: Tidy finds nothing to do

- **WHEN** a module has been bumped and a maintainer then tidies it
- **THEN** the tidy changes no file

### Requirement: Registries come from the CUE registry mapping

The registry serving each module SHALL be the one the CUE registry mapping names. The updater SHALL carry no second host-to-registry table.

#### Scenario: The mapping changes

- **WHEN** the registry mapping points a module host at a different registry
- **THEN** the next run resolves that host's modules from the new registry with no change to the updater

### Requirement: A run reports every bump

A run SHALL report an old-to-new version summary for every dependency it bumped.

#### Scenario: Two dependencies move

- **WHEN** a run bumps two dependencies
- **THEN** the summary lists each with its old and new version

#### Scenario: Nothing moves

- **WHEN** no dependency has a newer release in its major
- **THEN** the summary lists no bump

### Requirement: A bump stays inside the pinned major

An automatic update SHALL NOT change a dependency's major. The version chosen SHALL be the newest within the major the dependency key already names.

#### Scenario: A newer minor exists

- **WHEN** a dependency pinned to major 0 has two newer releases in major 0
- **THEN** the updater chooses the newest of them

#### Scenario: Only a newer major exists

- **WHEN** the newest release of a dependency is in a higher major than the one pinned
- **THEN** the updater keeps the current pin

### Requirement: A newer major is not offered

A newer major published in the same registry repository as the pinned major SHALL NOT be offered as a candidate.

#### Scenario: Majors share one registry repository

- **WHEN** a registry repository holds releases of major 0 and major 1 and the dependency names major 0
- **THEN** only releases of major 0 are candidates

### Requirement: Test-fixture modules are bumped

A CUE module under a test-fixture directory SHALL be bumped like any other module. No path SHALL be excluded from discovery.

#### Scenario: A fixture module

- **WHEN** a repo holds a module used only as a test fixture
- **THEN** the run bumps its dependencies and includes it in the summary
