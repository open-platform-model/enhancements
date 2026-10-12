## MODIFIED Requirements

### Requirement: No selector selects the highest core-compatible major

Without a selector, the command SHALL list the published versions across all majors and walk the majors from highest to lowest, taking each major's newest release. It SHALL select the first major whose release is compatible with the core major the CLI renders against. A release that carries the metadata block SHALL be judged by the core major its block declares. A release without the block SHALL be judged by its core dependency, so no artifact published before the block becomes unselectable. It SHALL skip a major with no selectable release, a release whose block declares a kind other than module, a blockless release with no core dependency, or a release on another core major, and record the reason, naming the declared kind for a non-module release. When every major is skipped, it SHALL exit 2 naming each major and its reason.

#### Scenario: A newer major on another core is skipped

- **WHEN** the CLI renders against core major 2, major 3 of a module depends on core major 3, and major 2 depends on core major 2
- **THEN** the newest release of major 2 is selected, and major 3 is recorded as skipped because it requires core major 3

#### Scenario: A major without a core dependency is skipped

- **WHEN** the highest major of a module declares no core dependency and the next major depends on the CLI's core major
- **THEN** the next major's newest release is selected, and the higher major is recorded as skipped because it declares no core dependency

#### Scenario: A major with only development builds is skipped

- **WHEN** the highest major holds only development builds and the next major depends on the CLI's core major
- **THEN** the next major's newest release is selected, and the higher major is recorded as skipped for holding only development builds

#### Scenario: Nothing is compatible

- **WHEN** no major of the module depends on the CLI's core major
- **THEN** the command exits 2 and lists every major with its reason

#### Scenario: A template is skipped

- **WHEN** a candidate's block declares the kind template
- **THEN** the walk skips it and the report says template

#### Scenario: An older artifact is judged by its dependency

- **WHEN** the walk meets a candidate with no block and a core v2 dependency
- **THEN** it judges the candidate compatible with a core v2 CLI
