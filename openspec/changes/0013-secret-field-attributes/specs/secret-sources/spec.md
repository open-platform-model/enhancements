## Purpose

How a platform offers several ways to materialise a secret, how a deployer picks one per value, and how the platform sets each source's settings. Core defines the envelope once and never names a method.

## ADDED Requirements

### Requirement: A platform carries several secret sources

A platform SHALL carry several secret sources at once, and each SHALL render only the secrets whose deployer named it. The same instance SHALL use different sources for different secrets and per environment without changing the module, and a module SHALL name no backend. A catalog SHALL add a source with no change to core or the kernel.

#### Scenario: Two sources side by side

- **WHEN** a platform enables a plain-Secret source and an external-store source
- **THEN** each secret renders through the source its value names

#### Scenario: A new source needs no core change

- **WHEN** a third party publishes a catalog with a new source
- **THEN** a platform enabling it can use it without a new core or kernel release

### Requirement: A source is named by its contract name

A deployer SHALL name a secret source by the exact name of its contract, apiVersion included, and nothing SHALL resolve a short name or pick a version. A name that is not a defined contract, or that lacks the reserved source annotation, SHALL fail the render with the installed sources listed. A new apiVersion SHALL change nothing for a value that names the old one.

#### Scenario: An unknown source

- **WHEN** a value names a contract the platform does not define
- **THEN** the render fails and lists the sources the platform carries

#### Scenario: A catalog adds an apiVersion

- **WHEN** a catalog publishes a newer apiVersion of a source
- **THEN** a value naming the older one renders as before

### Requirement: A literal renders through the literal source

A literal value SHALL render through the one source the platform marks as the literal source, with the same result as the equivalent named-source form. A platform defining two literal sources SHALL be refused before any instance renders, and a literal on a platform with none SHALL fail naming the missing source. The first-party catalog SHALL ship the literal source.

#### Scenario: Two literal sources

- **WHEN** a platform enables catalogs that define two literal sources
- **THEN** the platform is refused as not routable

#### Scenario: No literal source

- **WHEN** an instance supplies a literal on a platform with no literal source
- **THEN** the render fails naming the missing source

### Requirement: A platform sets a source's settings

A platform SHALL set a source's settings once, and every secret using that source SHALL inherit them. A deployer SHALL override a setting only where the source's schema allows it, and a setting not allowed SHALL fail at the member that set it. A misspelled or wrongly typed setting SHALL fail, and a catalog version bump SHALL NOT lose the platform's settings.

#### Scenario: A platform default

- **WHEN** the platform sets a store for a source and a deployer sets none
- **THEN** every object the source renders uses the platform's store

#### Scenario: A forbidden override

- **WHEN** a deployer overrides a setting the source does not allow
- **THEN** the render fails at the member that set it

### Requirement: Synthesised secret components pass authored checks

The component the kernel synthesises for a secret group SHALL be checked as an authored one is: an entry missing a required field SHALL fail at the deployer's values path, and a secret whose source has no provider SHALL fail the render. It SHALL coexist with every authored component of the instance, whatever their keys, and SHALL never share a name with one.

#### Scenario: An entry missing a field

- **WHEN** a source entry lacks a field the source requires
- **THEN** the render fails at the deployer's values path, even if no transformer reads the field

#### Scenario: A source with no provider

- **WHEN** a value names a source that no installed catalog provides
- **THEN** the render fails even when unprovided demands are otherwise skipped

### Requirement: A secret source in use is a dependency

The render SHALL report every contract it required, including those of synthesised components, so that an instance using a secret source is recorded as depending on that source's contract. A guard that protects contracts in use SHALL refuse to remove it.

#### Scenario: Removing a source in use

- **WHEN** an operator removes a source that an instance uses
- **THEN** the removal is refused while the instance depends on it
