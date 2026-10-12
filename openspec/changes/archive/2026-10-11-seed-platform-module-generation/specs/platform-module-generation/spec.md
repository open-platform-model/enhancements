## Purpose

Generate the platform module from the platform's catalog subscriptions and the active provider claims, and keep it current. The module is a CUE module that embeds `#Platform` and imports every catalog the platform carries. The generator is pure, the dependency list is derived once from published module files, and the operator builds the result before any render may use it.

## ADDED Requirements

### Requirement: Generation is pure and deterministic

The generator SHALL produce a platform module from typed input alone: the platform's name and type, its registry entries (catalog path with major, catalog build, enable flag), the module path and the resolved dependency list. It SHALL read no environment, do no I/O, and emit entries and dependencies in sorted path order, so identical input yields byte-identical output. The module SHALL embed `#Platform`, import every entry's catalog, and carry one `#registry` entry per subscription.

#### Scenario: Same input, same bytes

- **WHEN** the generator runs twice on the same entries and dependencies in different orders
- **THEN** both results are byte-identical, with entries and dependencies sorted by path

#### Scenario: Two catalogs

- **WHEN** two enabled entries for different catalogs are generated with a dependency list that pins both
- **THEN** the module imports both under distinct names, and its `#registry` carries both keys, enabled, each with its expected version and its imported catalog

#### Scenario: A disabled entry still imports its catalog

- **WHEN** an entry is generated with its enable flag false
- **THEN** the catalog is still imported and the dependency list still pins it, and the entry carries the false flag

#### Scenario: Invalid input is refused

- **WHEN** the input has an empty name, type or module path, a duplicate registry path, an entry or dependency with an empty path or version, a dependency pinned twice at different versions, or a dependency list that lacks core or an entry's catalog
- **THEN** generation fails naming the offending field or path and emits nothing

### Requirement: An entry's expected version is stamped bare

Each registry entry SHALL carry its subscription's version as an expected-version assertion, written without a `v` prefix, so that both spellings of one version produce the same module. The assertion SHALL NOT select a build; the pinned dependency does.

#### Scenario: A prefixed version stamps the bare form

- **WHEN** an entry is generated with version `v4.0.1`
- **THEN** its stamped version is `4.0.1`, and the module is byte-identical to the one generated for `4.0.1`

#### Scenario: Either spelling builds

- **WHEN** a platform is generated from a subscription to a published catalog, once with version `0.1.0` and once with `v0.1.0`
- **THEN** both modules build through the kernel, and each entry's version reads `0.1.0`

### Requirement: Core is pinned at the kernel's verified release

The generated module SHALL pin core at the release the kernel was verified against, taken from the library and never from a constant of the caller. The dependency roots SHALL be that core pin plus every entry's catalog, disabled entries included. A caller that needs another core build SHALL supply its own roots, and the generator SHALL pin what it is given.

#### Scenario: Default core pin

- **WHEN** roots are derived from a list of entries
- **THEN** they hold core at the kernel's verified release and one root per entry

#### Scenario: Explicit core pin

- **WHEN** the caller supplies roots that pin core at another version
- **THEN** the generated module pins that version

#### Scenario: The pin follows the library

- **WHEN** the operator is built against a library release whose verified core is a newer build
- **THEN** the generated module pins that build, and no operator code change is needed

### Requirement: The dependency closure comes from published module files

The generator SHALL derive the full dependency list from the roots by walking the published module file of each reachable build, selecting the highest version for each major-qualified path, roots included, and skipping local replacements. The result SHALL match a tidy of the same roots, except that unreached modules stay pinned. An unpublished build named by a requirement SHALL fail with its module path and version, and no partial list. The walk SHALL use the caller's registry settings.

#### Scenario: A transitive dependency is pinned

- **WHEN** a subscribed catalog's published module file requires another module that the platform does not name
- **THEN** the list pins that module at the highest version any reachable module file names

#### Scenario: The root wins a shared path

- **WHEN** a root pins a path at a higher version than any transitive requirement names
- **THEN** the root's version is selected

#### Scenario: An unpublished build is refused

- **WHEN** a root or a transitive requirement names a build the registry cannot resolve
- **THEN** derivation fails naming that module path and version, and returns no list

#### Scenario: Resolution follows the caller's settings

- **WHEN** a frontend supplies its registry mapping, client type and environment
- **THEN** module files resolve through that mapping and cache, registry requests report that client type, and the generator reads no ambient setting

### Requirement: The registry unites authored subscriptions and active claims

The platform's registry SHALL be the union of two sources: one entry per authored subscription, at the version it names, and one entry per accepted and active provider claim, enabled and pinned at the claim's version. A catalog is one registry key, so when both name it the subscription SHALL win and a provider SHALL NOT re-enable a catalog the admin disabled. A disabled subscription SHALL stay pinned and imported with its flag false.

#### Scenario: A two-catalog platform generates two entries

- **WHEN** the platform subscribes to two catalogs at named versions
- **THEN** the generated dependency list pins both at exactly those versions, and the module carries one importing entry for each

