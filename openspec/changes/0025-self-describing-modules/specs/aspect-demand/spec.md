## Purpose

How a platform reports what a module asks for and nobody handles. Aspects join the contract inventory, which is stated with the inventory itself, so an unhandled demand is never silent.

## ADDED Requirements

### Requirement: A required unhandled aspect trait fails the render

An aspect that attaches a required, catalog-fulfilled module trait that no enabled module transformer handles SHALL fail the render, naming the trait and the aspect.

#### Scenario: A required trait with no transformer

- **WHEN** a module's aspect attaches a required module trait and no enabled transformer handles it
- **THEN** the render fails, naming the trait and the aspect

### Requirement: An optional unhandled aspect trait is reported

The same case for an optional module trait SHALL be reported, not refused, and SHALL name the trait and the aspect.

#### Scenario: An optional trait with no transformer

- **WHEN** a module's aspect attaches an optional module trait and no enabled transformer handles it
- **THEN** the render succeeds and reports the unhandled trait, naming the trait and the aspect

### Requirement: A disabled catalog contributes nothing

A disabled catalog SHALL contribute no module transformers and no module traits to the platform.

#### Scenario: A catalog turned off

- **WHEN** a platform disables a catalog that defines a module transformer
- **THEN** the transformer is not folded in and the inventory omits the catalog's module traits
