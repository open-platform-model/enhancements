# apply-preflight-gates Specification

## Purpose
The checks the CLI runs before it applies an instance to a cluster, and what it refuses or warns about before any object is written. They cover the ModuleInstance CustomResourceDefinition, the conditions under which the operator-version ceiling is read or skipped, the access the CLI needs to record its inventory, their order, and the dry run, which skips them. The ownership checks that also run before the first write are stated elsewhere.

## Requirements

### Requirement: A missing ModuleInstance CRD stops the apply

Before it applies an instance, the CLI SHALL check that the ModuleInstance CustomResourceDefinition (`moduleinstances.opmodel.dev`) exists. When it is absent, the apply SHALL fail with exit code 2 and a validation error of one line that says the CRD was not found and names the operator install command, in its CRDs-only form, as the fix. A read of the CRD that fails for another reason SHALL fail the apply and say that the CRD could not be read.

#### Scenario: The CRD is absent

- **WHEN** an instance is applied to a cluster that has no ModuleInstance CRD
- **THEN** the command exits with code 2 and the error names the operator install command in its CRDs-only form
- **AND** no object is applied

#### Scenario: The CRD cannot be read for another reason

- **WHEN** the read of the CRD fails with an error other than not found
- **THEN** the apply fails and the error says that the CRD could not be read

### Requirement: An outdated ModuleInstance CRD stops the apply

The CLI SHALL check that the storage version of the installed ModuleInstance CRD carries the properties `spec.owner` and `status.inventory`. When none is marked as the storage version, the first served version SHALL count. A CRD that lacks either property SHALL stop the apply with exit code 2 and a validation error that says required fields are missing and names the same fix. A CRD with no version, or with a version that has no schema, SHALL stop it too, with an error that says what is missing.

#### Scenario: The CRD lacks the owner property

- **WHEN** the installed CRD schema has no `spec.owner`
- **THEN** the command exits with code 2 and the error says the CRD is missing required fields
- **AND** no object is applied

#### Scenario: The CRD lacks the inventory property

- **WHEN** the installed CRD schema has no `status.inventory`
- **THEN** the apply is refused and the error says the CRD is missing required fields

#### Scenario: A current CRD passes silently

- **WHEN** the installed CRD schema has both properties
- **THEN** the check passes and prints nothing

#### Scenario: A CRD without a schema is refused

- **WHEN** the installed CRD has no version, or its version has no schema
- **THEN** the apply is refused with a validation error that says the CRD has no version, or that its version has no schema

### Requirement: The ceiling is skipped when it cannot compare

For the operator-version ceiling the CLI SHALL read the cluster-scoped Platform named `cluster`. It SHALL skip the check, and the apply SHALL go on, when the Platform or its operator version is absent (no output), or when the CLI's version or the operator's is not valid SemVer, or the read is denied by access control (a warning each). Any other failure to read the Platform SHALL fail the apply.

#### Scenario: A solo cluster skips the ceiling

- **GIVEN** a CLI whose version is a released SemVer version
- **WHEN** the cluster has no Platform, or the Platform reports no operator version
- **THEN** the ceiling check is skipped and prints nothing, and the apply goes on

#### Scenario: A development build skips with a warning

- **WHEN** the CLI version is `dev`
- **THEN** the check is skipped, a warning is printed and the apply goes on

#### Scenario: An invalid operator version skips with a warning

- **WHEN** the Platform reports an operator version that is not valid SemVer
- **THEN** the check is skipped, a warning is printed and the apply goes on

#### Scenario: A denied read degrades to a warning

- **WHEN** reading the Platform is forbidden
- **THEN** the check is skipped, a warning is printed and the apply goes on, so a namespace-scoped user can still apply

#### Scenario: Another read failure stops the apply

- **GIVEN** a CLI whose version is a released SemVer version
- **WHEN** reading the Platform fails with an error that is neither not found nor forbidden
- **THEN** the apply fails and the error says the Platform could not be read for the ceiling

