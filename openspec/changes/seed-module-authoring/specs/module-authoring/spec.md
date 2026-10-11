## Purpose

State the commands that write module and catalog source, and registry credentials, without inventing identity. An author sets a version on purpose, scaffolds a module from an official template that is itself a published module, repairs an existing tree behind a second confirmation, and logs in to a registry. Identity always comes from the author or the tree, never from the tool.

## ADDED Requirements

### Requirement: Version set changes only the version value

The module and catalog version commands SHALL write the version value of the artifact's identity file in place and SHALL change nothing else: comments, field order and alignment survive byte for byte. The writer SHALL keep the form it finds: a plain value, a value under a type assertion, or a default with a release marker. An open version field SHALL gain the new version by unification.

#### Scenario: A plain value is replaced

- **WHEN** the version is declared as the plain value 1.2.0 and the version is set to 1.3.0
- **THEN** the value is 1.3.0 and every other byte of the file is unchanged

#### Scenario: A type assertion survives

- **WHEN** the version is declared under a type assertion and the version is set to 1.3.0
- **THEN** the value is 1.3.0 and the assertion is still there

#### Scenario: A default keeps its marker

- **WHEN** the version is declared as a default carrying a release-automation marker and the version is set to 1.3.0
- **THEN** the default value is replaced and the field is still a default with the marker intact

#### Scenario: An open field gains the version

- **WHEN** the version field is declared with no value, only its type, and the version is set to 1.3.0
- **THEN** the file now unifies that type with the version that was set

### Requirement: Setting the declared version writes nothing

Setting the version a file already declares SHALL write no byte and leave the modification time unchanged, and the command SHALL report success. The version commands SHALL do no registry or network work. An argument that is not a bare SemVer, a leading v included, SHALL be refused before any file is read.

#### Scenario: Setting the same version is a no-op

- **WHEN** the version is set to the value the file already declares
- **THEN** the file is not written and the command reports that the version is already that value, and succeeds

#### Scenario: The command works offline

- **WHEN** the version is set with no registry reachable
- **THEN** the command succeeds

#### Scenario: A prefixed version is refused

- **WHEN** the version argument is v1.3.0
- **THEN** the command refuses, names the expected form, and reads and writes no file

### Requirement: A non-conformant identity file is refused

When the identity file is absent, does not parse, or declares no version at the schema-fixed place, a version command SHALL refuse, name the file and what it did not find, and write nothing. The refusal SHALL point at the full check of that kind: module vet for a module, a catalog publish dry run for a catalog. The catalog refusal SHALL NOT name a command that does not exist.

#### Scenario: A missing version field is refused

- **WHEN** a version command runs on an identity file that declares no version field
- **THEN** the command refuses, names the file and the missing field, and writes nothing

#### Scenario: The catalog refusal names the dry run

- **WHEN** a version command refuses a catalog's identity file
- **THEN** the pointer names the catalog publish dry run and never module vet

### Requirement: Official templates are published modules

The official templates minimal, standard and advanced SHALL be real modules hosted in the cli repository. The cli's release pipeline SHALL publish them through module publish into a reserved segment of the opmodel.dev domain, one name deep, and each SHALL pass every publish gate other than the refusal of a version the registry already holds. The segment SHALL be a module segment. No official template version SHALL be published unless every template passes the gates.

#### Scenario: Templates pass the gates of any module

- **WHEN** a template tree fails a publish gate other than the refusal of a version the registry already holds
- **THEN** that template version is not published and the cli release stays a draft

#### Scenario: A template publishes one name deep in the reserved segment

- **WHEN** the official template standard declares version 1.2.0 and the cli release publishes it
- **THEN** it is published through module publish as opmodel.dev/templates/standard@v1 at v1.2.0, and a template whose module path is not the segment, its own name and its major is refused

### Requirement: A failing template stops the release

Before any template is published, each SHALL pass the tidy check, the publish gates in a dry run, and module vet against its own debug values. If any template fails, no template SHALL be published and the cli release SHALL stay a draft, so it never ships while a template fails. The release SHALL publish only the versions its gates found unpublished.

