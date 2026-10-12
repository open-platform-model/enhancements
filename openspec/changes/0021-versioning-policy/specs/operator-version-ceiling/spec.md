## Purpose

How the CLI limits the operator versions it will drive or install. The ceiling compares `MAJOR.MINOR` only. This amends the earlier full-version ceiling of enhancement 0006. No seed holds that older rule, so these requirements are ADDED.

## ADDED Requirements

### Requirement: The ceiling compares MAJOR.MINOR only

The CLI SHALL refuse an operator only when the operator's `MAJOR.MINOR` is above the CLI's own. Patch and prerelease differences SHALL never be refused.

#### Scenario: A newer beta counter

- **WHEN** the operator is `1.0.0-beta.3` and the CLI is `1.0.0-beta.2`
- **THEN** the CLI does not refuse it

#### Scenario: A newer minor

- **WHEN** the operator is `1.1.0` and the CLI is `1.0.0`
- **THEN** the CLI refuses the operator

### Requirement: No operator release needs a newer CLI

No operator release SHALL need a CLI newer than the newest released CLI. A change the released CLI cannot drive SHALL ship in an operator release only after a CLI release that drives it.

#### Scenario: An operator change the CLI cannot drive

- **WHEN** an operator change needs a CLI feature that is not yet released
- **THEN** the operator release waits for the CLI release

### Requirement: Install is not refused by the running operator

Installing the operator SHALL NOT be refused because the operator running in the cluster is above the CLI's `MAJOR.MINOR`.

#### Scenario: Repairing a newer operator

- **WHEN** the cluster runs an operator above the CLI's `MAJOR.MINOR` and the user installs the operator
- **THEN** the ceiling does not refuse the install

### Requirement: Install refuses a module with a newer operator

Installing the operator SHALL refuse, before any object changes, a module whose operator `MAJOR.MINOR` is above the CLI's own. The refusal SHALL name upgrading the CLI as the fix.

#### Scenario: A module that deploys a newer operator

- **WHEN** the chosen module deploys an operator `MAJOR.MINOR` above the CLI's
- **THEN** install refuses, changes nothing and tells the user to upgrade the CLI
