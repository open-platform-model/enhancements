# duplicate-object-identities Specification

## Purpose
Find, between render and apply, the rendered objects that share one Kubernetes apply identity, and name who produced each, so a runtime refuses the render before the last write silently wins. The check is opt-in: the render itself never refuses.

## Requirements

### Requirement: Identity is group, kind, namespace and name

Two rendered objects SHALL share an apply identity when they carry the same API group, kind, namespace and name. The version of the group SHALL NOT distinguish them, because Kubernetes addresses one object under every version of its group. An object with no API version, or a bare version such as `v1`, is in the core group. An object with no namespace has an empty one.

#### Scenario: One object under two versions of its group

- **WHEN** one transformer renders a Deployment `web` as `apps/v1` and another renders a Deployment `web` as `apps/v1beta2` in the same namespace
- **THEN** the two objects share one identity

#### Scenario: An object with no API version is in the core group

- **WHEN** a render produces a ConfigMap `x` as `v1` and a ConfigMap `x` with no API version in the same namespace
- **THEN** the two objects share one identity

#### Scenario: One kind and name in two groups stays distinct

- **WHEN** a render produces a kind `Widget` named `web` under `a.example.com/v1` and under `b.example.com/v1`
- **THEN** the objects share no identity

#### Scenario: One name in two namespaces stays distinct

- **WHEN** a render produces a Service `web` in two namespaces
- **THEN** the objects share no identity

### Requirement: Each shared identity is reported with its producers

The check SHALL take a render's compiled objects and return one row for every identity that two or more objects share, and no row when none does. A row SHALL carry the identity of the first object rendered with it, its API version as rendered, and every producer: the component, the transformer and that object's own API version. Rows and producers SHALL follow render order.

#### Scenario: Two components render one cluster-scoped object

- **WHEN** two components of one instance each render a registration object named after the instance
- **THEN** one row carries that identity with an empty namespace and both producers, each as component and transformer

#### Scenario: Three objects, two identities

- **WHEN** a render produces a Deployment `web` twice from two transformers and a Service `web` once
- **THEN** one row is returned for the Deployment with two producers, and none for the Service

#### Scenario: A mixed-version row keeps each producer's version

- **WHEN** a Deployment `web` is rendered as `apps/v1` first and as `apps/v1beta2` second
- **THEN** the row carries `apps/v1` and its producers carry `apps/v1` and `apps/v1beta2` in that order

#### Scenario: A clean render returns nothing

- **WHEN** every rendered object has a distinct identity
- **THEN** no rows are returned

### Requirement: A non-object value is skipped

A rendered value with no kind or no name SHALL NOT be treated as a Kubernetes object. The check SHALL skip it without a row and without an error, and SHALL validate nothing else about the objects.

#### Scenario: A value without a name is ignored

- **WHEN** a transformer renders a value with a kind and no name beside two objects that share an identity
- **THEN** the shared identity is returned and the nameless value adds nothing

### Requirement: The refusal is worded once

The library SHALL provide one error for the rows of the check. Its message SHALL open with a header line that counts the objects and the identities, then name each identity once, on its own line, with every producer as component and transformer. When the producers of a row carry different API versions, the message SHALL name each producer's version, and `<no apiVersion>` for a producer with none. Otherwise it SHALL name no per-producer version.

#### Scenario: The message names every producer

- **WHEN** the error is built from a row with two producers
- **THEN** its message names the identity once and both components with their transformers

#### Scenario: A version mismatch is visible

- **WHEN** the error is built from a row whose producers carry `apps/v1` and `apps/v1beta2`
- **THEN** each producer is named with its own version, so a reader sees one object under two versions

#### Scenario: A same-version row names no versions

- **WHEN** the error is built from a row whose producers all carry one API version
- **THEN** the line names the identity and the producers, and no per-producer version

#### Scenario: A missing version is worded

- **WHEN** the error is built from a row whose producers carry `v1` and no API version
- **THEN** the message names the second producer as `<no apiVersion>`

### Requirement: The check runs after the render

The render SHALL NOT refuse objects that share an identity: it SHALL return them all, and only a caller of the check learns of the collision. A frontend that applies to something other than Kubernetes MAY skip the check.

#### Scenario: A render with duplicates still succeeds

- **WHEN** a render produces two objects with one identity
- **THEN** the render returns both with no error

### Requirement: A runtime refuses a duplicate before apply

A runtime that applies to Kubernetes SHALL run the check on every render, before any resource, digest or output is built, and SHALL refuse a render with a shared identity, carrying the library's error unchanged. The CLI refuses as a validation failure. The operator marks the object not ready with a reason of its own, stalled, and applies nothing.

#### Scenario: The CLI builds nothing

- **WHEN** a render shows a shared identity
- **THEN** the CLI prints the error's header and each identity with its producers, and builds no resource, digest or output

#### Scenario: The operator names the cause

- **WHEN** a module instance renders a shared identity
- **THEN** the object reports not ready and stalled, with a reason that is neither a render failure nor a platform problem, and nothing is applied

#### Scenario: A module package is refused alike

- **WHEN** a module package renders a shared identity
- **THEN** the operator reports the same reason and applies nothing
