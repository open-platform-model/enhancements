## MODIFIED Requirements

### Requirement: The compatibility gate compares against history

For every beta or GA member of a catalog, publish SHALL compare the member under the additive-only rule with the last published build of the same major that shipped a member of that name at that API version. A member that carries `promotedFrom` SHALL be compared instead with the newest published build that carries its name at the origin level. Publish SHALL scan published versions below the one being published, newest first, release prereleases included and dev builds excluded. A member no earlier build carried SHALL pass unless it names an origin level. Transformers SHALL be exempt, and a member the comparison does not bind SHALL pass.

#### Scenario: A field removal is refused against the true predecessor

- **WHEN** a beta member removes a field relative to the newest published build that carried it
- **THEN** publish refuses with the violation path and the predecessor coordinate

#### Scenario: A prerelease predecessor counts

- **WHEN** the newest build carrying the member is a prerelease newer than the latest stable
- **THEN** the comparison runs against that prerelease

#### Scenario: Removal then re-adding is refused

- **WHEN** a member absent from the immediate predecessor is shipped incompatibly reshaped and an older build carried it
- **THEN** the scan finds the older build and publish refuses

#### Scenario: A new API version escapes the history

- **WHEN** a member ships at an API version no build has carried and names no origin level
- **THEN** it passes the gate

#### Scenario: A first publish at a new level

- **WHEN** a catalog publishes a contract at stable for the first time, naming beta as its origin
- **THEN** the gate finds the newest published beta build of that name and compares against it
