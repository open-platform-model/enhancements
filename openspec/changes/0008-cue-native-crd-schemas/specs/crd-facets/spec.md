## Purpose

How the scope, names, status subresource and display columns of a custom resource are authored. They are data on the same core value as the schema, not comments in Go.

## ADDED Requirements

### Requirement: A resource's facets are authored in core

A CRD's scope, short names, status subresource, printer columns and validation rules SHALL be authored on its value in core. The generated manifest SHALL carry each of them.

#### Scenario: A printer column reaches the manifest

- **WHEN** a printer column is authored on a resource in core
- **THEN** the generated manifest lists that column for the version

#### Scenario: Scope and short names

- **WHEN** a resource is authored as cluster scoped with a short name
- **THEN** the generated manifest carries that scope and that short name

### Requirement: An invalid facet value is refused in core

A scope other than namespaced or cluster, a printer-column type outside the five CRD column types, and a validation rule with no rule text SHALL each be rejected when core evaluates.

#### Scenario: An unknown scope

- **WHEN** a resource names a scope that is neither namespaced nor cluster
- **THEN** core evaluation fails before any manifest is generated

#### Scenario: A validation without a rule

- **WHEN** a validation carries a message and no rule text
- **THEN** core evaluation fails

### Requirement: A resource carries a version and defaults names

A CRD value SHALL carry at least one version. A version MAY omit the singular name, the list kind and the short names, and the API server's defaulting SHALL supply them.

#### Scenario: No version

- **WHEN** a CRD value lists no version
- **THEN** core evaluation fails

#### Scenario: Names left out

- **WHEN** a CRD value omits the singular name, the list kind and the short names
- **THEN** it is accepted, and the generated manifest leaves them to the API server
