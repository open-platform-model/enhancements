<!-- MOCKUP EXCERPT. Shows one enhancement changing another's requirement. See openspec/MOCKUP.md. -->

## ADDED Requirements

### Requirement: 0013:D26:R1

An exported instance SHALL carry no plaintext secret value, and every other field of it stays readable and diffable.

- Decision: `0013`, D26

#### Scenario: a literal secret in an exported instance

- **WHEN** an instance holding a literal at a secret path is exported
- **THEN** that `value` is encrypted in the exported file
- **AND** every other field is plain text

## MODIFIED Requirements

### Requirement: 0014:D3:R1

The exported `ModuleInstance` SHALL carry the live CR's `spec.values` byte-for-byte, except the `value` of a literal at a secret path, which is encrypted; no other value is redacted, substituted or omitted.

- Decision: `0014`, D3
- Modified by: `0013`, D26

#### Scenario: values survive export unchanged

- **WHEN** an instance with no literal secret is exported
- **THEN** the exported `spec.values` equal the live CR's `spec.values` byte-for-byte

#### Scenario: a literal secret is the one exception

- **WHEN** an instance with a literal at a secret path is exported
- **THEN** only that `value` differs from the live CR
