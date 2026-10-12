## Purpose

What a `-beta.N` release line promises. A beta line is on the path to GA, and a break on it is declared and migrated, never silent.

## ADDED Requirements

### Requirement: A beta release carries a rising counter

Every release on a beta line SHALL carry a beta prerelease counter on the version the line will reach at GA, and the counter SHALL rise by one with each release of that line.

#### Scenario: The next beta

- **WHEN** a line's latest release is `1.0.0-beta.3`
- **THEN** its next release is `1.0.0-beta.4`

### Requirement: A beta break carries a migration note

A breaking change released on a beta line SHALL be marked breaking in that release's changelog, with a migration note a consumer can follow.

#### Scenario: A breaking release on beta

- **WHEN** a beta release contains a breaking change
- **THEN** its changelog marks it breaking and carries a migration note

### Requirement: A beta break keeps the module path

A breaking change released on a beta line SHALL keep the line's module path and major. No beta release SHALL move a consumer's import to a new major.

#### Scenario: A break during beta

- **WHEN** a beta release breaks an exported definition
- **THEN** the module path and major stay unchanged

### Requirement: A stable line breaks as a new major

A breaking change on a stable line SHALL release as a new major of that stable line. This holds when a dependency's beta break caused the change.

#### Scenario: A beta break reaches a stable catalog

- **WHEN** a dependency's beta break forces a break in a stable catalog line
- **THEN** the catalog releases a new major

### Requirement: A core beta break needs owner sign-off

No core beta release SHALL force a new major on a stable catalog line unless the owner has signed off on that catalog major before the core release ships.

#### Scenario: A core release without sign-off

- **WHEN** a core beta release would force a stable catalog major and no sign-off exists
- **THEN** the core release does not ship

### Requirement: Moving to beta leaves contract levels alone

Moving a release line to beta SHALL change no catalog contract's `apiVersion` level and no promise a contract level makes.

#### Scenario: A line moves to beta

- **WHEN** a release line moves from alpha to beta
- **THEN** every contract keeps its level and its promise

### Requirement: The first GA drops only the suffix

The first GA release of a beta line SHALL carry the same `MAJOR.MINOR.PATCH` with no prerelease suffix. From it on the stable table SHALL bind the line.

#### Scenario: GA of a beta line

- **WHEN** a line at `1.0.0-beta.9` reaches GA
- **THEN** the release is `1.0.0`
