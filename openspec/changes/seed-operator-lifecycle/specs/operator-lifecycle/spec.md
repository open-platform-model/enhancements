## Purpose

How the CLI installs, upgrades and removes the operator, and how the operator reports its own version. The CLI installs the operator from its published module as a CLI-owned instance, refuses before it writes when it cannot do the job safely, and removes only what the instance records.

## ADDED Requirements

### Requirement: Install records the operator as a CLI-owned instance

`opm operator install` SHALL render the operator module as an instance named `opm-operator` in the namespace `opm-operator-system`, and record that instance as CLI-owned.

#### Scenario: Fresh cluster

- **WHEN** `opm operator install` runs against a cluster with none of OPM's CRDs
- **THEN** the instance `opm-operator` exists in `opm-operator-system` as CLI-owned
- **AND** the operator Deployment is running

### Requirement: CRDs are served before the instance is recorded

Install SHALL apply the rendered CustomResourceDefinitions first, with server-side apply, and wait until each reports `Established=True`. It SHALL then apply the whole render as the CLI-owned instance, through the same apply the CLI uses for every instance, so the record is written only after the CRDs are served. Install SHALL NOT create the Namespace outside the render.

#### Scenario: CRDs first

- **WHEN** install runs against a cluster with none of OPM's CRDs
- **THEN** the four CRDs are applied and `Established` before any other object is applied

#### Scenario: The Namespace comes with the render

- **WHEN** install runs on a cluster where `opm-operator-system` does not exist
- **THEN** the instance apply creates the Namespace as one of its objects, and does not refuse it as a foreign object

### Requirement: The record lists every rendered object

The instance record SHALL list every object the module renders, the CRDs and the Namespace included, and no step of install SHALL refuse an object that the same install applies. Apart from the render, install SHALL create only the cluster Platform and the opt-in user role, and the role SHALL NOT be listed in the record.

#### Scenario: CRDs and Namespace are recorded

- **WHEN** install completes on a fresh cluster
- **THEN** the record lists every rendered object, the four CRDs and the Namespace included

#### Scenario: The role is not recorded

- **WHEN** install with the opt-in role and a user completes
- **THEN** neither the ClusterRole `opm-cli-user` nor its binding appears in the record

### Requirement: A reinstall changes only what changed

Running install again with the same module version and values SHALL change no live object. Installing another module version over the instance SHALL apply what changed and delete every object the previous version rendered and the new one does not, except CRDs and the Namespace. The record SHALL then list the objects of the new version.

#### Scenario: Unchanged reinstall

- **WHEN** install runs a second time with the same module version and no new values
- **THEN** every object keeps its uid and resourceVersion, and the command reports every resource unchanged

#### Scenario: Upgrade drops an object the new version no longer renders

- **WHEN** install of module version B runs over an instance of version A, and A rendered a ClusterRole that B does not
- **THEN** that ClusterRole is deleted, the CRDs and the Namespace stay, and the record lists B's objects

### Requirement: Install refuses a non-CLI-owned record

Before any object changes, install SHALL refuse when the instance `opm-operator` in `opm-operator-system` exists and its owner is not the CLI, an absent owner included. The refusal SHALL exit 2, name the record, say that its owner is not the CLI and give the command that sets it. Install SHALL NOT change the owner itself: the operator never reconciles the instance that deploys it, so nothing would install.

#### Scenario: Operator-owned record

- **WHEN** install runs on a cluster whose record has the operator as owner
- **THEN** install exits 2 naming the record, saying its owner is not the CLI and how to set it, and nothing changed

#### Scenario: Record without an owner

- **WHEN** install runs on a cluster whose record has no owner
- **THEN** install refuses in the same way, and nothing changed

### Requirement: Install resolves a selected version

With a version selector, install SHALL resolve the module version through the CLI's published-module resolution and refuse an unserved selector before any cluster call. Install SHALL report the module version and the operator version it deploys.

#### Scenario: Selecting another version

- **WHEN** install is given a selector that the registry serves
- **THEN** install applies that module version, and its output names the module version and the operator version it deploys

#### Scenario: Unserved version

- **WHEN** install is given a selector that no published module version matches
- **THEN** the command exits 2 before contacting the cluster

### Requirement: Install refuses an unreadable operator version

Install SHALL refuse a module version that states no operator version, or one that is not a release, with exit 2 naming the module version and what is missing. The refusal SHALL come before any object changes.

#### Scenario: A module that states no operator version

- **WHEN** the target module version states no operator version, or one that is not a release
- **THEN** install exits 2 naming the module version and what is missing, and nothing changed

### Requirement: Install refuses a render that disagrees with itself

