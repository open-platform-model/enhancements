## Purpose

What both OPM frontends decide about Kubernetes resources: the same inputs give the same inventory, stale set, digest and deletion plan, whichever frontend asks.

## ADDED Requirements

### Requirement: Both frontends decide alike

For the same rendered output, inventory, instance identity, deletion policy and live object state, the CLI and the operator SHALL compute the same inventory entries, stale set, digest and deletion plan, with the same skip reasons.

#### Scenario: Same inputs, same plan

- **WHEN** the CLI and the operator are given the same render, inventory, identity, policy and live state
- **THEN** both compute the same deletion plan with the same skip reasons

#### Scenario: Same render, same inventory decisions

- **WHEN** the CLI and the operator are given the same render, inventory and identity
- **THEN** both compute the same inventory entries, the same stale set and the same digest
