<!-- The sections run in order: section 1 is done before section 2, and so on. The order is advice: no field, no check. -->

## 1. Release immutability

- [x] 1.1 core: refuse a version the registry already holds, and publish only to a local registry from the task (guard-release-immutability)
- [x] 1.2 opm-controller: attach release assets to a draft and publish last, and refuse to re-point a version tag on image push (adopt-draft-first-release)
- [x] 1.3 cli: draft the release first, let the release tool fill and publish it, and refuse recovery of a published one (adopt-draft-first-release)
- [ ] 1.4 library: refuse to re-point a version it has already pushed on every release path
- [ ] 1.5 catalog_opm: refuse to re-point a version it has already pushed on every release path

## 2. Release branches

- [ ] 2.1 core: adopt the release-branch automation (cut action, branch release workflow, branch pull-request checks) once the sandbox proves it
- [ ] 2.2 library: adopt the release-branch automation once the sandbox proves it
- [ ] 2.3 cli: adopt the release-branch automation once the sandbox proves it
- [ ] 2.4 opm-controller: adopt the release-branch automation once the sandbox proves it
- [ ] 2.5 catalog_opm: adopt the release-branch automation once the sandbox proves it, releasing only the branch's own component

## 3. Beta line and GA

- [x] 3.1 core: move the prerelease line from alpha to beta and state the beta promise (adopt-beta-release-line)
- [x] 3.2 cli: move the line to beta and compare only `MAJOR.MINOR` in the controller version ceiling (adopt-beta-release-line)
- [x] 3.3 opm-controller: move the line to beta (adopt-beta-release-line)
- [x] 3.4 library: type registry fetch failures as they leave the library (type-fetch-errors-and-check-cancellation)
- [x] 3.5 library: type author-defect resolution failures with a kind (type-author-resolution-errors)
- [x] 3.6 library: classify a token endpoint refusal as unauthorized through one anchored match, the owner's recorded exception (classify-token-endpoint-refusal)
- [x] 3.7 opm-controller: decide retry or stall from the library's typed fetch errors (classify-registry-errors-by-type)
- [x] 3.8 cli: read connectivity, unpublished and absent answers from the library's typed fetch errors (classify-registry-errors-by-type)
- [x] 3.9 cli: decide fetch and resolution answers from the library's error types, with a guard against new text matches (drop-resolution-text-matches)
- [ ] 3.10 library: return plain data from render, pass strict spec validation, and make the documents match the code
- [ ] 3.11 cli: republish the module templates and the quickstart against GA versions at each GA
- [ ] 3.12 opmodel.dev: drop the beta label of the documentation site at GA

## 4. Controller install module

- [x] 4.1 opm-controller: publish the controller module on its own version train, one controller version per module version (release-controller-module)
- [x] 4.2 cli: install the controller from the module in a registry, check the target module's controller version, and uninstall from the recorded inventory (install-controller-from-module)

## 5. Policy publication

- [ ] 5.1 opmodel.dev: publish the policy page with the universal rules and one section per artifact class, and pin docs sources by tag or full SHA
- [ ] 5.2 core: point the versioning table at the policy and define breaking against the published definitions
- [ ] 5.3 catalog_opm: state how a contract-level event moves the build number, and point the repo notes at the policy
- [ ] 5.4 modules: state the config-schema rule and the fleet's release convention, and point the repo notes at the policy
