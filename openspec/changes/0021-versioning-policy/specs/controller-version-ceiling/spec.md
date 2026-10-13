## Purpose

How the CLI limits the controller versions it will drive or install. The ceiling compares `MAJOR.MINOR` only. This amends the earlier full-version ceiling of enhancement 0006. No seed holds that older rule, so these requirements are ADDED.

## ADDED Requirements

### Requirement: The ceiling compares MAJOR.MINOR only

The CLI SHALL refuse a controller only when the controller's `MAJOR.MINOR` is above the CLI's own. Patch and prerelease differences SHALL never be refused.

#### Scenario: A newer beta counter

- **WHEN** the controller is `1.0.0-beta.3` and the CLI is `1.0.0-beta.2`
- **THEN** the CLI does not refuse it

#### Scenario: A newer minor

- **WHEN** the controller is `1.1.0` and the CLI is `1.0.0`
- **THEN** the CLI refuses the controller

### Requirement: No controller release needs a newer CLI

No controller release SHALL need a CLI newer than the newest released CLI. A change the released CLI cannot drive SHALL ship in a controller release only after a CLI release that drives it.

#### Scenario: A controller change the CLI cannot drive

- **WHEN** a controller change needs a CLI feature that is not yet released
- **THEN** the controller release waits for the CLI release

### Requirement: Install is not refused by the running controller

Installing the controller SHALL NOT be refused because the controller running in the cluster is above the CLI's `MAJOR.MINOR`.

#### Scenario: Repairing a newer controller

- **WHEN** the cluster runs a controller above the CLI's `MAJOR.MINOR` and the user installs the controller
- **THEN** the ceiling does not refuse the install

### Requirement: Install refuses a module with a newer controller

Installing the controller SHALL refuse, before any object changes, a module whose controller `MAJOR.MINOR` is above the CLI's own. The refusal SHALL name upgrading the CLI as the fix.

#### Scenario: A module that deploys a newer controller

- **WHEN** the chosen module deploys a controller `MAJOR.MINOR` above the CLI's
- **THEN** install refuses, changes nothing and tells the user to upgrade the CLI
