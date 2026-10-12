## Purpose

Where the Kubernetes custom resources of OPM are authored, and what comes from that definition. Core is the one place a person writes a custom resource. The manifest and the API types are generated from it.

## ADDED Requirements

### Requirement: A custom resource has one authored definition

Each of the `ModuleInstance`, `ModulePackage` and `Platform` custom resources SHALL have exactly one authored definition, in the published core module. Its CRD manifest and its API types SHALL be generated from that definition, and SHALL NOT be edited by hand.

#### Scenario: A field added in core reaches both outputs

- **WHEN** a field is added to the core definition of a resource and the outputs are regenerated
- **THEN** the manifest and the API types both carry the field, with no hand edit

#### Scenario: Generation reads the published module

- **WHEN** the outputs are generated
- **THEN** they come from the published core module, the one the kernel loads, not from a source checkout

### Requirement: A generated schema rejects what core rejects

The schema of a generated CRD SHALL be structural, and it SHALL reject at admission any object that the core definition rejects at evaluation. The rejection SHALL name the offending field.

#### Scenario: A value of the wrong shape

- **WHEN** core requires the instance values to be an object, and an instance is applied with a list for its values
- **THEN** the API server rejects it at admission and names the values field

#### Scenario: The cluster accepts the manifest

- **WHEN** a generated CRD is applied to a cluster
- **THEN** the API server accepts its schema as structural

### Requirement: Generation changes no resource

A resource SHALL serialise identically before and after generation replaces the hand-written artefacts. No field shape, validation or API version SHALL change.

#### Scenario: An existing object stays valid

- **WHEN** an object that the shipped CRD admits is applied under the generated CRD
- **THEN** it is admitted unchanged

#### Scenario: The generated manifest matches the shipped one

- **WHEN** a generated manifest is compared with the hand-written manifest it replaces
- **THEN** every field has the same shape and validations, and every version the same API version, apart from formatting
