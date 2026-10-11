## ADDED Requirements

### Requirement: A registration alone admits its provider catalog

A provider catalog SHALL be admitted by its accepted registration alone. No admission entry for its path SHALL be required.

#### Scenario: No entry is needed

- **WHEN** a registration is accepted and the platform has no entry for its catalog
- **THEN** the catalog is admitted

### Requirement: A platform entry replaces the provider's window whole

When an admission entry exists for a provider catalog's path, its floor and ceiling SHALL replace the registration's window whole. When none exists, the registration's window SHALL be the effective one, and removing the entry SHALL make the author's window bind again.

#### Scenario: An entry replaces the window

- **WHEN** the platform has an entry with ceiling 1.9.0 and the author's ceiling is 1.8.0
- **THEN** the effective ceiling is 1.9.0

#### Scenario: Removing the entry restores the window

- **WHEN** that entry is deleted
- **THEN** the effective ceiling is 1.8.0 again

### Requirement: A platform range wider than the window warns

A platform range wider than the author's window SHALL be accepted with a warning condition on the registration naming both bounds.

#### Scenario: A wider range warns

- **WHEN** the platform ceiling is 1.9.0 and the author's is 1.8.0
- **THEN** the registration is accepted and carries a warning naming 1.9.0 and 1.8.0

### Requirement: A platform range excluding the version is refused

A platform range that excludes the registration's version SHALL be refused at acceptance.

#### Scenario: The version is excluded

- **WHEN** the platform range is 1.7.0 to 1.9.0 and the registration's version is 1.6.0
- **THEN** the registration is refused

### Requirement: A contract has one provider per declaring major

Acceptance SHALL refuse a claim that provides a contract another enabled platform entry or another active claim already provides, when that holder serves the same major of the declaring catalog, naming the holder and the contract. Providers serving different majors of the declaring catalog SHALL both be accepted and SHALL NOT count against each other. A claim's own catalog SHALL NOT hold a contract against that claim, and an inactive claim SHALL NOT hold one against a competitor.

#### Scenario: A claim is refused against an enabled platform entry

- **WHEN** a claim provides a contract an enabled platform entry serving the same major of the declaring catalog already provides
- **THEN** it is refused, naming the contract and the entry by catalog path with major

#### Scenario: A claim is refused against an active claim

- **WHEN** a claim provides a contract another active claim serving the same major of the declaring catalog already provides
- **THEN** it is refused, naming the contract and the holding claim

#### Scenario: Providers of different majors are both accepted

- **WHEN** one claim serves the older major of the declaring catalog, another serves the newer, and both provide one contract
- **THEN** both are accepted

#### Scenario: An active claim is not refused against its own catalog

- **WHEN** an active claim is judged again against a platform that now carries its own catalog
- **THEN** it is not refused for providing its own contracts

## MODIFIED Requirements

### Requirement: A build-incompatible provider is refused at acceptance

Acceptance SHALL compare the catalog's committed requirements with the static floor of the admitted entry that shares the provider's major, on each shared platform path, and SHALL refuse a claim that requires a newer version within that major, naming the provider and the path. It SHALL refuse a different major only when no admitted entry shares it. The refusal SHALL say the comparison is conservative and that lowering the requirement is the author's fix.

#### Scenario: A provider requiring a newer build is refused

- **WHEN** the catalog requires a shared path at a higher version than the floor of the admitted entry of its major
- **THEN** the claim is refused, naming the path, both versions and the one-line fix

#### Scenario: A provider on a different major is refused

- **WHEN** the catalog requires a shared path in a major no admitted entry shares
- **THEN** the claim is refused without comparing versions

#### Scenario: A provider requiring an older build is accepted by this check

- **WHEN** every shared requirement is at or below the floor of the admitted entry of its major
- **THEN** this check does not refuse the claim

#### Scenario: A provider is compared against the entry of its own major

- **WHEN** the platform admits two majors of a catalog and the provider requires a version of the older one
- **THEN** the comparison uses the older major's floor, never the newer's

## REMOVED Requirements

### Requirement: A contract has one provider

**Reason**: The count of providers is taken per declaring major. Two majors of one catalog are no longer two providers of one contract.

**Migration**: Replaced by "A contract has one provider per declaring major"
