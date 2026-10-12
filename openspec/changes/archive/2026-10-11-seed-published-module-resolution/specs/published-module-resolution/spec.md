## Purpose

Define how a command that takes a published OPM module turns a major-free module path and an optional version selector into one exact published version, and how it reports that choice. Every such command resolves the same way, so there is one grammar for deploying a published module.

## ADDED Requirements

### Requirement: A module is named by a major-free path

A command that takes a published module as its subject SHALL accept it only as a module path without a major (module authoring states the grammar of the template reference of module init): a dotted first element, at least two elements, and only lowercase letters, digits, dots, underscores and hyphens. It SHALL refuse a path that carries a major suffix, or a URL, with exit code 2 before any registry access. The refusal for a suffix SHALL show the version selector that means the same.

#### Scenario: A major suffix is refused with the selector spelling

- **WHEN** a command is given `opmodel.dev/modules/web_app@v1`
- **THEN** it exits 2 without contacting the registry, and the message suggests naming the module without the suffix and selecting `v1` as the version

#### Scenario: A URL is refused

- **WHEN** a command is given `oci://ghcr.io/open-platform-model/opmodel.dev/modules/web_app`
- **THEN** it exits 2 stating that a module is named by its module path and that the registry configuration routes it

#### Scenario: A path that is not module-shaped is refused

- **WHEN** a command is given `opmodel.dev` or `opmodel.dev/Modules/web_app`
- **THEN** it exits 2 without contacting the registry, naming the path and what a module path holds

### Requirement: The version selector floats or pins

A command SHALL accept a version selector in exactly two forms: a major such as `v1`, which floats to the newest release within that major, and a bare SemVer version such as `1.0.4` or `1.0.4-rc.1`, which pins that published tag. It SHALL refuse any other value, `v1.0.4` included, with exit code 2 before any registry access, showing both forms. It SHALL refuse a selector the registry cannot satisfy with exit code 2, naming the module path, the selector and the registry.

#### Scenario: A pin selects its exact tag

- **WHEN** the selector is `1.0.3` and the registry holds that tag and `1.0.4`
- **THEN** `1.0.3` is selected

#### Scenario: A malformed selector is refused

- **WHEN** the selector is `v1.0.4`
- **THEN** the command exits 2 without contacting the registry and shows the forms `v1` and `1.0.4`

#### Scenario: A pin the registry does not hold is refused

- **WHEN** the selector is `1.0.9` and the registry holds no such tag
- **THEN** the command exits 2 naming the module path, `1.0.9` and the registry

#### Scenario: A major the module has no release in is refused

- **WHEN** the selector is `v4` and the module has no published version in major 4
- **THEN** the command exits 2 naming the module path, the major and the registry

### Requirement: A float never selects a development build

The newest release within a major SHALL be its newest stable version, or, when the major has no stable version, its newest prerelease that is not a development build. A development build is any version whose prerelease carries the identifier `dev`. A float SHALL NOT select one, and SHALL be refused with exit code 2 when the major holds only development builds. An exact pin SHALL select any published tag, development builds included.

#### Scenario: A float prefers the newest stable release

- **WHEN** major 1 holds `1.0.3`, `1.0.4` and `1.1.0-alpha.1`, and the selector is `v1`
- **THEN** `1.0.4` is selected

#### Scenario: A prerelease-only major floats to its newest named prerelease

- **WHEN** major 2 holds `2.0.0-alpha.1`, `2.0.0-alpha.2` and `2.0.1-0.dev.4.gdeadbee`, and the selector is `v2`
- **THEN** `2.0.0-alpha.2` is selected

#### Scenario: A major with only development builds is refused

- **WHEN** major 3 holds only `3.0.0-0.dev.1.gabc1234`, and the selector is `v3`
- **THEN** the command exits 2 stating that a float never selects a development build, and that a pin can

#### Scenario: A pin selects a development build

- **WHEN** the selector is `3.0.0-0.dev.1.gabc1234` and the registry holds that tag
- **THEN** that tag is selected

### Requirement: No selector selects the highest core-compatible major

Without a selector, the command SHALL list the published versions across all majors and walk the majors from highest to lowest, taking each major's newest release. It SHALL select the first major whose release declares a dependency on the core module in the same major the CLI renders against. It SHALL skip a major with no selectable release, no core dependency or another core major, and record the reason. When every major is skipped, it SHALL exit 2 naming each major and its reason.

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

### Requirement: Resolution reports its choice on standard error

After resolving, the command SHALL report the module path, the selected major and version, and how it was chosen: pinned, newest in the named major, or highest major on the CLI's core major. It SHALL add one line for each higher major it skipped, with the reason. The report SHALL go to standard error, so manifests or other data a command writes to standard output stay parseable.

#### Scenario: The report names the selection

- **WHEN** a command resolves `opmodel.dev/modules/web_app` to `1.0.4` in major 1 as the highest major on core major 2
- **THEN** standard error carries a line naming the module path, major 1, `1.0.4` and that it is the highest major on core major 2, and standard output carries only the command's data

#### Scenario: A skipped major is reported

- **WHEN** resolution skipped major 3 because it requires core major 3
- **THEN** standard error carries a line after the selection naming major 3 and that reason

### Requirement: Unreachable registry exits 3, refusal exits 2

Resolution SHALL use the registry that the CLI configuration routes the module path to. When that registry cannot be reached, whether while listing versions or while reading a release's module file, the command SHALL exit 3 naming the module path and the registry, and SHALL stop before the command's other work. A registry that answers but lacks the module, or what the selector asks for, is a refusal, exit code 2, never exit code 3.

#### Scenario: An unreachable registry exits 3

- **WHEN** the registry that serves the module path cannot be reached
- **THEN** the command exits 3 naming the module path and the registry, and renders nothing

#### Scenario: A registry that answers without the module is a refusal

- **WHEN** the registry is reachable and holds no version of the module path, whatever the selector
- **THEN** the command exits 2, not 3, stating that the module has no published versions and naming the registry
