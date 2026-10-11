## Purpose

State how the CLI deploys, updates and deletes an instance on a cluster: the commands a user runs, what each prints, asks and waits for, and how it ends. It covers the module apply and instance apply commands and the instance delete command. The ownership guard, the prune rules, the pre-apply gates and the shared delete verdict are stated elsewhere. The instance-ownership capability states what an operator-owned delete hands to the finalizer and the outcome it reports; this capability keeps the prompt and the closing claim output.

## ADDED Requirements

### Requirement: Module apply takes a directory or published module

The module apply command SHALL accept a module package directory, defaulting to the current directory, or a published module named by its module path, and SHALL deploy the instance it synthesizes around that module. A version selector SHALL apply only to a published module. A file SHALL be refused with an error that points to the instance apply command.

#### Scenario: Default to the current directory

- **WHEN** the user runs module apply with no argument inside a module package directory
- **THEN** the command synthesizes an instance from that directory and applies it

#### Scenario: A file is refused

- **WHEN** the user passes a module file to module apply
- **THEN** the command refuses, says it expects a directory, and names the instance apply command for instance files

#### Scenario: A version selector with a directory

- **WHEN** the user passes a version selector together with a local directory
- **THEN** the command refuses with exit code 2 and says the selector applies only to a published module

### Requirement: A module apply names its synthetic instance

The module apply command SHALL name the synthetic instance after the module with the suffix `-debug`, unless the user gives a name. The name and the namespace SHALL choose the instance, so each pair gets its own record, and the same pair run again SHALL reach the same record. The apply log SHALL show the resolved name.

#### Scenario: The default name

- **WHEN** the user applies a module named `my-module` without a name
- **THEN** the apply log names the instance `my-module-debug`

#### Scenario: Two namespaces, two records

- **WHEN** the user applies the same module into two namespaces
- **THEN** each namespace holds its own instance record, and neither run touches the other's

#### Scenario: The same inputs reach the same record

- **WHEN** the user applies the same module with the same name and namespace twice
- **THEN** both runs read and write the same record

### Requirement: Module apply deploys debug values unless overridden

Module apply SHALL take the values it deploys from the user's values files when any are given, and otherwise from the module's debug values, the author's test values. It SHALL warn whenever it deploys debug values, and SHALL point to the instance init command for an editable instance package. Values files SHALL NOT fall back to debug values.

#### Scenario: Values files replace debug values

- **WHEN** the user applies a module with one values file
- **THEN** only that file supplies the values, and no warning about debug values appears

#### Scenario: Debug values warn

- **WHEN** the user applies a module with no values file
- **THEN** the command warns that it deploys the author's test values and names the instance init command

### Requirement: Applies stage definitions before the rest

Both apply commands SHALL apply the rendered CustomResourceDefinitions and Namespaces first. Outside a dry run they SHALL then wait until every definition applied is established and its kinds are served, bounded by the timeout (five minutes by default) counted from the start of the apply, and only then apply the rest. A wait that fails SHALL fail the command, name the definitions still pending, apply nothing more, and neither prune nor write the record.

#### Scenario: A definition and its custom resource in one run

- **WHEN** a module renders a custom resource and the definition of its kind, and the cluster has neither
- **THEN** the definition is applied, the command waits until it is established, the custom resource follows, and the first run succeeds

#### Scenario: A definition that never becomes established

- **WHEN** an applied definition is not established within the timeout
- **THEN** the command exits non-zero naming it, applies nothing else, prunes nothing and writes no record

### Requirement: A failed resource does not stop the others

When one resource fails to apply, both apply commands SHALL report it and SHALL still apply the remaining resources of that stage and of the next. The command SHALL then exit 1, say how many resources failed to apply, and print no success line.

#### Scenario: One resource is refused by the server

- **WHEN** one of five resources fails to apply
- **THEN** the other four are applied, the failure is reported, and the command exits 1 without a success line

### Requirement: A dry run skips what the apply creates

