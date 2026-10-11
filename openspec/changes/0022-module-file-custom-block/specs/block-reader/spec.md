## Purpose

That the verdict the block gives and the verdict the dependencies give agree. How the major walk uses the block and falls back to the dependencies is stated with the published-module resolution.

## ADDED Requirements

### Requirement: Block and dependency verdicts agree

For an artifact published with the block, the verdict from the block and the verdict from the dependencies SHALL agree.

#### Scenario: A gated artifact

- **WHEN** an artifact passed the publish gate
- **THEN** both rules give the same verdict for it
