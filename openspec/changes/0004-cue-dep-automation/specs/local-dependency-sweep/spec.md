## Purpose

How a developer bumps CUE dependencies by hand, and how that path relates to the scheduled job: both use one implementation.

## ADDED Requirements

### Requirement: Local and scheduled runs share one implementation

The local workspace sweep and the scheduled CI job SHALL run one implementation. The same tree bumped by either SHALL give the same result.

#### Scenario: Same tree, two callers

- **WHEN** a developer and the scheduled job each run on the same tree
- **THEN** both produce the same bumped dependencies

### Requirement: The local sweep keeps its invocation

A developer SHALL invoke the local sweep the same way as before this change. Only its implementation SHALL change.

#### Scenario: The existing command

- **WHEN** a developer runs the workspace update task as before
- **THEN** the task bumps dependencies without new arguments or setup steps
