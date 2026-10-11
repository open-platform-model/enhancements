## Purpose

How the scheduled job turns bumps into pull requests: how many it opens, how it refreshes and closes them, and how often it runs.

## ADDED Requirements

### Requirement: A run opens at most one pull request

A scheduled run SHALL open at most one dependency pull request per repo, grouping every bump found in that run.

#### Scenario: Several bumps in one run

- **WHEN** a run finds bumps in three dependencies
- **THEN** it opens one pull request that holds all three

### Requirement: A later run updates the open pull request

A later run that finds new bumps SHALL update the open pull request in place. It SHALL NOT open a second one.

#### Scenario: A new release arrives while a pull request is open

- **WHEN** a dependency publishes a release after the pull request was opened
- **THEN** the next run adds that bump to the same pull request

### Requirement: A run with no remaining difference closes it

A run whose bumps no longer differ from the base branch SHALL close the open pull request.

#### Scenario: The bumps are merged another way

- **WHEN** the base branch already holds every bump of the open pull request
- **THEN** the next run closes the pull request

### Requirement: The scheduled run happens daily

The scheduled run SHALL happen daily in every enrolled repo.

#### Scenario: A day passes

- **WHEN** a day passes in an enrolled repo
- **THEN** the scheduled run has started once
