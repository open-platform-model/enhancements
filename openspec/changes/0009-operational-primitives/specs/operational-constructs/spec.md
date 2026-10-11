## Purpose

The four constructs an author uses to declare operations: the step, the reusable composition, the state-bound flow and the on-demand flow. The set of step kinds is closed and owned by OPM; composition is open.

## ADDED Requirements

### Requirement: Four core constructs declare operations

A module or catalog author SHALL declare operational intent with `#Op`, `#Action`, `#Lifecycle` and `#Workflow` from the published core module, not from a catalog.

#### Scenario: A module imports the constructs from core

- **WHEN** a module declares a lifecycle and imports only the core module
- **THEN** the module validates with no catalog involved

### Requirement: Authors compose operation kinds but cannot add one

An author SHALL compose existing `#Op` kinds and SHALL NOT declare a new one. An `opKind` outside the vocabulary OPM owns SHALL be rejected.

#### Scenario: An unknown kind

- **WHEN** an author declares a step with a kind OPM does not own
- **THEN** validation rejects the step

#### Scenario: Known kinds compose freely

- **WHEN** an author places a wait step and an exec step in one action
- **THEN** the action validates

### Requirement: An action identity derives from its coordinates

An `#Action` SHALL carry an identity derived from its module path, name and version. An identity authored independently of those three SHALL be rejected.

#### Scenario: A derived identity

- **WHEN** an action sets a module path, a name and a version
- **THEN** its identity is built from those three

#### Scenario: An authored identity

- **WHEN** an author sets an identity that differs from the derived one
- **THEN** validation rejects the action

### Requirement: A workflow runs only when invoked by name

A `#Workflow` SHALL run only when a caller invokes it by name. No state transition SHALL trigger it.

#### Scenario: An upgrade does not run a workflow

- **WHEN** a module with a workflow is installed, upgraded or removed
- **THEN** the workflow does not run

#### Scenario: An explicit invocation

- **WHEN** a caller invokes a workflow by name
- **THEN** the plan for that workflow is produced

### Requirement: A step orders itself only against siblings

A step's ordering edges SHALL name sibling steps in the same map. An edge that names anything else SHALL be rejected.

#### Scenario: A sibling edge

- **WHEN** a step names another step of the same map as its predecessor
- **THEN** the flow validates

#### Scenario: A foreign edge

- **WHEN** a step names a step that is not in its map
- **THEN** validation rejects it
