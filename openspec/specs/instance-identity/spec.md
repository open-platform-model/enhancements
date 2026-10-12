# instance-identity Specification

## Purpose
Define how a deployed module instance derives its own identity, apart from the identity of the module it deploys. The instance FQN joins the module's major-free registry path, the instance name and the namespace, so that identity survives a version change and a major bump, and still tells modules, names and namespaces apart.

## Requirements

### Requirement: An instance declares its own FQN

A `#ModuleInstance` SHALL declare its own FQN: the deployed module's major-free registry path, the instance name and the namespace, joined by colons in that order. It SHALL NOT derive the FQN from the module's FQN, UUID, version or major.

#### Scenario: The FQN composes the registry path, name and namespace

- **WHEN** an instance named `postgres-prod` in namespace `prod` deploys a module whose registry path is `opmodel.dev/modules/postgres`
- **THEN** the instance FQN is `opmodel.dev/modules/postgres:postgres-prod:prod`

#### Scenario: The module's major does not appear

- **WHEN** the deployed module's path is `opmodel.dev/modules/postgres@v2`
- **THEN** the instance FQN carries no `@v2`

### Requirement: Instance identity derives from the instance FQN

A `#ModuleInstance` SHALL derive its UUID as a version 5 (SHA-1) UUID of its own FQN under the OPM namespace UUID. It SHALL NOT use the module's UUID. It SHALL carry that UUID in its `module-instance.opmodel.dev/uuid` label.

#### Scenario: The UUID hashes the instance FQN

- **WHEN** an instance is evaluated
- **THEN** its UUID equals the version 5 UUID of its FQN under the OPM namespace UUID

#### Scenario: The label carries the UUID

- **WHEN** an instance is evaluated
- **THEN** its `module-instance.opmodel.dev/uuid` label equals its UUID

### Requirement: The identity formula is fixed

The OPM namespace UUID SHALL stay the same in every version of the core schema, and the formulas of the instance FQN and UUID SHALL NOT change. A changed formula would move the identity of every deployed instance at once.

#### Scenario: Fixed inputs give a fixed UUID

- **WHEN** an instance named `postgres-prod` in namespace `prod` deploys the module `opmodel.dev/modules/postgres@v2`
- **THEN** its UUID is `b6a249c2-6d12-5422-ae0b-ecf44cbbf8bf`, in every version of the schema

### Requirement: Instance identity survives every module upgrade

For one registry path, instance name and namespace, the instance FQN and UUID SHALL NOT change when the module's version changes or when the major of its path changes. The ownership label depends on it: a UUID that moved on upgrade would orphan live objects the new render no longer emits.

#### Scenario: A release within a major does not move the UUID

- **WHEN** the deployed module's version changes from `2.4.1` to `2.9.9` and the name and namespace stay
- **THEN** the instance FQN and UUID are unchanged

#### Scenario: A major bump does not move the UUID

- **WHEN** the deployed module's path changes from `opmodel.dev/modules/postgres@v2` to `opmodel.dev/modules/postgres@v3` and the name and namespace stay
- **THEN** the instance FQN and UUID are unchanged

#### Scenario: Two majors under one name and namespace share an identity

- **WHEN** two instances share a name and a namespace and deploy the same module at `@v2` and `@v3`
- **THEN** their UUIDs are equal

### Requirement: Instance identity still separates what it must

Instance UUIDs SHALL differ for two modules with different registry paths, and for one module deployed into two namespaces or under two instance names. Without this, the survival rule is met by an identity that no longer tells anything apart.

#### Scenario: Two modules with one leaf name stay distinct

- **WHEN** two instances share a name and a namespace and deploy `opmodel.dev/modules/postgres` and `example.com/postgres`
- **THEN** their UUIDs differ

#### Scenario: One module in two namespaces stays distinct

- **WHEN** two instances share a name, deploy the same module and declare the namespaces `prod` and `staging`
- **THEN** their UUIDs differ

#### Scenario: Two names in one namespace stay distinct

- **WHEN** two instances share a namespace, deploy the same module and declare the names `postgres-prod` and `postgres-replica`
- **THEN** their UUIDs differ

### Requirement: An instance FQN cannot take a module path

The instance FQN SHALL read the module's major-free registry path only. A full module path with a major in that position SHALL be refused structurally, and no third identity SHALL result.

#### Scenario: A module path in the registry path position is refused

- **WHEN** a module whose path is `opmodel.dev/modules/postgres@v2` is given the registry path `opmodel.dev/modules/postgres@v2`
- **THEN** validation fails with a conflict between `opmodel.dev/modules/postgres` and `opmodel.dev/modules/postgres@v2`, and the instance FQN is not built from it
