## Purpose

How an aspect becomes resources. A module transformer is the component transformer transposed: it matches an aspect and renders into the same output, in the same build.

## ADDED Requirements

### Requirement: A module transformer runs once per matched aspect

A module transformer SHALL run once for each matched pair of an aspect and a transformer, and SHALL NOT run once per component.

#### Scenario: Three components, one aspect

- **WHEN** a module with three components and one matched aspect is rendered
- **THEN** the module transformer runs once

#### Scenario: Two aspects of one kind

- **WHEN** a module carries two aspects that the same transformer matches
- **THEN** the transformer runs twice, once for each aspect

### Requirement: A module transformer outputs resources only

A module transformer's output SHALL be rendered resources and nothing else. A catalog whose module transformer produces any other output SHALL be refused at catalog validation.

#### Scenario: A transformer produces a plan

- **WHEN** a catalog publishes a module transformer whose output is not a resource
- **THEN** catalog validation fails

### Requirement: A module transformer never reads rendered output

Rendered component output SHALL NOT be an input to any module transformer. The render SHALL be one build.

#### Scenario: Aspects and components in one build

- **WHEN** a module with components and an aspect is rendered
- **THEN** the render builds the module once

#### Scenario: The transformer sees no component output

- **WHEN** a module with a component and a matched aspect is rendered
- **THEN** no object the component transformers rendered is among the module transformer's inputs

### Requirement: A render is component and aspect output

A module's rendered set SHALL be the union of its component output and its aspect output. A duplicate object identity SHALL be refused as it is today.

#### Scenario: Both kinds of output

- **WHEN** a module with components and a matched aspect is rendered
- **THEN** the rendered set holds the component objects and the aspect object

#### Scenario: A colliding identity

- **WHEN** an aspect renders an object with the identity of a component's object
- **THEN** the render fails on the duplicate identity
