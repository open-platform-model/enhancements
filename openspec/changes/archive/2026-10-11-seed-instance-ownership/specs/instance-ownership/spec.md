## Purpose

Define how a ModuleInstance records whether the CLI or the operator owns it, and what each side may do with an instance the other owns. One owner acts on an instance at a time: the CLI never reconciles an operator-owned instance, and the operator never reconciles a CLI-owned one. It also states how the CLI's apply and prune treat a resource the instance does not own: what stops the apply, what the dry run shows, and what the prune leaves behind.

## ADDED Requirements

### Requirement: A ModuleInstance records its owner

A ModuleInstance SHALL record who manages it in an optional owner field that accepts exactly two values, `cli` and `operator`. The API server SHALL reject any other value, an empty string included, and SHALL fill in no default. An instance with no owner SHALL be reconciled by the operator, as an instance owned by the operator.

#### Scenario: The two values are accepted

- **WHEN** a ModuleInstance is created with owner `cli` or with owner `operator`
- **THEN** the API server accepts it

#### Scenario: Any other value is rejected

- **WHEN** a client creates a ModuleInstance with owner `future-actor` or with an empty owner
- **THEN** the API server rejects it, so the operator never meets an unknown owner

#### Scenario: No owner is not defaulted

- **WHEN** a ModuleInstance is created with no owner
- **THEN** the API server accepts it and the stored object still has no owner
- **AND** the operator reconciles it as an instance it owns

### Requirement: The CLI sets the owner once, at creation

An instance that the CLI creates SHALL carry the owner `cli` explicitly. When the CLI writes an instance that exists, it SHALL restate the owner the instance already holds, and no CLI command SHALL move an instance between CLI and operator ownership. An operator-owned instance is therefore always one created outside the CLI.

#### Scenario: A created instance is CLI-owned

- **WHEN** the CLI applies a module as a new instance
- **THEN** the stored instance carries owner `cli`

#### Scenario: Restating keeps the owner as it was

- **WHEN** the CLI edits an existing instance whose owner is `operator`, or whose owner is absent
- **THEN** the owner is `operator`, or absent, afterwards

#### Scenario: No command moves an instance

- **WHEN** any CLI command that writes a ModuleInstance runs against an existing instance
- **THEN** the stored owner after the command equals the owner before it

### Requirement: The CLI reads ownership from the owner field

The CLI SHALL treat an instance as CLI-owned when no instance exists yet or its owner is `cli`, and as operator-owned for any other state of an existing instance, an absent owner included. Apply and delete SHALL reach the same verdict for the same instance.

#### Scenario: Owner cli is CLI-owned

- **WHEN** the CLI reads an instance whose owner is `cli`
- **THEN** it treats the instance as CLI-owned

#### Scenario: Operator and absent owners are operator-owned

- **WHEN** the CLI reads an instance whose owner is `operator`, or has no owner
- **THEN** it treats the instance as operator-owned

#### Scenario: Apply and delete agree

- **WHEN** apply and delete read the same operator-owned instance
- **THEN** apply edits its spec and delete hands its cleanup to the operator, and neither writes a resource itself

### Requirement: Apply edits an operator-owned instance's spec only

Apply SHALL, for an operator-owned instance, write only the module reference and the values, restating the owner the instance holds. It SHALL then wait a bounded time for the operator to reconcile that edit and report the operator's Ready outcome. The CLI SHALL NOT render and apply resources, prune or write status in this mode.

#### Scenario: A values edit writes only the values

- **WHEN** apply updates only the values of an operator-owned instance and the module is the one it already references
- **THEN** only the values in its spec change, and its module reference, its other spec fields and its owner are as before

#### Scenario: The operator's outcome is reported

- **WHEN** apply edits an operator-owned instance
- **THEN** the CLI waits for the operator's reconcile and reports its Ready outcome
- **AND** it applies and prunes no resource and writes no status field

### Requirement: An unconfirmed operator edit fails the apply

When the operator does not report the edit Ready within the bound, or reports it not Ready, the apply SHALL exit 1. It SHALL say that the spec change is written and the operator will retry, and SHALL name how to investigate. When no read during the wait returns the instance and one failed other than by not being found, the apply SHALL instead exit 1 with the read error.

#### Scenario: An edit the operator does not confirm in time

- **WHEN** the operator does not report the edit Ready within the bound
- **THEN** the command exits 1, says the spec change is written and the operator will retry, and names how to investigate

#### Scenario: An edit the operator reports not Ready

