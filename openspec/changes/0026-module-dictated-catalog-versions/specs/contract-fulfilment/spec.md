## ADDED Requirements

### Requirement: A provider-fulfilled contract admits one provider per resolution

A resolution SHALL carry exactly one provider of a provider-fulfilled contract: an enabled registry entry, keyed by catalog path with its major, whose transformers require the contract. Several transformers of one entry are one provider. Providers of different majors of the declaring catalog SHALL NOT count against each other. Core SHALL compute this count once, in the platform's contract inventory, which the inventory capability states; consumers read that one count and keep none of their own.

#### Scenario: Providers of different majors are not counted together

- **WHEN** one provider serves the older major of the declaring catalog, another serves the newer, and both require one provider-fulfilled contract
- **THEN** both are accepted and neither counts against the other

#### Scenario: Several transformers of one entry are one provider

- **WHEN** one enabled entry ships two transformers that require the same provider-fulfilled contract and no other entry requires it
- **THEN** the contract has one provider and meets the exactly-one rule

### Requirement: Two providers of one major are refused

Two providers serving the same major of the declaring catalog SHALL still be refused: the contract has two providers and does not meet the exactly-one rule.

#### Scenario: Two providers of one major are refused

- **WHEN** two providers serving the same major of the declaring catalog require one provider-fulfilled contract
- **THEN** the contract has two providers and does not meet the exactly-one rule

## REMOVED Requirements

### Requirement: A provider-fulfilled contract admits exactly one provider

**Reason**: The count is taken per resolution. Two majors of one catalog are no longer two providers of one contract across the whole platform.

**Migration**: Replaced by "A provider-fulfilled contract admits one provider per resolution"
