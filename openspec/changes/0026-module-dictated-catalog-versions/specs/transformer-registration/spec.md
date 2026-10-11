## ADDED Requirements

### Requirement: A provider may state a compatibility window

A provider module MAY state a floor and a ceiling on its registration, the compatibility window of its catalog. Each SHALL default to the registration's version, so a provider that states none behaves as before. The catalog, the version and the list of provided contracts SHALL stay derived and verified.

#### Scenario: No window stated

- **WHEN** a provider states no floor or ceiling
- **THEN** both equal the registration's version

#### Scenario: A window stated

- **WHEN** a provider states floor 1.4.0 and ceiling 1.8.0 around version 1.6.0
- **THEN** its registration carries floor 1.4.0 and ceiling 1.8.0

## MODIFIED Requirements

### Requirement: Every claim field is required at admission

The API server SHALL reject a claim that lacks the provider catalog's module path, its version, its list of provided contracts, or the namespace and name of the claiming instance. The path and the version SHALL be non-empty; the list MAY be empty. The check SHALL NOT be left to the authoring catalog, because a missing required field in CUE is an incomplete value, not an error. A rendered claim SHALL carry a floor and a ceiling, defaults filled, so the claim reads without the provider module.

#### Scenario: A claim missing its catalog is rejected

- **WHEN** a claim is applied with a version, a provided list and a claiming instance but no catalog path
- **THEN** the API server rejects it, naming the missing field

#### Scenario: A claim with an empty version is rejected

- **WHEN** a claim is applied with an empty version
- **THEN** the API server rejects it

#### Scenario: A claim with an empty provided list is accepted

- **WHEN** a claim is applied whose provided list is empty
- **THEN** the API server accepts it, because a catalog that implements no provider-fulfilled contract is a claim that acceptance refuses on its merits, not a malformed object

#### Scenario: A defaulted window is visible

- **WHEN** a provider states no window and its claim is rendered
- **THEN** the claim shows a floor and a ceiling equal to its version

### Requirement: Claim status separates acceptance from activation

A claim's status SHALL carry conditions, an accepted flag, an active flag and the generation last reconciled, so that a stored claim reports one of three states: not yet judged, accepted but inactive, or active. The status SHALL also report the effective window and its source, platform or provider. The platform SHALL set the active flag when an accepted claim's provider is ready. Recording the verdict itself is the work of acceptance.

#### Scenario: Status records the generation reconciled

- **WHEN** a valid claim is applied and the operator is running
- **THEN** the generation recorded in its status matches the claim's generation

#### Scenario: An accepted claim can be inactive

- **WHEN** a claim is accepted and its provider is not yet ready
- **THEN** the accepted flag is true and the active flag is false

#### Scenario: The source is reported

- **WHEN** a platform entry sets the window
- **THEN** the status reports that window with source platform
