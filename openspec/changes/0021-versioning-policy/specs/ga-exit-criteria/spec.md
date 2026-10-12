## Purpose

When a beta line may drop its suffix. These are the criteria a consumer can check from outside the repos.

## ADDED Requirements

### Requirement: The announced breaking change lands before GA

Enhancement 0013 SHALL be delivered before any line it breaks reaches GA.

#### Scenario: GA with 0013 undelivered

- **WHEN** a line that 0013 breaks is about to reach GA and 0013 is not delivered
- **THEN** the line does not reach GA

### Requirement: Draft entries that would break GA are named

Before GA, the policy SHALL name each draft entry whose delivery would break a GA line. Each named entry SHALL land before GA or wait for that line's next major.

#### Scenario: A draft that breaks a line

- **WHEN** a draft entry would break a line that is nearing GA
- **THEN** the policy names it, and it lands before GA or waits for the next major

### Requirement: The operator's CRD version is decided before GA

Before the operator reaches GA, the CRD version it serves SHALL be decided. A move to a new version SHALL be served with conversion, and every first-party artifact that names the version SHALL name the served one. For the first GA the operator SHALL serve `v1alpha1` with no conversion.

#### Scenario: The first GA

- **WHEN** the operator reaches its first GA
- **THEN** it serves `v1alpha1` and all first-party artifacts name `v1alpha1`

### Requirement: The library records a migration note per break

From GA on, the kernel library SHALL record a migration note for every breaking change of its exported API, and its published API-stability statement SHALL describe the GA promise.

#### Scenario: A breaking change after GA

- **WHEN** the library breaks an exported API after GA
- **THEN** a migration note records the change

### Requirement: Latest resolves to the GA release

After GA, the GitHub "latest" release of the core, kernel library, CLI and operator repositories, the operator image's `latest` tag, and Go's latest-version query for the library and the CLI SHALL each resolve the GA release. No `0.x` release or prerelease SHALL be advertised as latest.

#### Scenario: A consumer asks for latest

- **WHEN** a consumer resolves latest for the CLI after its GA
- **THEN** it gets the GA release

### Requirement: No new pin names a GA line's prerelease

After a line reaches GA, no first-party pin written from then on SHALL name a prerelease of that line.

#### Scenario: A new pin after GA

- **WHEN** a first-party artifact pins the library after the library's GA
- **THEN** the pin names a stable version

### Requirement: Templates and the quickstart follow GA

At GA, the CLI's module templates and the quickstart SHALL be republished against the GA versions, and the documentation site SHALL drop its beta label.

#### Scenario: A new user at GA

- **WHEN** a user follows the quickstart after GA
- **THEN** it names GA versions and the site shows no beta label

### Requirement: GA releases are cut in dependency order

GA releases SHALL be cut in this order: core, the kernel library, the operator, the operator module's first `v1` release, deploying the GA operator, then the CLI pinning that module. No GA release SHALL pin a prerelease dependency, and a `v0` operator module counts as one. A CI tool pin is not a dependency.

#### Scenario: The CLI before the operator module

- **WHEN** the operator module has no `v1` release
- **THEN** the CLI does not reach GA

### Requirement: A GA line can cut a release branch

Before a line of a repository that the immutable-tag rule covers reaches GA, that repository SHALL be able to cut a release branch. The cut action, release workflows on release branches and pull-request checks on them SHALL be in place there and proven in the sandbox repository.

#### Scenario: GA without the automation

- **WHEN** a repository has not proven the cut action in the sandbox
- **THEN** its line does not reach GA
