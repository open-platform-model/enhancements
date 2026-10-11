## Purpose

How a platform states whom it trusts, how every artifact it materializes is checked against that statement before its content is used, and who enforces and who reports a failed check.

## ADDED Requirements

### Requirement: A platform declares whom it trusts

A platform SHALL declare whom it trusts, the signer identities and the builders it accepts, on the platform itself. The declaration SHALL apply to the whole platform and MAY be overridden for one subscription.

#### Scenario: A subscription overrides the platform

- **WHEN** a platform accepts one signer for all its subscriptions and names a stricter signer for one catalog subscription
- **THEN** the stricter signer governs that subscription and the platform-wide signer governs the others

### Requirement: Every materialized artifact is verified first

Every artifact that a platform with a declared trust policy materializes SHALL be verified against that policy before its content is used.

#### Scenario: A signer outside the policy

- **WHEN** a platform that accepts only one signer materializes an artifact signed by a different one
- **THEN** the verdict reports that the signer is not accepted
- **AND** the artifact's content has not been used when the verdict is reached

### Requirement: The CLI and operator reach one verdict

The CLI and the operator SHALL reach the same verdict for the same artifact and the same policy.

#### Scenario: One artifact, two frontends

- **WHEN** the CLI and the operator verify the same artifact against the same policy
- **THEN** both report the same verdict

### Requirement: The operator enforces and the CLI reports

A failing verdict SHALL be enforced by the operator and reported by the CLI.

#### Scenario: The operator meets a failing artifact

- **WHEN** an artifact of a subscription fails the platform's trust policy in the operator
- **THEN** the operator enforces the failing verdict and does not use the artifact's content

#### Scenario: The CLI meets a failing artifact

- **WHEN** the CLI verifies an artifact that fails the policy
- **THEN** it reports the failing verdict