#### Scenario: An active claim's catalog is pinned and imported

- **WHEN** a claim for a catalog is accepted and active and the platform does not subscribe to that catalog
- **THEN** the module pins the catalog at the claim's version and carries an enabled importing entry for it

#### Scenario: An authored subscription wins over a claim

- **WHEN** the platform subscribes to a catalog at one version with enable false, and an active claim names the same catalog at another version
- **THEN** the module carries one entry for that catalog, at the subscribed version and disabled

#### Scenario: A disabled subscription is generated disabled

- **WHEN** a subscription carries enable false
- **THEN** the module still pins and imports its catalog, and the entry carries the false flag

### Requirement: The package depends on spec and active claims

The operator SHALL generate the package from exactly two inputs: the Platform's spec and the set of accepted and active claims, computed from their current state and never from the event that woke it. With no active claim it SHALL generate what the spec alone implies. A claim whose deletion is blocked SHALL stay in the active set until the block releases; a deletion timestamp alone SHALL NOT drop its catalog.

#### Scenario: An active claim's catalog reaches the package

- **WHEN** a claim becomes active
- **THEN** the regenerated package carries that provider's catalog as a registry entry at the claim's version

#### Scenario: The waking event is ignored

- **WHEN** regeneration is woken by an event about a claim that has since left the active set
- **THEN** the package matches the one the current state implies, with that claim's catalog absent

#### Scenario: No active claim leaves the spec alone

- **WHEN** no claim is accepted and active
- **THEN** the package is a function of the Platform's spec alone, and the same inputs reconciled twice give byte-identical content

#### Scenario: A blocked claim's catalog survives regeneration

- **WHEN** the package is regenerated while an active claim is terminating and its deletion is blocked
- **THEN** the package still carries that claim's catalog, and the claim's dependents keep rendering

#### Scenario: A released claim leaves the active set

- **WHEN** a terminating claim's block releases
- **THEN** the next regenerated package no longer carries that claim's catalog

### Requirement: Regeneration follows every input and coalesces bursts

The operator SHALL regenerate the package when the Platform's spec changes and when a claim starts, stops or changes what it contributes to the active set, so a claim activating does not wait for an unrelated reconcile. A claim change that does not alter the active set SHALL NOT trigger a regeneration. A burst of changes SHALL converge in one or a few regenerations, not one per claim.

#### Scenario: Activating a claim wakes regeneration

- **WHEN** a claim becomes active
- **THEN** the package is regenerated without the Platform being edited

#### Scenario: A burst of activations coalesces

- **WHEN** several claims are active when the reconciler next runs and it was woken once for each claim
- **THEN** the first run generates one package that carries every one of their catalogs, and the other wake-ups regenerate nothing

#### Scenario: A change outside the active set is ignored

- **WHEN** a claim changes in a way that leaves the active set as it was
- **THEN** no regeneration runs

### Requirement: Platform status names the package and its registry

Each package SHALL carry an identity derived from the Platform's generation and the sorted active claim coordinates: equal inputs give equal identities and any change gives a new one. Platform status SHALL report the identity of the package renders consume and the resolved registry, with each entry's source (subscription or claim), version and whether it registers transformers. Every render SHALL log the identity it consumed.

#### Scenario: A claim change yields a new identity

- **WHEN** a claim activates while the Platform's generation is unchanged
- **THEN** the regenerated package carries a different identity than the previous one

#### Scenario: The union shows both sources

- **WHEN** a platform has an authored subscription and an active claim
- **THEN** the status lists both, and says which entry came from which source

#### Scenario: A disabled subscription is listed as not registering

- **WHEN** a platform authors a subscription with enable false
- **THEN** the status lists its catalog and marks it as contributing no transformer

#### Scenario: The status follows the active set

- **WHEN** a claim stops being active
- **THEN** the next package's identity differs and the status no longer lists its catalog

#### Scenario: A render reports what it consumed

- **WHEN** a render completes
- **THEN** the identity of the package it built against is written to the reconcile log, so the render is attributable to an exact registry state

### Requirement: The generated module is validated by building it

After writing the module, the operator SHALL build it through the kernel against its configured registry and SHALL record the package only when the build succeeds and its contract inventory is readable and accepted. A module generated from a closure derived against a registry SHALL build with no further tidy. Ready SHALL be True on success and False, with a reason naming the failure, otherwise. A failed or refused reconcile SHALL leave the last recorded package in place.

#### Scenario: A clean build sets Ready

- **WHEN** the pins name published builds, the build succeeds and the inventory is accepted
- **THEN** the Platform reports Ready=True with reason Generated, and records the reconciled generation and the operator's version

#### Scenario: A nonexistent pin surfaces on the Platform

- **WHEN** the Platform subscribes to a catalog version that is not published
- **THEN** it reports Ready=False with reason BuildFailed and a message naming the catalog path and version

#### Scenario: A key that disagrees with its catalog fails the build

