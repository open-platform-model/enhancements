# Operational Concerns: The Operator Becomes the Controller

## Observability

No new signal. Conditions, events and log lines keep their meaning; the component name and the owner value they carry change.

## Semver Impact

Breaking for every consumer of the ModuleInstance and Platform APIs and of the CLI's controller commands. It ships before the first `v1.0.0` release, on the beta lines, as a breaking beta of the controller and of the CLI. The module that deploys the controller starts a new train under its new path.

## Deprecation

Nothing is deprecated. The former owner value, status field, command group, repository, image, module and namespace are removed in the same releases that introduce the new names.

## Rollback

Rolling back means reinstalling the previous controller and CLI releases, which still use the former names. A ModuleInstance written with owner `controller` is refused by the former CRD, so a rollback also rewrites the owner of each instance.

## Cross-Repo Coordination

- The enhancements vocabulary accepts the new repository name before any delivery log records a change in it, and keeps the former name for as long as an entry or a log names it.
- The live draft entries that restate a former name are edited after the repository carries its new name. Between the two, 0032:D1 is where the names are stated.
- The controller's first release under the new names exists before the CLI pins it, because the CLI resolves the deploying module from a registry.
- The docs site follows the controller and the CLI releases, because it builds the reference pages from their published docs bundles.
