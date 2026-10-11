## MODIFIED Requirements

### Requirement: Version set changes only the version value

The module and catalog version commands SHALL write the version value of the artifact's identity file in place, and the same version to the identity of the block in the same operation, so that the two never differ after a write. They SHALL change nothing else: comments, field order and alignment survive byte for byte. The writer SHALL keep the form it finds: a plain value, a value under a type assertion, or a default with a release marker. An open version field SHALL gain the new version by unification.

#### Scenario: A plain value is replaced

- **WHEN** the version is declared as the plain value 1.2.0 and the version is set to 1.3.0
- **THEN** the value is 1.3.0 and every other byte of the file is unchanged

#### Scenario: A type assertion survives

- **WHEN** the version is declared under a type assertion and the version is set to 1.3.0
- **THEN** the value is 1.3.0 and the assertion is still there

#### Scenario: A default keeps its marker

- **WHEN** the version is declared as a default carrying a release-automation marker
- **THEN** the default value is replaced and the field is still a default with the marker intact

#### Scenario: An open field gains the version

- **WHEN** the version field is declared with no value, only its type
- **THEN** the file now unifies that type with the version that was set

#### Scenario: A version bump updates the block

- **WHEN** an author sets version 2.1.0
- **THEN** the identity package and the block both read 2.1.0

### Requirement: Init scaffolds by fetch and re-identification

Module init SHALL fetch the template module, copy its source tree, and re-identify the copy to the new module path: the module declaration, the block's identity module path, the identity file's path, every literal self-import and every package clause, with the identity version reset to 0.1.0 as a plain literal. The template's identity SHALL appear nowhere in the scaffold, which SHALL pass module vet and every publish dry-run gate except already-published. The new path SHALL carry an explicit major and a snake_case leaf.

#### Scenario: A scaffold is publishable and leak-free

- **WHEN** a module is scaffolded from any official template
- **THEN** the publish dry run reports go and no file carries the template's identity or path

#### Scenario: A path without a major is refused

- **WHEN** the new module path has no major suffix
- **THEN** init refuses before fetching and shows an example path

#### Scenario: An existing target directory is refused

- **WHEN** the target directory already exists and holds no module
- **THEN** init refuses and writes nothing

#### Scenario: A failed scaffold leaves nothing behind

- **WHEN** re-identification or the final check fails after the directory was created
- **THEN** the new directory is removed

#### Scenario: A renamed template

- **WHEN** an author creates a module from a template under a new path
- **THEN** the block's module path equals the new module path
