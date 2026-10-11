## Purpose

The fixed set of phases a lifecycle binds steps to. The closed set lets an operator reason about, and drive, state transitions.

## ADDED Requirements

### Requirement: A lifecycle accepts exactly nine phases

A `#Lifecycle` SHALL accept exactly the phases pre-install, install, post-install, pre-upgrade, upgrade, post-upgrade, pre-uninstall, uninstall and post-uninstall. It SHALL reject any other phase key at module validation.

#### Scenario: A known phase

- **WHEN** a lifecycle binds steps to the pre-upgrade phase
- **THEN** the module validates

#### Scenario: An invented phase

- **WHEN** a lifecycle binds steps to a phase named pre-restart
- **THEN** module validation rejects it

### Requirement: Steps in a phase run in authored order

The steps of one lifecycle phase SHALL run in the order the author wrote them.

#### Scenario: Two steps in a phase

- **WHEN** a phase lists a wait step and then a migration step
- **THEN** the plan puts the wait step first

### Requirement: An absent phase does nothing

A phase that is absent or empty SHALL be a no-op, and the transition SHALL proceed with nothing to run.

#### Scenario: A module with no upgrade phase

- **WHEN** a module with a lifecycle but no upgrade phase is upgraded
- **THEN** the upgrade proceeds and no step runs
