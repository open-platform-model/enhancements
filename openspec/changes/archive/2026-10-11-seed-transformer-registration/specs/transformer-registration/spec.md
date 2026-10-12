## Purpose

State the shape and lifecycle of a provider's registration claim, the cluster resource a provider module renders to say that its catalog implements platform contracts. The claim is cluster-scoped, requires four facts at admission, and can be created only by a platform administrator. It becomes active when its provider is ready, and it cannot be deleted or shrunk while instances depend on it. Judging a claim is the work of another capability.

## ADDED Requirements

### Requirement: Cluster-scoped TransformerRegistration resource

The platform SHALL define a cluster-scoped TransformerRegistration resource in group opmodel.dev, version v1alpha1, with a status. A provider module SHALL render a claim with exactly that group, version and kind, because the platform's group is the authority and a catalog cannot derive it.

#### Scenario: The kind is installable and cluster-scoped

- **WHEN** the resource definition is installed
- **THEN** TransformerRegistration is registered as cluster-scoped
- **AND** a claim carries no namespace

#### Scenario: A rendered claim is accepted by the API server

- **WHEN** an object with the group, version and kind that the catalog renderer emits is applied with every required field present
- **THEN** the API server accepts and stores it

### Requirement: Every claim field is required at admission

The API server SHALL reject a claim that lacks the provider catalog's module path, its version, its list of provided contracts, or the namespace and name of the claiming instance. The path and the version SHALL be non-empty; the list MAY be empty. The check SHALL NOT be left to the authoring catalog, because a missing required field in CUE is an incomplete value, not an error.

#### Scenario: A claim missing its catalog is rejected

- **WHEN** a claim is applied with a version, a provided list and a claiming instance but no catalog path
- **THEN** the API server rejects it, naming the missing field

#### Scenario: A claim with an empty version is rejected

- **WHEN** a claim is applied with an empty version
- **THEN** the API server rejects it

#### Scenario: A claim with an empty provided list is admitted

- **WHEN** a claim is applied whose provided list is empty and every other required field is present
- **THEN** the API server accepts and stores it, and admission leaves the judgement of the list to acceptance

### Requirement: The claim's name is instance-derived

The API server SHALL reject a claim whose name has no dot. The name a provider renders is the namespace and the name of the claiming instance joined by a dot. A namespace holds no dot, so the join is collision-free, and two instances of one provider module produce two distinct claims instead of contending for one.

#### Scenario: An instance-derived name is accepted

- **WHEN** a claim named with a namespace, a dot and an instance name is applied
- **THEN** the API server accepts it

#### Scenario: A name with no dot is rejected

- **WHEN** a claim named with a single word and no dot is applied
- **THEN** the API server rejects it with a message that names the required shape

### Requirement: Claim status separates acceptance from activation

A claim's status SHALL carry conditions, an accepted flag, an active flag and the generation last reconciled, so that a stored claim reports one of three states: not yet judged, accepted but inactive, or active. The platform SHALL set the active flag when an accepted claim's provider is ready. Recording the verdict itself is the work of acceptance.

#### Scenario: Status records the generation reconciled

- **WHEN** a valid claim is applied and the operator is running
- **THEN** the generation recorded in its status matches the claim's generation

#### Scenario: An accepted claim can be inactive

- **WHEN** a claim is accepted and its provider is not yet ready
- **THEN** the accepted flag is true and the active flag is false

### Requirement: Creating a claim requires platform-admin RBAC

The platform SHALL ship a cluster role that grants create, update and delete on claims, and SHALL ship no tenant-facing role that grants those verbs. A cluster administrator binds the role deliberately, so a module applied under an impersonated tenant identity cannot create a claim unless that identity holds a platform-admin binding. The role SHALL ship unbound.

#### Scenario: A tenant identity cannot create a claim

- **WHEN** a rendered claim is applied through the impersonated tenant identity of a module whose subject holds no platform-admin binding
- **THEN** the API server refuses the create as forbidden, and the applying module reports the refusal as an impersonation failure

#### Scenario: A platform-admin subject can create a claim

- **WHEN** the same object is applied by a subject bound to the shipped platform-admin role
- **THEN** the API server accepts the create

### Requirement: An accepted claim activates on provider readiness

An accepted claim SHALL become active when the module instance named as its provider reports ready, and SHALL stay inactive until then. Activation SHALL follow provider readiness without waiting for an unrelated reconcile. A claim that is not accepted SHALL NOT activate, whatever its provider reports.

#### Scenario: A claim activates when its provider becomes ready

- **WHEN** an accepted claim's provider becomes ready
- **THEN** the claim reports active without a change to its own spec

#### Scenario: An accepted claim with an unready provider stays inactive

- **WHEN** a claim is accepted and its provider is not ready
- **THEN** the claim is not active, and a condition says it is waiting on its provider

