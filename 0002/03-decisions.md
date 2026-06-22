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

### D2: Scope is cross-cutting; the GitOps `Release` CRD is renamed to `ModulePackage` (supersedes D1)

**Decision:** This enhancement is no longer core-only. It drives the rename through `core`, `library`, `opm-operator`, and `cli` (`affects: [core, library, opm-operator, cli]`). In particular, the operator's GitOps reconciliation CRD `Release` (`opm-operator/api/v1alpha1/release_types.go`) **is** renamed — to **`ModulePackage`**. This supersedes the scoping conclusion of **D1**, which kept that CRD un-renamed. D1 remains in the log as the original (now reversed) conclusion.

**Alternatives considered:**

- **Keep D1 — leave the GitOps `Release` CRD un-renamed.** Rejected: with `#ModuleRelease`/`ModuleRelease` renamed to `Instance` across core, library, the operator's `ModuleRelease` CRD, and the CLI, leaving a sibling CRD literally named `Release` keeps "release" vocabulary alive on the very surface the rename exists to clean up. The user elected full vocabulary consistency over the artifact-vs-reconciler distinction D1 protected.
- **Rename the GitOps CRD to `Instance` (collapse it into the deployable instance).** Rejected for the same reason D1 gave: it is a reconciliation resource, not an instance. `ModulePackage` names what it actually points at — a packaged module artifact, fetched from a Flux source, that the reconciler renders into a `#ModuleInstance`.
- **Rename it to `Deployment`/`Placement`.** Rejected: `Deployment` collides with the Kubernetes kind; `Placement` is scheduling jargon. `ModulePackage` reads as "the packaged module to reconcile" and stays in the `Module*` family.

**Rationale:** A cross-cutting rename whose stated goal is one coherent "Instance" vocabulary cannot stop at the boundary D1 drew without reintroducing the exact confusion it set out to remove. `ModulePackage` keeps the artifact-vs-reconciler *distinction* D1 valued (the reconciler is still a separate kind, not an `Instance`) while removing the "release" lexeme.

**Source:** User decision 2026-06-22 (AskUserQuestion: GitOps Release CRD → "Rename Release to ModulePackage"; scope → cross-cutting).

---

### D3: The `kind` discriminator strings move (resolves OQ1)

**Decision:** The wire `kind` strings move in lockstep: `"ModuleRelease"` → `"ModuleInstance"`, `"BundleRelease"` → `"BundleInstance"` (see D7), and the GitOps CRD kind `Release` → `ModulePackage` (see D2). The library kernel kind-detection (`ReleaseSpec.ExpectedKind`, `synth` `#ModuleRelease` lookup), the operator render constant (`KindModuleRelease`), and the CLI kind-detection (`DetectReleaseKind`) all update to the new literals.

**Alternatives considered:**

- **Keep `kind: "ModuleRelease"` while renaming the CUE definition.** Rejected: this is the split-brain end-state called out in 05-risks — `#ModuleInstance` would evaluate to `kind: "ModuleRelease"`, adding a second name without retiring the first. Worse than the status quo.

**Rationale:** With library + operator + cli all in scope (D2), the consumers that match the literal are being edited anyway; there is no isolation benefit left to preserve. Move the wire to match the definitions.

**Source:** User decision 2026-06-22 (cross-cutting scope implies the wire moves; confirmed via AskUserQuestion on label/group).

---

### D4: The label domain moves to `module-instance.opmodel.dev/*` (resolves OQ2)

**Decision:** The rendered-object label keys `module-release.opmodel.dev/{name,namespace,uuid}` → `module-instance.opmodel.dev/{name,namespace,uuid}`, everywhere they are defined (core schema, library `synth`, operator `pkg/core/labels.go`, cli `pkg/core/labels.go`) and consumed (operator prune/ownership, cli inventory selectors).

**Alternatives considered:**

- **Keep `module-release.opmodel.dev/*` to avoid data-plane selector churn.** Rejected: leaves release-flavored keys on every rendered object, contradicting the rename, and the operator/CLI that select on these keys are being updated in lockstep anyway.

**Rationale:** Consistency end-to-end. The migration cost (re-applying objects so the new key lands, updating any external selectors) is accepted as part of the breaking rollout.

**Source:** User decision 2026-06-22 (AskUserQuestion: label domain → "Move to module-instance.opmodel.dev/*").

---

### D5: The operator Kubernetes API group is renamed to `opmodel.dev`

**Decision:** The operator's API group `releases.opmodel.dev` → **`opmodel.dev`** (kubebuilder `domain: opmodel.dev`, `group: ""`). All three CRDs (`ModuleInstance`, `ModulePackage`, `Platform`) move to the new group. The finalizer key `releases.opmodel.dev/cleanup` → `opmodel.dev/cleanup`. RBAC, kustomize bases, samples, and `PROJECT` regenerate accordingly.