- **WHEN** the operator reports Ready False for the edited generation
- **THEN** the command exits 1 with the same statement and names the operator's outcome

### Requirement: Apply refuses modules the operator cannot fetch

Apply SHALL refuse, before it writes anything, a module that resolves from local bytes (a local directory or a local replacement) and a build with no complete module path and version, because the operator fetches only published modules. The refusal for local bytes SHALL name publishing as the remedy.

#### Scenario: A local module is refused

- **WHEN** apply targets an operator-owned instance and its module resolves from a local directory or a local replacement
- **THEN** the CLI refuses, names publishing as the remedy, and writes nothing

#### Scenario: An incomplete module reference is refused

- **WHEN** apply targets an operator-owned instance and the build has no module path or no version
- **THEN** the CLI refuses as a validation failure and writes nothing

### Requirement: A dry run previews the spec edit only

A dry run of apply against an operator-owned instance SHALL read the instance's owner, run the same refusals as a real apply, write nothing, and report the spec edit it would make. It SHALL say that the CLI applies and prunes nothing itself in this mode, and SHALL NOT preview a render and apply of resources.

#### Scenario: A dry run on an operator-owned instance

- **WHEN** a dry run targets an operator-owned instance
- **THEN** the output says it would set the module reference and update the values, then wait for the operator
- **AND** no resource is previewed as applied or pruned

#### Scenario: A dry run refuses what a real apply refuses

- **WHEN** a dry run targets an operator-owned instance with a module that resolves from local bytes
- **THEN** the CLI refuses as the real apply does

### Requirement: Operator-owned delete hands cleanup to the finalizer

Delete SHALL, for an operator-owned instance, delete the ModuleInstance and leave the cleanup of its workloads to the operator's finalizer, wait a bounded time and report the completion. Before it deletes, the CLI SHALL check that the operator is ready and SHALL refuse when it is not, because a finalizer with no running controller holds the instance in deletion.

#### Scenario: Delete with a ready operator

- **WHEN** delete targets an operator-owned instance and the operator is ready
- **THEN** the CLI deletes the ModuleInstance, waits for the finalizer to finish and reports the removal

#### Scenario: Delete refused while the operator is not ready

- **WHEN** the operator is not ready and delete targets an operator-owned instance
- **THEN** the CLI refuses and explains that the finalizer would hold the instance in deletion without a running operator
- **AND** it deletes nothing

### Requirement: Delete reports the outcome that occurred

Whether the operator removes the workloads of a deleted instance SHALL follow the instance's prune setting, which has no default and which the CLI does not write. Without it, the operator removes the instance and leaves the workloads running. The CLI SHALL report that outcome and name the remedy, and SHALL NOT claim a prune it has not established.

#### Scenario: Delete without prune reports the orphaning

- **WHEN** delete removes an operator-owned instance whose prune setting is unset
- **THEN** the CLI reports that the workloads were left running and names how to have the operator remove them
- **AND** it does not report that any resource was pruned

#### Scenario: Delete with prune reports the finished cleanup

- **WHEN** delete removes an operator-owned instance whose prune setting is true
- **THEN** the CLI reports that the operator finished its cleanup of the instance's workloads

### Requirement: The operator leaves a CLI-owned instance alone

When an instance's owner is `cli`, the operator SHALL return from its reconcile without rendering, applying, pruning or running deletion cleanup, and SHALL NOT add its cleanup finalizer. It SHALL decide this before it registers the finalizer, so an instance that was always CLI-owned never carries one.

#### Scenario: A live CLI-owned instance is not reconciled

- **WHEN** the operator reconciles an instance with owner `cli` that is not being deleted
- **THEN** nothing is rendered or applied and the cleanup finalizer is not added
- **AND** the operator does not requeue it for work

#### Scenario: Deleting a CLI-owned instance prunes nothing

- **WHEN** the operator reconciles a CLI-owned instance that is being deleted and has no cleanup finalizer
- **THEN** it prunes nothing and does not hold the deletion

### Requirement: The operator releases a CLI-owned instance's leftover finalizer

An instance can carry the operator's cleanup finalizer from when the operator owned it. When such an instance is being deleted, the operator SHALL remove the finalizer, SHALL NOT delete any object in the instance's inventory whatever its prune setting, and SHALL write no status. On a CLI-owned instance that is not being deleted it SHALL change no finalizer.

#### Scenario: Deletion releases the finalizer without a prune

