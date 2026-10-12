# registration-acceptance Specification

## Purpose
Decide whether a provider's claim to supply contracts to a platform is accepted. A claim is a registration a provider module renders. Acceptance re-derives every fact it judges instead of trusting what the claim says, and a refusal names what failed and the value that failed it.

## Requirements

### Requirement: Every claim receives a verdict

Acceptance SHALL give every registration a recorded verdict, accepted or refused. A refusal SHALL name the failed check and the offending value, and a claim SHALL NOT be partly honoured.

#### Scenario: An accepted claim reports acceptance

- **WHEN** a claim passes every check
- **THEN** it is recorded as accepted

#### Scenario: A refused claim names its reason

- **WHEN** a claim fails any check
- **THEN** it is recorded as refused, and the record names the failing check and the offending value

### Requirement: The claimed artifact must be a catalog

Acceptance SHALL acquire the artifact the claim names and SHALL refuse the claim unless it is a catalog. An artifact that cannot be resolved SHALL be refused with a reason distinct from one that resolves as the wrong kind.

#### Scenario: A module artifact is refused

- **WHEN** the claim names an artifact that is a module
- **THEN** the claim is refused, naming the kind found

#### Scenario: An unresolvable coordinate is refused distinguishably

- **WHEN** the claim names a coordinate the registry does not hold
- **THEN** the claim is refused with a reason distinct from the wrong-kind refusal, naming the coordinate

### Requirement: The provider set is re-derived and compared

Acceptance SHALL derive the set of provider-fulfilled contracts from the acquired catalog and SHALL refuse a claim whose list differs in either direction, naming both lists. A subset SHALL NOT be accepted.

#### Scenario: A claim listing an unimplemented contract is refused

- **WHEN** the claim lists a contract the catalog does not provide
- **THEN** the claim is refused, naming the claimed and the derived list

#### Scenario: A claim omitting an implemented contract is refused

- **WHEN** the catalog provides a contract the claim omits
- **THEN** the claim is refused, naming both lists

### Requirement: A claim must come from its named instance

Acceptance SHALL refuse a claim that the module instance it names does not own. A claim that arrives before its instance has recorded its inventory SHALL wait for a verdict and SHALL NOT be refused.

#### Scenario: A claim its named instance does not own is refused

- **WHEN** the named instance has a settled inventory that does not hold this claim
- **THEN** the claim is refused, naming both identities

#### Scenario: A claim racing its instance is not refused

- **WHEN** the named instance exists but has recorded no inventory yet
- **THEN** no verdict is recorded and the claim is retried

### Requirement: A second claim for one provider is refused

When more than one claim names the same provider catalog, acceptance SHALL accept at most one, SHALL refuse the others naming the holder, and SHALL keep the same holder across reconciles. A claim whose deletion is blocked SHALL keep holding the provider.

#### Scenario: The second claim is refused naming the first

- **WHEN** two instances of one provider module each render a claim for the same catalog
- **THEN** one is accepted and the other is refused, naming the accepted claim

#### Scenario: A blocked deletion keeps the hold

- **WHEN** a new claim for the same catalog is judged while the holder's deletion is blocked
- **THEN** the new claim is refused, naming the blocked claim

### Requirement: A contract has one provider

Acceptance SHALL refuse a claim that provides a contract another enabled platform entry or another active claim already provides, naming the holder and the contract. Two majors of one catalog SHALL count as two providers. A claim's own catalog SHALL NOT hold a contract against that claim, and an inactive claim SHALL NOT hold one against a competitor.

#### Scenario: A claim is refused against an enabled platform entry

- **WHEN** a claim provides a contract an enabled platform entry already provides
- **THEN** it is refused, naming the contract and the entry by catalog path with major

#### Scenario: A claim is refused against an active claim

- **WHEN** a claim provides a contract another active claim already provides
- **THEN** it is refused, naming the contract and the holding claim

#### Scenario: An active claim is not refused against its own catalog

- **WHEN** an active claim is judged again against a platform that now carries its own catalog
- **THEN** it is not refused for providing its own contracts

#### Scenario: Another major of the claim's own catalog is another provider

- **WHEN** a claim for one major of a catalog provides a contract that an enabled entry for a different major of the same catalog already provides
- **THEN** it is refused, naming the contract and the other major's entry

### Requirement: A build-incompatible provider is refused at acceptance

Acceptance SHALL compare the catalog's committed requirements with the platform's resolved versions on each shared platform path, and SHALL refuse a claim that requires a newer version within the same major, or a major the platform does not resolve for that path. The refusal SHALL say the comparison is conservative and that lowering the requirement is the author's fix.

#### Scenario: A provider requiring a newer build is refused

- **WHEN** the catalog requires a shared path at a higher version than the platform resolves, same major
- **THEN** the claim is refused, naming the path, both versions and the one-line fix

#### Scenario: A provider on a different major is refused

- **WHEN** the catalog requires a shared path in a major the platform does not resolve
- **THEN** the claim is refused without comparing versions

#### Scenario: A provider requiring an older build is accepted by this check

- **WHEN** every shared requirement is at or below the platform's resolved version within the same major
- **THEN** this check does not refuse the claim

### Requirement: An accepted claim survives a transient registry failure

When the registry fails transiently while acquiring the claimed catalog, an accepted claim whose spec is unchanged SHALL keep its verdict, report the failure, and be retried with backoff. Any other acquisition failure SHALL refuse the claim.

#### Scenario: An accepted claim survives an unreachable registry

- **WHEN** an accepted, active claim is reconciled while the registry cannot be reached
- **THEN** it stays accepted and active, and the failure is reported without changing the verdict

#### Scenario: A catalog the registry does not hold un-accepts

- **WHEN** an accepted claim is reconciled and the registry answers that it does not hold the catalog at that version
- **THEN** the claim is refused

#### Scenario: An edited claim is refused, not held

- **WHEN** an accepted claim's version is changed and the registry cannot be reached
- **THEN** the claim is refused, naming the new version