A dry run SHALL NOT send a custom resource whose definition the same apply would create, nor a namespaced object whose namespace the same apply would create, because the server cannot validate them yet. It SHALL warn naming the skipped object and the reason, count it as skipped in the summary, and not treat it as an error. Anything whose definition and namespace already exist SHALL be sent.

#### Scenario: A new definition

- **WHEN** a dry run renders a new definition and one custom resource of its kind
- **THEN** the custom resource is skipped with a warning, the summary counts one skipped resource, and the command exits 0

#### Scenario: An existing namespace

- **WHEN** the same dry run meets a namespace that already exists
- **THEN** every object in it is sent and none is skipped

#### Scenario: A real run skips nothing

- **WHEN** the same apply runs without the dry run option
- **THEN** it applies every object and skips none

### Requirement: Create-namespace reads before it creates

With the option to create the namespace, apply SHALL first read whether the instance namespace exists. An existing namespace SHALL be left alone. A failed read SHALL stop the apply with the exit code of its cause and make no further cluster call. A dry run SHALL create nothing and SHALL say that the namespace would be created.

#### Scenario: The namespace exists

- **WHEN** apply runs with the option and the namespace exists
- **THEN** nothing is created and the apply goes on as without the option

#### Scenario: The read is denied

- **WHEN** the read of the namespace fails with Forbidden
- **THEN** the command exits 4 and makes no further call to the cluster

#### Scenario: A dry run

- **WHEN** a dry run meets a missing namespace
- **THEN** it reports that the namespace would be created and creates nothing

### Requirement: A namespace made meanwhile stops the apply

When apply creates a missing namespace and the create fails, the command SHALL exit with the code of its cause and apply no resource. When the namespace turns out to exist at the create although the first read found it missing, apply SHALL exit 1 before any change and tell the user to run the command again, because nothing inside that namespace was checked.

#### Scenario: The create is denied

- **WHEN** every check passes and the create of the namespace fails with Forbidden
- **THEN** the command exits 4, applies no resource and writes no record

#### Scenario: Someone else created it

- **WHEN** another actor creates the namespace after apply found it missing
- **THEN** the command exits 1, says the namespace was created by someone else and asks the user to run again
- **AND** no resource is applied

### Requirement: A real apply reports whether it changed anything

A successful apply SHALL print how many resources were created, configured and left unchanged, and then one success line. The line SHALL say the instance is up to date when nothing changed and that it was applied otherwise. The command SHALL exit 0.

#### Scenario: Nothing changed

- **WHEN** the user applies an instance twice without any change
- **THEN** the second run ends with the up-to-date success line and exit 0

#### Scenario: Something changed

- **WHEN** the second apply changes a value
- **THEN** the summary counts the configured resources and the success line says the instance was applied

### Requirement: A successful apply writes the instance record

After every resource applied, apply SHALL write the instance record: the module path and version it deployed, the values, whether the module came from local source, the resources the instance owns, a revision that starts at 1 and rises by one with each apply, and digests of the render, the source and the values.

#### Scenario: A first apply

- **WHEN** apply succeeds for an instance with no record
- **THEN** the record holds the module path and version, the values, the owned resources and revision 1

#### Scenario: A later apply

- **WHEN** apply succeeds for an instance whose record is at revision 3
- **THEN** the record is at revision 4 with the new digests

### Requirement: Wait blocks until the applied resources are healthy

With the wait option, apply SHALL poll every applied resource after the record is written until each is healthy, bounded by a full timeout of its own. It SHALL then print a healthy line and exit 0. When the timeout passes or a resource has disappeared, it SHALL exit 1, list the resources not yet healthy, leave resources and record in place, and name the instance status command. A dry run SHALL NOT wait.

#### Scenario: All resources become healthy

- **WHEN** apply runs with the wait option and every resource becomes healthy within the timeout
- **THEN** the command prints the healthy line and exits 0

#### Scenario: The timeout passes

- **WHEN** a Deployment is still unhealthy at the timeout
- **THEN** the command exits 1 listing the Deployment, and the applied resources and the record remain