- **WHEN** the operator reconciles a CLI-owned instance that is being deleted, with prune true, a non-empty inventory and the cleanup finalizer
- **THEN** the finalizer is removed and the instance is deleted
- **AND** every object in the inventory still exists

#### Scenario: A live instance keeps a leftover finalizer

- **WHEN** the operator reconciles a CLI-owned instance that carries the finalizer and is not being deleted
- **THEN** the finalizer stays and the instance is acknowledged as managed externally

### Requirement: The operator acknowledges a CLI-owned instance once

On a CLI-owned instance that is not being deleted, the operator SHALL set Ready to Unknown with reason `ManagedExternally`, remove the Reconciling, Stalled and Healthy conditions, and write no other status field: not the observed generation, the inventory, the last-applied digests, the instance UUID or anything else the CLI writes. A repeated acknowledgement SHALL change nothing.

#### Scenario: The acknowledgement is set

- **WHEN** the operator reconciles a CLI-owned instance that is not being deleted
- **THEN** Ready is Unknown with reason `ManagedExternally`
- **AND** the Reconciling, Stalled and Healthy conditions are absent

#### Scenario: CLI-written status is untouched

- **WHEN** the instance carries CLI-written inventory, last-applied digests and instance UUID
- **THEN** after the reconcile those fields and the observed generation are unchanged

#### Scenario: Acknowledging again is a no-op

- **WHEN** the operator reconciles an instance that already carries the acknowledgement
- **THEN** the status patch is empty and no condition transition time changes

### Requirement: A hand-over to the operator is adopted

When an instance's owner changes from `cli` to `operator`, the operator's next reconcile SHALL take the normal path: register the cleanup finalizer, render, apply, prune and write the real Ready status over the acknowledgement.

#### Scenario: A flip to operator adopts the instance

- **WHEN** the owner of a CLI-owned instance that is not the operator's own is set to `operator` and the operator reconciles it
- **THEN** the cleanup finalizer is added and the instance is rendered and applied
- **AND** Ready reflects the real outcome and is no longer `ManagedExternally`

### Requirement: A refusal names every refused resource

When the shared ownership verdict refuses any rendered resource, the apply SHALL list every refused resource by kind, namespace and name with its reason, SHALL say that it stopped before any change, and SHALL exit 1. Every ownership refusal SHALL name the adopt annotation and the identity to set.

#### Scenario: A foreign resource is refused

- **WHEN** a rendered resource exists without OPM management and the instance does not list it
- **THEN** the command exits 1 and names the resource, the adopt annotation and the instance's identity
- **AND** the error says that the apply stopped before any change

#### Scenario: Every refused resource is reported

- **WHEN** two rendered resources are refused
- **THEN** the output names both before the command exits 1

### Requirement: An unreadable resource stops the apply

When a rendered resource cannot be read for any reason other than not being found, the apply SHALL fail before its first write with an error that names the resource and carries the read error. The exit code SHALL be 4 when the API server denied the read, 3 when it timed out or was unavailable, and 1 otherwise. A resource that is not found, or whose kind the cluster does not serve yet, SHALL count as absent.

#### Scenario: A denied read

- **WHEN** the read of a rendered resource fails with Forbidden
- **THEN** the command exits 4 with an error naming the resource and the read error
- **AND** no rendered resource is applied

#### Scenario: A kind the cluster does not serve yet

- **WHEN** a rendered resource is of a kind the cluster does not serve yet
- **THEN** the guard counts the resource as absent and does not refuse it

### Requirement: A dry run runs the same guard

A dry run SHALL read the same resources and reach the same verdicts as the real apply, and SHALL write nothing. For each resource the real apply would refuse, it SHALL print one line with the status `would refuse` and the reason. It SHALL then stop where the real apply stops: it sends no rendered resource, prints no prune preview and exits 1, with an error that counts the refused resources and says the dry run changed nothing. A resource it cannot read SHALL fail it as it fails the real apply.

#### Scenario: A dry run previews a refusal

- **WHEN** a dry run meets a rendered resource the real apply would refuse
- **THEN** the output lists it as `would refuse` with the reason, and the command exits 1
- **AND** no resource is sent to the server

#### Scenario: A dry run fails on an unreadable resource

- **WHEN** a dry run cannot read a rendered resource because the API server denied the read
- **THEN** it fails with the real apply's error and exit code

### Requirement: A first-apply refusal explains earlier identities

