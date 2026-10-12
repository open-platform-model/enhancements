## Purpose

How the kernel reads the same module twice: once to render resources, once to plan steps. A module can declare what should happen around a deployment, and the render stays what it was.

## ADDED Requirements

### Requirement: Operational declarations leave the render unchanged

A module SHALL render to the same resources with and without lifecycle or workflow declarations, and the render output SHALL carry no resource derived from them.

#### Scenario: A module gains a lifecycle

- **WHEN** an author adds a lifecycle to a module that rendered before
- **THEN** the render output is identical to the output without it

#### Scenario: A module carries only a workflow

- **WHEN** a module declares a workflow and no lifecycle
- **THEN** the render holds no resource for the workflow

### Requirement: A module yields an ordered plan of steps

From the same module the render half reads, a caller SHALL obtain an ordered plan of steps for a lifecycle phase or for a named workflow. The plan SHALL hold steps, never rendered resources.

#### Scenario: A plan for a lifecycle phase

- **WHEN** a caller asks for the plan of the upgrade phase of a module
- **THEN** it receives the steps of that phase in order, and no resource

#### Scenario: A plan for a named workflow

- **WHEN** a caller asks for the plan of a workflow by name
- **THEN** it receives that workflow's steps in order

### Requirement: Operational traits attach on a named aspect

A module SHALL attach lifecycle and workflow declarations as module traits on a named aspect and nowhere else. A lifecycle or workflow declared on a component, or as a dedicated field of `#Module`, SHALL be rejected.

#### Scenario: A lifecycle on an aspect

- **WHEN** a module attaches a lifecycle trait on a named aspect
- **THEN** the module validates and the plan reads the lifecycle from that aspect

#### Scenario: A lifecycle on a component

- **WHEN** an author declares a lifecycle on a component
- **THEN** the module is rejected

### Requirement: Operational traits render no resource

A module carrying lifecycle or workflow traits SHALL render with no resource emitted for them and no missing-transformer failure.

#### Scenario: A module with both traits renders

- **WHEN** a module attaches a lifecycle and a workflow and the platform has no transformer for either
- **THEN** the render succeeds and reports no missing transformer
