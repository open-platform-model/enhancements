## Purpose

Decide what a platform's contract inventory does to the tools that read it. The offline platform check and the operator's generation of a platform package read the same findings. Some findings fail the check and refuse generation. Some are only reported. Neither tool recounts what core derived.

## ADDED Requirements

### Requirement: The check reports a platform's contract inventory

The platform check SHALL build the resolved platform through the kernel and report what its core derives: each defined contract with its defining catalog and its implementations, the provider-fulfilled contracts nothing implements, over-subscribed contracts, comparable transformer pairs, and one verdict each for fulfilled, routable and discriminated. It SHALL apply and render nothing.

#### Scenario: A healthy platform reports clean

- **WHEN** every defined contract is implemented once and transformers that share a contract are told apart
- **THEN** the report lists the defined contracts with their defining catalogs, states that nothing is unfulfilled, over-subscribed or comparable, and the check exits 0

#### Scenario: The report names the defining catalog

- **WHEN** an enabled catalog defines a contract
- **THEN** the report shows that catalog's registry key beside the contract key

#### Scenario: The report names both transformers of a comparable pair

- **WHEN** two enabled transformers have comparable predicates over a catalog-fulfilled contract
- **THEN** the report lists the pair under its own heading, marks the broader and the narrower transformer, and names the shared contracts

#### Scenario: A verdict never says yes against a false boolean

- **WHEN** the inventory reads false for fulfilled, routable or discriminated
- **THEN** the matching verdict line says no and names how many findings produced it

### Requirement: Verdicts read vacuous only when nothing is defined

The report SHALL word a verdict as vacuous only when no enabled catalog defines a contract and no enabled transformer provides one. It SHALL then say that the catalogs define no contracts, so a vacuous answer is distinguishable from a verified one.

#### Scenario: Catalogs that list nothing report an empty inventory

- **WHEN** no catalog populates a contract map and no transformer requires a provider-fulfilled contract
- **THEN** the report says the catalogs define no contracts, nothing was verified, and words all three verdicts as vacuous

#### Scenario: Providers of an undefined contract are not vacuous

- **WHEN** no enabled catalog defines a contract and transformers of two enabled registry entries require one provider-fulfilled contract
- **THEN** no verdict is worded as vacuous, the contract is listed as over-subscribed and defined by no enabled catalog, and routable reads no

### Requirement: An unfulfilled contract is reported, not failed

A provider-fulfilled contract that no enabled transformer implements SHALL be listed with its defining catalog and SHALL NOT change the exit status. A platform may define a contract ahead of the provider that implements it, and the render that demands an unmet contract is the one that refuses.

#### Scenario: An unfulfilled contract exits zero

- **WHEN** the platform defines a provider-fulfilled contract that nothing implements
- **THEN** the report names the contract and its defining catalog, and the check exits 0

#### Scenario: The report keeps unfulfilled and over-subscribed apart

- **WHEN** one contract is unfulfilled and another is over-subscribed
- **THEN** they appear under separate headings, and only the over-subscription decides the exit status

### Requirement: An over-subscribed contract fails the check

A provider-fulfilled contract required by transformers of more than one enabled registry entry SHALL be listed with every providing entry (catalog path with major, sorted), and the check SHALL fail with the validation exit code.

#### Scenario: Two catalogs providing one contract exit non-zero

- **WHEN** transformers of two enabled catalogs each require one provider-fulfilled contract
- **THEN** the report names the contract and both registry keys as its providers, and the check exits with the validation code

#### Scenario: Two majors of one catalog are two providers

- **WHEN** two majors of one provider catalog are enabled and each has a transformer requiring one provider-fulfilled contract
- **THEN** the report lists the contract as over-subscribed with both registry keys, and the check exits with the validation code

#### Scenario: Plurality of catalog-fulfilled implementations is not over-subscription

- **WHEN** several transformers across enabled catalogs require one catalog-fulfilled contract
- **THEN** the report lists no over-subscribed contract for it

#### Scenario: A disabled defining catalog does not hide over-subscription

- **WHEN** the catalog that defines a provider-fulfilled contract is disabled and transformers of two other enabled entries require it
- **THEN** the report lists the contract as over-subscribed and defined by no enabled catalog, and the check exits with the validation code

### Requirement: An undiscriminated platform fails the check

