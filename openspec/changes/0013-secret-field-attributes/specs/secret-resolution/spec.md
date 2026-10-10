## Purpose

What OPM does with a declared secret at render time: it names one Secret object per group, rewrites every secret to a reference, keeps supplied plaintext out of the render, and fails loudly on mistakes without echoing a value.

## ADDED Requirements

### Requirement: Every secret renders as a reference

At render, every declared secret SHALL hold the reference form, an object name and a key, whichever arm the deployer wrote. A supplied value SHALL become a reference to the object OPM materialises, and a reference the deployer wrote SHALL pass through unchanged. Every consumer SHALL read the same reference whichever source produced it.

#### Scenario: A literal becomes a reference

- **WHEN** a deployer supplies a literal for a secret
- **THEN** the render holds a reference to the object OPM materialises

#### Scenario: A deployer-written reference is untouched

- **WHEN** a deployer supplies a reference
- **THEN** the render holds the same object name and key, never prefixed with the instance name

### Requirement: Supplied plaintext stays out of the render

A supplied secret value SHALL appear in no rendered manifest except the data of the Secret object that stores it, and no value field SHALL exist at a declared secret in the render. A module that interpolates a secret into a string SHALL fail CUE's own vet. The deployer's values file SHALL stay unmodified. An authored instance package SHALL refuse a literal secret, naming the path and the allowed alternatives.

#### Scenario: No plaintext in other manifests

- **WHEN** an instance supplies a literal and is rendered
- **THEN** the literal appears only in the data of the materialised Secret

#### Scenario: Interpolation into a string

- **WHEN** a module writes a secret into a string
- **THEN** CUE vet fails at authoring time, before any render

#### Scenario: A literal in a package

- **WHEN** an authored instance package carries a literal at a declared secret
- **THEN** it is refused, and the same literal given through a resource's values renders normally

### Requirement: A secret group renders to one object name

Each secret group of an instance SHALL be one Secret object, named once from the instance and the group, and every reference to the group SHALL carry that identical name. Components that consume one group SHALL reach the same object. An immutable group's name SHALL carry a content hash of its data, so references follow the object when the data changes.

#### Scenario: Environment variable and volume agree

- **WHEN** one component reads a secret through an environment variable and another through a volume
- **THEN** both reference the identical object name

#### Scenario: Immutable data changes

- **WHEN** the data of an immutable group changes
- **THEN** the object name changes and every reference follows it

### Requirement: Members of a group must agree

Members of one secret group SHALL agree on the Secret type and immutability, and non-reference members SHALL agree on the source and its settings. A group that disagrees SHALL be refused, naming the group and each member path.

#### Scenario: Two types in one group

- **WHEN** two members of one group declare different Secret types
- **THEN** the render is refused, naming the group and both paths

### Requirement: An unfulfilled secret fails every render

A declared secret with no complete value SHALL fail every render and every kernel validation, whether or not a component reads it. A declared secret whose resolved value is not a core secret, including the shape of the earlier core release, SHALL fail naming its path. CUE validation with concreteness SHALL name an unfulfilled secret by its config path.

#### Scenario: A secret nobody reads

- **WHEN** a declared secret has no value and no component reads it
- **THEN** the render fails naming the path

#### Scenario: A plain default left unset

- **WHEN** a declared path resolves to a plain default instead of a core secret
- **THEN** the render fails naming the path

### Requirement: Diagnostics never carry a secret value

No validation error, render error, event or status condition SHALL carry the value written at a declared secret path, or a value that a source's own schema rejected, including a malformed one. Such an error SHALL still name the path and why it failed.

#### Scenario: A bare string where a secret belongs

- **WHEN** a deployer writes a bare string at a declared secret
- **THEN** the error names the path and the reason and shows a fixed placeholder, not the string

#### Scenario: A literal failing a source's constraint

- **WHEN** a literal fails the constraint of its source
- **THEN** the error carries no part of the literal