- **WHEN** a registry entry's key differs from the module path its imported catalog declares
- **THEN** the Platform reports Ready=False with reason BuildFailed, naming the entry

#### Scenario: An unreadable inventory fails the build

- **WHEN** the built platform carries no readable contract inventory
- **THEN** the Platform reports Ready=False with reason BuildFailed, naming the missing field, and the package is not recorded

#### Scenario: A refused inventory carries the gate's reason

- **WHEN** the module builds and the inventory gate refuses it
- **THEN** the Platform reports Ready=False with the gate's own reason

#### Scenario: An unwritable module reports a generate failure

- **WHEN** the module cannot be written to disk
- **THEN** the Platform reports Ready=False with reason GenerateFailed

#### Scenario: A failed or refused build keeps the last good package

- **WHEN** generation N built and was recorded, and generation N+1 fails to build or builds but is refused by the inventory gate
- **THEN** renders still use generation N's package, and the Platform reports Ready=False for generation N+1

### Requirement: Packages are written whole and kept while held

The operator SHALL write each package into a directory named by its identity, through a staging step, so a module is absent or complete and a partial one is never recorded. After a successful build it SHALL keep the current package and every superseded package a render holds, and remove the rest. A held package SHALL be reclaimed once released. At start it SHALL empty the directory and regenerate before admitting any render.

#### Scenario: A crash mid-write leaves no current module

- **WHEN** the operator fails after writing some files of a package
- **THEN** no directory named by that identity holds a partial module and the recorded package is unchanged

#### Scenario: Two identities for one generation do not collide

- **WHEN** one package is generated for a generation with no active claim and another for the same generation with one active claim
- **THEN** the two occupy different directories and neither overwrites the other

#### Scenario: A held package survives the prune

- **WHEN** a render holds a package while the next one is generated and built
- **THEN** the held package remains beside the current one, and the next reconcile that records a package removes it once the render releases it

#### Scenario: Superseded packages are pruned

- **WHEN** three packages are generated and built in turn and no render holds any of them
- **THEN** only the current package remains

#### Scenario: A restart regenerates from the Platform

- **WHEN** the operator restarts with a Platform present
- **THEN** the directory is emptied at start, and the first reconcile regenerates and builds the module before any render is admitted

### Requirement: Generated files stay in a local owned directory

The generator SHALL write its files only under a directory its caller supplies, creating parent directories, and SHALL refuse a file name that would resolve outside it. It SHALL own no directory lifecycle: naming, staging, retention and reset belong to the frontend. The operator SHALL NOT publish a generated module to a registry, write it to the cluster, or serve it to another consumer, and the reserved platforms namespace stays unpublished.

#### Scenario: Write into an empty directory

- **WHEN** the generated files are written into an empty directory
- **THEN** the module file and the platform file exist under it with the generated bytes

#### Scenario: A path escape is refused

- **WHEN** a file name would resolve outside the target directory
- **THEN** the write fails naming the file and writes nothing

#### Scenario: Nothing leaves the pod

- **WHEN** a Platform is reconciled successfully
- **THEN** no registry push, ConfigMap, Secret or other cluster object carries the generated module

### Requirement: The Platform is a cluster singleton

The operator SHALL define a Platform resource that is cluster-scoped and permits one instance. The only permitted name SHALL be `cluster`, enforced declaratively at admission with no webhook.

#### Scenario: A Platform named cluster is accepted

- **WHEN** a Platform named `cluster` is applied
- **THEN** the API server accepts it

#### Scenario: Any other name is rejected

- **WHEN** a Platform with another name is applied
- **THEN** the API server rejects it with a message that names the singleton rule

#### Scenario: A Platform has no namespace

- **WHEN** the resource definition is installed
- **THEN** Platform is cluster-scoped and its objects carry no namespace

### Requirement: The Platform spec names type and pinned subscriptions

A Platform SHALL carry a required informational type and a registry keyed by major-suffixed catalog path. Each subscription SHALL name one published catalog build as a bare SemVer string, required at admission, with an optional enable flag defaulting to true; no range or allow or deny filter SHALL exist. A subscription without a version SHALL fail the build naming its path. The skew policy, Warn (default) or Refuse, SHALL stay outside the generated module.

#### Scenario: A minimal Platform is accepted

- **WHEN** a Platform sets a type and one registry entry that carries only a version
- **THEN** the API server accepts it, the generated entry is enabled and the skew policy in force is Warn

#### Scenario: A missing type is rejected

- **WHEN** a Platform is applied without a type
- **THEN** the API server rejects it as a missing required field

#### Scenario: A filter is not accepted

- **WHEN** a Platform is applied with a filter under a subscription
- **THEN** the field never reaches the reconciler

#### Scenario: An invalid skew policy is rejected

- **WHEN** a Platform sets a skew policy other than Warn or Refuse
- **THEN** the API server rejects it

#### Scenario: A subscription without a version fails the build

- **WHEN** a stored Platform has a subscription that lacks a version
- **THEN** the Platform reports Ready=False with reason BuildFailed naming the subscription's path, before any registry call