When an instance has no record and a resource is refused because it carries another instance's identity, the refusal SHALL add one line. It says that when the resources are the instance's own under an earlier identity (the line names a changed module path, name or namespace, a deleted record, or an old release that recorded it elsewhere), the user annotates each resource as shown, and that nothing has to be removed first.

#### Scenario: Resources under an earlier identity

- **WHEN** a first apply meets rendered resources that carry one other instance identity
- **THEN** the refusal names each resource and the annotation to set
- **AND** it says that nothing has to be removed first when the resources are the instance's own

### Requirement: Let-go resources get a warning

When the live adopt annotation of a rendered resource names another instance, the apply SHALL print one warning that names the resource and the adopting instance and says how to take the resource back, and SHALL exit 0 when the other resources apply. A dry run SHALL print a line with the status `would skip` and the same text in place of the warning, and SHALL NOT fail.

#### Scenario: A recorded resource handed to another instance

- **WHEN** an apply renders a resource the record lists and its live adopt annotation names another instance
- **THEN** the output warns that the instance drops it, names the adopting instance and says how to take it back
- **AND** the command exits 0 when the other resources apply

#### Scenario: A dry run skips the resource

- **WHEN** a dry run meets a rendered resource whose live adopt annotation names another instance
- **THEN** the output lists it as `would skip` with a reason naming the adopting instance, and the command exits 0 when the other resources pass

### Requirement: A full let-go ends with a closing line

When every rendered resource is let go, so that the apply applies nothing, the real apply SHALL print after the warnings and the inventory write one closing line that says nothing was applied because all rendered resources are adopted by another instance, with their number. It SHALL print no success line and SHALL exit 0. A dry run in the same state SHALL print one closing line that says nothing would be applied.

#### Scenario: Every rendered resource is adopted elsewhere

- **WHEN** the live adopt annotation of each rendered resource names another instance
- **THEN** nothing is applied or deleted, and the inventory is written without those resources
- **AND** one closing line gives the reason and the number, and the command exits 0

#### Scenario: A dry run in the same state

- **WHEN** a dry run meets the same state
- **THEN** one closing line says nothing would be applied, and the command exits 0

### Requirement: A failed apply prunes nothing and records nothing

If any resource fails to apply, the apply SHALL NOT prune stale resources and SHALL NOT write the inventory record. The record stays at its previous state, so a retry converges.

#### Scenario: A partial apply failure

- **WHEN** three of five resources apply and two fail
- **THEN** no stale resource is pruned and the record is not written
- **AND** the command exits with an error

### Requirement: An unreadable record stops the apply

When the read of the instance's record fails with any error other than not found, apply SHALL stop with an error that names the instance and its namespace, carries the cause and says to check access to the record and run again. It SHALL apply, prune and write nothing, a dry run included, and SHALL say that it stopped before any change. The exit code SHALL be 4 when the read was denied, 3 when it timed out or was unavailable, and 1 otherwise. A not-found answer SHALL still mean no record exists.

#### Scenario: A denied record read

- **WHEN** apply runs and the record read fails with Forbidden
- **THEN** the command exits 4 and applies no rendered resource

#### Scenario: A dry run with an unreadable record

- **WHEN** a dry run runs and the record read fails with an internal server error
- **THEN** it fails with an error and prints no dry-run summary

#### Scenario: A missing record is a first install

- **WHEN** the record read answers not found
- **THEN** the apply proceeds as a first apply

### Requirement: No record is read from a missing namespace

When the user asks the CLI to create the namespace and it does not exist, the apply SHALL NOT read the instance's record, because none can exist there. It SHALL proceed as a first apply.

#### Scenario: A namespace that does not exist

- **WHEN** an apply that asks to create its namespace runs and the namespace does not exist
- **THEN** the command does not read the record and proceeds as a first apply

### Requirement: An empty render needs force to prune

When the render yields no resources and the previous inventory is not empty, the apply SHALL fail with an error saying that all resources would be pruned, unless the user forces it. When forced, the prune SHALL run over every previous resource under its usual rules.

#### Scenario: An empty render without force

- **WHEN** the render yields no resources and the previous inventory holds five entries
- **THEN** the command fails and says all resources would be pruned

#### Scenario: An empty render with force

- **WHEN** the render yields no resources, the previous inventory holds five ConfigMaps the instance owns, and the apply is forced
- **THEN** all five ConfigMaps are pruned after the apply

### Requirement: Pruning can be switched off

When the user switches pruning off, the apply SHALL delete no stale resource, SHALL leave them on the cluster, and SHALL still write the record with the current entries. A dry run with pruning off SHALL list no prune preview and SHALL read no stale resource.