#### Scenario: A dry run does not wait

- **WHEN** apply runs with both the wait option and the dry run option
- **THEN** the command does not poll the cluster for health

### Requirement: Delete takes an instance file, name or UUID

Instance delete SHALL take exactly one argument: an instance file or a directory holding one, an instance name, or an instance UUID. An argument that ends in the CUE file extension, contains a path separator or starts with a dot or a tilde SHALL be a path, and any other word SHALL be a name or UUID, whatever sits on disk. A UUID SHALL match the identity recorded in an instance record of the instance's namespace.

#### Scenario: A bare word is a name

- **WHEN** the user runs delete for `hello` in a directory that holds a folder named `hello`
- **THEN** the command deletes the instance named `hello` and does not read the folder

#### Scenario: A path is an instance file

- **WHEN** the user runs delete for `./hello` and that directory holds an instance file
- **THEN** the command reads the instance file and deletes the instance it names

#### Scenario: A UUID

- **WHEN** the user passes the UUID recorded for an instance
- **THEN** the command selects that instance in the namespace

#### Scenario: No argument

- **WHEN** the user runs delete with no argument
- **THEN** the command returns a usage error that names the required argument

### Requirement: Delete reads only the instance record

Delete SHALL find the resources to delete only in the instance's persisted record, SHALL NOT need the module source, and SHALL NOT scan the cluster by label. A resource that carries the instance's labels but is not in the record SHALL NOT be deleted.

#### Scenario: The source is gone

- **WHEN** the module source has been deleted and the user runs delete for the instance
- **THEN** the tracked resources are deleted from the record

#### Scenario: A derived resource

- **WHEN** an Endpoints object carries the instance's labels but is not in the record
- **THEN** delete leaves it alone

### Requirement: Delete asks before it deletes

Delete SHALL ask for confirmation before it deletes, unless the user passes the yes option, whose old spelling stays as a deprecated alias, or runs a dry run. An answer other than yes, a closed input included, SHALL delete nothing, say the deletion was cancelled, and exit 0.

#### Scenario: The user declines

- **WHEN** the user answers no at the prompt
- **THEN** nothing is deleted, the command says the deletion was cancelled and exits 0

#### Scenario: The prompt is skipped

- **WHEN** the user passes the yes option or runs a dry run
- **THEN** no prompt is shown

### Requirement: The prompt for a CLI-owned instance names claims

For a CLI-owned instance the prompt SHALL say that CustomResourceDefinitions and Namespaces are left behind and that PersistentVolumeClaims are kept. With data deletion asked, it SHALL name every live tracked claim by namespace and name and say that the data on them is deleted.

#### Scenario: Claims are kept

- **WHEN** the user runs delete without data deletion
- **THEN** the prompt says that PersistentVolumeClaims are kept

#### Scenario: Claims are named

- **WHEN** the user runs delete with data deletion and the record tracks claims `config` and `media` in namespace `media`
- **THEN** the prompt names `media/config` and `media/media` and says their data is deleted

### Requirement: The operator-managed prompt says what the operator does

For an operator-managed instance the prompt SHALL say so. When the prune setting is unset, it SHALL say the operator leaves the tracked resources running. When it is set, it SHALL say the operator deletes them, and SHALL say nothing about claims if the record tracks none. The data deletion warning SHALL come before the question.

#### Scenario: Prune unset

- **WHEN** the user runs delete for an operator-managed instance whose prune setting is unset
- **THEN** the prompt says the operator leaves its tracked resources running

#### Scenario: Prune set, no claims

- **WHEN** the prune setting is true and the record tracks no claim
- **THEN** the prompt says the operator deletes the tracked resources and does not mention claims

#### Scenario: Warning before the question

- **WHEN** the user passes data deletion for an operator-managed instance
- **THEN** the data deletion warning is printed before the question

### Requirement: The prompt states the fate of operator claims

