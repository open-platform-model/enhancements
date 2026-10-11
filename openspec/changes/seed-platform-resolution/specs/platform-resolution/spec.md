## Purpose

State which platform a CLI command renders against, in what order the sources are tried, how a missing or stale cluster Platform degrades, how a platform is generated from the cluster or from a render's own dependency pins, and what the CLI reports about its choice. There is no local default platform: every source is a platform module directory that the kernel acquires.

## ADDED Requirements

### Requirement: Module build and vet use flag or deps

The module build and module vet commands SHALL render against the platform directory the user names with the platform option, else against a platform generated from the module's own dependency pins. They SHALL NOT read the cluster to find a platform. No command SHALL take a platform from a module kept in the OPM home directory, and no provider option SHALL exist.

#### Scenario: The platform option wins

- **WHEN** a module build runs with a platform directory named
- **THEN** the render uses that directory and no platform is generated from the module's pins

#### Scenario: No option, the module's pins

- **WHEN** a module build runs with no platform option and no platform module in the OPM home directory
- **THEN** the render succeeds against a platform generated from the module's pins

#### Scenario: The cluster is never read

- **WHEN** a module build or vet runs with a reachable cluster in the kubeconfig
- **THEN** the CLI makes no cluster read to find a platform

### Requirement: Deploying renders try flag, cluster, then deps

Instance build, vet, diff and apply, and module apply, SHALL resolve the platform in this order: the directory named with the platform option, the cluster's Platform named `cluster`, a platform generated from the render's own dependency pins. The first source that yields a platform wins, and a later source is not read once an earlier one wins.

#### Scenario: The flag wins over the cluster

- **WHEN** an instance apply runs with a platform directory named, against a cluster that has a Platform
- **THEN** the render uses the directory and the output reports the flag as the source

#### Scenario: The cluster is used without a flag

- **WHEN** an instance build runs with no platform option against a cluster with a readable Platform
- **THEN** the render uses a platform generated from that Platform and the output reports the cluster as the source

#### Scenario: Module apply uses the cluster too

- **WHEN** a module apply runs with no platform option against a cluster with a readable Platform
- **THEN** the render uses the platform generated from that Platform, not one from the module's pins

### Requirement: Platform check: argument, flag, then cluster

The platform check command SHALL resolve its platform from the directory argument, else the platform option, else the cluster's Platform, and SHALL read the cluster only when neither names a directory. When none is available it SHALL refuse, naming the argument, the option and the cluster as the sources it looked for. It SHALL NOT use a platform generated from dependency pins or one from the OPM home directory.

#### Scenario: The argument wins

- **WHEN** the check runs with a directory argument and a platform option naming another directory
- **THEN** the platform checked is the argument's directory and the cluster is not read

#### Scenario: No source refuses

- **WHEN** the check runs with no argument, no platform option and no readable cluster Platform
- **THEN** it fails naming the argument, the option and the cluster, and reads no directory under the OPM home

### Requirement: A named platform must be a platform module

A directory the user names as a platform, by option or argument, SHALL be a CUE module directory that holds a platform package. A file, a missing path, or a directory with no module manifest SHALL be refused before any render or build, with a message that names the expected shape.

#### Scenario: A file is refused

- **WHEN** the platform option names a file
- **THEN** resolution fails before any render, naming the expected module-directory shape

#### Scenario: A directory with no manifest is refused

- **WHEN** the platform option names a directory that holds no module manifest
- **THEN** resolution fails before any build, naming the directory and the expected shape

### Requirement: Every source is acquired the same way

Whatever the source, the platform SHALL reach the render as a platform module directory that the kernel acquires. A bad pin, an entry whose key does not match its catalog or an unpublished build SHALL fail before any instance is rendered, naming the entry or dependency, whatever the source. A platform that fails to build SHALL be reported with its directory and its source. The CLI SHALL NOT build a platform value from typed inputs and SHALL NOT persist one.

#### Scenario: An unpublished pin fails at acquisition

- **WHEN** the cluster's Platform names a catalog version that is not published
- **THEN** resolution fails naming the catalog path and version, before any instance is rendered

#### Scenario: The same failure for every source

- **WHEN** a named directory, a generated cluster module or a deps platform fails to build
- **THEN** the error names the failing dependency or entry in the same way, and also names the directory and the source

