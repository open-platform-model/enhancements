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

### Requirement: Delete reports the outcome that occurred

Whether the controller removes the workloads of a deleted instance SHALL follow the instance's prune setting, which has no default and which the CLI does not write. Without it, the controller removes the instance and leaves the workloads running. The CLI SHALL report that outcome and name the remedy, and SHALL NOT claim a prune it has not established.

#### Scenario: Delete without prune reports the orphaning

- **WHEN** delete removes a controller-owned instance whose prune setting is unset
- **THEN** the CLI reports that the workloads were left running and names how to have the controller remove them
- **AND** it does not report that any resource was pruned

#### Scenario: Delete with prune reports the finished cleanup

- **WHEN** delete removes a controller-owned instance whose prune setting is true
- **THEN** the CLI reports that the controller finished its cleanup of the instance's workloads

## REMOVED Requirements

### Requirement: The operator leaves a CLI-owned instance alone

**Reason**: The requirement or a scenario name uses the old owner value or the old name of the controller.

**Migration**: Replaced by "The controller leaves a CLI-owned instance alone"

### Requirement: The operator releases a CLI-owned instance's leftover finalizer

**Reason**: The requirement or a scenario name uses the old owner value or the old name of the controller.

**Migration**: Replaced by "The controller releases a CLI-owned instance's leftover finalizer"

### Requirement: The operator acknowledges a CLI-owned instance once

**Reason**: The requirement or a scenario name uses the old owner value or the old name of the controller.

**Migration**: Replaced by "The controller acknowledges a CLI-owned instance once"

### Requirement: An unconfirmed operator edit fails the apply

**Reason**: The requirement or a scenario name uses the old owner value or the old name of the controller.

**Migration**: Replaced by "An unconfirmed controller edit fails the apply"

### Requirement: Apply refuses modules the operator cannot fetch

**Reason**: The requirement or a scenario name uses the old owner value or the old name of the controller.

**Migration**: Replaced by "Apply refuses modules the controller cannot fetch"

### Requirement: The CLI reads ownership from the owner field

**Reason**: The requirement or a scenario name uses the old owner value or the old name of the controller.

**Migration**: Replaced by "The CLI reads ownership from the stored owner"

### Requirement: Apply edits an operator-owned instance's spec only

**Reason**: The requirement or a scenario name uses the old owner value or the old name of the controller.

**Migration**: Replaced by "Apply edits a controller-owned instance's spec only"

### Requirement: A dry run previews the spec edit only

**Reason**: The requirement or a scenario name uses the old owner value or the old name of the controller.

**Migration**: Replaced by "A dry run previews only the spec edit"

### Requirement: Operator-owned delete hands cleanup to the finalizer

**Reason**: The requirement or a scenario name uses the old owner value or the old name of the controller.

**Migration**: Replaced by "Controller-owned delete hands cleanup to the finalizer"

### Requirement: A hand-over to the operator is adopted

**Reason**: The requirement or a scenario name uses the old owner value or the old name of the controller.

**Migration**: Replaced by "A hand-over to the controller is adopted"

### Requirement: Data deletion does not change an operator-owned instance

**Reason**: The requirement or a scenario name uses the old owner value or the old name of the controller.

**Migration**: Replaced by "Data deletion does not change a controller-owned instance"

## ADDED Requirements

### Requirement: The controller leaves a CLI-owned instance alone

When an instance's owner is `cli`, the controller SHALL return from its reconcile without rendering, applying, pruning or running deletion cleanup, and SHALL NOT add its cleanup finalizer. It SHALL decide this before it registers the finalizer, so an instance that was always CLI-owned never carries one.

#### Scenario: A live CLI-owned instance is not reconciled

- **WHEN** the controller reconciles an instance with owner `cli` that is not being deleted
- **THEN** nothing is rendered or applied and the cleanup finalizer is not added
- **AND** the controller does not requeue it for work