#### Scenario: One bad template blocks every template

- **WHEN** one template fails module vet and the others pass
- **THEN** nothing is published and the release stays a draft

#### Scenario: A template renders its own debug values

- **WHEN** module vet runs on an official template with no values given
- **THEN** it renders every component and succeeds

#### Scenario: An unchanged release publishes nothing

- **WHEN** no template changed and no template version was raised
- **THEN** no publish is invoked and the job succeeds

### Requirement: A template is exactly its published module

A template tree SHALL hold exactly the files its module zip holds: no symbolic link, special file or nested module. Any change to a template's files SHALL come with a higher identity version. The version SHALL be a stable SemVer: the highest stable version published for its major, or an unpublished one above it. The path SHALL end in that major. The release refuses a template that breaks a rule.

#### Scenario: A file the zip leaves out is refused

- **WHEN** a template tree holds a symbolic link to a file elsewhere in the repository
- **THEN** the release refuses the template

#### Scenario: A change without a version bump is refused

- **WHEN** a template's files differ from the published module at the version it declares
- **THEN** the release refuses the template

#### Scenario: A prerelease or lower version is refused

- **WHEN** a template declares a prerelease, or a version below the highest published stable version of its major
- **THEN** the release refuses it

### Requirement: A template identity is a plain literal

A template's identity file SHALL declare the version as a concrete string literal with no local version type, and the template's metadata version SHALL be a plain reference to it. No file the CLI itself writes SHALL introduce a default arm into an identity version.

#### Scenario: The version is a quoted literal

- **WHEN** an official template's identity file is read
- **THEN** the version is a quoted SemVer literal with no disjunction and no local version type

#### Scenario: Metadata refers to the identity version

- **WHEN** an official template's module file is read
- **THEN** its metadata version is a plain reference to the identity file's version, with no literal and no default

### Requirement: Init scaffolds by fetch and re-identification

Module init SHALL fetch the template module, copy its source tree, and re-identify the copy to the new module path: the module declaration, the identity file's path, every literal self-import and every package clause, with the identity version reset to 0.1.0 as a plain literal. The template's identity SHALL appear nowhere in the scaffold, which SHALL pass module vet and every publish dry-run gate except already-published. The new path SHALL carry an explicit major and a snake_case leaf.

#### Scenario: A scaffold is publishable and leak-free

- **WHEN** a module is scaffolded from any official template
- **THEN** the publish dry run reports go and no file carries the template's identity or path

#### Scenario: A path without a major is refused

- **WHEN** the new module path has no major suffix
- **THEN** init refuses before fetching and shows an example path

#### Scenario: The scaffold starts at 0.1.0

- **WHEN** a module is scaffolded from an official template
- **THEN** the identity file declares version 0.1.0 as a plain literal, and the module's metadata version reads 0.1.0

### Requirement: Init never leaves a partial scaffold

When it scaffolds a new module, init SHALL refuse a target directory that already exists, and SHALL remove the new directory when any step fails after it created it.

#### Scenario: An existing target directory is refused

- **WHEN** the target directory already exists and holds no module
- **THEN** init refuses and writes nothing

#### Scenario: A failed scaffold leaves nothing behind

- **WHEN** re-identification or the final check fails after the directory was created
- **THEN** the new directory is removed

### Requirement: A clone source must derive its metadata

After re-identification, init SHALL check that the scaffold's metadata carries the new module path and the initial version. A clone source whose metadata is written as literals, not derived from its identity file, SHALL be refused, naming the field and the identity value it should derive from. The new directory SHALL be removed.

#### Scenario: A donor with literal metadata is refused

- **WHEN** a module is cloned from a source whose metadata version is a literal other than 0.1.0
- **THEN** init refuses, names the metadata field, and removes the new directory

### Requirement: Shortcut expansion is syntactic and never falls back

A template reference that is a bare word SHALL expand into the reserved segment. A reference with a slash or a dot SHALL be a literal module path and SHALL never be expanded. A major suffix SHALL float to the newest release of that major, stable preferred. A full SemVer SHALL pin that tag. With no suffix an official template takes its default major. An explicit source option SHALL accept any published module. Naming the template more than once SHALL be refused.

