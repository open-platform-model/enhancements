## Purpose

Show the checker at work on one small capability so that every rule has a fixture.

## ADDED Requirements

### Requirement: The checker calls a symbol

The checker SHALL call render.Apply for each entry.

#### Scenario: A clean entry

- **WHEN** the checker reads a clean entry
- **THEN** it reports no error