### Requirement: Status access is checked before a CLI-run apply

When the CLI itself applies the instance's objects, it SHALL ask the cluster, by a SelfSubjectAccessReview, whether the caller may patch `moduleinstances/status` in the instance namespace, before any object is applied. When access is denied, the apply SHALL fail with exit code 4 and a permission-denied error. The error SHALL say that the inventory cannot be recorded and SHALL name the remedies: grant that access, or run the operator install command in its CRDs-only form with its RBAC option.

#### Scenario: Denied status access stops the apply

- **WHEN** the review reports that patching `moduleinstances/status` is denied
- **THEN** the command exits with code 4 before any object is applied
- **AND** the error says the inventory cannot be recorded and names the RBAC remedy

#### Scenario: Allowed status access proceeds silently

- **WHEN** the review reports that the access is allowed
- **THEN** the apply goes on and prints nothing for this check

#### Scenario: A failed review stops the apply

- **WHEN** the access review request itself fails
- **THEN** the apply fails and the error says the access to patch `moduleinstances/status` could not be checked

### Requirement: Operator-owned instances skip the status check

The status access check SHALL run only when the CLI applies the instance's objects itself. An instance whose spec an operator owns is edited by the CLI and applied by the operator, so the CLI SHALL NOT check for it whether the caller can patch `moduleinstances/status`. The CRD presence, field-floor and ceiling checks run before that point and apply to it as to any instance.

#### Scenario: The operator owns the instance

- **WHEN** an apply targets an instance that an operator owns
- **THEN** no access review for `moduleinstances/status` is made
- **AND** the CRD presence, field-floor and ceiling checks have already run

### Requirement: The checks run in a fixed order

The CLI SHALL run its checks in this order: ModuleInstance CRD presence, CRD field floor, operator-version ceiling, then, for an instance the CLI applies itself, the status access check. The first check that fails SHALL stop the apply, and no later check SHALL run. The ownership checks, stated elsewhere, run between and after these; every check runs before the first write.

#### Scenario: A missing CRD stops the ceiling from being read

- **WHEN** the ModuleInstance CRD is absent
- **THEN** the apply fails on the missing CRD and the Platform is not read

#### Scenario: An outdated CRD stops the ceiling from being read

- **WHEN** the CRD is present but lacks a required property
- **THEN** the apply fails on the missing fields and the Platform is not read

### Requirement: A refused apply writes nothing

When a check refuses an instance apply or a module apply, the CLI SHALL have created and changed nothing in the cluster: no object, no inventory record and no namespace. A namespace that the user asked the CLI to create SHALL be created only after the last check that can refuse, and before the first object is applied.

#### Scenario: A failed check leaves the cluster untouched

- **WHEN** any check fails during an instance apply
- **THEN** no object has been created or changed and no inventory has been written

#### Scenario: A refusal creates no namespace

- **WHEN** the user asked for the namespace to be created, the namespace is missing and a check refuses the apply
- **THEN** the namespace is not created

#### Scenario: A namespace is created after the checks

- **WHEN** the user asked for the namespace to be created and no check refuses
- **THEN** the namespace is created after the checks and before the first object is applied

### Requirement: A dry run skips the cluster checks

A dry run SHALL skip the CRD presence, CRD field-floor, ceiling and status access checks, because it writes nothing that they protect. It SHALL make no probe of the CRD or the Platform for them. Against a cluster with no ModuleInstance CRD it SHALL produce its render without the missing-CRD error. The same apply without a dry run SHALL run the checks.

#### Scenario: A dry run needs no CRD

- **WHEN** an instance apply is made as a dry run against a cluster with no ModuleInstance CRD
- **THEN** the render is produced and no missing-CRD error is raised
- **AND** none of the four checks reads the CRD or the Platform, and no access review is made

#### Scenario: The same apply without a dry run is refused

- **WHEN** the same apply is made without a dry run against that cluster
- **THEN** it fails on the missing CRD
