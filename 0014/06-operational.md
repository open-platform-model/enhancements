# Operational Concerns — Export a Deployed Instance as GitOps Manifests

This document is the OPM Production Readiness Review (PRR-lite). Five fixed prompts, each answered.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

The export is a CLI operation, so its observability is its terminal output and its exit codes; it emits no metrics and writes nothing to the cluster.

New surfaces, all in `cli/internal/workflow/export/` and rendered via `cli/internal/output/`:

- **Gate failures**, one message per gate, each reusing handoff's remediation wording so the two commands fail identically on the same condition: local render provenance ("publish the module, re-apply with the CLI, then export"), an incomplete `spec.module`, an absent `status.lastAppliedRenderDigest`, and a verification-digest mismatch reporting both digests and the module coordinate. Exit codes follow the existing `opmexit` classification — validation failures are `ExitValidationError`, a missing instance is `ExitNotFound`.
- **Completion notices**, one per apply-bearing field the export filled in. The `spec.prune` notice states the behaviour change (orphan versus delete) rather than the field name.
- **The values warning**, unconditional, naming the file the values were written to (D3).
- **The written-file summary**, listing the directory and the file count.

There is no new operator-side or cluster-side signal: the export reads and writes nothing that a controller observes.

The one diagnostic gap worth naming: a successful export tells the user the tree reproduces what is running *now*. Nothing re-checks that afterwards. If the instance changes between export and commit, the tree is stale and no OPM signal reports it — the user finds out from Flux applying it.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

Not breaking for anyone. `opmodel.dev/core` is untouched — no schema definition changes, so no `@v0` → `@v1` pressure. The `ModuleInstance` CRD is untouched: the export reads existing fields and writes files. The library kernel is untouched.

The only change is additive CLI surface: a new `opm instance export` subcommand plus one read-only field on the CLI-internal `inventory.Record`. `config.yaml.semver` is `none` on the published-contract axis, matching 0006's precedent (which added a whole command group and still recorded `none`). On the CLI's own version the change is a minor bump.

The one internal refactor — lifting `VerificationDigest` out of `internal/workflow/handoff/` into a shared package — moves an unexported-to-users symbol inside `internal/`, so it has no consumer impact.

## Deprecation

**What gets removed and when? What replaces it?**

Nothing is deprecated. No CUE definition, Go function, field, or fixture is removed, and no existing command changes behaviour.

The one thing that becomes *discouraged* rather than removed is the manual procedure: hand-assembling a per-app directory from a `kubectl get -o yaml` dump. It keeps working, since nothing prevents a user from writing YAML by hand, and `opm-kind-demo/`'s hand-written directories stay as they are — they are pedagogical artifacts, and rewriting them as generated output would remove the reference that shows what the generator is aiming at.

If OQ6 resolves toward a warning on `opm instance apply` for git-managed instances, that is a new diagnostic on an existing path, not a deprecation of it: the CLI still applies, it just says what will happen next.

## Rollback

**If this lands and proves bad, what's the rollback story?**

Clean, because the command has no cluster-side effect. Reverting the CLI to the prior version removes `opm instance export`; every instance in every cluster is exactly where it was, since the export never wrote to the API server.

The state that survives a code rollback is the exported files themselves and whatever the user did with them. Those decompose into two cases:

- **Exported but not applied.** The directory is inert YAML in a working tree. Deleting it is the whole rollback.
- **Exported, committed, and applied by Flux.** The rollback is a GitOps rollback, not an OPM one: the CR is now owned by Flux's field manager, so removing the CLI changes nothing about who reconciles it. Returning that instance to CLI or plain-operator management means removing it from the Flux `Kustomization`'s path (with `prune` disabled, or the deletion cascades) — which is the standard Flux disown procedure and is outside this enhancement's control. This asymmetry is worth stating plainly: **the command is reversible, its consequences are not.** That is a property of adopting GitOps, not of this design, but a user reading "rollback" deserves to see it named.

There is no data-plane state change, no CRD change, and no stored format to migrate.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

Only `cli/`. `config.yaml.affects` lists it alone, and the sequencing is internal to that repo: the shared verification package first, then the export workflow, then the command and its tests.

Two soft dependencies, neither blocking:

- **`opm-operator/`** ships no code for this, but its `ModuleInstanceSpec` is the contract the exported CR must satisfy. A future field on that spec that the export does not know about would silently drop out of exported documents — the same class of incompleteness `01-problem.md` documents for `serviceAccountName` and `prune` today. The field-class table in `02-design.md` is the place that has to be updated when the spec grows.
- **`opmodel.dev/`** regenerates its CLI reference from the Cobra definitions; mechanical, and it follows the CLI landing rather than gating it.

`core/`, `library/`, `catalog/` and `modules/` are uninvolved.
