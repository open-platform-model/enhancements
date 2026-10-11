## Purpose

State when a catalog's contracts stay compatible with the ones it already published: the additive-only comparison, the levels it binds, and the standalone check that repeats the comparison on a published build. A contract at beta level or above may only grow. Publish enforces it, and the publish gate is stated in the artifact-publishing capability. The standalone check is an aid.

## ADDED Requirements

### Requirement: Compatible means additive only

A new definition of a contract SHALL be compatible with its prior definition only if it removes no field, adds no required field, changes no default, makes no optional field required and narrows no value a field accepts; a narrowing SHALL carry CUE's own diagnostic. Fields and options MAY be added. Each violation SHALL carry its dotted path from the compared root and a stable kind. A default change SHALL carry the old and new values.

#### Scenario: A removed field is reported

- **WHEN** the new definition lacks a field the prior definition declares
- **THEN** the comparison reports one violation at that field's path with the kind `field removed`

#### Scenario: A required addition is reported

- **WHEN** the new definition adds a field that is required and has no default
- **THEN** the comparison reports the kind `field added without optional or default` at that path
- **AND** adding the same field as a regular field with a default, with no required marker, reports nothing

#### Scenario: A field made required is reported

- **WHEN** a field that was optional is required in the new definition
- **THEN** the comparison reports the kind `field made required` at that path
- **AND** the reverse change, from required to optional, reports nothing

#### Scenario: A field that loses its default is a default finding

- **WHEN** a defaulted field loses its default in the new definition
- **THEN** the comparison reports `default removed` at that path and not `field made required`

#### Scenario: A changed default is reported with both values

- **WHEN** an existing field's default changes and the values the field accepts do not
- **THEN** the comparison reports `default changed` at that path with the old and new values

#### Scenario: A narrowed domain is reported at the leaf

- **WHEN** a leaf no longer accepts a value the prior definition accepted
- **THEN** the comparison reports `domain narrowed` at that path, carrying the CUE diagnostic verbatim

#### Scenario: Both kinds of addition pass

- **WHEN** the new definition only adds an optional field, or only adds an option to a disjunction
- **THEN** the comparison reports no violation

### Requirement: Only authored defaults are compared

A default SHALL be compared only where an author marked one. The default CUE gives an open list SHALL NOT count on either side: it is not compared, its absence is not `default removed`, and a change of that list from required to optional reports nothing. Narrowing an open list SHALL still report `domain narrowed`. A default written inside an open list's fixed elements is authored and SHALL be compared at the element's path.

#### Scenario: An implicit list default is not compared

- **WHEN** a non-empty open list field becomes optional in the new definition
- **THEN** the comparison reports no violation

#### Scenario: Narrowing an open list reports only the narrowing

- **WHEN** a plain open list field gains a minimum length in the new definition
- **THEN** the comparison reports `domain narrowed` at that path and no default finding

#### Scenario: An authored list default is compared

- **WHEN** a list field's authored default changes, or is dropped
- **THEN** the comparison reports `default changed`, or `default removed`, at that path
- **AND** adding an authored default to a list that had none reports nothing

#### Scenario: A default inside a fixed element is compared

- **WHEN** a default written in the first fixed element of an open list is dropped
- **THEN** the comparison reports `default removed` at the first element's path

### Requirement: Provenance and hidden fields are not contract surface

The comparison SHALL NOT compare or report the catalog version or the description under any field named metadata, at any depth, so that a member referenced inside another member reports nothing for the referenced member's release stamp. Hidden fields SHALL NOT be compared. Every other field under metadata SHALL be compared.

#### Scenario: A stamp inside a member reference is ignored

- **WHEN** a trait's applies-to list references a resource and only that resource's catalog version differs between the two builds
- **THEN** the comparison reports no violation

#### Scenario: A restamped member passes

- **WHEN** a member differs from its predecessor only in its catalog version and description
- **THEN** the member passes the comparison

#### Scenario: Another metadata field is still compared

- **WHEN** the new definition removes a metadata field other than the catalog version and the description
- **THEN** the comparison reports `field removed` at that path

