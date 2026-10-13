## Purpose

That the CLI and the controller give the same result for the same declared side manifests, so an instance behaves alike from a laptop and from a controller.

## ADDED Requirements

### Requirement: Both drivers produce the same object set

The same instance declaration with the same side manifests SHALL yield the same object set whether the CLI builds and applies it or the controller reconciles it.

#### Scenario: Laptop then controller

- **WHEN** an instance with side manifests is applied from the CLI and later reconciled by the controller
- **THEN** both produce the same object set

### Requirement: A CLI build shows the side objects

The CLI's build output SHALL include passed-through objects beside the rendered ones.

#### Scenario: Build output

- **WHEN** a user builds an instance that declares a side source
- **THEN** the output contains the side objects and the rendered objects
