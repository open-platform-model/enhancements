## Purpose

What a user gets when a deployed instance is exported for GitOps: a complete directory that applies on its own, is stable between runs, keeps secret values encrypted, and takes the live instance as its only input.

## ADDED Requirements

### Requirement: An export is one directory per instance

An export SHALL write one directory per instance. The directory SHALL hold the instance, its namespace, the service account that applies it, that account's role binding, and a kustomization that lists exactly those four documents in apply-safe order.

#### Scenario: One instance, one directory

- **WHEN** a user exports an instance
- **THEN** the output is a single directory for that instance with the four documents and a kustomization that lists exactly them

### Requirement: The exported directory applies on its own

The exported directory SHALL apply into a cluster that holds only the operator. It SHALL produce the same instance under the same applier identity with the same deletion behaviour. It SHALL NOT assume anything outside the directory.

#### Scenario: Apply into an empty cluster

- **WHEN** the directory is applied into a cluster that holds only the operator
- **THEN** the instance runs under the applier account named in the directory and deleting it has the deletion behaviour the directory states

### Requirement: No repo-level Flux wiring is exported

An export SHALL NOT emit the source object or the Flux kustomization that pull a repository, and it SHALL NOT offer a mode that emits a bare instance.

#### Scenario: Wiring stays out

- **WHEN** a user exports any instance
- **THEN** the output holds no source object and no Flux kustomization, and no option produces a bare instance

### Requirement: Exporting an unchanged instance is byte-stable

Exporting an unchanged instance twice SHALL produce byte-identical output.

#### Scenario: A second run shows no diff

- **WHEN** a user exports the same unchanged instance twice into the same place
- **THEN** a diff between the two outputs is empty

### Requirement: The exported module version keeps its v prefix

The exported module version SHALL carry its `v` prefix, so the operator can resolve the document without a second actor correcting it.

#### Scenario: Version with prefix

- **WHEN** the live instance runs version 2.1.0 of its module
- **THEN** the exported document names version v2.1.0

### Requirement: Completed fields are named in the output

A field the export writes that the live instance did not carry SHALL be named in the command output together with its behavioural consequence. A field that decides the render SHALL only be copied, never completed or altered.

#### Scenario: A completed field is reported

- **WHEN** the export writes a field that the live instance does not carry
- **THEN** the output names that field together with its behavioural consequence

#### Scenario: A render-bearing field is never completed

- **WHEN** the export writes the module coordinate and the values
- **THEN** both are copied from the live instance unchanged

### Requirement: Exported values are copied byte for byte

An export SHALL write the live instance's values byte for byte. It SHALL NOT redact, substitute or omit a value. Where a path is marked secret, the requirement that exported secret values are encrypted governs that value.

#### Scenario: Values are verbatim

- **WHEN** an instance with unmarked values is exported
- **THEN** the exported values equal the live values byte for byte

### Requirement: Every export that writes values warns

Every export that writes values SHALL print a warning that the values were written to disk unredacted and that OPM cannot identify which of them are secret.

#### Scenario: The warning appears

- **WHEN** an export writes an instance that has values
- **THEN** the output carries the warning, and it carries it on every such export

### Requirement: The live instance is the only input

An export SHALL read the instance from the cluster and nothing else. It SHALL NOT read a local instance file or a values file, and it SHALL NOT merge local state into the output.

#### Scenario: A drifted local file is ignored

- **WHEN** the local instance file differs from the deployed instance
- **THEN** the export reflects the deployed instance only

### Requirement: A bulk export writes one directory per instance

An export invocation SHALL name one instance, or SHALL export every exportable instance in a namespace or in the cluster. It SHALL write one directory per instance, with nothing shared or merged between them.

#### Scenario: A whole namespace

- **WHEN** a user exports every instance in a namespace that holds three
- **THEN** the output holds three directories, each complete on its own

### Requirement: Secret-bearing export output can be SOPS-encrypted

When an instance is exported for GitOps consumption, its secret-bearing output SHALL be SOPS-encryptable on write, for decryption in the cluster by the GitOps tool.

#### Scenario: Encrypt on write

- **WHEN** a user exports an instance that has secret values and asks for encryption
- **THEN** the written secret-bearing output is SOPS-encrypted and the GitOps tool can decrypt it in the cluster

### Requirement: Exported secret values are encrypted

An exported instance SHALL carry no plaintext secret value. Every other field of it SHALL stay readable and diffable.

#### Scenario: Only the secret is hidden

- **WHEN** an instance with a literal at a secret path is exported
- **THEN** that value is encrypted in the output and every other field is plain text that a diff can read

### Requirement: An exported instance renders as the original

Once the GitOps tool has decrypted the exported instance, it SHALL render exactly as the unexported instance.

#### Scenario: Same render after decryption

- **WHEN** the GitOps tool decrypts an exported instance
- **THEN** the render equals the render of the instance before export