### Requirement: Closed lists are walked at equal length

Two closed lists of equal length SHALL be compared element by element, so that a field removed inside a referenced member is reported at the element's path and the stamp rule above reaches it. Any other pair of lists SHALL be judged as one value. A value whose written form is identical on both sides SHALL report nothing, even where it carries a validator or a pending comprehension.

#### Scenario: Equal-length lists are walked

- **WHEN** a blueprint's list of composed resources has the same length on both sides and one element removed a field
- **THEN** the comparison reports `field removed` at that element's path

#### Scenario: Unequal-length lists are one value

- **WHEN** the new definition drops an element from a closed list
- **THEN** the comparison reports `domain narrowed` at the list's path

#### Scenario: An unchanged guarded value is silent

- **WHEN** a field typed by a struct that carries conditional blocks, or by a validator, is identical on both sides
- **THEN** the comparison reports no violation at that path

### Requirement: The comparison binds only what the promise binds

The comparison SHALL bind a contract exactly where the additive-only promise binds it, as the primitive-keying capability states the levels, read from the contract's own API version and never from the catalog's release version. A contract the promise does not bind SHALL pass without its definitions being evaluated. An API version outside the ladder grammar of core SHALL be an error and never a violation.

#### Scenario: A contract the promise does not bind is not compared

- **WHEN** a contract at `v1alpha1` removes a field relative to its predecessor
- **THEN** the comparison reports nothing and no error, and evaluates none of its definitions

#### Scenario: An API version off the ladder is an error

- **WHEN** the comparison is asked about the API version `v1alpha` or `1.2.0`
- **THEN** it returns an error and no violation

### Requirement: The check verifies a published build

The catalog registry check SHALL pull a published catalog by path and version and verify what a platform verifies when it imports the catalog: its declared path and version are concrete and agree with the coordinate it was fetched by. It SHALL list the members it found, grouped by package. A member package that does not load SHALL be a finding. Its help text SHALL state that the check is an aid, not a guarantee, and that only publish enforces.

#### Scenario: A declared version that differs from the tag is found

- **WHEN** a published build declares a version other than the tag it was fetched by
- **THEN** the check reports both values and exits with code 2

#### Scenario: An identity that is not concrete is a finding

- **WHEN** a published catalog declares no concrete path or version
- **THEN** the check reports a finding for each missing value

#### Scenario: The help states the check is an aid

- **WHEN** the command's help is displayed
- **THEN** it says nothing requires the check to have been run, and that enforcement exists only at publish

### Requirement: The check judges a build as publish would

With its compatibility mode, the check SHALL run the predecessor comparison for the fetched build exactly as publish would have, the fetched version standing in for the version being published. The two commands SHALL agree on every build, the exempt ones included; which builds are exempt, and how a predecessor is chosen, are stated by the publish capability.

#### Scenario: A violating build exits 2

- **WHEN** the compatibility mode runs against a published stable build whose beta member narrows a field of the predecessor that publish would select
- **THEN** the check lists the violation and exits with code 2, as publish would refuse it

### Requirement: The check's exit code names the cause

The check SHALL exit 0 when clean and 2 when it reports findings. It SHALL exit 5 when the registry answers that it does not hold the named version, a 403 on the tag lookup included. Any other registry answer, or none, while the named build is fetched SHALL exit 3, with the build never judged. A failure that asks no registry SHALL exit 1.

#### Scenario: A version that is not published exits 5

- **WHEN** the check names a version the registry does not hold
- **THEN** it exits 5 and prints no report

#### Scenario: A forbidden tag lookup reads as not published

- **WHEN** the registry answers the tag lookup for the named version with status 403
- **THEN** the check exits 5

#### Scenario: An unreachable registry exits 3

- **WHEN** the registry does not answer while the named build is fetched
- **THEN** the check exits 3 and judges nothing

#### Scenario: A coordinate that is not a path and a version exits 1

- **WHEN** the argument has no version after the path
- **THEN** the check exits 1 without contacting a registry
