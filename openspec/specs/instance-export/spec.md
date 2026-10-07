# instance-export Specification

## Purpose

Export a running instance as files a GitOps tool can apply, so a cluster's state can be committed and replayed.

## Requirements

### Requirement: Exports copy every value except literal secrets

The exported `ModuleInstance` SHALL carry the live CR's `spec.values` byte-for-byte, except the `value` of a literal at a secret path, which is encrypted; no other value is redacted, substituted or omitted.

- Design: 0014
- Changed by: 0013, Exporting
- Was: `0014:D3:R1`

#### Scenario: values survive export unchanged

- **WHEN** an instance with no literal secret is exported
- **THEN** the exported `spec.values` equal the live CR's `spec.values` byte-for-byte

#### Scenario: a literal secret is the one exception

- **WHEN** an instance with a literal at a secret path is exported
- **THEN** every value other than that one equals the live CR's

### Requirement: An export warns about unredacted values

Every export that writes values SHALL print a warning that the values were written to disk unredacted and that OPM cannot identify which of them are secret.

- Design: 0014
- Was: `0014:D3:R2`

#### Scenario: warning on export

- **WHEN** an export writes values to disk
- **THEN** a warning says the values are unredacted

### Requirement: An export hides secrets and stays readable

An exported instance SHALL carry no plaintext secret value, and every other field of it stays readable and diffable.

- Design: 0013, Exporting
- Was: `0013:D26:R1`

#### Scenario: a literal secret in an exported instance

- **WHEN** an instance holding a literal at a secret path is exported
- **THEN** that `value` is encrypted in the exported file
- **AND** every other field is plain text

### Requirement: A decrypted export renders like the original

The exported instance, once decrypted by the GitOps tool, SHALL render exactly as the unexported one.

- Design: 0013, Exporting
- Was: `0013:D26:R2`

#### Scenario: the GitOps tool applies an export

- **WHEN** the GitOps tool decrypts an exported instance in the cluster
- **THEN** it renders exactly as the instance that was exported
