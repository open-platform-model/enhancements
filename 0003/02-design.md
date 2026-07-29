# Design — OPM Module Publishing Workflow

> **Stub.** This entry is superseded; its narrative documents were collapsed on 2026-07-29. This is the document the supersession note singled out: it still described the version-agreement design under a "Revised" banner while later decisions had already retired it, and the old append-only rule made repairing it in place illegal. The full prior text is in git history.

## What this document covered

A convention anchored on one canonical identifier, enforced where modules are produced and consumed:

- **Canonical reference mapping.** `registry path = metadata.modulePath + "/" + metadata.nameSnakeCase`, major qualifier `vMAJOR(metadata.version)`, CUE package name `= metadata.nameSnakeCase` — collapsing three independent spellings to one identity with one canonical projection.
- **Version agreement.** `metadata.version` and the artifact's release tag are the same value, stated in `schemas/target.cue` as `#PublishedModuleRef` so a mismatch is a type error rather than a tolerated disagreement.
- **Verification at acquire, not only at publish.** `cue mod publish` exists and every module published to date bypassed OPM tooling, so a check a publisher can walk past is worth nothing to a consumer. Placing it on the registry acquisition path in `library` means the CLI and the operator inherit it from one implementation.
- **Two artifact types, two fetch paths, one invariant.** Modules arrive through `AcquireModuleFromRegistry`; catalogs through subscription resolution in `library/opm/materialize`. Catalogs are degenerate on the addressing axis and acute on the version axis.

## Why it stopped being accurate

The decision log kept moving and this document did not. D13 removed `metadata.version` from `#Module` entirely — with one version in the system there is nothing to agree. D16 made `metadata.modulePath` the full CUE module path. D17 and D18 made FQNs major-keyed. D19 then reversed D17's version-deletion for `#Catalog`, because the full version is what lets a module record which catalog build it was authored against.

By supersession the design above was three reversals out of date, which is precisely why the work was split rather than repaired.

## Where it went

- **[0010 — Module and Catalog Identity](../0010/)** — the identity shape, restated with only current answers.
- **[0011 — Module and Catalog Publishing](../0011/)** — the publish pipeline and the registry.

Both start fresh decision logs at D1. `schemas/target.cue` in this entry still compiles and records the shape as it stood at supersession — read it as history, not as a contract.