#### Scenario: A refused claim never activates

- **WHEN** a refused claim's provider is ready
- **THEN** the claim stays inactive

#### Scenario: A refusal replaces the waiting report

- **WHEN** a claim that was accepted and waiting on its provider is later refused
- **THEN** it no longer reports that it is waiting on its provider

### Requirement: Activation latches against provider health

An active claim SHALL NOT be deactivated because its provider's readiness regressed. The readiness gate SHALL govern initial activation only, and a claim SHALL leave the active state by deletion alone. The gate orders installation; it does not track health, and a provider's definitions outlive its pods.

#### Scenario: A provider going unready leaves the claim active

- **WHEN** an active claim's provider stops being ready
- **THEN** the claim stays active and its status does not flap

#### Scenario: A recovering provider does not re-run the gate

- **WHEN** that provider becomes ready again
- **THEN** the claim is still active and records no new activation, because it never left

#### Scenario: A refusal does not end activation

- **WHEN** an active claim is later refused
- **THEN** it is no longer accepted and still reports active

### Requirement: A claim with dependents cannot be deleted

The platform SHALL prevent the deletion of an accepted claim while instances demand contracts it provides, and SHALL report the block on the claim, naming how many instances depend on it. The block SHALL release once no dependent remains, so a claim never becomes permanently undeletable.

#### Scenario: Deleting a depended-on claim is blocked

- **WHEN** an active claim is deleted while instances demand a contract it provides
- **THEN** the object is not removed, and its status names the dependent count

#### Scenario: The block releases when dependents go away

- **WHEN** the last dependent stops demanding the claim's contracts
- **THEN** the pending deletion completes without further action on the claim

#### Scenario: A claim nothing depends on deletes without a block

- **WHEN** a claim with no dependents is deleted
- **THEN** it is removed without a block

### Requirement: The dependent count is derived, never authored

The platform SHALL derive the dependent count from what instances demand, and SHALL NOT read it from any field that a module author writes. Equal cluster state SHALL yield an equal count and an equal verdict. An unreadable answer SHALL NOT release a claim.

#### Scenario: The count follows actual demand

- **WHEN** an instance stops demanding a contract and the claim is evaluated again
- **THEN** the count falls to match, with no edit to the claim

#### Scenario: The verdict is stable

- **WHEN** a blocked deletion is evaluated again with no change to the instances
- **THEN** the same count and the same refusal are reported

#### Scenario: An unreadable count keeps the block

- **WHEN** a depended-on claim is deleted and the platform cannot read what the instances demand
- **THEN** the object is not removed, and the deletion is evaluated again later

### Requirement: A shrinking upgrade is refused while dependents exist

The platform SHALL refuse to apply a rendered claim that removes a contract from its provided list while instances still demand that contract. The refusal SHALL take effect while the previously accepted claim is the stored one, SHALL name the dropped contracts and the dependent count, and covers writes the platform makes itself: an edit by another actor is outside the guarantee.

#### Scenario: A shrinking upgrade is refused

- **WHEN** a provider upgrade renders its claim with a contract dropped and instances still demand it
- **THEN** the stored claim is unchanged, and the refusal names the dropped contracts and the dependent count

#### Scenario: The accepted claim keeps serving

- **WHEN** such an upgrade is refused
- **THEN** the claim accepted before the upgrade stays effective, and the instances that demand its contracts keep rendering

#### Scenario: A non-shrinking upgrade passes

- **WHEN** a provider upgrade renders its claim with the same contracts at a new catalog version
- **THEN** the stored claim names the new version, and the provider's instance reports no shrink refusal

#### Scenario: Dropping a contract nobody demands is allowed

- **WHEN** an upgrade removes a contract that no instance demands
- **THEN** it is applied

#### Scenario: A provider that renders no claim is unaffected

- **WHEN** a module that renders no claim is upgraded
- **THEN** the upgrade applies, and the instance reports no shrink refusal

### Requirement: A refused upgrade is reported on its provider

The platform SHALL report a refused shrink on the module instance whose render produced the claim, naming the claim, the dropped contracts and the dependent count. The instance SHALL NOT report ready while a rendered resource is withheld. The refusal SHALL NOT write the claim's own status, which belongs to acceptance.

#### Scenario: The instance names what was refused

- **WHEN** an upgrade is refused
- **THEN** the provider's module instance reports not ready, naming the claim, the dropped contracts and the dependent count

#### Scenario: The claim's own verdict is untouched

- **WHEN** an upgrade is refused
- **THEN** the claim's conditions still describe the accepted claim, unchanged by the refusal

#### Scenario: The refusal clears when the cause does

- **WHEN** the instances that demand a dropped contract stop demanding it and the provider is reconciled again
- **THEN** the upgrade applies and the instance converges, with no action on the claim
