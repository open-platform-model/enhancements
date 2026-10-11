## Purpose

How rendered Kubernetes objects are held to the upstream definitions, and how the suite checks that conformance across upstream snapshots in addition to the catalog's own check.

## ADDED Requirements

### Requirement: Rendered objects satisfy their upstream definition

Every object a catalog transformer renders SHALL satisfy the upstream Kubernetes CUE definition chosen by the object's own API version and kind.

#### Scenario: A rendered object conforms

- **WHEN** a transformer renders a Deployment
- **THEN** the object satisfies the upstream definition for its API version and kind

#### Scenario: A field the definition does not allow

- **WHEN** a transformer renders an object with a field its upstream definition does not allow
- **THEN** the object does not conform and the check reports it

### Requirement: The suite checks upstream conformance across snapshots

The conformance suite SHALL check the upstream conformance of rendered objects at each upstream snapshot in its version matrix, in addition to the check the catalog runs in its own module. A field that a snapshot drops or tightens SHALL appear as drift on the transformer that emits it.

#### Scenario: A snapshot drops a field

- **WHEN** a newer upstream snapshot drops a field that a transformer still emits
- **THEN** the suite reports drift at that snapshot, naming that transformer

#### Scenario: The catalog check stays

- **WHEN** the suite runs
- **THEN** the catalog still runs its own upstream check as before, and the suite repeats it across snapshots