#### Scenario: Stale resources stay

- **WHEN** the stale set holds two resources and pruning is off
- **THEN** none is deleted and the record is written with the current entries

#### Scenario: A dry run with pruning off

- **WHEN** a dry run runs with pruning off and the stale set holds two resources
- **THEN** it prints no prune preview and reads no stale resource

### Requirement: A stale claim is kept by default

The prune SHALL NOT delete a stale PersistentVolumeClaim of the core group unless the user asks for data deletion. A kept claim SHALL stay in the written inventory, so a later apply with data deletion removes it, and SHALL be listed with the status `kept` with one line that counts the kept claims and names the option. A claim no longer in the cluster SHALL leave the inventory and go unlisted. A kept claim SHALL NOT fail the apply. Data deletion together with pruning off SHALL be a usage error.

#### Scenario: A stale claim is kept

- **WHEN** the stale set holds a ConfigMap and a PersistentVolumeClaim and data deletion is not asked
- **THEN** the ConfigMap is deleted and the claim is not, the written inventory holds the claim, and the output lists it as `kept`
- **AND** the command exits 0

#### Scenario: A claim already gone

- **WHEN** the stale claim is no longer in the cluster
- **THEN** it is not listed as kept and the written inventory does not hold it

#### Scenario: Data deletion prunes the claim

- **WHEN** data deletion is asked and the stale set holds a claim
- **THEN** the claim is deleted and leaves the inventory

#### Scenario: Data deletion with pruning off

- **WHEN** both are asked
- **THEN** the command exits 1 and names both options

### Requirement: An unreadable stale claim is kept

Without data deletion, a stale PersistentVolumeClaim whose read fails other than by not being found SHALL be kept, as a claim that may still hold data. The apply SHALL keep it in the written inventory, list it as `kept` and SHALL NOT fail because of it.

#### Scenario: An unreadable claim is kept

- **WHEN** data deletion is not asked and the read of a stale claim fails with Forbidden
- **THEN** the claim is not deleted, stays in the written inventory and is listed as `kept`
- **AND** the command exits 0

### Requirement: Data deletion does not change an operator-owned instance

On an operator-owned instance the data-deletion option SHALL NOT change what the operator does and SHALL NOT fail the command. Apply SHALL print a warning that says so, names the data-policy setting of the instance as the one an operator with that field obeys for PersistentVolumeClaims, and says that an older operator deletes them. The apply SHALL go on as without the option.

#### Scenario: Data deletion on an operator-owned instance

- **WHEN** apply runs with data deletion for an operator-owned instance
- **THEN** it prints the warning and goes on as without the option

### Requirement: The prune lists what it leaves behind

A stale resource that the prune does not delete because the ownership verdict refuses it, or because its kind is protected (a Namespace or a CustomResourceDefinition), SHALL be listed as left behind with its kind, namespace and name, and with the verdict's reason where there is one. It SHALL NOT count as a failure and SHALL NOT stay in the written inventory. A resource of kind Namespace outside the core group is not protected.

#### Scenario: A stale name taken by a user's object

- **WHEN** a stale resource's live object carries no OPM management
- **THEN** the output lists it as left behind with the reason, the command exits 0 and the written inventory does not hold it

#### Scenario: A protected kind

- **WHEN** the stale set holds a Namespace and a CustomResourceDefinition
- **THEN** the output lists both as left behind and the apply does not fail because of them

#### Scenario: A Namespace kind in another group

- **WHEN** a stale resource is of kind Namespace in a group other than the core group
- **THEN** it is pruned like any other stale resource

### Requirement: The prune judges with the recorded identity

An instance's identity changes when the registry path of its module changes; a major bump alone does not change it. On the first apply after such a change the prune SHALL still delete the stale resources the instance owned under the recorded identity, and the record SHALL take the rendered identity only in the write that follows the prune.

#### Scenario: A stale resource after the module moved

- **WHEN** the module's registry path changed from `opmodel.dev/modules/postgres` to `example.com/postgres` and a stale resource's live object carries the recorded identity
- **THEN** it is deleted, and the written record holds the rendered identity and not that resource

#### Scenario: A stale resource with neither identity

- **WHEN** a stale resource's live object carries an identity equal to neither the recorded nor the rendered one
- **THEN** it is not deleted and is listed as left behind

### Requirement: A failed delete keeps its entry

