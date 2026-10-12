## Purpose

Who may write a definition, how a platform ships one as rendered output, and what an offered module may say about itself without ever emitting the definition.

## ADDED Requirements

### Requirement: Only a platform identity creates a definition

A definition SHALL be created only under a platform-team identity, whether it is applied directly or arrives as rendered output. One applied under a tenant identity SHALL be refused.

#### Scenario: A tenant applies a definition

- **WHEN** a tenant identity applies a definition
- **THEN** the API server refuses it

### Requirement: A product module ships definitions as output

A platform product module SHALL be able to ship definitions as ordinary rendered output by attaching the catalog-published definition resource contract to a component. They SHALL appear in dry-run and export like any other object.

#### Scenario: A definition in a dry-run

- **WHEN** a platform product module attaches the resource contract and is dry-run
- **THEN** the definition appears among the rendered objects

### Requirement: A declaration is readable without a cluster

An offered module's declaration, its intended group and kind and a suggested update policy, SHALL be readable from the published artifact with no cluster and no instance. A definition SHALL be draftable from it.

#### Scenario: Drafting from an artifact

- **WHEN** a user reads a published module that declares an offering, with no cluster present
- **THEN** the intended group, kind and update policy are returned
- **AND** a definition can be drafted from them

### Requirement: A declaration alone offers nothing

A declaration without a platform-authored definition SHALL offer nothing. No kind SHALL be served and no instance SHALL be creatable from it.

#### Scenario: A declaring module and no definition

- **WHEN** a module declares an offering and no definition binds it
- **THEN** no kind is served for it

### Requirement: A disagreeing definition is reported

A definition whose bound module carries a declaration that disagrees with it SHALL be reported on the definition and SHALL NOT be refused.

#### Scenario: A different kind name

- **WHEN** a definition names a kind other than the one the module declares
- **THEN** the definition reports the disagreement
- **AND** the definition stays accepted

### Requirement: A declaration renders no object

An offered module's declaration SHALL render no object. Nothing in the module's own output SHALL be a definition of itself.

#### Scenario: Deploying a declaring module

- **WHEN** a module that declares an offering is rendered
- **THEN** the output holds no definition of that module
