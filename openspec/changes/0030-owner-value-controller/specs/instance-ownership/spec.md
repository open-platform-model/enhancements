## MODIFIED Requirements

### Requirement: A ModuleInstance records its owner

A ModuleInstance SHALL record who manages it in an optional owner field that accepts exactly two values, `cli` and `controller`. The API server SHALL reject any other value, an empty string included, and SHALL fill in no default. An instance with no owner SHALL be reconciled by the controller, as an instance owned by the controller.

#### Scenario: The two values are accepted

- **WHEN** a ModuleInstance is created with owner `cli` or with owner `controller`
- **THEN** the API server accepts it

#### Scenario: Any other value is rejected

- **WHEN** a client creates a ModuleInstance with owner `future-actor` or with an empty owner
- **THEN** the API server rejects it, so the controller never meets an unknown owner

#### Scenario: No owner is not defaulted

- **WHEN** a ModuleInstance is created with no owner
- **THEN** the API server accepts it and the stored object still has no owner
- **AND** the controller reconciles it as an instance it owns

### Requirement: The CLI sets the owner once, at creation

An instance that the CLI creates SHALL carry the owner `cli` explicitly. When the CLI writes an instance that exists, it SHALL restate the owner the instance already holds, and no CLI command SHALL move an instance between CLI and controller ownership. A controller-owned instance is therefore always one created outside the CLI.

#### Scenario: A created instance is CLI-owned

- **WHEN** the CLI applies a module as a new instance
- **THEN** the stored instance carries owner `cli`

#### Scenario: Restating keeps the owner as it was

- **WHEN** the CLI edits an existing instance whose owner is `controller`, or whose owner is absent
- **THEN** the owner is `controller`, or absent, afterwards

#### Scenario: No command moves an instance

- **WHEN** any CLI command that writes a ModuleInstance runs against an existing instance
- **THEN** the stored owner after the command equals the owner before it

### Requirement: The CLI reads ownership from the owner field

The CLI SHALL treat an instance as CLI-owned when no instance exists yet or its owner is `cli`, and as controller-owned for any other state of an existing instance, an absent owner included. Apply and delete SHALL reach the same verdict for the same instance.

#### Scenario: Owner cli is CLI-owned

- **WHEN** the CLI reads an instance whose owner is `cli`
- **THEN** it treats the instance as CLI-owned

#### Scenario: Operator and absent owners are operator-owned

- **WHEN** the CLI reads an instance whose owner is `controller`, or has no owner
- **THEN** it treats the instance as controller-owned

#### Scenario: Apply and delete agree

- **WHEN** apply and delete read the same controller-owned instance
- **THEN** apply edits its spec and delete hands its cleanup to the controller, and neither writes a resource itself

### Requirement: A hand-over to the operator is adopted

When an instance's owner changes from `cli` to `controller`, the controller's next reconcile SHALL take the normal path: register the cleanup finalizer, render, apply, prune and write the real Ready status over the acknowledgement.

#### Scenario: A flip to operator adopts the instance

- **WHEN** the owner of a CLI-owned instance that is not the controller's own is set to `controller` and the controller reconciles it
- **THEN** the cleanup finalizer is added and the instance is rendered and applied
- **AND** Ready reflects the real outcome and is no longer `ManagedExternally`
