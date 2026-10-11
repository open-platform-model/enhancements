## Purpose

Define the authored platform: the data a platform team writes to say which catalog lineages a platform admits and within what range of releases. It admits and bounds. It never loads a catalog and never picks a version.

## ADDED Requirements

### Requirement: A platform is pure data naming admitted lineages

An authored platform SHALL import nothing and carry no dependency list of its own. It SHALL name each admitted lineage by module path with its major, with an enable flag, a required floor, an optional ceiling and a prerelease opt-in that defaults to off.

#### Scenario: A platform that imports a catalog is rejected

- **WHEN** a platform value imports a catalog
- **THEN** platform validation rejects it

#### Scenario: A minimal entry is valid

- **WHEN** an entry names a path with its major and a floor only
- **THEN** the platform is valid, enabled, with no ceiling and prereleases off

### Requirement: An entry needs a floor in its major

Platform validation SHALL reject an entry without a floor, and an entry whose floor or ceiling carries a major other than its path's.

#### Scenario: A missing floor

- **WHEN** an entry has no floor
- **THEN** platform validation rejects it

#### Scenario: A bound on another major

- **WHEN** an entry for a major 4 path has a ceiling in major 5
- **THEN** platform validation rejects it

### Requirement: Prereleases are admitted only by opt-in

With prereleases off, a render SHALL refuse a pin that carries a prerelease suffix even when its ordering falls inside the range, and platform validation SHALL reject a bound that carries one. With prereleases on, prerelease pins and bounds SHALL be admitted by ordering alone.

#### Scenario: A development tag inside the range is refused

- **WHEN** the floor is 4.2.0, prereleases are off, and a module pins 4.3.0-dev.2
- **THEN** the render is refused as not admitted

#### Scenario: A prerelease bound without opt-in is rejected

- **WHEN** an entry with prereleases off has a ceiling carrying a prerelease suffix
- **THEN** platform validation rejects it

#### Scenario: The opt-in admits a release candidate

- **WHEN** prereleases are on, the floor is 0.3.0, and a module pins 0.4.0-rc.1
- **THEN** the render holds 0.4.0-rc.1

### Requirement: One platform value serves cluster and offline

For a render given a platform, one authored platform value, with the same fields, SHALL serve as the operator's Platform resource spec and as the offline file the render starts from. A hand-written platform module SHALL NOT be an input.

#### Scenario: The same fields in both places

- **WHEN** a platform team moves a platform from an offline file to the cluster resource
- **THEN** the fields are the same

### Requirement: Several majors of one catalog may be admitted

An authored platform SHALL be able to admit several majors of one catalog as separate admission entries. Admitting or disabling one major SHALL NOT change what a render of a module on another major holds.

#### Scenario: Disabling one major leaves the other alone

- **WHEN** a platform admits two majors and the older entry is disabled
- **THEN** a render of a module on the newer major holds the same versions as before

### Requirement: The readiness build holds one major per catalog

The platform's own module-less build, for readiness and the contract inventory, SHALL hold each enabled static catalog at its floor, and SHALL NOT hold two majors of one catalog in one build. A platform admitting two majors of one catalog SHALL evaluate and report readiness.

#### Scenario: Static catalogs sit at their floors

- **WHEN** a platform admits a static catalog with floor 4.2.0
- **THEN** its module-less build holds that catalog at 4.2.0

#### Scenario: Two majors evaluate

- **WHEN** a platform admits two majors of one catalog
- **THEN** the platform evaluates and reports readiness, and no build holds both majors