With the prune setting set and claims tracked, the prompt SHALL say that the operator deletes them, data included, when the installed ModuleInstance CRD has no data-policy field or the policy is Delete. When the CRD has the field and the policy is Keep, unset or any other value, it SHALL say the operator keeps them and add that an older operator deletes them whatever the field says.

#### Scenario: The operator has no data policy

- **WHEN** the CRD has no data-policy field and the record tracks a claim
- **THEN** the prompt says the operator deletes the claims and their data

#### Scenario: The policy is unset

- **WHEN** the CRD has the field and the policy is unset
- **THEN** the prompt says the operator keeps claims and that an older operator deletes them

### Requirement: The prompt claims nothing it cannot read

When the CRD has no schema that can be read and the policy is not Delete, the prompt SHALL NOT say claims are kept or deleted. It SHALL say that an operator with the field keeps them, that an older one deletes them, and that the CLI could not read the schema to tell. A policy value other than Keep and Delete SHALL be shown quoted and named as read as Keep.

#### Scenario: An unreadable schema

- **WHEN** the CRD has no readable schema
- **THEN** the prompt says it could not read the schema and does not say the claims are kept

#### Scenario: An unknown policy value

- **WHEN** the policy is `Retain` and the CRD has the field
- **THEN** the prompt shows `"Retain"` and says it is read as Keep

### Requirement: A refused delete asks nothing

Delete SHALL read the instance record before it asks, and every check that can refuse the delete SHALL run before the prompt: the guard for an instance that deploys the operator and, for an operator-managed instance, the operator-readiness check. A missing instance SHALL exit 5 as not found before any prompt. A refused delete SHALL NOT ask for confirmation.

#### Scenario: No such instance

- **WHEN** the user runs delete for an instance with no record
- **THEN** the command exits 5 and shows no prompt

#### Scenario: The operator is not ready

- **WHEN** the instance is operator-managed and the operator is not ready
- **THEN** the command exits 2 with the readiness refusal and shows no prompt

### Requirement: Delete refuses an instance that deploys the operator

Delete SHALL refuse an operator-owned instance that deploys the operator, exit 2, delete and patch nothing, name the signal that matched, and say to set the instance's owner to the CLI first. An instance deploys the operator when it has the operator's name and namespace, its module is the operator module, or its record holds one of the operator's definitions.

#### Scenario: Any of the three signals

- **WHEN** an operator-owned instance matches by name, by module or by a definition in its record
- **THEN** delete exits 2 and the instance still exists

#### Scenario: A look-alike

- **WHEN** an instance has a module whose path only begins like the operator's and holds an unrelated definition
- **THEN** the guard does not apply

### Requirement: Delete refuses while instances await operator cleanup

A CLI-owned instance that deploys the operator SHALL NOT be deleted while any instance in the cluster carries the operator's cleanup finalizer. Delete SHALL exit 2, delete and patch nothing, name each such instance as namespace and name, mark the target if it is one, and name the operator uninstall command with its finalizer-removal choice and that this choice orphans their workloads. A failed cluster-wide list SHALL fail closed with the exit code of its cause.

#### Scenario: An instance awaits cleanup

- **WHEN** `default/hello` carries the finalizer and the user deletes the operator's CLI-owned instance
- **THEN** the command exits 2 naming `default/hello` and the uninstall command, and every object still exists

#### Scenario: The list is denied

- **WHEN** the user may not list instances cluster-wide
- **THEN** the command exits 4 and deletes nothing

### Requirement: The operator refusals have no bypass

Both refusals SHALL hold on a dry run with the same outcome as the real run. The yes option and its deprecated alias SHALL NOT bypass them, delete SHALL offer no option that removes finalizers, and delete SHALL NOT change the owner of an instance. The refusals SHALL NOT apply to any other instance.

#### Scenario: A dry run is refused alike

- **WHEN** the user runs delete as a dry run for the operator's CLI-owned instance while another instance carries the finalizer
- **THEN** the command exits 2 with the same refusal as the real run and deletes nothing