### Requirement: A cluster Platform is generated like the operator's

The CLI SHALL turn the cluster's Platform into a platform module the way the operator does: its type and registry entries feed the shared generator, and the module path is the reserved cluster platform path. The same Platform and generator release SHALL give the module the operator generates, so a Platform that renders in the cluster renders the same on the laptop.

#### Scenario: A provider catalog renders locally

- **WHEN** the Platform's recorded registry holds a catalog that a registration contributed, beside the subscribed ones
- **THEN** a module demanding a contract that provider fulfils renders on the laptop as it does in the cluster

### Requirement: The recorded registry wins over the spec

When the Platform's status records a resolved registry, the CLI SHALL generate from it, each entry with its catalog, version and enabled flag, an entry with no flag being disabled. When the status records none, the CLI SHALL generate from the spec's subscriptions, each enabled unless the spec says otherwise. A recorded entry with no version SHALL be refused, naming the entry.

#### Scenario: The recorded registry wins

- **WHEN** the spec subscribes one catalog and the status registry records that catalog plus a registration-sourced one
- **THEN** the generated module carries both entries

#### Scenario: No recorded registry, the spec

- **WHEN** the status records no registry
- **THEN** the generated module carries the spec's subscriptions and the report says the spec was used because no operator generation is recorded

#### Scenario: An entry with no flag is disabled

- **WHEN** a recorded entry has no enabled flag
- **THEN** the generated module carries that catalog disabled

#### Scenario: A hand-edited status is refused

- **WHEN** a recorded entry has no version
- **THEN** resolution fails naming that entry

### Requirement: A stale or refused Platform warns, still renders

When the CLI generates from a recorded registry, it SHALL warn if the generation the status describes is behind the Platform's own, naming both, and warn if the Ready condition is False, naming its reason. Neither warning SHALL change the registry used: the render goes on against the last package the operator recorded. With no recorded registry, neither warning is raised.

#### Scenario: A stale status warns

- **WHEN** the Platform is at generation 5 and its status describes generation 4
- **THEN** the CLI warns naming 4 and 5 and generates from the recorded registry

#### Scenario: A refused Platform renders against the last package

- **WHEN** the Platform's Ready condition is False with reason `OverSubscribedContracts`
- **THEN** the CLI warns naming that reason and renders against the recorded registry

### Requirement: A legacy stored Platform still decodes

The CLI SHALL read Platforms stored in older shapes. A filter key SHALL be ignored. A subscription with no version SHALL decode and fail at generation, before any registry access, with a hint that the Platform may predate the one-version-per-subscription shape and needs its spec re-applied. This tolerance SHALL cover reads of the cluster Platform only, never platform modules.

#### Scenario: A filter-shaped Platform decodes

- **WHEN** the stored Platform carries a filter block and no version
- **THEN** decoding succeeds and generation fails with the missing-version error and the legacy hint, before any registry access

### Requirement: No readable Platform falls back to deps

With no platform option and no readable cluster Platform (the resource is absent, or the read is denied), the CLI SHALL render against a platform generated from the render's own dependency pins and SHALL warn that the cluster Platform was not used, and why. Diff, apply and module apply SHALL fail when the cluster cannot be reached.

#### Scenario: An absent Platform falls back

- **WHEN** an instance apply runs with no platform option and the cluster has no Platform
- **THEN** the render uses a platform generated from the instance package's pins, and a warning says why

#### Scenario: A denied read falls back

- **WHEN** the read of the Platform is denied by RBAC
- **THEN** the same fallback and warning apply

#### Scenario: An unreachable cluster fails an apply

- **WHEN** an instance apply cannot reach the cluster
- **THEN** it fails and does not fall back to the deps

### Requirement: Instance build and vet never fail on cluster

Instance build and vet SHALL try the cluster's Platform before the deps and SHALL NOT fail because of the cluster. With the offline switch or a platform option the CLI SHALL NOT resolve a kubeconfig or contact a server. With no resolvable context it SHALL use the deps without a warning. On any other failure, including no answer within 10 seconds for the whole lookup, it SHALL warn naming the error and use the deps.

#### Scenario: Offline never contacts the cluster

- **WHEN** an instance build runs offline with a kubeconfig context for an unreachable server
- **THEN** it renders against the deps with no delay and no cluster warning

