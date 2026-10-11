## Purpose

How a step reaches the code that performs it. Each operation names a backend by protocol and an artifact by locator. Each frontend registers the backends it wants and refuses a plan it cannot run, before the first step.

## ADDED Requirements

### Requirement: A frontend runs only the backends it registered

A frontend SHALL run a plan through only the backends it registered. The same plan SHALL run through different backends on different frontends.

#### Scenario: One plan, two frontends

- **WHEN** the CLI and the operator register different backends for an exec step
- **THEN** each runs the step through its own backend and the plan is unchanged

### Requirement: An unregistered protocol refuses the plan

A plan holding a step whose protocol has no registered backend SHALL be refused before any step runs. The refusal SHALL name the step and the protocol.

#### Scenario: A frontend declines a backend

- **WHEN** the operator has no backend for the container build protocol and receives a plan that needs it
- **THEN** the plan is refused before the first step and the error names the step and the protocol

#### Scenario: All backends present

- **WHEN** every step's protocol has a registered backend
- **THEN** the plan passes the check and the first step may run

### Requirement: Every operation kind names its backend and artifact

Every concrete `#Op` kind SHALL carry an `@op(...)` attribute naming the backend protocol and the artifact locator. The attribute SHALL sit on the field after its value.

#### Scenario: A kind without the attribute

- **WHEN** a concrete operation kind carries no `@op` attribute
- **THEN** it is not accepted as an operation kind

### Requirement: The dispatch attribute does not change the value

The `@op` attribute SHALL NOT change the evaluated value. Exporting an operation with and without its attribute SHALL give identical data.

#### Scenario: Export with and without the attribute

- **WHEN** an operation is exported once with its attribute and once with it removed
- **THEN** the two exports are identical