#### Scenario: A bare word expands and a path never does

- **WHEN** init is run once with the template reference standard@v1 and once with the reference example.com/templates/standard@v1
- **THEN** the first resolves inside the reserved segment, and the second is looked up as the literal module path example.com/templates/standard@v1, never expanded

#### Scenario: A typo fails inside the segment

- **WHEN** the bare word names no published template
- **THEN** init refuses, naming the expanded path, and tries no other path

#### Scenario: Two names for the template are refused

- **WHEN** the template is named both by position and by the explicit source option
- **THEN** init refuses and asks for one

### Requirement: Template list prints the official set offline

The template list command SHALL print each official template's name, description and default major from the same table that drives shortcut expansion. It SHALL need no registry access and SHALL print as a table, JSON or YAML.

#### Scenario: The list prints offline

- **WHEN** template list runs with no registry reachable
- **THEN** it prints minimal, standard and advanced, each with its description and default major, and succeeds

#### Scenario: A listed name expands

- **WHEN** a name printed by the list is used as a shortcut
- **THEN** it expands and resolves

### Requirement: Init refuses honestly when it cannot fetch

Init SHALL ask the registry for the template's published versions on every run, an exact tag included, and no template SHALL be embedded in the binary. When the registry cannot be reached, init SHALL refuse as a connectivity failure that names the lookup and the registry, even for a template fetched before. A template-only invocation SHALL prompt for the new module path on a terminal and refuse without one.

#### Scenario: Offline refuses, cached or not

- **WHEN** init runs with the registry unreachable, whether or not the template was fetched before
- **THEN** it refuses as a connectivity failure, naming the expanded path and the registry

#### Scenario: The path is asked for on a terminal

- **WHEN** init is given only a template name and runs on a terminal
- **THEN** it prompts for the new module path before writing anything

#### Scenario: The path cannot be asked for in a pipe

- **WHEN** init is given only a template name and standard input is not a terminal
- **THEN** it refuses and shows the form that takes both arguments

### Requirement: Init repairs a tree behind a second confirmation

Run in a directory that already holds a module, init SHALL detect a missing or disagreeing module declaration, a missing identity file, or a disagreeing identity module path. It SHALL list each file to create or edit, with the current and the new value, and ask for confirmation. Without a terminal it SHALL refuse unless consent is given up front. A declined repair SHALL write nothing. A template named for an existing module SHALL be refused.

#### Scenario: The repair is shown before it is applied

- **WHEN** the module declaration disagrees with the identity file and the author passes the path
- **THEN** init lists the edit with both values and writes only after the author confirms

#### Scenario: A declined repair writes nothing

- **WHEN** the author declines the confirmation
- **THEN** init refuses and no file changes

#### Scenario: No terminal and no consent is refused

- **WHEN** a repair is needed, standard input is not a terminal, and consent was not given up front
- **THEN** init refuses, names the way to consent up front, and no file changes

#### Scenario: A template for an existing module is refused

- **WHEN** init is given a template and the target directory already holds a module
- **THEN** init refuses and suggests repair without the template, or another directory

### Requirement: A consistent tree needs no repair

Run in a directory whose module declaration and identity file agree, init SHALL report that there is nothing to repair and point at module vet.

#### Scenario: A consistent tree needs nothing

- **WHEN** the module declaration and the identity file agree
- **THEN** init reports that there is nothing to repair and points at module vet

### Requirement: Repair never invents identity

Repair SHALL take the module path from its argument, else from the tree's own statements, and SHALL refuse a tree whose statements disagree or state none. A new identity file SHALL take its version from the tree's own metadata version and SHALL refuse when none is stated. Repair SHALL refuse a realignment that would strand self-imports of the old path, and SHALL NOT rewrite a malformed file.

#### Scenario: A tree that disagrees with itself is refused

- **WHEN** the identity file and the module declaration name different paths and no path is given
- **THEN** repair refuses and shows both statements