**Alternatives considered:**

- **Keep `releases.opmodel.dev` as a stable group domain.** Rejected by the user in favour of full consistency, even at higher cluster-migration cost.
- **Rename to `instances.opmodel.dev`.** Rejected: the group now holds mixed kinds (`ModuleInstance`, `ModulePackage`, `Platform`); a kind-specific group name fits none of them. A flat `opmodel.dev` is kind-agnostic.

**Rationale:** With the CRD kinds renamed and "releases" no longer describing the group's contents, a neutral flat group is the cleanest stable home. This is the single most disruptive part of the change (every existing CR, RBAC rule, and manifest moves) and is taken deliberately — see 05-risks.

**Source:** User decision 2026-06-22 (AskUserQuestion: API group → "Rename the API group"; flat `opmodel.dev` proposed in the implementation plan).

---

### D6: The CLI user-facing command group `release` is renamed to `instance`

**Decision:** The CLI command group `opm release …` → `opm instance …`, alias `rel` → `inst`. All nine subcommands (vet/build/apply/diff/status/tree/events/delete/list), their help text, examples, and the `internal/cmd/release/` package are renamed. Internal Go identifiers follow.

**Alternatives considered:**

- **Rename internal identifiers only, keep `opm release` as the verb.** Rejected: leaves a release-named command rendering a `#ModuleInstance` — partial consistency at the most visible surface.

**Rationale:** The CLI has no external users (project memory: refactor freely, no backwards-compat owed), so a user-facing command rename is safe and the consistency win is worth it.

**Source:** User decision 2026-06-22 (AskUserQuestion: CLI command surface → "Rename commands to `opm instance`").

---

### D7: `BundleRelease` is renamed to `BundleInstance`

**Decision:** The parallel `BundleRelease` construct (CLI: `pkg/bundle/release.go`, `ProcessBundleRelease`, the `"BundleRelease"` arm of `DetectReleaseKind`) → `BundleInstance` / `"BundleInstance"`. If a bundle kind exists in `core`/`catalog`, it renames there too (to be confirmed during the implementing slice — inventory found `BundleRelease` only in `cli`).

**Alternatives considered:**

- **Leave `BundleRelease` as-is.** Rejected: a bundle is "many instances released together," but keeping "Release" on it reintroduces the lexeme the rename retires. The user chose full vocabulary alignment.

**Rationale:** Uniform "Instance" vocabulary across every deployable artifact kind the CLI recognizes.

**Source:** User decision 2026-06-22 (AskUserQuestion: BundleRelease → "Rename to BundleInstance").

---

### D8: Hard rename, no alias window; `semver: major` (resolves OQ3, OQ4)

**Decision:** No compatibility alias is offered in any repo — old identifiers, kinds, labels, the API group, and CLI commands are removed, not dual-published. `config.yaml.semver` is `major` (design impact). The `core` CUE-module tag stays capped at `@v0` per `core/CLAUDE.md` (`bump-minor-pre-major: true`) and ships the break as a `feat!:` / `BREAKING CHANGE:` **minor** `v0.x` bump.

**Alternatives considered:**

- **Alias window (`#ModuleRelease: #ModuleInstance`, dual labels, hidden `release` command alias).** Rejected: `core` is pre-`v1` and the operator/CLI have no external users, so the migration-easing value is low and the cost (carrying both names, two-vocabulary docs) is real.

**Rationale:** Pre-`v1` posture plus no external consumers makes a clean break cheaper than a transition window. Design impact is `major`; release mechanics stay on the `v0.x` axis.

**Source:** User decision 2026-06-22 (AskUserQuestion: hard rename selected via the maximalist answers; OQ4 confirmed against `core/CLAUDE.md` release config).

---

## Open Questions

All four open questions are now resolved (2026-06-22). They were the crux that determined whether this stayed core-only or became cross-repo; the user chose the cross-repo, fully-consistent path, which is recorded in D2–D8.

- **OQ1: Does the `kind` discriminator string change from `"ModuleRelease"` to `"ModuleInstance"`?** Status: resolved-by-D3 (yes — `kind` strings move, including `BundleInstance` and the GitOps `ModulePackage` kind).

- **OQ2: Does the label domain change from `module-release.opmodel.dev/*` to `module-instance.opmodel.dev/*`?** Status: resolved-by-D4 (yes — label keys move everywhere defined and consumed).

- **OQ3: Hard rename, or a transition window with a `#ModuleRelease` alias in `core`?** Status: resolved-by-D8 (hard rename, no alias — pre-`v1` core, no external CLI/operator users).

- **OQ4: Confirm `config.yaml.semver: major` and the CUE-module tag mechanics.** Status: resolved-by-D8 (`semver: major` design impact; core ships as a `feat!:` `v0.x` minor tag per `bump-minor-pre-major: true`).