#### Scenario: A silent server degrades to the deps

- **WHEN** an instance vet runs and the server does not answer
- **THEN** within the bound it warns that the cluster could not be reached and renders against the deps, and the exit code is the render's

#### Scenario: A context flag selects the cluster

- **WHEN** an instance build runs with a context named
- **THEN** the Platform is read from that context

### Requirement: Deps become one catalog entry each, core floored

A platform generated from dependency pins SHALL carry one enabled entry for each pinned dependency that is a catalog, at its pinned version. Its dependency list SHALL be derived by the generator's closure rule, with core at the higher of the render's pin and the release the kernel was verified against.

#### Scenario: Catalog pins come from the module

- **WHEN** a module pins a catalog at 4.4.0 and core at the release the kernel was verified against
- **THEN** the generated platform has one enabled entry for that catalog at 4.4.0 and pins core at that release

#### Scenario: Core never falls below the kernel's release

- **WHEN** the module pins core older than the kernel's verified release
- **THEN** the generated platform pins core at the verified release

### Requirement: No catalog pins gives an empty registry

A module or instance package that pins no catalog SHALL render against a generated platform with an empty registry. A module with no components SHALL pass with zero objects. A component SHALL be refused as unmatched, with a hint that names the tidy command for that kind of source and the platform option.

#### Scenario: No components, no objects

- **WHEN** a module build runs on a module that pins no catalog and has no components
- **THEN** it succeeds with zero objects

#### Scenario: A component is refused with a hint

- **WHEN** the same module has one component
- **THEN** the render is refused as unmatched with exit code 2, and the hint names the tidy command and the platform option

### Requirement: A refused deps render points to a platform

When a render against a deps platform is refused for an unresolved demand, the output SHALL add a hint that the render's own catalogs do not implement the contract and that a provider-fulfilled contract comes from a platform, naming the platform option. A demand that no provider supplies keeps the kernel-render hint instead.

#### Scenario: A provider-fulfilled demand names the option

- **WHEN** a module build with no platform option is refused because a trait's contract needs a provider
- **THEN** the render fails with exit code 2 and the output adds the hint naming the platform option

### Requirement: A deps platform carries local replacements

Each local replacement of the render's source whose path the generated platform pins SHALL be carried into the generated platform, a relative directory target being taken against the module root. The closure SHALL read a directory-replaced module's requirements from that directory. A published module has no local context, so nothing is carried for it.

#### Scenario: A local catalog checkout is rendered

- **WHEN** a module replaces a catalog with a local checkout and a module build runs with no platform option
- **THEN** the generated platform serves the catalog from the checkout and the render succeeds even when the pinned version is not published

#### Scenario: A published module carries nothing

- **WHEN** a module acquired from the registry is built with no platform option
- **THEN** the platform is derived from the module file in the published artifact and no replacement is carried

### Requirement: Deps are read from the render's own source

For module commands the pins SHALL be read from the module's acquired source, so a module acquired from a directory and one acquired from the registry follow one rule. For instance commands they SHALL be read from the instance package's own module file at its module root, with its own local replacements. A pin that is not published SHALL fail at generation, naming the module path and version.

#### Scenario: An instance renders against its own pins

- **WHEN** an instance build runs with no platform option and no kubeconfig context, and the package pins a catalog at 4.4.0
- **THEN** the render uses a generated platform with one entry for that catalog at 4.4.0

#### Scenario: An unpublished pin fails

- **WHEN** a pinned catalog version is not published
- **THEN** generation fails naming the module path and version

### Requirement: A generated platform is cached by content

A platform generated from the cluster or from dependency pins SHALL live in a directory named by the hash of its content, under the cache beside the config file. The same inputs SHALL map to the same directory and rewrite nothing. The CLI SHALL NOT publish a generated module, write it to the cluster, or treat it as user-editable. It is derived state and may be deleted at any time.

#### Scenario: Unchanged inputs reuse the directory

- **WHEN** two invocations resolve the same cluster Platform or the same pins
- **THEN** both use the same directory and the second rewrites nothing

#### Scenario: Concurrent invocations converge

- **WHEN** two invocations generate the same platform at the same time
- **THEN** both end with one directory of identical content

#### Scenario: A deleted cache is regenerated

