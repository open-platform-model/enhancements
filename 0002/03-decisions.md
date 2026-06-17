# Design Decisions — Rename #ModuleRelease to #ModuleInstance

This document records every significant design choice with its reasoning and the alternatives that were ruled out. Decisions are append-only (`D1`, `D2`, …); reversed conclusions get a new `DN`, never a renumber.

---

## Decisions

### D1: Scope is the core deployable-artifact family; the operator `Release` CRD is not renamed

**Decision:** This enhancement renames the `core` schema's deployable-artifact construct and its supporting identity types (`#ModuleRelease`, `#ModuleReleaseMap`, `#ReleaseIdentity`, `#ctx.release`, `#Component.#release`, transformer `#moduleRelease*`) to instance vocabulary. It does **not** rename the operator's `Release` CRD (`opm-operator/api/v1alpha1/release_types.go`).

**Alternatives considered:**

- **Rename both `core` artifact and operator `Release` CRD to Instance.** Rejected: the operator's `Release` is a GitOps reconciliation resource (fetch artifact → render → SSA apply → prune, with `dependsOn`/`suspend`/impersonation). It models the *act of releasing*, not an instance; "Instance" describes it poorly, and Argo (`Application`) / Flux (`HelmRelease`, `Kustomization`) precedent shows "Release"/reconciler-noun is idiomatic for that role. Collapsing both into "Instance" would erase a distinction the architecture deliberately maintains.
- **Rename the operator CRD to a third name (e.g. `Deployment`/`Placement`).** Rejected for this enhancement: it is a separate decision with its own justification and blast radius; bundling it dilutes the focused terminology fix. Can be a follow-up enhancement.

**Rationale:** The driver is *clearer multiplicity* — "Instance" conveys that one `#Module` yields many concrete deployments. That argument applies to the `core` artifact and is weak-to-wrong for the reconciliation CRD. Keeping the rename to where the argument holds keeps the change coherent and the blast radius bounded.

**Source:** User decision 2026-06-17 (scope: "Core #ModuleRelease only"; driver: "Clearer multiplicity").

---

## Open Questions

These must resolve (each → `resolved-by-D##`, `deferred-to-NNNN`, or `answered`) before promotion to `accepted`. OQ1 and OQ2 are the crux: they determine whether this is genuinely a core-only change or a cross-repo wire-contract change.

- **OQ1: Does the `kind` discriminator string change from `"ModuleRelease"` to `"ModuleInstance"`?** Status: open. The library kernel and the operator's `Release` reconciler match this literal to recognize a deployable render (`opm-operator/.../release_types.go` rejects any other kind). Renaming the CUE definition but keeping `kind: "ModuleRelease"` keeps the change truly core-only but leaves a visible inconsistency (definition says Instance, wire says Release). Renaming `kind` too is the honest end-state but forces lockstep library + operator updates — i.e. `affects` grows to `[core, library, opm-operator]`. Resolution needs the user to choose consistency-now (cross-repo) vs core-isolation-now (deferred wire rename).

- **OQ2: Does the label domain change from `module-release.opmodel.dev/*` to `module-instance.opmodel.dev/*`?** Status: open. These keys land on rendered Kubernetes objects (`module_release.cue:29-30`, `transformer.cue:147`) and may appear in selectors or external tooling. Changing them is observable on the data plane; not changing them leaves Helm-flavored vocabulary on every rendered object. Tied to OQ1 — if the wire stays `Release`, the labels arguably should too, for consistency.

- **OQ3: Hard rename, or a transition window with a `#ModuleRelease` alias in `core`?** Status: open. `core` is pre-`v1` (`opmodel.dev/core@v0`). A hard rename (no alias) is simplest and matches the pre-`v1` posture. An alias (`#ModuleRelease: #ModuleInstance`) eases downstream migration at the cost of carrying both names. Default position: hard rename.

- **OQ4: Confirm `config.yaml.semver: major` and the CUE-module tag mechanics.** Status: open. A definition rename is breaking for any consumer referencing the old identifiers, so the *design-impact* field is `major`. Note the CUE-module tag does **not** jump to `@v1`: per `core/CLAUDE.md` (`bump-minor-pre-major: true`), the module stays capped at `@v0` pre-1.0 and a breaking change ships as a `feat!:` / `BREAKING CHANGE:` **minor** `v0.x` bump. So `semver: major` (design impact) and a `v0.x` minor tag (release mechanics) are both correct on their respective axes — OQ4 just confirms the field value and that the implementer uses `feat!:`. An OQ3 alias could soften the design impact to `minor`.
