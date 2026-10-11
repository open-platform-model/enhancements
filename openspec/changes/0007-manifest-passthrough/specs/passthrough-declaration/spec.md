## Purpose

How an instance declares extra raw or Kustomize manifests on the side of its module, and what a declared source can name. The core schema stays out of it.

## ADDED Requirements

### Requirement: A module cannot declare side manifests

The core schema SHALL gain no side-manifest surface, and a module SHALL have no way to declare one. A module that is valid before this capability exists SHALL stay valid, with the same render, after it.

#### Scenario: An existing module is unchanged

- **WHEN** a module valid before passthrough exists is rendered with no side manifests declared
- **THEN** it renders the same objects as before

#### Scenario: A module cannot carry a side manifest

- **WHEN** an author tries to declare a side manifest inside a module
- **THEN** the module has no field that accepts it

### Requirement: An instance declares its own side manifests

An instance SHALL declare side manifests as an optional list of sources on its own spec, separate from the module and its components. Declaring none SHALL be valid and SHALL change nothing.

#### Scenario: No list declared

- **WHEN** an instance declares no side manifests
- **THEN** it renders and applies exactly as before

#### Scenario: A list is declared

- **WHEN** an instance declares one raw source and one Kustomize source
- **THEN** the objects of both sources are part of the instance

### Requirement: A source is either raw or Kustomize

Each declared source SHALL be exactly one of a raw manifest path or a Kustomize directory. A source that names both, or neither, SHALL be rejected.

#### Scenario: A source names both

- **WHEN** a source names a raw path and a Kustomize directory
- **THEN** the declaration is rejected

#### Scenario: A source names neither

- **WHEN** a source names no raw path and no Kustomize directory
- **THEN** the declaration is rejected

### Requirement: A source path stays inside the source tree

A source path SHALL resolve inside the instance's own source tree and SHALL NOT resolve outside it. A path that escapes the tree SHALL be rejected before anything is read from it.

#### Scenario: A path climbs out of the tree

- **WHEN** a source path uses parent segments to leave the source tree
- **THEN** the instance is rejected and nothing outside the tree is read
