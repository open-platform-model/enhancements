## Purpose

How OPM decides, object by object, whether an apply may touch an existing live object: one verdict for both frontends, with one per-object override, the adopt annotation.

## ADDED Requirements

### Requirement: Each object gets an apply verdict

Before applying, each object SHALL receive the same verdict on both frontends. A refused object SHALL NOT be applied, and its reason SHALL be reported.

#### Scenario: A refusal is reported

- **WHEN** the verdict refuses an object
- **THEN** the frontend does not apply it and reports the reason

#### Scenario: One verdict for both

- **WHEN** the CLI and the operator judge the same object in the same state
- **THEN** they reach the same verdict

### Requirement: Ownership refusals follow the inventory

The verdict SHALL refuse an existing object outside the instance's recorded inventory that OPM does not manage, that carries another instance's identity or whose adopt annotation names another instance, unless the annotation names this instance. When the instance's identity is known, it SHALL also refuse an inventory object whose adopt annotation names another instance.

#### Scenario: An object outside the inventory

- **WHEN** an existing object outside the inventory carries another instance's identity
- **THEN** the verdict refuses it

#### Scenario: An annotated inventory object

- **WHEN** the identity is known and an inventory object's adopt annotation names another instance
- **THEN** the verdict refuses it

### Requirement: A foreign object is refused on every apply

An existing live object that is not in the instance's recorded inventory, and that OPM does not manage or that carries another instance's identity, SHALL be refused on every apply with a reason, not only the first, unless it carries the adopt annotation naming this instance's identity. Creating an object that does not exist SHALL never be refused by this guard.

#### Scenario: A later release adds a colliding object

- **WHEN** a later release of a module renders an object that already exists and is foreign
- **THEN** the apply refuses it with a reason

#### Scenario: A new object

- **WHEN** a rendered object does not exist in the cluster
- **THEN** the guard does not refuse it

### Requirement: The adopt annotation overrides ownership refusals

An object carrying the adopt annotation that names this instance's identity SHALL pass the ownership refusals and, unless it is being deleted, SHALL be applied and recorded in the instance's inventory. An annotation naming another instance SHALL override nothing.

#### Scenario: A user adopts an object

- **WHEN** the user sets the adopt annotation to the instance's identity on an existing object
- **THEN** the next apply applies it and records it

#### Scenario: An annotation for another instance

- **WHEN** the annotation names a different instance
- **THEN** this instance still refuses the object

### Requirement: No other override exists

Neither frontend SHALL offer another override of the ownership refusals. No refusal message SHALL name one, and neither frontend SHALL set the adopt annotation on the user's behalf. Installing the operator SHALL be no exception.

#### Scenario: A refusal message

- **WHEN** an apply refuses a foreign object
- **THEN** the message names no flag that overrides the refusal

### Requirement: An object being deleted is never applied

An existing object that is being deleted SHALL be refused on every apply, whether or not it is in the instance's recorded inventory. The adopt annotation SHALL NOT override that refusal.

#### Scenario: A terminating object

- **WHEN** a rendered object exists and is terminating
- **THEN** the apply refuses it, even with the adopt annotation set

### Requirement: A ModulePackage keeps its instance identity

A ModulePackage SHALL carry its instance identity in its status across reconciles, and the guard SHALL protect the objects it owns as it protects a ModuleInstance's. A ModulePackage created before the field existed SHALL gain it with no change to its spec.

#### Scenario: An older ModulePackage

- **WHEN** the operator reconciles a ModulePackage that has no recorded identity
- **THEN** it records the identity in status and leaves the spec unchanged

### Requirement: An annotation for another instance is refused

When the instance's identity is known, an existing object whose adopt annotation names another instance SHALL be refused, inside the inventory or outside it. An inventory object SHALL be refused as adopted elsewhere. An object outside the inventory SHALL be refused as foreign when OPM does not manage it or its identity label names neither this instance nor the annotated one, and as adopted elsewhere otherwise.

#### Scenario: An inventory object adopted by another instance

- **WHEN** the annotation of an inventory object names another instance
- **THEN** the object is refused as adopted elsewhere

#### Scenario: The label alone is not enough

- **WHEN** an object in the inventory carries another instance's identity label but no adopt annotation
- **THEN** the instance goes on applying it

#### Scenario: An unmanaged annotated object outside the inventory

- **WHEN** an object that OPM does not manage, outside the inventory, carries an annotation naming another instance
- **THEN** it is refused as foreign, not as adopted elsewhere

### Requirement: An object adopted elsewhere is let go

The instance SHALL NOT apply or delete an object refused as adopted elsewhere, SHALL drop it from the inventory it records next, and SHALL go on applying its other objects and report the reason. Installing the operator SHALL refuse before it changes anything when it needs such an object.

#### Scenario: A hand-over between two instances

- **WHEN** another instance adopts an object the first still records
- **THEN** the first instance drops it, applies its other objects and never deletes the object

#### Scenario: A needed object on install

- **WHEN** installing the operator needs an object annotated for another instance
- **THEN** the install refuses and changes nothing

### Requirement: An unknown identity counts every annotation as foreign

When the instance's identity is unknown, an object in its inventory SHALL NOT be refused for ownership. Outside the inventory, any adopt annotation SHALL count as naming another instance, because an unknown identity is never the one an annotation names.

#### Scenario: Identity not yet known

- **WHEN** the instance's identity is unknown and an object outside its inventory carries an adopt annotation
- **THEN** the apply refuses the object

#### Scenario: An inventory object with an unknown identity

- **WHEN** the instance's identity is unknown and an object in its inventory carries another instance's identity label
- **THEN** the apply does not refuse it for ownership
