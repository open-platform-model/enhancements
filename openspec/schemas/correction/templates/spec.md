<!-- THE SHIPPED BEHAVIOUR of one capability that already exists in openspec/specs/. Write no
     Purpose. Write what ships, never what you want to ship.
     A MODIFIED requirement keeps its name and every scenario of the main spec that still holds.
     To reverse a shipped scenario, REMOVE it with Migration `Replaced by "<new name>"` and ADD the new one.
     A requirement name is a short plain statement of at most 8 words.
     Each requirement has a SHALL or MUST sentence of at most 500 characters and at least one scenario.
     Admission test: no Go symbol, CLI flag or file path. A published CUE definition may be named.
     Delete the sections you do not use. -->

## MODIFIED Requirements

### Requirement: <Name exactly as in openspec/specs/>

<Subject> SHALL <observable outcome that ships today>.

#### Scenario: <short name>

- **WHEN** <condition>
- **THEN** <outcome>

## REMOVED Requirements

### Requirement: <Name exactly as in openspec/specs/>

**Reason**: <why the behaviour is gone>
**Migration**: Replaced by "<new name>"

## RENAMED Requirements

- FROM: `### Requirement: <old name>`
- TO: `### Requirement: <new name>`

## ADDED Requirements

### Requirement: <Short plain statement, at most 8 words>

<Subject> SHALL <observable outcome that ships today>.

#### Scenario: <short name>

- **WHEN** <condition>
- **THEN** <outcome>
