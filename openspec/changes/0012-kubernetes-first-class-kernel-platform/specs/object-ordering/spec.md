## Purpose

In what order OPM applies and deletes the objects of an instance: one kind-class order, a fact about Kubernetes, shared by both frontends and independent of the module.

## ADDED Requirements

### Requirement: Frontends order objects by kind class

The CLI and the operator SHALL order the same set of objects by kind class identically, for apply and for delete, and each SHALL submit objects in the library's order. An engine's own staging MAY refine the order within a stage and SHALL NOT contradict it.

#### Scenario: A CRD before its resources

- **WHEN** a render holds a CustomResourceDefinition and resources of its kind
- **THEN** both frontends apply the definition before the resources

#### Scenario: One delete order

- **WHEN** the CLI and the operator delete the same set of objects
- **THEN** both submit the deletions in the same kind-class order

#### Scenario: Engine staging

- **WHEN** an engine sorts objects within a stage
- **THEN** no object is submitted ahead of one the library order puts before it

### Requirement: Kind-class order changes once

A change to kind-class order SHALL be made once, in the library, and SHALL reach both frontends through a library version bump.

#### Scenario: A new weight

- **WHEN** the library moves a kind in the order
- **THEN** both frontends follow it after bumping the library version, and neither edits a table of its own

### Requirement: Order does not depend on the module

For the same set of objects, the library's apply and delete order SHALL be the same whichever module rendered them. The library SHALL add no module-specific ordering.

#### Scenario: Two modules, one set of kinds

- **WHEN** two modules render the same set of kinds
- **THEN** the order of those kinds is the same for both
