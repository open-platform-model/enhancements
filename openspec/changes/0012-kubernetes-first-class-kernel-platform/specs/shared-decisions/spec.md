## Purpose

What both OPM frontends decide about Kubernetes resources: the same inputs give the same inventory, stale set, digest and deletion plan, whichever frontend asks.

## ADDED Requirements

### Requirement: Both frontends decide alike

For the same rendered output, inventory, instance identity, deletion policy and live object state, the CLI and the operator SHALL compute the same inventory entries, stale set, digest and deletion plan, with the same skip reasons.

#### Scenario: Same inputs, same plan

- **WHEN** the CLI and the operator are given the same render, inventory, identity, policy and live state
- **THEN** both compute the same deletion plan with the same skip reasons

#### Scenario: A removed CRD

- **WHEN** a module drops a feature that shipped a CustomResourceDefinition and the CRD becomes a stale entry
- **THEN** both frontends skip it with the same reason, and no custom resource of that type is deleted