- **WHEN** the cache is deleted between two invocations
- **THEN** the second invocation generates the same module again

### Requirement: Every render reports its platform source

Every command that renders SHALL report which platform source it resolved and the directory it acquired. For the cluster source it SHALL say whether the recorded registry or the spec was used, and the package identity the operator recorded, or that none is recorded. For a deps source it SHALL name the module or instance package and each catalog path and version, and SHALL NOT name or apply the skew policy.

#### Scenario: A flag source is reported

- **WHEN** a render runs with a platform directory named
- **THEN** the output names that directory as the platform, given by the option

#### Scenario: A cluster source is reported

- **WHEN** a render uses a Platform whose status records a registry and a package identity
- **THEN** the output names the cluster Platform, the recorded registry and the package identity

#### Scenario: A deps source is reported

- **WHEN** a module build uses a platform generated from its pins
- **THEN** the output names the module's deps as the source and lists each catalog path and version, and no skew policy

### Requirement: A catalog version is resolved from the registry

The CLI SHALL resolve the catalog version a Platform subscription pins by listing the published versions of a major-qualified catalog path, scoped to that major. The default mode SHALL select the highest version with no prerelease. The opt-in prerelease mode SHALL select the highest whose prerelease begins with a non-numeric identifier. A development build, whose first prerelease identifier is numeric, SHALL never be selected. Versions that are not valid SemVer SHALL be ignored.

#### Scenario: A release is the default

- **WHEN** the major has published 2.0.0-alpha.3, 2.0.0 and 2.1.0
- **THEN** the default mode resolves 2.1.0

#### Scenario: Prerelease mode skips development builds

- **WHEN** the major has published 2.0.0-alpha.3 and a later development build
- **THEN** the prerelease mode resolves 2.0.0-alpha.3

### Requirement: Resolution refuses rather than guesses a version

When no version satisfies the mode, resolution SHALL refuse and SHALL NOT use the other mode, widen the major, infer maturity or fall back to a literal. The refusal SHALL name the catalog path, the registry, the highest version seen and the action that would select one. A listing that fails in transport SHALL be a connectivity failure naming the lookup and the registry, not a refusal.

#### Scenario: Only prereleases under the default

- **WHEN** the major has published only prereleases and the default mode runs
- **THEN** it refuses, naming the highest prerelease seen and the action that selects a prerelease

#### Scenario: Only development builds

- **WHEN** every published version is a development build
- **THEN** both modes refuse and offer no development build

#### Scenario: Empty history

- **WHEN** the major has no published version
- **THEN** resolution refuses naming the path and the registry

#### Scenario: A failed listing is not a refusal

- **WHEN** the version listing fails in transport
- **THEN** the failure is reported as a connectivity failure naming the lookup and the registry

### Requirement: The seeded subscription uses the same resolution

Operator install SHALL pick the catalog build that the seeded Platform subscribes to by this resolution, over the CLI's default catalog in its current major. Nothing SHALL be inferred from a neighbouring version.

#### Scenario: Install subscribes to the release

- **WHEN** the catalog lists a release and a newer prerelease and install seeds a Platform without the prerelease option
- **THEN** the seeded Platform subscribes to the release

#### Scenario: Install subscribes to a named prerelease on request

- **WHEN** the prerelease option is given and the catalog lists alpha and development builds
- **THEN** the seeded Platform subscribes to the newest alpha, never to a development build

### Requirement: No render seeds a Platform

No render command SHALL create, update or seed a Platform; only operator install seeds one, as the operator-lifecycle capability states.

#### Scenario: Apply never seeds

- **WHEN** an instance apply succeeds against a cluster with no Platform
- **THEN** no Platform exists afterwards and the output does not mention seeding

### Requirement: Operator install renders against its own pins

Operator install, the CRDs-only form included, SHALL render the operator module against a platform generated from the module's own dependency pins. It SHALL NOT read the cluster's Platform and SHALL NOT accept a platform directory for that render. The reported source SHALL be the module's deps.

#### Scenario: The source is the module's deps

- **WHEN** operator install runs against a cluster whose Platform subscribes to a catalog release other than the one the operator module pins
- **THEN** the render uses a platform generated from the module's pins, no platform directory is accepted, and the output names the module's deps as the source
