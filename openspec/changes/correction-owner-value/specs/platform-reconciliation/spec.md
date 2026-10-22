## MODIFIED Requirements

### Requirement: Only the cluster Platform is reconciled

The controller SHALL reconcile only the Platform named `cluster`. A reconcile triggered for a Platform of any other name SHALL do nothing and return without error. This guard sits behind the declarative singleton rule at admission.

#### Scenario: A Platform of another name is ignored

- **WHEN** the reconciler is triggered for a Platform whose name is not `cluster`
- **THEN** it generates nothing, changes no status and returns without error

### Requirement: An unchanged package is not rebuilt

A reconcile whose inputs resolve to the package identity the controller already holds, for a module directory that still exists, SHALL regenerate nothing and SHALL still report the outcome on the Platform status. If the directory has gone, the controller SHALL rebuild, because renders read that directory.

#### Scenario: Repeated wake-ups rewrite nothing

- **WHEN** the reconciler is woken several times while the Platform spec and the active claims are unchanged
- **THEN** the held package is not rewritten and the Platform still reports Ready=True with reason Generated

#### Scenario: A missing directory forces a rebuild

- **WHEN** the held package's directory no longer exists and the reconciler is woken with the same inputs
- **THEN** the controller generates and builds the package again before it reports Ready

### Requirement: A failure records the observed generation

On a failure the reconciler SHALL record the generation it reconciled on the Platform status, as it does on success, so that a stalled Platform does not read as one the controller has not seen.

#### Scenario: A stalled Platform reports its generation

- **WHEN** the build fails for generation N
- **THEN** the Platform status records generation N as observed beside the failure

### Requirement: A failed build requeues on a bounded interval

When the dependency closure, the generation or the build fails, the controller SHALL requeue the Platform after a bounded interval and SHALL NOT wait for a spec change. It SHALL mark Ready false and Stalled true with the failure reason. No such failure is terminal.

#### Scenario: A failure requeues

- **WHEN** the build fails for the Platform named `cluster`
- **THEN** the reconcile asks to run again after a non-zero interval, and the Platform reports Ready=False and Stalled=True

#### Scenario: Recovery needs no spec change

- **WHEN** a Platform is in BuildFailed and the cause clears with no change to the spec
- **THEN** a later automatic reconcile builds the package, reports Ready=True with reason Generated and clears the Stalled condition

### Requirement: A registry failure does not outlive its reconcile

Each reconcile SHALL look up the published module files it needs afresh, so that a lookup failure met by an earlier reconcile never decides a later one. A registry that refuses a module file once and then serves it SHALL let the next reconcile succeed with no other change.

#### Scenario: A transient refusal is forgotten

- **WHEN** a reconcile ends Ready=False with reason BuildFailed because the registry refused a catalog's module file, and the registry then serves it again with no change to the Platform spec, the configuration or the controller process
- **THEN** the next reconcile fetches the file, builds the package and reports Ready=True with reason Generated at the same generation

### Requirement: One generated platform is held for readers

The controller SHALL hold at most one current generated platform, keyed by its package identity. A new identity SHALL replace the held record. A render that started before the replacement SHALL finish against the platform it started with.

#### Scenario: A spec change replaces the held record

- **WHEN** the Platform spec changes and the new package builds
- **THEN** readers get the record of the new identity and the earlier record is no longer current

#### Scenario: A claim change replaces the held record

- **WHEN** the reconciler records a package under a new identity while the Platform's generation is unchanged
- **THEN** readers get the record of the new identity

#### Scenario: A render in flight keeps its record

- **WHEN** a render is running and the reconciler then records a regenerated package
- **THEN** the running render completes against the package it started with, and the next render uses the new one

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
