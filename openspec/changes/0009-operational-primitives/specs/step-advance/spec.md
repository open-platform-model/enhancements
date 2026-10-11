## Purpose

How a plan moves forward: one step per call. The library decides what happens next and never acts. The caller owns the loop and the run state, so a one-shot command and a controller share one set of rules.

## ADDED Requirements

### Requirement: One advance returns at most one action

Given a plan and a run state, one advance SHALL return the next state and at most one action for the caller to perform. The advance itself SHALL perform no side effect.

#### Scenario: A step is next

- **WHEN** a caller advances a plan whose next step is eligible
- **THEN** it receives the next state and that one action, and nothing has run

#### Scenario: The plan is complete

- **WHEN** a caller advances a plan whose steps are all satisfied
- **THEN** it receives the completed state and no action

### Requirement: A stored run state advances identically

A run state that is written out and read back SHALL advance exactly as the same state held in memory.

#### Scenario: A controller resumes

- **WHEN** a controller stores the state between two reconciles and advances the stored copy
- **THEN** the result equals advancing the state that stayed in memory

### Requirement: The library decides what happens next

The library SHALL decide which steps are eligible, in what order, what satisfies a step, what a failure does, and when a phase or plan is complete. Two callers with the same plan, state and result SHALL receive the same next action.

#### Scenario: Two frontends, one answer

- **WHEN** the CLI and the operator advance the same plan with the same state and result
- **THEN** both receive the same next action

#### Scenario: A step fails

- **WHEN** a caller reports a failed result for a step
- **THEN** the library, not the caller, decides what the failure does to the plan

### Requirement: The library keeps no run state between calls

The library SHALL hold no run state between calls. A caller that stops calling advance SHALL owe nothing further.

#### Scenario: A caller abandons a run

- **WHEN** a caller stops advancing a plan midway
- **THEN** the library holds nothing to clean up
