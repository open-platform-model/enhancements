# 0004: Automated CUE Dependency Updates via Dagger

One function bumps every CUE dependency under a directory, inside the major each dependency already names. A daily CI job in each repo runs it and opens one pull request. The local update task runs the same function.

## Why

CUE pins move only when a maintainer runs a workspace task by hand, from a checkout that holds every repo. Nothing watches for new releases, so a repo can sit on a stale pin for months. The task cannot run in the CI of one repo, and a bump leaves no trail of what changed upstream.

## What Changes

- One function walks a directory for CUE modules and bumps each dependency to the newest release inside its pinned major.
- Each bumped module is tidied, so a bump is a consistent module and not a bare version edit.
- A daily job in every enrolled repo opens one grouped pull request on a fixed branch, and updates it in place later.
- The local update task wraps the same function, so the two cannot drift.
- Test-fixture modules are bumped like any other.

## What this is not

- Not other ecosystems: Go modules, Action pins, Dockerfiles.
- Not auto-merge. A human reviews every pull request.
- Not a major-version migration, and not a bump of the CUE language version.

## Example

`opmodel.dev/core` publishes a new minor release. Today `modules` keeps the old pin until a maintainer sweeps the workspace. After this change the next daily run in `modules` bumps the pin, tidies it and opens one pull request with the old and new versions.

## Capabilities

- **New:** `cue-dependency-bump`, `dependency-update-pr`, `local-dependency-sweep`

## Impact

- **Maintainers** review one pull request per repo.
- **Seven repos** change: a short caller workflow in each of six repos, and the shared reusable workflow in `.github`. The shared Dagger module lives in the organisation's daggerverse repo.
- The Dagger engine becomes a CI dependency in six repos. Not breaking.
