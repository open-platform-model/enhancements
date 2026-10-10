<!-- THE CONTRACT, as a delta against openspec/specs/<capability>/spec.md. specs/ holds delivered work only.
     Owner: agent-written, approved by the proposer in the accept sample. Reader: whoever implements a piece.
     A requirement name is a short plain statement of at most 8 words. Delete the sections you do not use.
     Each requirement has a SHALL or MUST sentence of at most 500 characters and at least one scenario.
     Admission test: no Go symbol, CLI flag or file path in a requirement. A published CUE definition may be named. -->

## Purpose

<Only when this enhancement creates the capability: one or two sentences, at least 50 characters, on what the capability is for. `openspec archive` copies it into the new spec. Delete this section when the capability already exists.>

## ADDED Requirements

### Requirement: <Short plain statement, at most 8 words>

<Subject> SHALL <observable outcome>.

#### Scenario: <short name>

- **WHEN** <condition>
- **THEN** <outcome>

## MODIFIED Requirements

### Requirement: <The existing requirement's name, unchanged>

<The full requirement as it reads after this enhancement. Restate every scenario of the main spec that still holds: OpenSpec refuses a MODIFIED block that drops one.>

#### Scenario: <short name>

- **WHEN** <condition>
- **THEN** <outcome>

## REMOVED Requirements

### Requirement: <The existing requirement's name>

**Reason**: <Why it no longer holds.>

**Migration**: <What a consumer does instead.>

<!-- To reverse a shipped scenario, do not MODIFY. Remove the old requirement with this fixed form:
**Migration**: Replaced by "<new name>"
and add the requirement under <new name> in the ADDED section. -->

## RENAMED Requirements

- FROM: `### Requirement: <old name>`
- TO: `### Requirement: <new name>`