#### Scenario: Yes does not bypass

- **WHEN** the user runs delete with the yes option for the operator's instance while another instance carries the finalizer
- **THEN** the command exits 2 and deletes nothing

#### Scenario: Another instance

- **WHEN** the user deletes an unrelated CLI-owned instance while some instance carries the finalizer
- **THEN** the delete proceeds

### Requirement: Delete lists what it leaves behind

For a CLI-owned instance, delete SHALL list each tracked resource it leaves in place as left behind, with kind, namespace, name and the reason, in the dry run and the real run. A left-behind resource SHALL NOT be a failure: the others are deleted, the record is deleted last and the command exits 0. The closing line SHALL give how many were left behind and say to remove them with kubectl.

#### Scenario: A Namespace is left behind

- **WHEN** the record tracks a Deployment and the Namespace it runs in
- **THEN** the Deployment is deleted, the Namespace is listed as left behind, the record is deleted and the command exits 0

#### Scenario: A resource another instance owns

- **WHEN** a tracked resource now belongs to another instance
- **THEN** it is listed as left behind with that reason and does not count as a failure

### Requirement: Delete removes only the object it read

Delete SHALL read each tracked resource again just before its delete and SHALL send the delete with Foreground propagation and a precondition on the identity of the object read. A delete the server refuses on that precondition SHALL count as a failed resource. A resource that is gone, at the read or at the delete, SHALL count as neither deleted nor failed.

#### Scenario: The object was replaced

- **WHEN** the server refuses a delete because a new object holds the name
- **THEN** the resource is reported failed and not deleted, and the record is kept

#### Scenario: The resource is already gone

- **WHEN** a tracked resource no longer exists at its re-read
- **THEN** no error is reported and it is not counted as deleted

### Requirement: A failed resource delete keeps the record

For a CLI-owned instance, when the delete of a tracked resource fails, delete SHALL still process the others, keep the record, say that re-running is safe and exit 1. A failed API discovery request SHALL exit with the code of its cause instead.

#### Scenario: A delete is refused for one resource

- **WHEN** the server refuses the delete of one tracked ConfigMap with Forbidden and accepts the rest
- **THEN** the other resources are deleted, the record stays, the command says re-running is safe and exits 1

### Requirement: An unreadable tracked resource keeps the record

For a CLI-owned instance, when a tracked resource cannot be read during discovery for any reason but not found, delete SHALL list it with its read error, still process the others, keep the record, say re-running is safe, and exit 1, or with the code of a failed discovery request. An unreadable Namespace, CustomResourceDefinition or, unless data deletion is asked, claim is not a failure. A dry run SHALL count the resource as not checked. An operator-managed delete SHALL ignore such errors.

#### Scenario: A forbidden read

- **WHEN** the read of a tracked ConfigMap fails with Forbidden
- **THEN** the Deployment is deleted, the ConfigMap is listed with the error, the record stays and the command exits 1

#### Scenario: A dry run

- **WHEN** a dry run cannot read one tracked resource
- **THEN** it deletes nothing, reports that one resource could not be checked and exits 1

#### Scenario: An unreadable claim

- **WHEN** a tracked claim cannot be read and data deletion is not asked
- **THEN** the claim is listed as kept and the command does not fail because of it

#### Scenario: An operator-managed delete

- **WHEN** a tracked resource of an operator-managed instance cannot be read
- **THEN** the command deletes the instance record and waits for the operator as without the error

#### Scenario: An unreadable Namespace

- **WHEN** a tracked Namespace cannot be read and every other resource is deleted
- **THEN** the Namespace is listed as left behind, the record is deleted and the command exits 0

### Requirement: A failed record delete is not success

When every tracked resource is deleted and the delete of the record then fails for any reason but not found, delete SHALL print no success line and SHALL exit non-zero. The output SHALL name the record and the error, say the resources were deleted and the record remains, and say re-running is safe. The exit code SHALL be 4 when denied, 3 on a server timeout or unavailability, and 1 otherwise.