Install SHALL refuse, with exit 2 naming the module version and the rule, a module whose render does not run the controller Deployment `opm-operator-controller-manager` with an image tagged with the operator version the module states, and one whose rendered ModuleInstance CRD lacks the fields the CLI requires of that CRD, naming the floor. Both refusals SHALL come before any object changes.

#### Scenario: Rendered image disagrees with the stated operator version

- **WHEN** the target module states operator `1.0.0-beta.6` and its rendered controller image is tagged `v1.0.0-beta.5`
- **THEN** install exits 2 naming the module version and both versions, and nothing changed

#### Scenario: Rendered CRD below the floor

- **WHEN** the target's rendered ModuleInstance CRD lacks the field that records the owner
- **THEN** install exits 2 naming the module version and the floor, before the CRD step

### Requirement: The operator's settings are recorded values

Install SHALL layer values files, in order, over the values recorded on the operator's instance: maps merge, and a later scalar or list replaces an earlier one. A run SHALL be able to drop the recorded values. Every install, of the same or another module version, SHALL keep each recorded value it does not change. The module's `debugValues` SHALL NOT be used. Values the target's `#config` rejects SHALL refuse install before any change, naming each.

#### Scenario: A recorded value survives reinstall

- **WHEN** install ran with a values file setting a registry mapping, and install runs again with no values file
- **THEN** the second render carries the same registry mapping, and the record still holds it

#### Scenario: Changing one value keeps the others

- **WHEN** the record holds a registry mapping and a replica count, and install runs with a file that sets only the replica count
- **THEN** the render carries the new replica count and the recorded registry mapping

#### Scenario: A recorded value the target rejects

- **WHEN** the record holds a value that the target version's `#config` does not accept
- **THEN** install exits 2 naming the value's path and the way to drop recorded values, and nothing changed

### Requirement: Install succeeds only after the rollout

Install SHALL report success only after the rendered CRDs are `Established` and the controller Deployment has completed its rollout, within the one timeout budget that also covers waiting out terminating objects. When the rollout does not complete in time, install SHALL keep every applied object and the record, roll nothing back, and exit non-zero naming the Deployment and that re-running install completes it. Install SHALL NOT wait for the cluster Platform.

#### Scenario: Upgrade waits for the rollout

- **WHEN** install upgrades the operator to another module version
- **THEN** install reports success only after the controller Deployment's new ReplicaSet has completed its rollout

#### Scenario: Rollout does not complete

- **WHEN** the new controller pod cannot become ready before the timeout
- **THEN** install exits non-zero naming `opm-operator-controller-manager` and the timeout, and every applied object and the record remain

#### Scenario: A failure after the CRD step is safe to re-run

- **WHEN** the instance apply fails after the CRDs were applied
- **THEN** the error says that install is idempotent and safe to re-run

### Requirement: Platform seeding follows the rollout

After the rollout, unless the options that skip it are given, install SHALL create the singleton Platform `cluster`, subscribed to the catalog build it resolved before it contacted the cluster, with a plain create as field manager `opm-cli`, never server-side apply or update. An AlreadyExists answer SHALL be a success, and a create denied by RBAC SHALL degrade to a warning.

#### Scenario: Platform is seeded on a full install

- **WHEN** install completes against a cluster with no Platform
- **THEN** a Platform named `cluster` exists, subscribing to the resolved catalog build, and the output names the catalog module path and version

#### Scenario: Platform create denied by RBAC

- **WHEN** the installing user may apply the operator but may not create `platforms`
- **THEN** the command warns that the Platform was not seeded, names the missing permission, and does not fail because of it

#### Scenario: Seeding skipped on request

- **WHEN** install runs with the option that skips the Platform
- **THEN** no Platform is created and the output says so

### Requirement: Catalog resolution precedes every cluster write

When install will seed a Platform, it SHALL resolve the catalog version from the registry before it resolves the kubeconfig, contacts the cluster or applies any document. A failed resolution SHALL abort the command with nothing applied. A catalog major with no selectable version SHALL be a validation refusal, exit 2, naming the option that selects a prerelease. An unreachable or unreadable registry SHALL exit 3.

#### Scenario: No selectable release aborts before install

- **WHEN** the catalog major has published no stable release
- **THEN** the command exits 2 naming the option that selects a prerelease, and no operator resource, CRD included, has been created

#### Scenario: Unreachable registry aborts before install

- **WHEN** the catalog registry cannot be reached
- **THEN** the command exits 3 naming the lookup and the registry, and no operator resource has been created

### Requirement: Contradictory options are refused first

Install SHALL refuse these combinations as a validation error, exit 2, before any registry lookup, kubeconfig resolution or cluster call: the prerelease option with CRDs-only or with skipping the Platform, because neither seeds a Platform; values files, or dropping recorded values, with CRDs-only, which records no instance; a user or group for the opt-in role without that role; and a user together with a group.