#### Scenario: Deleting a CLI-owned instance prunes nothing

- **WHEN** the controller reconciles a CLI-owned instance that is being deleted and has no cleanup finalizer
- **THEN** it prunes nothing and does not hold the deletion

### Requirement: The controller releases a CLI-owned instance's leftover finalizer

An instance can carry the controller's cleanup finalizer from when the controller owned it. When such an instance is being deleted, the controller SHALL remove the finalizer, SHALL NOT delete any object in the instance's inventory whatever its prune setting, and SHALL write no status. On a CLI-owned instance that is not being deleted it SHALL change no finalizer.

#### Scenario: Deletion releases the finalizer without a prune

- **WHEN** the controller reconciles a CLI-owned instance that is being deleted, with prune true, a non-empty inventory and the cleanup finalizer
- **THEN** the finalizer is removed and the instance is deleted
- **AND** every object in the inventory still exists

#### Scenario: A live instance keeps a leftover finalizer

- **WHEN** the controller reconciles a CLI-owned instance that carries the finalizer and is not being deleted
- **THEN** the finalizer stays and the instance is acknowledged as managed externally

### Requirement: The controller acknowledges a CLI-owned instance once

On a CLI-owned instance that is not being deleted, the controller SHALL set Ready to Unknown with reason `ManagedExternally`, remove the Reconciling, Stalled and Healthy conditions, and write no other status field: not the observed generation, the inventory, the last-applied digests, the instance UUID or anything else the CLI writes. A repeated acknowledgement SHALL change nothing.

#### Scenario: The acknowledgement is set

- **WHEN** the controller reconciles a CLI-owned instance that is not being deleted
- **THEN** Ready is Unknown with reason `ManagedExternally`
- **AND** the Reconciling, Stalled and Healthy conditions are absent

#### Scenario: CLI-written status is untouched

- **WHEN** the instance carries CLI-written inventory, last-applied digests and instance UUID
- **THEN** after the reconcile those fields and the observed generation are unchanged

#### Scenario: Acknowledging again is a no-op

- **WHEN** the controller reconciles an instance that already carries the acknowledgement
- **THEN** the status patch is empty and no condition transition time changes

### Requirement: An unconfirmed controller edit fails the apply

When the controller does not report the edit Ready within the bound, or reports it not Ready, the apply SHALL exit 1. It SHALL say that the spec change is written and the controller will retry, and SHALL name how to investigate. When no read during the wait returns the instance and one failed other than by not being found, the apply SHALL instead exit 1 with the read error.

#### Scenario: An edit the controller does not confirm in time

- **WHEN** the controller does not report the edit Ready within the bound
- **THEN** the command exits 1, says the spec change is written and the controller will retry, and names how to investigate

#### Scenario: An edit the controller reports not Ready

- **WHEN** the controller reports Ready False for the edited generation
- **THEN** the command exits 1 with the same statement and names the controller's outcome

### Requirement: Apply refuses modules the controller cannot fetch

Apply SHALL refuse, before it writes anything, a module that resolves from local bytes (a local directory or a local replacement) and a build with no complete module path and version, because the controller fetches only published modules. The refusal for local bytes SHALL name publishing as the remedy.

#### Scenario: A local module is refused

- **WHEN** apply targets a controller-owned instance and its module resolves from a local directory or a local replacement
- **THEN** the CLI refuses, names publishing as the remedy, and writes nothing

#### Scenario: An incomplete module reference is refused

- **WHEN** apply targets a controller-owned instance and the build has no module path or no version
- **THEN** the CLI refuses as a validation failure and writes nothing

### Requirement: The CLI reads ownership from the stored owner

The CLI SHALL treat an instance as CLI-owned when no instance exists yet or its owner is `cli`, and as controller-owned for any other state of an existing instance, an absent owner included. Apply and delete SHALL reach the same verdict for the same instance.

#### Scenario: Owner cli is CLI-owned

