## Purpose

How rendered Kubernetes objects are held to the upstream definitions, and that the suite also exercises the catalog's own check.

## ADDED Requirements

### Requirement: Rendered objects satisfy their upstream definition

Every object a catalog transformer renders SHALL satisfy the upstream Kubernetes CUE definition chosen by the object's own API version and kind.

#### Scenario: A rendered object conforms

- **WHEN** a transformer renders a Deployment
- **THEN** the object satisfies the upstream definition for its API version and kind

#### Scenario: A field the definition does not allow

- **WHEN** a transformer renders an object with a field its upstream definition does not allow
- **THEN** the object does not conform and the check reports it

### Requirement: The suite exercises the catalog's upstream unification

The conformance suite SHALL also exercise the catalog's in-module unification with the upstream definitions.

#### Scenario: The suite runs

- **WHEN** the suite runs
- **THEN** it exercises the catalog's in-module unification with the upstream definitions