#### Scenario: Prerelease option with CRDs-only

- **WHEN** a CRDs-only install is run with the prerelease option
- **THEN** the command fails validation, saying the option has no effect without Platform seeding, and no registry lookup and no cluster call is made

#### Scenario: Values with CRDs-only

- **WHEN** a CRDs-only install is run with a values file
- **THEN** the command fails validation before any registry or cluster call

#### Scenario: Subject without the role

- **WHEN** install is given a user but not the opt-in role
- **THEN** the command fails validation, saying the user requires the role, before contacting the cluster

### Requirement: The opt-in user role stays an install step

With the opt-in role, install SHALL also apply the ClusterRole `opm-cli-user`: all verbs on `moduleinstances`, get, patch and update on `moduleinstances/status`, and get and list on `platforms`. A given user or group SHALL be bound to it by a ClusterRoleBinding. Without the option, install SHALL create no RBAC object beyond the render's. The role SHALL be applied on the CRDs-only path as on the full one.

#### Scenario: Role off by default

- **WHEN** a CRDs-only install is run
- **THEN** no `opm-cli-user` ClusterRole or ClusterRoleBinding is created

#### Scenario: Role plus binding for a user

- **WHEN** a CRDs-only install is run with the opt-in role and the user `alice`
- **THEN** the `opm-cli-user` ClusterRole and a ClusterRoleBinding for `alice` are applied with field manager `opm-cli`

### Requirement: Install refuses before it writes

Before it writes any object, install SHALL run every check that can refuse it: module resolution, the render, the values against `#config`, the version rules, the permission to patch instance status (a CRDs-only install skips it), the wait for terminating objects and the ownership check. Only then SHALL it write: the CRDs, the instance, then the Platform. Outside the instance apply and its prune, install SHALL send no delete and no patch of managed fields. A refusal SHALL change no object.

#### Scenario: A refused install leaves the CRDs untouched

- **WHEN** install refuses because an object the render names already exists and OPM does not manage it
- **THEN** no CRD, label or other object in the cluster has changed

#### Scenario: Status permission missing

- **WHEN** the installing user may not patch instance status in `opm-operator-system`
- **THEN** install exits 4 naming the permission, and nothing changed

### Requirement: Install judges every object it applies

Install SHALL run the ownership check over every object it applies, the CRDs only for a CRDs-only install, whether or not the operator's instance has a record. An object an earlier operator release manifest created SHALL be judged as any other existing object, and install SHALL NOT adopt it by itself.

#### Scenario: Unlabelled objects of an earlier manifest install are refused

- **WHEN** the four `opmodel.dev` CRDs, the Namespace and the Deployment were applied from an operator release manifest and carry no OPM managed-by label and no adopt annotation
- **THEN** install exits 2 with `refusing to install:` and one line for each such object, saying it exists and OPM does not manage it, and naming the adopt annotation and the UUID to set
- **AND** install adopts none of them by itself, and no object has changed

#### Scenario: CRDs-only refuses unlabelled CRDs

- **WHEN** a CRDs-only install finds a CRD of the render that exists without an OPM managed-by label and without an adopt annotation
- **THEN** the command exits 2 naming that CRD, and no CRD has changed

### Requirement: An ownership refusal exits 2 and changes nothing

Each ownership refusal of install, a failed read by the check included, SHALL exit 2, name the object and its owner or adopter, name the adopt annotation and the UUID to set where it lifts the refusal, and change no object. No refusal SHALL tell the user to delete or rename an object.

#### Scenario: The refusal names the object and how to lift it

- **WHEN** install refuses an object that OPM does not manage
- **THEN** the command exits 2 naming the object, the adopt annotation and the UUID to set, offers no advice to delete or rename the object, and no object has changed

#### Scenario: A read the check fails

- **WHEN** an earlier read of a rendered object was answered and the ownership check's own read of it fails with Forbidden
- **THEN** the command exits 2 naming that object and the read error, and no object has changed

### Requirement: Install waits out terminating objects

Before the ownership check, install SHALL wait, within the timeout budget, for each object of the render that exists with a deletion timestamp to disappear, so install right after uninstall waits instead of refusing. An object that outlives the budget SHALL fail the command, naming it, with nothing applied. A failed read of a render object, other than NotFound, SHALL refuse install with the exit code of the read error: 4 when denied, 3 on a server timeout or unavailability, 1 otherwise.

#### Scenario: Install right after uninstall waits

- **WHEN** `opm operator uninstall` has returned and install runs before the deleted Deployment is gone
- **THEN** the command reports it is waiting for the terminating Deployment, applies only after it is gone, and completes

#### Scenario: Terminating object outlives the budget