When the delete of a stale resource fails for any reason other than not found, the prune SHALL go on to the remaining stale resources and the apply SHALL then write the record with the current entries plus every entry it failed to delete. The output SHALL name each such resource with its delete error and say that the next apply retries. The command SHALL exit 1 without the success line. A kept entry SHALL be stale again on the next apply.

#### Scenario: One delete is denied

- **WHEN** the stale set holds ConfigMaps `a` and `b` and the delete of `a` fails with Forbidden
- **THEN** `b` is still deleted, and the written inventory holds the entry of `a` and not of `b`
- **AND** the output names `a` with the error and the command exits 1 without the success line

### Requirement: The prune deletes only the object it read

Each prune delete SHALL carry a precondition on the UID of the object that was read, so that an object deleted and created again under the same name is not deleted. A delete the API server refuses on that precondition, and a live read that fails other than by not being found, SHALL each count as a failed delete.

#### Scenario: An object replaced after the read

- **WHEN** the API server refuses a delete because the UID precondition no longer matches
- **THEN** the resource is not reported as pruned and counts as a failed delete

#### Scenario: A denied live read

- **WHEN** the live read of a stale resource fails with Forbidden
- **THEN** the resource is not deleted and counts as a failed delete

### Requirement: A prune counts what the API server accepts

A stale resource SHALL count as pruned when the API server accepts its delete, also while a finalizer holds it, and a resource already gone SHALL count as success. When an API discovery request fails, the prune SHALL send no further request and SHALL report the resource and every resource not yet tried as failed with the discovery error. The exit code SHALL then be 4 when discovery was denied and 3 when it was unavailable.

#### Scenario: A resource held by a finalizer

- **WHEN** the delete of a stale ConfigMap is accepted and a finalizer keeps the object
- **THEN** it counts as pruned, leaves the written inventory and the command exits 0

#### Scenario: A failed discovery request

- **WHEN** the discovery request for the first stale resource's group fails with Forbidden
- **THEN** no request is sent for the second, both entries stay in the written inventory and the command exits 4

### Requirement: A dry run previews the prune

A dry run with pruning on SHALL read each stale resource and ask the same verdict, with the same identity, as the real prune, and SHALL send no delete. It SHALL list a resource the real apply deletes as `would prune`, a protected kind as `left behind`, and a claim the real apply keeps as `kept`. The preview SHALL follow the same protected-kind and data-deletion rules as the real prune.

#### Scenario: Pruned and left-behind resources are separated

- **WHEN** a dry run meets a stale ConfigMap, a Namespace and a CustomResourceDefinition
- **THEN** it lists the ConfigMap as `would prune` and the other two as `left behind`
- **AND** nothing is deleted

#### Scenario: A claim is kept

- **WHEN** a dry run meets a stale claim and data deletion is not asked
- **THEN** the claim is listed as `kept`, and with data deletion asked as `would prune`

### Requirement: A dry run explains kept stale resources

A stale resource the verdict leaves in place SHALL be listed with the verdict's reason, which names the owner: `would keep` when OPM does not manage the object or another instance owns it, `would let go` when another instance is adopting it. Neither line SHALL change the exit code, and a resource already gone SHALL be listed on no line. A resource whose read fails SHALL be listed as `cannot check` with the read error.

#### Scenario: A resource the instance does not own

- **WHEN** a dry run meets a stale ConfigMap whose live object carries another instance's identity
- **THEN** it lists `would keep` with a reason naming that identity, and exits 0

#### Scenario: A resource adopted elsewhere

- **WHEN** a stale ConfigMap's live adopt annotation names another instance
- **THEN** it is listed as `would let go` and no delete is sent

#### Scenario: A resource that cannot be checked

- **WHEN** the read of a stale ConfigMap fails with Forbidden
- **THEN** it is listed as `cannot check` with the read error, and the command exits with the code the real apply exits with after a failed prune

### Requirement: First installs over managed resources warn

On a first apply with no record, when rendered resources already exist with OPM management, apply SHALL print one warning before it applies any resource. It gives how many of the rendered resources exist and says that the instance has no record, that apply updates them in place and records them, and that it prunes nothing. It SHALL NOT change the exit code. A dry run SHALL print it too when its guard refuses nothing. With no such resource, or with a record, none is printed.

#### Scenario: Managed resources on a first install

- **WHEN** a first apply finds two of three rendered resources already managed by OPM
- **THEN** one warning names 2 of 3 and the missing record, and the apply goes on and exits 0

#### Scenario: A clean first install

- **WHEN** none of the rendered resources exists
- **THEN** no warning is printed