#### Scenario: A forbidden record delete

- **WHEN** the record delete fails with Forbidden after the resources are deleted
- **THEN** the output does not say the instance was deleted, says the record remains, and the command exits 4

#### Scenario: A re-run

- **WHEN** the user runs delete again after the cause is fixed
- **THEN** the record is deleted and the command exits 0

### Requirement: Delete keeps claims unless data deletion is asked

For a CLI-owned instance, delete SHALL keep each tracked PersistentVolumeClaim of the core group unless the user asks for data deletion. It SHALL list each kept claim with the status kept, as information and not as a warning, and a kept claim SHALL NOT be a failure. The closing output SHALL give how many were kept, print the command that deletes each, and name the data deletion option. Claims a StatefulSet creates SHALL stay untouched either way.

#### Scenario: A claim is kept

- **WHEN** the record tracks a Deployment and a claim and the user runs delete
- **THEN** the Deployment is deleted, the claim is listed as kept, the command exits 0, and the closing output prints the command that deletes the claim

#### Scenario: Data deletion

- **WHEN** the user runs delete with data deletion
- **THEN** the claim is deleted like any other tracked resource and nothing is listed as kept

### Requirement: An operator-managed delete names its claims

When an operator-managed delete with the prune setting set completes and the record tracked claims, the closing output SHALL name each claim, SHALL print the command that deletes it and SHALL NOT say the claim remains, unless the policy is Delete or the CRD has no data-policy field. In those cases it SHALL say the operator pruned the tracked resources.

#### Scenario: Claims the operator may have kept

- **WHEN** the policy is unset, the CRD has the field and the record tracked claim `data` in namespace `apps`
- **THEN** the closing output names `data`, prints the delete command and does not say the claim remains

#### Scenario: The policy is Delete

- **WHEN** the policy is Delete
- **THEN** the closing output says the operator pruned the tracked resources and prints no delete command

### Requirement: A delete dry run lists and deletes nothing

A delete dry run of a CLI-owned instance SHALL read each tracked resource, judge it as the real run does, send no delete and keep the record. It SHALL list the resources it would delete, leave behind or keep, and its closing line SHALL give how many would be deleted and how many left behind, counted apart.

#### Scenario: Left-behind resources are counted apart

- **WHEN** a dry run meets four deletable resources and a Namespace
- **THEN** the closing line says four would be deleted and one left behind, and nothing is deleted

### Requirement: Delete waits for deletions only when asked

Without the wait option, delete SHALL count a resource as deleted when the server accepts its delete, also while a finalizer holds it, and SHALL then delete the record and exit 0. With the wait option on a real run with no failed resource, it SHALL poll each resource it deleted before it deletes the record, until the resource is gone or a new object holds its name, bounded by the timeout, and print progress.

#### Scenario: A finalizer holds a resource

- **WHEN** the user runs delete without the wait option and a ConfigMap carries a finalizer no controller removes
- **THEN** the ConfigMap is listed as deleted, the record is deleted and the command exits 0

#### Scenario: Resources go away in time

- **WHEN** the user runs delete with the wait option and a Deployment is gone within the timeout
- **THEN** the command returns after the read answers not found, deletes the record and exits 0

### Requirement: A wait that runs out lists what remains

When the wait passes the timeout, delete SHALL list each resource still terminating with its finalizers, keep the record, print no success line and exit 1. The wait SHALL cover only resources this run deleted: not a claim that delete keeps, a resource left behind or one already gone. It SHALL do nothing on a dry run, after a failed resource, or for an operator-managed instance, which always waits for the operator.

#### Scenario: A finalizer holds past the timeout

- **WHEN** a ConfigMap with a finalizer remains after the timeout
- **THEN** the command lists it with its finalizer, keeps the record and exits 1

#### Scenario: A kept claim is not waited for

- **WHEN** the record tracks a claim that delete keeps and a ConfigMap
- **THEN** the command waits for the ConfigMap only and exits 0 while the claim exists