- **WHEN** an object of the render stays terminating for longer than the timeout
- **THEN** the command exits non-zero naming that object and the elapsed timeout, and nothing has been applied

#### Scenario: An object unreadable from the start

- **WHEN** every read of a ClusterRole the render names fails with Forbidden
- **THEN** the command exits 4 naming that ClusterRole and the read error, and no object has changed

### Requirement: Uninstall keeps the record after a read failure

When a recorded object cannot be read with an error other than NotFound, it SHALL count as a failure: it is listed with its read error and not deleted, the other recorded objects are still deleted, the record is not deleted, and the command SHALL exit 1 and not report the operator uninstalled. A recorded Namespace or CRD that cannot be read is left behind, not a failure. Re-running after the cause is fixed SHALL delete the rest and the record.

#### Scenario: Unreadable recorded object keeps the record

- **WHEN** reading the recorded ClusterRole fails with Forbidden
- **THEN** the recorded ServiceAccount and Deployment are deleted, the ClusterRole is listed with the Forbidden error and not deleted, and the record is not deleted
- **AND** the command exits 1 without reporting the operator uninstalled

### Requirement: Uninstall fails when the record cannot be deleted

When every recorded object was deleted and the delete of the record then fails with an error other than NotFound, uninstall SHALL NOT report the operator uninstalled and SHALL exit non-zero. The error SHALL name the record and the cause, and say that the objects were deleted, that the record remains and that re-running is safe. The exit code SHALL be 4 when the API server denied the delete, 3 on a server timeout or unavailability, and 1 otherwise.

#### Scenario: Forbidden record delete

- **WHEN** the delete of the record fails with Forbidden
- **THEN** the recorded objects are deleted and the record still exists
- **AND** the command exits 4 without reporting the operator uninstalled

### Requirement: Every CLI server-side apply uses one field manager

Every server-side apply the CLI performs, instance and module applies and operator installs alike, SHALL use the field manager `opm-cli`. The former manager name `opm` is retired: resources applied under it change owner on their next apply, with no change the user sees.

#### Scenario: One manager identity across the CLI

- **WHEN** any CLI command applies a resource
- **THEN** the resource's managed fields attribute the CLI's fields to the manager `opm-cli`, and no CLI code path applies with the manager `opm`

### Requirement: The running-operator check uses fixed names

The check for a running operator SHALL use fixed names alone and read no instance record: the Deployment `opm-operator-controller-manager` in `opm-operator-system` and the four CRDs `moduleinstances`, `modulepackages`, `platforms` and `transformerregistrations` in `opmodel.dev`. The operator runs only when every CRD is `Established` and the Deployment has rolled out. Otherwise the check SHALL name each failing object and point at `opm operator install`; a failed read counts as not ready.

#### Scenario: A module-installed operator is found

- **WHEN** the instance `opm-operator` rendered the four CRDs and the Deployment, every CRD is `Established` and the Deployment has rolled out
- **THEN** the check reports the operator as running

#### Scenario: Operator older than the fourth CRD

- **WHEN** the cluster serves `moduleinstances`, `modulepackages` and `platforms` but not `transformerregistrations.opmodel.dev`, and the Deployment has rolled out
- **THEN** the check reports the operator as not ready and names `transformerregistrations.opmodel.dev`

#### Scenario: No operator at all

- **WHEN** the cluster holds none of the four CRDs and no controller Deployment
- **THEN** the check reports the operator as not ready, names the missing objects and points at `opm operator install`

### Requirement: The operator reports its release version

An operator build SHALL report `v` plus the version of the release it was built from, by any build route and with no build flag. A released container image SHALL report exactly that string. A build from a git checkout SHALL append `+g` and the short revision, and `.dirty` when the tree has changes. A consumer that compares operator versions SHALL ignore the `+` suffix.

#### Scenario: Tagged commit self-describes

- **WHEN** the source at a release tag is built by any means: container image, local build or install from source
- **THEN** the binary reports the tag's version with no build flags

#### Scenario: Release image reports the clean tag

- **WHEN** the released container image runs
- **THEN** it reports exactly `v` plus the release version, with no suffix

#### Scenario: Dev build carries provenance

- **WHEN** the operator is built from a local git checkout with uncommitted changes
- **THEN** the reported version is the release version with `+g`, the short revision and `.dirty`

#### Scenario: A suffix does not change a comparison

- **WHEN** the Platform reports an operator version with a build suffix
- **THEN** the CLI's operator-version comparison ignores the suffix

### Requirement: The operator logs its version at startup

The operator SHALL log its version once at startup, before the manager starts.

#### Scenario: Startup log line

- **WHEN** the operator process starts
- **THEN** its setup log contains the reported version string
