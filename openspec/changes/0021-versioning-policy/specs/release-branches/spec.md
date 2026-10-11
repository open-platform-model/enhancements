## Purpose

Where a fix for a released minor lands. A lazy maintenance branch gives that fix a place, and the version-line rule keeps it and the main branch from releasing the same version.

## ADDED Requirements

### Requirement: A maintenance branch comes from the cut action

In every in-scope repository, a maintenance branch SHALL be cut from the newest tag of its minor, by SemVer precedence, by the automated cut action. It SHALL change only through a pull request and SHALL never be deleted or force-pushed. Its release settings SHALL bump only the patch. It SHALL release nothing until it carries both the cut action's settings and a release workflow able to release from it.

#### Scenario: A stray feature commit on the branch

- **WHEN** a feature commit lands on a maintenance branch
- **THEN** the branch still releases only a patch

### Requirement: Main and a branch never release one version

A maintenance branch for a minor SHALL be cut only when the main branch's next release of that component is above that minor in `MAJOR.MINOR`, prereleases included, and the cut action SHALL refuse otherwise. Once the branch exists, the main branch's release path SHALL refuse any version of that minor.

#### Scenario: A cut while main is still on the minor

- **WHEN** the cut action runs and main's next release is still in that minor
- **THEN** the action refuses

### Requirement: No cut before the automation is proven

No maintenance branch SHALL be cut in an in-scope repository until the cut action, release workflows on maintenance branches and pull-request checks on them exist there, proven in the sandbox repository. The proof SHALL include a cut from a tag that predates them and the case where main and a branch would compute the same version.

#### Scenario: A fix needed before the automation exists

- **WHEN** a fix is needed for a released minor and the automation is not yet proven
- **THEN** the fix goes forward on main

### Requirement: A branch pull request runs main's checks

A pull request into a maintenance branch SHALL run the same required checks as a pull request into the main branch.

#### Scenario: A backport pull request

- **WHEN** a backport pull request targets a maintenance branch
- **THEN** the same required checks run as for main

### Requirement: A failed cut never strands a branch

A cut that fails part-way SHALL leave either no branch or a branch that a re-run of the cut action finds at the cut tag's commit and completes.

#### Scenario: A cut fails after the branch exists

- **WHEN** a cut fails after creating the branch and the action runs again
- **THEN** the second run finds the branch at the cut tag's commit and completes the cut
