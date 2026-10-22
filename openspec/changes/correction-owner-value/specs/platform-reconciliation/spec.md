## MODIFIED Requirements

### Requirement: The skew policy is recorded with the package

The reconciler SHALL resolve the Platform's skew policy, Warn when unset, and hold it beside the generated package, so that every render against that package applies the same policy. A change to the policy alone SHALL give a new generation and a new package, and SHALL re-enqueue the instances.

#### Scenario: An unset policy reads Warn

- **WHEN** a Platform sets no skew policy and its package is generated
- **THEN** the held record carries the policy Warn

#### Scenario: A policy edit regenerates and re-enqueues

- **WHEN** the skew policy changes from Warn to Refuse with no other edit
- **THEN** the Platform reconciles to a new generation with reason Generated, the held record carries Refuse, and the controller-managed instances are re-enqueued

### Requirement: Deleting the Platform clears the held platform

When the Platform named `cluster` is deleted, or is being deleted, the reconciler SHALL clear the held platform so that no generated platform is held. It SHALL NOT delete or modify any workload resource: workloads freeze and are not torn down. A render already running finishes against the platform it started with.

#### Scenario: Delete clears the held platform

- **WHEN** the Platform `cluster` is deleted
- **THEN** no generated platform is held and no workload resource is modified as a direct result

#### Scenario: A Platform being deleted is not held

- **WHEN** the Platform `cluster` still exists but carries a deletion timestamp
- **THEN** the held platform is cleared at once

#### Scenario: Instances freeze without a platform

- **WHEN** a controller-managed instance reconciles after the Platform is deleted
- **THEN** it reports PlatformNotReady and the controller prunes nothing

### Requirement: A Platform change re-enqueues consuming instances

The instance reconciler SHALL watch the Platform and, on an update, re-enqueue only when a field that a render consumes differs: the Ready status, the package identity or the resolved registry, the skew policy, the observed generation, or the controller version the Platform reports. Create and delete events SHALL re-enqueue.

#### Scenario: A blocked instance retries when the platform appears

- **WHEN** an instance is blocked with PlatformNotReady and the Platform then reaches Generated
- **THEN** the instance is re-enqueued and renders on the next reconcile

#### Scenario: A new pin set re-renders instances

- **WHEN** the package identity changes because a claim became active, with the generation unchanged
- **THEN** every controller-managed, unsuspended instance is re-enqueued

#### Scenario: A report-only write enqueues nothing

- **WHEN** the Ready message changes, or the contract report changes, and none of the consumed fields differ
- **THEN** no instance is enqueued and no render runs

#### Scenario: A generation bump alone enqueues nothing

- **WHEN** a spec edit that leaves the skew policy unchanged bumps the generation, and the reconciler has not yet recorded the regenerated package
- **THEN** no instance is enqueued, and the later status write that carries the new observed generation re-enqueues them

### Requirement: A restart recovers instances blocked on no platform

After a controller restart the held platform is empty, so instances can render into PlatformNotReady before the platform is regenerated. The status write that records the regenerated Platform under the new controller version SHALL re-enqueue them, even when nothing else in the status differs, so they recover without waiting for the backoff.

#### Scenario: An upgrade into a Ready Platform recovers instances

- **WHEN** the controller restarts under a new version into a Platform already Ready, instances report PlatformNotReady, and the reconciler then regenerates the platform and writes a status that differs only in the controller version
- **THEN** every controller-managed, unsuspended instance is re-enqueued and renders on the next reconcile

## REMOVED Requirements

### Requirement: Only operator-managed instances are re-enqueued

**Reason**: The requirement name uses the old owner value.

**Migration**: Replaced by "Only controller-managed instances are re-enqueued"

## ADDED Requirements

### Requirement: Only controller-managed instances are re-enqueued

A Platform event SHALL re-enqueue only the ModuleInstances that render against the Platform: those the controller manages (owner absent or `controller`) and that are not suspended. An instance owned by the CLI, or suspended, SHALL NOT be enqueued by a Platform event.

#### Scenario: CLI-owned and suspended instances stay out

- **WHEN** the Platform becomes Ready with reason Generated, and one instance is CLI-owned, one is suspended and one is controller-managed
- **THEN** only the controller-managed instance is enqueued
