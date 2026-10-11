## Purpose

Reproduce a cluster's platform package on the laptop from the Platform resource's effective inputs, so that a local build renders what the cluster renders. The CLI reads the cluster, writes the package to a directory, reports what it reproduced and writes nothing to the cluster.

## ADDED Requirements

### Requirement: Pull writes the cluster's platform module

The CLI SHALL provide a pull command that reads the cluster's Platform resource and writes the platform module the cluster renders against to a directory the user names, so that a local module or instance build pointed at that directory renders what the cluster renders. The written module SHALL be the generated module unchanged, as regular files a repository can commit. The command SHALL NOT write to the cluster and SHALL NOT publish anything.

#### Scenario: A pulled package reproduces the cluster's render

- **WHEN** the pull command runs against a cluster whose Platform status records subscriptions and one catalog contributed by a provider claim
- **THEN** the directory holds a platform module pinning every recorded catalog at its recorded version, and a local build against it resolves a provider contract as the cluster's render does

#### Scenario: The pulled module is the generated module

- **WHEN** the same Platform is pulled twice
- **THEN** the two directories hold byte-identical files

#### Scenario: The directory holds real files

- **WHEN** the pull succeeds
- **THEN** every file in the directory is a regular file with its full content, and none is a link into the CLI's cache

#### Scenario: The cluster is only read

- **WHEN** the pull command runs
- **THEN** the CLI creates, changes and deletes no object in the cluster, and publishes no module to any registry

### Requirement: Pull reports what it reproduced

Pull SHALL print the Platform's name and generation, the generation the operator last built from, the package identity and operator version the status records (or that none is recorded), whether the recorded registry or the spec was used, and every registry entry with its catalog, version, enabled flag and source. It SHALL show the warnings that platform resolution raises. It SHALL end by naming the directory written and the build command that consumes it.

#### Scenario: Provenance is printed

- **WHEN** the pull succeeds against a Platform the operator has reconciled
- **THEN** the output names the generation, the generation observed, the package identity as recorded, the operator version, each entry's source, and the target directory

#### Scenario: The spec fallback is named

- **WHEN** the Platform has no status registry
- **THEN** the output says the spec was used and that no operator generation is recorded, and lists every entry as a subscription

#### Scenario: Resolution warnings are shown

- **WHEN** platform resolution warns while pull runs, for example that the status describes an older generation than the spec
- **THEN** the warning appears in the output and the pull still writes the module

#### Scenario: The next step is named

- **WHEN** the pull succeeds
- **THEN** the last lines name the directory and the local build command that takes it

### Requirement: Pull never overwrites by accident

If the target exists and holds files, pull SHALL refuse with the general error code and write nothing, unless the user gives the overwrite option, which replaces the directory's contents with the generated module. The overwrite option SHALL be off by default. A target that is a file SHALL be refused either way.

#### Scenario: A non-empty target is refused

- **WHEN** the directory holds files and the overwrite option is absent
- **THEN** the command fails naming the directory and the option, and leaves the directory as it was

#### Scenario: The overwrite option replaces the contents

- **WHEN** the directory holds a stale file and the overwrite option is given
- **THEN** the directory holds only the generated module

#### Scenario: A file target is refused

- **WHEN** the target path is a file
- **THEN** the command fails with the general error code, with or without the overwrite option

#### Scenario: The target is judged before the cluster is read

- **WHEN** the directory holds files, the overwrite option is absent and the cluster is unreachable
- **THEN** the command fails with the general error code, not the connectivity code

### Requirement: Pull has no local fallback

A cluster without a readable Platform resource SHALL fail pull with the not-found code naming the resource: there is no cluster package to reproduce, and pull falls back to no other platform source. A Platform whose recorded registry cannot be generated, such as an unpublished pin or a subscription with no version, SHALL fail with the validation code and the generation diagnostic. A cluster that cannot be reached SHALL fail with the connectivity code.

#### Scenario: No Platform resource

- **WHEN** the cluster has no Platform named `cluster`
- **THEN** the command exits with the not-found code, the message names the resource and says there is nothing to pull, and no directory is created

#### Scenario: A Platform the user may not read

- **WHEN** the cluster denies the user permission to read the Platform
- **THEN** the command exits with the not-found code as if the Platform were absent

#### Scenario: A legacy Platform cannot be generated

- **WHEN** a stored Platform has a subscription with no version
- **THEN** the command exits with the validation code and the message says the Platform may predate the one-version-per-subscription shape

#### Scenario: An unpublished pin cannot be generated

- **WHEN** the recorded registry names a catalog build that is not published
- **THEN** the command exits with the validation code naming the module path and version

#### Scenario: A hand-edited status is refused

- **WHEN** a status registry entry has no version
- **THEN** the command exits with the validation code naming that entry

#### Scenario: An unreachable cluster

- **WHEN** the cluster cannot be reached
- **THEN** the command exits with the connectivity code
