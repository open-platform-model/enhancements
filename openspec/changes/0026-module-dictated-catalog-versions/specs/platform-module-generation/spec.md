## ADDED Requirements

### Requirement: The Platform spec is the authored platform

A Platform SHALL carry a required informational type and an authored platform: a registry keyed by major-suffixed catalog path, each entry an admission entry with a required floor, an optional ceiling, an optional enable flag defaulting to true and a prerelease opt-in defaulting to off. An entry without a floor SHALL be rejected at platform validation. No allow or deny filter SHALL exist. The skew policy, Warn (default) or Refuse, SHALL stay outside the generated module.

#### Scenario: A minimal Platform is accepted

- **WHEN** a Platform sets a type and one registry entry that carries only a floor
- **THEN** the API server accepts it, the enable flag reads true, prereleases read off and the skew policy reads Warn

#### Scenario: A missing type is rejected

- **WHEN** a Platform is applied without a type
- **THEN** the API server rejects it as a missing required field

#### Scenario: A filter is not accepted

- **WHEN** a Platform is applied with a filter under an entry
- **THEN** the field never reaches the reconciler

#### Scenario: An invalid skew policy is rejected

- **WHEN** a Platform sets a skew policy other than Warn or Refuse
- **THEN** the API server rejects it

#### Scenario: An entry without a floor is rejected

- **WHEN** a Platform has an entry that lacks a floor
- **THEN** platform validation rejects it

## MODIFIED Requirements

### Requirement: Generation is pure and deterministic

The generator SHALL produce a platform module from typed input alone: the platform's name and type, its registry entries (catalog path with major, catalog build, enable flag), the module path and the resolved dependency list. It SHALL read no environment, do no I/O, and emit entries and dependencies in sorted path order, so identical input yields byte-identical output. The module SHALL embed `#ResolvedPlatform`, import every entry's catalog, and carry one `#registry` entry per subscription.

#### Scenario: Same input, same bytes

- **WHEN** the generator runs twice on the same entries and dependencies in different orders
- **THEN** both results are byte-identical, with entries and dependencies sorted by path

#### Scenario: Two catalogs

- **WHEN** two enabled entries for different catalogs are generated with a dependency list that pins both
- **THEN** the module imports both under distinct names, and its `#registry` carries both keys, enabled, each with its expected version and its imported catalog

#### Scenario: A disabled entry still imports its catalog

- **WHEN** an entry is generated with its enable flag false
- **THEN** the catalog is still imported and the dependency list still pins it, and the entry carries the false flag

#### Scenario: Invalid input is refused

- **WHEN** the input has an empty name, type or module path, a duplicate registry path, an entry or dependency with an empty path or version, a dependency pinned twice at different versions, or a dependency list that lacks core or an entry's catalog
- **THEN** generation fails naming the offending field or path and emits nothing

### Requirement: The package depends on spec and active claims

The controller SHALL generate the package once per distinct resolution, from exactly three inputs: the resolved catalog set, the Platform's spec and the set of accepted and active claims, computed from their current state and never from the event that woke it. With no active claim it SHALL generate what the spec alone implies. A claim whose deletion is blocked SHALL stay in the active set until the block releases; a deletion timestamp alone SHALL NOT drop its catalog.

#### Scenario: An active claim's catalog reaches the package

- **WHEN** a claim becomes active and no consumer pins its catalog's path
- **THEN** the regenerated package carries that provider's catalog as a registry entry at the claim's version

#### Scenario: The waking event is ignored

- **WHEN** regeneration is woken by an event about a claim that has since left the active set
- **THEN** the package matches the one the current state implies, with that claim's catalog absent

#### Scenario: No active claim leaves the spec alone

- **WHEN** no claim is accepted and active
- **THEN** the package is a function of the Platform's spec alone, and the same inputs reconciled twice give byte-identical content

#### Scenario: A blocked claim's catalog survives regeneration

- **WHEN** the package is regenerated while an active claim is terminating and its deletion is blocked
- **THEN** the package still carries that claim's catalog, and the claim's dependents keep rendering

#### Scenario: A released claim leaves the active set

- **WHEN** a terminating claim's block releases
- **THEN** the next regenerated package no longer carries that claim's catalog

### Requirement: Platform status names the package and its registry

Each package SHALL carry an identity derived from the resolved catalog set, the Platform's generation and the sorted active claim coordinates: equal inputs give equal identities and any change gives a new one. Platform status SHALL report the identity of the package renders consume and the resolved registry, with each entry's source (subscription or claim), version and whether it registers transformers. Every render SHALL log the identity it consumed.

#### Scenario: A claim change yields a new identity

- **WHEN** a claim activates while the Platform's generation is unchanged
- **THEN** the regenerated package carries a different identity than the previous one

#### Scenario: The union shows both sources

- **WHEN** a platform has an authored subscription and an active claim
- **THEN** the status lists both, and says which entry came from which source

#### Scenario: A disabled subscription is listed as not registering

- **WHEN** a platform authors a subscription with enable false
- **THEN** the status lists its catalog and marks it as contributing no transformer

#### Scenario: The status follows the active set

- **WHEN** a claim stops being active
- **THEN** the next package's identity differs and the status no longer lists its catalog

#### Scenario: A render reports what it consumed

- **WHEN** a render completes
- **THEN** the identity of the package it built against is written to the reconcile log, so the render is attributable to an exact registry state

## REMOVED Requirements

### Requirement: The Platform spec names type and pinned subscriptions

**Reason**: An entry now carries a floor and an optional ceiling, not one exact pinned version.

**Migration**: Replaced by "The Platform spec is the authored platform"
