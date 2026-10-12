## Purpose

What the conformance suite records for a case and when it reports drift: the rendered output for an accepted input, the message lines for a refused one, and drift when a message changes between version cells.

## ADDED Requirements

### Requirement: An accepted input records its rendered output

The expected outcome of a conformance case whose input is accepted SHALL be the rendered output, recorded verbatim.

#### Scenario: An accepted case is recorded

- **WHEN** a case with an accepted input is recorded
- **THEN** the record holds the rendered output word for word

### Requirement: A refused input records its message lines

The expected outcome of a conformance case whose input is refused SHALL be the message lines of the refusal, captured verbatim. A replay SHALL compare those lines with the record, and the fact of a refusal alone SHALL NOT satisfy the case.

#### Scenario: A refusal is recorded with its text

- **WHEN** a case whose input is refused is recorded at a version cell
- **THEN** the record holds the message lines of the refusal

#### Scenario: A refusal with other text does not pass

- **WHEN** a replay refuses the same input with different message lines
- **THEN** the case does not pass, although the input is still refused

### Requirement: A changed refusal message is drift

A change in the message of a refusal between two version cells SHALL be reported as drift, in the same way as a change in rendered output.

#### Scenario: A message changes at a new cell

- **WHEN** a new version cell refuses an input with a message that differs from its predecessor
- **THEN** the suite reports drift

#### Scenario: A changed output is also drift

- **WHEN** a new version cell renders different output for an accepted input
- **THEN** the suite reports drift in the same way
