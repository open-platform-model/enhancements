## Purpose

What the CLI and the operator offer around secrets: encrypted values files, a skeleton values file, grouped reports of unfulfilled secrets, and the stated limit of plaintext in an instance resource.

## ADDED Requirements

### Requirement: A SOPS-encrypted values file is accepted

The CLI SHALL accept a SOPS-encrypted values file, in YAML or JSON, wherever it accepts a plain one, and the render SHALL be identical whether the values arrived encrypted or plain. The kernel SHALL receive plain values and SHALL run no decryption.

#### Scenario: Encrypted and plain give one render

- **WHEN** the same values are given once encrypted and once plain
- **THEN** the two renders are identical

### Requirement: The CLI lists and reports a module's secrets

From a module alone, with no values present, the CLI SHALL emit a skeleton values file holding exactly the declared secret paths. Its module check SHALL report unfulfilled secrets as one grouped message naming each path, group and key, in place of per-field incompleteness errors.

#### Scenario: A skeleton from the module alone

- **WHEN** a user asks the CLI for a skeleton values file of a module
- **THEN** it holds exactly the declared secret paths and no other

#### Scenario: A grouped report

- **WHEN** a module check finds three unfulfilled secrets
- **THEN** it prints one message naming all three by path, group and key

### Requirement: An instance resource may carry a literal

An instance resource, applied by the operator or by the CLI, SHALL be accepted with a literal secret in its values and SHALL render as the same values given to the CLI do. The documentation SHALL state that such a literal is plaintext at rest in etcd on both paths, and SHALL direct production use to a reference or a named source.

#### Scenario: A literal in a resource

- **WHEN** a resource carries a literal secret in its values
- **THEN** the operator renders the same output as the CLI does for the same values

#### Scenario: The documentation states the limit

- **WHEN** a reader looks up literals in an instance resource
- **THEN** the documentation names plaintext at rest on both the operator path and the CLI apply path
