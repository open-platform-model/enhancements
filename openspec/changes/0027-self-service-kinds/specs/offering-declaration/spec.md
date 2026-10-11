## Purpose

The catalog trait with which a module declares what it is when offered, and the guarantee that the declaration is read by tools and never rendered.

## ADDED Requirements

### Requirement: A catalog publishes the offering trait

A catalog SHALL publish an `offering` module trait. Its spec SHALL carry the intended API group and kind and a suggested update policy.

#### Scenario: A module declares its offering

- **WHEN** a module attaches the trait on an aspect and sets a group, a kind and an update policy
- **THEN** the declaration holds those three values

### Requirement: The offering trait selects no transformer

The trait SHALL declare no match labels, so an aspect that attaches it derives an empty match set and no module transformer selects it.

#### Scenario: Nothing selects the aspect

- **WHEN** a render looks for transformers that match an aspect that attaches the trait
- **THEN** no transformer matches

### Requirement: A declaring aspect renders nothing

An aspect that attaches the trait SHALL render nothing and SHALL be carried through the render unchanged.

#### Scenario: Rendering a declaring module

- **WHEN** a module with the declaration is rendered
- **THEN** the declaration adds no resource to the output
- **AND** it is carried through the render unchanged