- **WHEN** the CLI reads an instance whose owner is `cli`
- **THEN** it treats the instance as CLI-owned

#### Scenario: Controller and absent owners are controller-owned

- **WHEN** the CLI reads an instance whose owner is `controller`, or has no owner
- **THEN** it treats the instance as controller-owned

#### Scenario: Apply and delete agree

- **WHEN** apply and delete read the same controller-owned instance
- **THEN** apply edits its spec and delete hands its cleanup to the controller, and neither writes a resource itself

### Requirement: Apply edits a controller-owned instance's spec only

Apply SHALL, for a controller-owned instance, write only the module reference and the values, restating the owner the instance holds. It SHALL then wait a bounded time for the controller to reconcile that edit and report the controller's Ready outcome. The CLI SHALL NOT render and apply resources, prune or write status in this mode.

#### Scenario: A values edit writes only the values

- **WHEN** apply updates only the values of a controller-owned instance and the module is the one it already references
- **THEN** only the values in its spec change, and its module reference, its other spec fields and its owner are as before

#### Scenario: The controller's outcome is reported

- **WHEN** apply edits a controller-owned instance
- **THEN** the CLI waits for the controller's reconcile and reports its Ready outcome
- **AND** it applies and prunes no resource and writes no status field

### Requirement: A dry run previews only the spec edit

A dry run of apply against a controller-owned instance SHALL read the instance's owner, run the same refusals as a real apply, write nothing, and report the spec edit it would make. It SHALL say that the CLI applies and prunes nothing itself in this mode, and SHALL NOT preview a render and apply of resources.

#### Scenario: A dry run on a controller-owned instance

- **WHEN** a dry run targets a controller-owned instance
- **THEN** the output says it would set the module reference and update the values, then wait for the controller
- **AND** no resource is previewed as applied or pruned

#### Scenario: A dry run refuses what a real apply refuses

- **WHEN** a dry run targets a controller-owned instance with a module that resolves from local bytes
- **THEN** the CLI refuses as the real apply does

### Requirement: Controller-owned delete hands cleanup to the finalizer

Delete SHALL, for a controller-owned instance, delete the ModuleInstance and leave the cleanup of its workloads to the controller's finalizer, wait a bounded time and report the completion. Before it deletes, the CLI SHALL check that the controller is ready and SHALL refuse when it is not, because a finalizer with no running controller holds the instance in deletion.

#### Scenario: Delete with a ready controller

- **WHEN** delete targets a controller-owned instance and the controller is ready
- **THEN** the CLI deletes the ModuleInstance, waits for the finalizer to finish and reports the removal

#### Scenario: Delete refused while the controller is not ready

- **WHEN** the controller is not ready and delete targets a controller-owned instance
- **THEN** the CLI refuses and explains that the finalizer would hold the instance in deletion without a running controller
- **AND** it deletes nothing

### Requirement: A hand-over to the controller is adopted

When an instance's owner changes from `cli` to `controller`, the controller's next reconcile SHALL take the normal path: register the cleanup finalizer, render, apply, prune and write the real Ready status over the acknowledgement.

#### Scenario: A flip to controller adopts the instance

- **WHEN** the owner of a CLI-owned instance that is not the controller's own is set to `controller` and the controller reconciles it
- **THEN** the cleanup finalizer is added and the instance is rendered and applied
- **AND** Ready reflects the real outcome and is no longer `ManagedExternally`

### Requirement: Data deletion does not change a controller-owned instance

On a controller-owned instance the data-deletion option SHALL NOT change what the controller does and SHALL NOT fail the command. Apply SHALL print a warning that says so, names the data-policy setting of the instance as the one a controller with that field obeys for PersistentVolumeClaims, and says that an older controller deletes them. The apply SHALL go on as without the option.

#### Scenario: Data deletion on a controller-owned instance

- **WHEN** apply runs with data deletion for a controller-owned instance
- **THEN** it prints the warning and goes on as without the option