A pair of enabled transformers whose match predicates are comparable over a shared catalog-fulfilled contract SHALL be listed, naming the broader transformer, the narrower transformer and the shared contracts, and the check SHALL fail with the validation exit code. No arbitration between the two SHALL be applied or suggested. A pair with incomparable predicates SHALL be listed as implementations only.

#### Scenario: A comparable pair exits non-zero

- **WHEN** one transformer requires a catalog-fulfilled resource alone and another requires the same resource plus a trait
- **THEN** the report names the first as broader, the second as narrower and the resource as shared, states the platform is not discriminated, and the check exits with the validation code

#### Scenario: Discriminated plurality exits zero

- **WHEN** several transformers require the same catalog-fulfilled contract and each adds a required label value or trait the others lack
- **THEN** the report lists them as implementations, states the platform is discriminated, and the check exits 0

### Requirement: One failure names every count

When the check fails on a finding, it SHALL print the whole report and then one error naming the number of over-subscribed contracts and comparable pairs, and SHALL exit once with the validation code. The two findings have different fixes, so neither SHALL hide the other.

#### Scenario: Over-subscription and a comparable pair are reported together

- **WHEN** a platform is over-subscribed on one contract and undiscriminated on another
- **THEN** both appear under their own headings, both verdict lines say no, and the error names both counts

### Requirement: The report states which platform it describes

The first line of the report SHALL name the platform checked and how it was chosen, so a report cannot be read as describing another platform. A directory given as an argument SHALL be the platform checked. A directory that is not a platform module SHALL be refused as platform resolution states, with the not-found exit.

#### Scenario: The report states its provenance

- **WHEN** the check runs against a platform directory given as an argument
- **THEN** the first line names that directory and says it came from the argument

#### Scenario: A directory that is not a platform module is refused

- **WHEN** the directory has no CUE module manifest
- **THEN** the check fails with a not-found error naming the directory

### Requirement: An unbuildable platform fails with a diagnostic

If the resolved platform does not build, the check SHALL print the build failure with the CLI's grouped CUE diagnostics, print no contract report and exit with the validation code. A failed build SHALL NOT be reported as an empty inventory.

#### Scenario: A broken platform module reports the build error

- **WHEN** a registry entry names a catalog that cannot be resolved
- **THEN** the check prints the build diagnostic, prints no contract report and exits with the validation code

### Requirement: A refused registry credential exits as permission denied

When the platform does not build because the registry refused the credentials, the check SHALL print the registry's answer and a login hint in place of the grouped diagnostics, and SHALL exit with the permission-denied code in place of the validation code. The hint SHALL name the registry host when every dependency the platform declares routes to one host, and SHALL be the bare login command otherwise.

#### Scenario: One registry host refuses the credentials

- **WHEN** a registry answers 401 and every declared dependency routes to that host
- **THEN** the check prints the answer and the login hint naming the host, exits with the permission-denied code and prints no contract report

#### Scenario: Several registry hosts

- **WHEN** a registry answers 401 and the declared dependencies route to more than one host
- **THEN** the hint is the bare login command without a host, and the exit code is permission denied

### Requirement: An unreadable inventory fails naming its cause

If the platform builds but its inventory cannot be read, the check SHALL fail with the validation code, with the refusal that the inventory read gives (the missing field and the core release that introduced it), and SHALL print no partial report.

#### Scenario: A core that derives no inventory

- **WHEN** the platform pins a core release that derives no contract inventory
- **THEN** the check fails naming the missing field and the core release required, and reports no empty inventory

#### Scenario: A core that derives no provider count

- **WHEN** the platform pins a core release that derives the inventory but not its provider count
- **THEN** the check fails with the validation code naming that field, and prints no partial report

### Requirement: The gates read core's counts and recount nothing

The check and the generation gate SHALL take the over-subscribed contracts, comparable pairs and their providers from the inventory as core reports them, and SHALL NOT recompute any.

#### Scenario: The check and the gate report the inventory's providers as given

- **WHEN** the inventory read lists a contract as over-subscribed with the providing entries it names
- **THEN** the check's report and the gate's message name that contract with exactly those entries, in sorted order, and neither names an entry the inventory does not list

### Requirement: An over-subscribed platform is refused at generation

After a generated platform module builds, when the inventory shows a provider-fulfilled contract provided by more than one enabled registry entry and no key collides, the reconciler SHALL refuse the package: Ready SHALL be False with reason OverSubscribedContracts and a message naming, in sorted order, each contract, its defining catalog when an enabled one defines it, and every providing entry. An unroutable inventory that names no cause and no colliding key SHALL be refused the same way.

