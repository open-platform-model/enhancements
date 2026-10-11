## Purpose

Why a release tag never moves. A named ref resolves to the same content forever, so pins, caches and the documentation site stay true. The rule binds the releasing repositories of the organization. The module fleet is excluded for now.

## ADDED Requirements

### Requirement: A tag keeps its commit

In every in-scope repository, a tag SHALL keep the commit it was first pushed with. No tag SHALL be moved, deleted or re-created after it exists.

#### Scenario: A tag move is attempted

- **WHEN** anyone tries to move or delete an existing release tag
- **THEN** the platform refuses it

### Requirement: A broken release is fixed forward

A wrong or broken release SHALL be corrected only by a later release with a higher version. For a Go module the retraction SHALL be published from the module's highest line, even when the fix ships from a maintenance branch.

#### Scenario: A bad Go release

- **WHEN** a Go module release is wrong
- **THEN** the next version retracts it, published from the highest line

### Requirement: A version-named registry tag keeps its content

A version-named registry tag pushed by an in-scope repository's release SHALL always resolve to the content first pushed under it. A release from a maintenance branch SHALL NOT move `latest` or the GitHub Latest flag.

#### Scenario: A repeated push

- **WHEN** a release path pushes a version tag that already holds different content
- **THEN** the push is refused, and identical content is a no-op

### Requirement: Documentation pins name fixed refs

For every site version the CLI has tagged, every source ref the documentation site's version list names SHALL be a tag or a full commit SHA, never a branch name. A SHA SHALL name a commit reachable from that repository's main branch or from the maintenance branch of the corrected minor. A pin SHALL move only by a reviewed commit to the list.

#### Scenario: A docs fix for a released version

- **WHEN** a documentation fix lands for a tagged site version
- **THEN** the version list pins the fix by tag or full SHA in a reviewed commit

### Requirement: Rulesets refuse tag changes

Every in-scope repository SHALL be covered by active organization rulesets that refuse update and deletion of any tag and deletion or force-push of a maintenance branch. Each ruleset SHALL have an empty bypass list.

#### Scenario: An admin tries to delete a tag

- **WHEN** an organization admin tries to delete a tag
- **THEN** the ruleset refuses it

### Requirement: Only the release app creates tags

Only the organization's release app SHALL create tags in an in-scope repository. An organization ruleset SHALL restrict tag creation with that app as its only bypass.

#### Scenario: A hand-made tag

- **WHEN** a person pushes a new release tag
- **THEN** the ruleset refuses it

### Requirement: Immutable releases are staged

GitHub immutable releases SHALL be enabled for core, the kernel library and the catalog repository. The CLI and the operator SHALL be added only after each has shipped a release that was created as a draft, received every asset while a draft, and was published last.

#### Scenario: The CLI before its draft-first release

- **WHEN** the CLI has not yet shipped a draft-first release
- **THEN** immutable releases are not enabled for the CLI
