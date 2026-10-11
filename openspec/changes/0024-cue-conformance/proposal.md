# 0024: CUE Testing and Conformance

Most of what OPM promises is CUE evaluation, and it is verified unevenly. This entry adds two layers: assertions beside each definition, and an outside suite that replays inputs across versions.

## Why

The catalog carries 163 hidden assertions. The core schema has no committed test. No test asserts a rejection or records the text of a refusal. A CUE, core or upstream release can change what an unchanged input renders to, and a consumer finds out one release later. The default-name change of enhancement 0019 was verified once, by hand, in a scratch copy.

## What Changes

- A definition gets assertions beside it that state what it accepts, what it rejects and what it derives, in pure CUE.
- A suite outside every product repo replays recorded cases per version cell and compares rendered output and refusal text.
- A difference that nothing explains fails. A difference a release explains is recorded and reviewed.
- Every rendered Kubernetes object is checked against the upstream definition for its own kind, at each upstream snapshot.

## What this is not

- Not a test strategy for the Go repos. The suite renders through the pure-CUE oracle and needs no kernel.
- Not admission or runtime validity beyond upstream types.
- Not one golden per case. Behaviour changes between releases, and the suite objects only to unexplained change.

## Example

A core release changes how an overlong default name is refused. The case is replayed at the new core version, and its refusal text differs from the record. The suite fails until the release note explains it and a reviewer reads the new record.

## Capabilities

- **New:** `conformance-record`, `upstream-conformance`

## Impact

- **Release maintainers** see every byte and message a release changed, before a fleet reconciles it.
- **Three repos** change: core, catalog_opm and library. The suite itself needs a home (see the second blocking question). No published definition changes, so the entry is not breaking.

## Open questions

- Blocking: Is the upstream axis the snapshot version of the upstream Kubernetes CUE module, or a Kubernetes release mapped to it? The records are keyed by this axis. The module records no Kubernetes release, and two snapshots differ in one group version. It settles when a consumer needs to pin a release rather than a snapshot.
- Blocking: Where does the conformance suite live? A new workspace repo, a directory in the meta repo, or a directory in library (rejected in the design). The answer sets `affects` and whether the repo list and the workspace routing change. It settles when a repo that owns no product artifact is shown to fit the workspace model.
- Blocking: Do product repos fail on conformance drift, or only report it? The design says drift fails unless explained, and that must name where. It settles when the release pipelines of core and catalog_opm are shown able to run a check against a pre-release tag before the release PR merges.
- Not blocking: Does the kernel's render join the version matrix as a fifth axis? It would catch drift the parity harness cannot see, at the cost of a Go dependency in the suite. It settles when such drift is shown worth a cell.
- Not blocking: How are source positions in a refusal excluded from comparison, and which runner drives the cases? The tool prints positions under each message and has no flag to suppress them. It settles with the first corpus and one core release of position churn.
- Not blocking: Do the catalog's 163 in-module assertions stay where they are? The leaning is yes, with the suite exercising the same transformers from outside.
- Not blocking: May a negative in-package assertion pass on an incomplete value? The guard treats incomplete as rejected. The options are to accept it, to require a paired positive, or to add a concreteness check.
- Not blocking: Do in-package test files ship inside published CUE modules? Publishing takes the module root. The options are to accept them as inert, to use a sibling test package that cannot see hidden fields, or to exclude them at publish time if the tooling can.
