## Purpose

How operations reach a platform. The library owns the mechanism. A catalog owns what an operation does. A platform gains an operation by subscribing a catalog, with no library release.

## ADDED Requirements

### Requirement: A catalog publishes operations beside transformers

A `#Catalog` SHALL carry `#ops` and `#actions` maps beside `#transformers`, keyed by identity. A catalog that omits them SHALL keep its meaning.

#### Scenario: A catalog with operations

- **WHEN** a catalog publishes an operation and an action
- **THEN** they appear under `#ops` and `#actions`, keyed by identity

#### Scenario: An existing catalog

- **WHEN** a catalog that omits `#ops` and `#actions` is read
- **THEN** its `#transformers` and every other field are the same as before the maps existed

### Requirement: An actions entry is keyed by action identity

An `#actions` entry SHALL be keyed by the identity of the action it contains.

#### Scenario: A mismatched key

- **WHEN** an entry's key differs from the identity of its action
- **THEN** the catalog is rejected

### Requirement: A platform gains an operation by subscription

A platform SHALL gain a new operation by subscribing a catalog that publishes it. No library release SHALL be involved.

#### Scenario: A new catalog version adds an operation

- **WHEN** a platform subscribes a catalog version that adds an operation
- **THEN** modules on that platform can use the operation with no library upgrade

### Requirement: The HTTP operation accepts five methods

The `http` operation SHALL accept GET, POST, PUT, PATCH and DELETE and SHALL reject any other method at validation.

#### Scenario: A listed method

- **WHEN** an http step uses PATCH
- **THEN** it validates

#### Scenario: An unlisted method

- **WHEN** an http step uses HEAD
- **THEN** validation rejects it

### Requirement: The HTTP operation returns the raw response

The `http` operation SHALL output the raw status, headers and body. The executor SHALL NOT parse or shape the body.

#### Scenario: A JSON response

- **WHEN** an http step receives a JSON body
- **THEN** its output holds the body as received, with no parsing or shaping