#### Scenario: Two catalogs providing one contract are refused

- **WHEN** the inventory lists a provider-fulfilled contract provided by each of two enabled registry entries
- **THEN** Ready is False with reason OverSubscribedContracts, the message names the contract, its defining catalog and both entries, and no package is recorded for that tuple

#### Scenario: Two majors of one provider catalog are refused

- **WHEN** two majors of one provider catalog are enabled, each has a transformer requiring the same provider-fulfilled contract, and no contract key is listed by both majors
- **THEN** Ready is False with reason OverSubscribedContracts, naming both entries, and no package is recorded

#### Scenario: A contract whose defining catalog is not enabled is still counted

- **WHEN** the defining catalog is disabled or absent and two enabled entries provide the contract
- **THEN** Ready is False with reason OverSubscribedContracts and the message names the contract and both entries without a defining catalog

#### Scenario: An unroutable inventory that names nothing still refuses

- **WHEN** the inventory reads not routable and lists no over-subscribed contract and no colliding contract key
- **THEN** Ready is False with reason OverSubscribedContracts, the message says the inventory names no cause, and it never reports a count of zero over-subscribed contracts

### Requirement: An undiscriminated platform is refused at generation

When the inventory is routable and reports a pair of enabled transformers with comparable predicates over a shared catalog-fulfilled contract, the reconciler SHALL refuse the package: Ready SHALL be False with reason ComparablePredicates, and the message SHALL name for each pair the broader transformer, the narrower transformer and the shared contracts, in a deterministic order. No arbitration, ordering or most-specific-wins rule SHALL be applied.

#### Scenario: A comparable pair is refused naming both transformers

- **WHEN** the inventory reports one comparable pair over one catalog-fulfilled contract
- **THEN** Ready is False with reason ComparablePredicates, the message names the broader transformer, the narrower transformer and the shared contract, and no package is recorded

#### Scenario: Discriminated transformers coexist

- **WHEN** the inventory is routable and reports no comparable pair, however many transformers share a catalog-fulfilled contract
- **THEN** the gate refuses nothing and the package is recorded

### Requirement: One refusal reports every finding

A refused package SHALL carry one reason and one message that holds every finding. When no contract key collides, the reason SHALL be OverSubscribedContracts when the platform is over-subscribed or unroutable, and ComparablePredicates otherwise. A platform that is routable and discriminated SHALL NOT be refused on these grounds.

#### Scenario: Both routing findings report under the routing reason

- **WHEN** the inventory is over-subscribed and not discriminated
- **THEN** the reason is OverSubscribedContracts and the message names the over-subscribed contracts and the comparable pairs

### Requirement: A refusal recovers when its cause is removed

A refusal SHALL be computed from the current inputs and never latched. Once the built inventory is routable and discriminated, the package SHALL be recorded and the Platform SHALL report Ready True with reason Generated, with nothing to clear by hand.

#### Scenario: Removing the competing catalog recovers

- **WHEN** a refused tuple's competing catalog is disabled in the registry or its claim is removed
- **THEN** the next reconcile records the package and Ready is True with reason Generated

### Requirement: Unfulfilled contracts are reported, never refused

The reconciler SHALL write a ContractsFulfilled condition from the inventory of the package renders consume, on a fresh build and when the package is already current. It SHALL be False with reason UnfulfilledContracts naming each unimplemented contract and its defining catalog, True with reason ContractsFulfilled when each has a provider, and True with reason NoContractsDefined when none is defined. It SHALL NOT move Ready, and a refusal SHALL NOT rewrite it.

#### Scenario: An unfulfilled contract reports beside a generated platform

- **WHEN** the inventory lists a provider-fulfilled contract that no enabled transformer requires
- **THEN** Ready is True with reason Generated and ContractsFulfilled is False with reason UnfulfilledContracts, naming the contract and its defining catalog

#### Scenario: Every contract fulfilled

- **WHEN** the inventory defines contracts and lists none unfulfilled
- **THEN** ContractsFulfilled is True with reason ContractsFulfilled

#### Scenario: No contract defined is visible, not a pass

- **WHEN** the inventory defines no contract
- **THEN** ContractsFulfilled is True with reason NoContractsDefined and the message says nothing was verified

#### Scenario: The skip path keeps the condition current

- **WHEN** a reconcile finds the held package already current for the tuple
- **THEN** ContractsFulfilled is written from the held package's inventory
