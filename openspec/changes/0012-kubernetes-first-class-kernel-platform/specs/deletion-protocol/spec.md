## Purpose

How OPM deletes what an instance applied: one plan, one next-action transition and one hold verdict, used by both frontends, which delete only what the plan names.

## ADDED Requirements

### Requirement: A frontend deletes only what the plan names

A frontend SHALL delete an object only when the deletion transition names that deletion as the next action, and SHALL release an instance's hold only on a release verdict.

#### Scenario: Progress needs the next action

- **WHEN** a frontend deletes an instance's objects
- **THEN** it deletes each object only after asking for the next action and receiving that deletion

#### Scenario: The hold stays until the verdict

- **WHEN** the plan is not finished or the verdict says hold
- **THEN** the frontend keeps the instance's hold

### Requirement: A skipped object is never deleted

Neither frontend SHALL delete an object the deletion plan marked as skipped.

#### Scenario: A skipped object survives

- **WHEN** the plan marks an object as skipped and the instance is deleted
- **THEN** the object remains in the cluster

### Requirement: Namespaces and CRDs are never deleted automatically

A Namespace or a CustomResourceDefinition in an instance's inventory SHALL never be deleted automatically by either frontend.

#### Scenario: A stale CRD

- **WHEN** a CustomResourceDefinition is a stale inventory entry and a prune runs
- **THEN** both frontends skip it and name the reason

#### Scenario: A Namespace in the inventory

- **WHEN** an instance with a Namespace in its inventory is deleted
- **THEN** the Namespace remains

### Requirement: Objects OPM does not own are skipped

A live object whose manager label is not an OPM runtime identity, whose instance identity differs from the deleting instance's, or whose adopt annotation is set and does not name the deleting instance SHALL be skipped by both frontends, with the reason named. When the deleting instance's identity is unknown, any adopt annotation SHALL count as naming another instance.

#### Scenario: Another tool adopted the object

- **WHEN** an object that OPM once managed now carries another manager label
- **THEN** both frontends skip it and name the reason

#### Scenario: Handed over by annotation

- **WHEN** an object's adopt annotation names another instance
- **THEN** neither frontend deletes it, whatever its instance label says

#### Scenario: Unknown deleting identity

- **WHEN** the deleting instance's identity is unknown and an object carries an adopt annotation
- **THEN** both frontends skip the object

### Requirement: The hold verdict follows policy and outcome

Whether an instance's deletion hold may be released SHALL be decided from its policy and the plan's outcome, identically for whichever frontend asks, with the reason named.

#### Scenario: Same policy and outcome, same verdict

- **WHEN** the CLI and the operator ask whether the hold of the same instance may be released, with the same policy and the same plan outcome
- **THEN** both receive the same verdict and the reason is named

### Requirement: A stored deletion state advances identically

A deletion state written out and read back SHALL advance identically to one held in memory, and advancing the same plan and state twice SHALL name the same next action.

#### Scenario: State carried across reconciles

- **WHEN** the operator stores the state and reads it back on the next reconcile
- **THEN** the next action is the one an in-memory state would name

### Requirement: A deletion plan holds only deletions and skips

A deletion plan's actions SHALL be only deletions and skips of objects in the instance's inventory, plus the hold verdict. No step a module declares SHALL run as part of it.

#### Scenario: A module declares a step

- **WHEN** a module declares a step around its deletion
- **THEN** the plan contains no such step
