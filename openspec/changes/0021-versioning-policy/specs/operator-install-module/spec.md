## Purpose

How the operator is installed and versioned. The operator is an OPM module on its own version train, and the CLI installs it from a registry. This amends six earlier decisions of enhancement 0006. No seed holds that older behaviour, so these requirements are ADDED.

## ADDED Requirements

### Requirement: Install resolves the operator module from a registry

The operator install command SHALL install the operator from a version of the operator module resolved from a registry. The CLI SHALL carry no operator manifest of its own.

#### Scenario: A default install

- **WHEN** a user installs the operator
- **THEN** the CLI resolves the operator module from the registry and applies its render

### Requirement: A mirror gives the same install

Pointed at a registry mirror that serves the operator module and its dependencies, install SHALL produce the same objects it produces from the default registry.

#### Scenario: An air-gapped cluster

- **WHEN** install runs against a mirror that serves the module and its dependencies
- **THEN** the objects match those of the default registry

### Requirement: The module has its own version train

The operator module's version SHALL move on its own train. An operator or CLI release SHALL NOT by itself move it. A module release that changes only the module SHALL deploy the same operator as the one before it.

#### Scenario: A module-only change

- **WHEN** the module's own configuration surface changes and the operator does not
- **THEN** a new module version deploys the same operator version as before

### Requirement: The module major stays v0 until operator GA

The operator module's path major SHALL stay `v0` until the operator reaches GA.

#### Scenario: Before operator GA

- **WHEN** the operator has not reached GA
- **THEN** the module is published on the `v0` major

### Requirement: One module version deploys one operator version

Each operator module version SHALL deploy exactly one operator version and SHALL name its image by version tag and content digest.

#### Scenario: Reading a module version

- **WHEN** a user reads a module version's image
- **THEN** it names one operator version by tag and digest

### Requirement: Each CLI release names its module and operator

Each CLI release SHALL name one default operator module version and the operator version that module deploys. No CLI release SHALL be published whose named module does not deploy the operator version it names.

#### Scenario: A CLI release with a mismatched pin

- **WHEN** a CLI release names a module that deploys a different operator version
- **THEN** the release is not published

### Requirement: The CRDs-only form uses the same render

The CRDs-only install form SHALL apply only the CRDs of the same render the full install applies. Every object either form writes SHALL be applied with the CLI's field manager.

#### Scenario: CRDs only

- **WHEN** a user installs only the CRDs
- **THEN** exactly the CRDs of the full render are applied, with the CLI's field manager

### Requirement: Install leaves an existing Platform alone

Install SHALL never overwrite an existing cluster Platform and SHALL never record the Platform in the operator's instance.

#### Scenario: A cluster that already has a Platform

- **WHEN** install runs on a cluster with a Platform
- **THEN** the Platform is unchanged and the operator's instance does not record it

### Requirement: The operator never touches its own instance

The operator SHALL apply, prune and finalize nothing for the instance that deploys it, whatever that instance's owner field says.

#### Scenario: A mislabelled owner field

- **WHEN** the operator's own instance carries an owner field that names the operator
- **THEN** the operator still skips it

### Requirement: Install does not depend on the cluster Platform

For a given module version and values, install SHALL apply the same objects whether or not the cluster holds a Platform and whatever that Platform says.

#### Scenario: Two clusters with different Platforms

- **WHEN** install runs against two clusters whose Platforms differ
- **THEN** the same objects are applied

### Requirement: Uninstall removes what the inventory holds

Uninstalling the operator SHALL delete the objects in the operator instance's recorded inventory, except the CRDs and the Namespace, and then the instance's record. It SHALL refuse while any instance carries the operator's cleanup finalizer, unless the user asks for those finalizers to be removed.

#### Scenario: Uninstall with a live instance

- **WHEN** an instance still carries the cleanup finalizer and the user did not ask to remove finalizers
- **THEN** uninstall refuses and deletes nothing

### Requirement: No module release is marked latest

No operator module release SHALL be marked as the GitHub latest release of the operator's repository.

#### Scenario: A module release

- **WHEN** a module release is published
- **THEN** the operator's latest release mark does not move