#### Scenario: A missing identity file takes the tree's version

- **WHEN** a tree has no identity file and its metadata states a version
- **THEN** the new identity file carries that version, not a chosen one

#### Scenario: No stated version is refused

- **WHEN** a tree has no identity file and states no version
- **THEN** repair refuses rather than choose a version

#### Scenario: A realignment that strands imports is refused

- **WHEN** realigning the module declaration would leave imports of the old path
- **THEN** repair refuses and lists the importing files

### Requirement: Scaffold layout is one package, no values file

A scaffolded module SHALL hold a module declaration and an identity package. Its body SHALL be one package at the tree root, named after the module's leaf, with the same package clause in every root file. A scaffold SHALL hold no separate values file: the author's test values live in the module's debug values, and module vet SHALL validate such a tree with them without reporting a missing values file.

#### Scenario: The scaffold carries the mandatory files

- **WHEN** example.com/modules/my_app@v0 is scaffolded from the standard template
- **THEN** the scaffold holds a module declaration and an identity package, and every root file declares the package my_app

#### Scenario: Vet needs no values file

- **WHEN** module vet runs on a scaffold that has no separate values file
- **THEN** it validates the module with its debug values and reports no missing file

### Requirement: Login stores the credential where push reads it

Registry login SHALL store the credential in the standard OCI credential file, which the CUE resolver reads for push and pull, so a later publish authenticates with no further configuration. It SHALL change only the targeted host's entry and keep every other key as found. It SHALL create a missing file with owner-only permissions, keep the permissions of an existing file, and refuse a file that is not valid JSON.

#### Scenario: The shared file is preserved

- **WHEN** the file already holds other hosts, a credential store or credential helpers
- **THEN** everything outside the targeted host's entry survives

#### Scenario: A new file is private

- **WHEN** the credential file does not exist
- **THEN** it is created readable by its owner only

#### Scenario: An unreadable file is not rewritten

- **WHEN** the credential file is not valid JSON
- **THEN** login refuses and leaves it as it was

### Requirement: Login verifies the credential before writing

Login SHALL verify the entered credential against the registry before it writes anything. A credential the registry rejects SHALL be a refusal. A registry that gives no verdict SHALL be a connectivity failure, which is a different kind. Both SHALL leave the credential file untouched.

#### Scenario: A bad credential never lands

- **WHEN** the registry rejects the entered credential
- **THEN** login refuses and the credential file is unmodified

#### Scenario: An unreachable registry is not a rejection

- **WHEN** the registry cannot be reached
- **THEN** login fails as a connectivity failure and the credential file is unmodified

### Requirement: Login resolves its host

With a host argument login SHALL take the host literally, and a suffix on it marks a host served over plain HTTP. Without one, login SHALL resolve the configured registry mapping, with the flag over the environment over the config, and report the winning source and any shadowed value. Exactly one host SHALL proceed. Several SHALL be refused, each listed as a runnable login command. None SHALL be refused, pointing at configuration.

#### Scenario: A single-host mapping logs in

- **WHEN** the resolved mapping names one host and the credential verifies
- **THEN** that host's entry is written and the resolution is reported

#### Scenario: A multi-host mapping lists actions

- **WHEN** the resolved mapping names several hosts and no argument is given
- **THEN** login refuses and lists one runnable login command per host

#### Scenario: No configured registry is refused

- **WHEN** no registry is configured and no argument is given
- **THEN** login refuses and points at configuration

### Requirement: Login is interactive only

Login SHALL prompt for the username and the secret, read the secret without echo, and take no credential from arguments or a pipe. An empty username or secret SHALL be refused. Without a terminal login SHALL refuse and point at docker login for scripted use. If the docker auth environment variable is set, login SHALL warn that it shadows the file being written.

#### Scenario: A pipe is refused

- **WHEN** login runs with standard input that is not a terminal
- **THEN** it refuses and points at docker login for scripted use

#### Scenario: A shadowing variable is reported

- **WHEN** the docker auth environment variable is set
- **THEN** login warns that the stored login will not be read while it stays set
