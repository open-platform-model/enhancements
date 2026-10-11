## Purpose

How CEL validation rules reach a generated CRD. Core stores a rule as text. It never evaluates a rule, translates one, or derives one from a CUE constraint.

## ADDED Requirements

### Requirement: A CEL rule is carried unchanged

A CEL rule authored on a version of a CRD value SHALL appear in the generated manifest's validation rules exactly as written, with its message and its metadata fields.

#### Scenario: A rule with a message

- **WHEN** a rule and its message are authored on a version
- **THEN** the generated manifest holds the same rule text and the same message

### Requirement: No CEL rule is invented or translated

A generated CRD SHALL carry no CEL rule that was not authored on its core value, and no CUE constraint SHALL be derived from a CEL rule.

#### Scenario: A CUE constraint adds no rule

- **WHEN** a field has a CUE constraint and no rule is authored for it
- **THEN** the generated manifest carries no rule for that field

#### Scenario: A rule adds no constraint

- **WHEN** a CEL rule is authored on a version
- **THEN** core gains no CUE constraint from it

### Requirement: The Platform CRD carries its singleton rule

The generated `Platform` CRD SHALL carry, unchanged, the rule that the only permitted name of a Platform is `cluster`.

#### Scenario: A Platform with another name is refused

- **WHEN** a Platform with any name other than `cluster` is applied
- **THEN** the API server rejects it at admission
