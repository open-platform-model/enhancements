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

### D9: The instance-file naming convention moves — `release.cue` → `instance.cue`

**Decision:** The CLI's expected instance-file name moves with the rename: the loader filename `release.cue` → `instance.cue`, and the kind-detection / file-resolution that keys off that name (`get_release_file.go`, `release_kind.go`, the `internal/releasefile` package) updates to the new literal. Every authoring fixture that uses the old name is renamed too — `cli/examples/releases/**/release.cue` → `cli/examples/instances/**/instance.cue`, and the out-of-scope `modules/` + `releases/` fixtures (tracked as the closing sweep). This surfaced during implementation planning; it was not covered by D1–D8.

**Alternatives considered:**

- **Keep the `release.cue` filename while the kind/types become `Instance`.** Rejected: a user-facing file-naming convention is the most-touched authoring surface; leaving "release" on it reintroduces the exact lexeme the rename retires, at the place users see most often. Partial consistency at the highest-traffic surface is worse than the migration cost.

**Rationale:** The rename's goal is one coherent "instance" vocabulary end-to-end (02-design); a visible authoring convention is squarely inside that goal. The cost is a rename ripple into the out-of-scope `modules/` and `releases/` repos, accepted and tracked as a final sweep rather than left split-brained.

**Source:** User decision 2026-06-25 (AskUserQuestion: `release.cue` filename → "Rename to instance.cue").

---

### D10: Every `release`-named file and directory is renamed on disk (extends D8 to the filesystem)

**Decision:** The hard rename of D8 applies to paths as well as identifiers. Every source, test, sample, fixture, and example file or directory whose name carries the "release" lexeme is `git mv`'d to its instance/package equivalent across all four repos — not only the two the design originally named (`core/src/module_instance.cue`, `cli/internal/cmd/instance/`). Representative moves: library `opm/module/release.go` → `instance.go`, `opm/helper/synth/release.go` → `instance.go`; operator `api/v1alpha1/modulerelease_types.go` → `moduleinstance_types.go`, `release_types.go` → `modulepackage_types.go`, `internal/reconcile/release.go` → `modulepackage.go`, `test/fixtures/releases/` → `modulepackages/`; cli `pkg/render/process_bundlerelease.go` → `process_bundleinstance.go`, `internal/releasefile/` → `internal/instancefile/`. After the slices land, no "release" lexeme remains in any tracked path (excluding incidental tooling — `.goreleaser.yml`, release-please configs — and frozen historical records — ADRs, archived OpenSpec changes, `library/enhancements/001-007`).

**Alternatives considered:**

- **Rename file *contents* everywhere but only `git mv` the files the design explicitly called out.** Rejected: leaves `release`-named files containing `Instance` code — a confusing half-state that contradicts D8's "old names deleted, not aliased" intent and leaves stale paths for greps and imports to trip over.

**Rationale:** D8 established a clean break with no lingering "release"; that intent governs file paths as much as identifiers. The cost is `git mv` churn and a blame discontinuity, accepted given the pre-`v1` posture and absence of external consumers.

**Source:** User decision 2026-06-25 (AskUserQuestion: file renames → "Rename all files to match").

---

### D11: Renamed Go identifiers carry a doc comment with a `// Was:` old-name breadcrumb

**Decision:** In the three Go repos (`library`, `opm-operator`, `cli`), every renamed **exported** func, method, and type gets a Go doc comment whose first line uses the new name and instance vocabulary, followed by a blank comment line and a `// Was: <OldName>` tag — e.g.

```go
// Instance is a materialized module deployment.
//
// Was: Release
type Instance struct { ... }
```

Existing doc prose is rewritten in place to the new vocabulary (not duplicated); identifiers that already have docs are updated, identifiers that lack them get a short stub. Scope is exported funcs/methods/types only — unexported helpers are not required to gain new docs, and renamed constants/label keys keep their existing inline comments. This is documentation-only: the old identifier appears solely in a comment, so it is **not** a code alias and stays compatible with D8's hard rename.

**Alternatives considered:**

- **Inline parenthetical `(formerly Release)` on the first doc line.** Rejected in favour of the structured `// Was:` tag, which is uniform and greppable and survives line-wrapping.
- **No breadcrumb at all.** Rejected: a hard rename with no alias leaves readers no trail from old name to new; the breadcrumb provides that trail without reintroducing the old identifier in code.

**Rationale:** A clean break (D8) gives consumers and future readers nothing connecting the old name to the new. A doc-comment breadcrumb restores the trail at zero code-surface cost, and a single `// Was:` token keeps it consistent and machine-findable for the duration of the transition.

**Source:** User decision 2026-06-25 (AskUserQuestion: docstring scope = funcs/methods + types, exported only, update wording + name prefix; hint format = godoc-style `// Was:` tag).

---

### D12: The old-name breadcrumb applies to every rename site across code, docs, and specs (extends D11)

**Decision:** The breadcrumb introduced in D11 is generalized: whenever a name is changed anywhere in this rollout — in code, in docs, or in specs — a short old-name note is left at the rename site. This broadens D11 in two ways. (1) **Beyond Go exported identifiers** to every renamed *definition* regardless of visibility — package-private Go helpers and CUE `#`-definitions/fields included. (2) **Beyond Go source** to every surface, each with its own light form: CUE — a `// Was: #ModuleRelease` line comment above the renamed definition/field; markdown docs — a "Renamed from `…` (0002)." note on the renamed construct's heading or first mention; core `SPEC.md` — a "Renamed from `…` (0002)." line in the construct's **Definition** prose (fits the `core-schema-edit` four-part format); OpenSpec `spec.md` deltas — a one-line "Renamed from `…` (0002)." in each renamed/`MODIFIED` Requirement, with capability-directory renames recorded in that change's `proposal.md`. The breadcrumb sits at **declaration/definition sites** and at **doc/spec section headings or first mention** — never stamped on every downstream reference. Like D11 it is documentation-only (the old name survives only in a comment/prose note), so it remains compatible with D8's hard rename. D11 stands; D12 extends its scope.

**Alternatives considered:**

- **Keep D11 as-is — breadcrumb on Go exported identifiers only.** Rejected: a reader who lands on the renamed `SPEC.md`, a CUE module, or an OpenSpec requirement gets no trail from old name to new. The migration trail is wanted on every surface a name changes, not only the Go API.
- **Stamp the old name on every reference/occurrence.** Rejected: thousands of call sites would turn the trail into noise. Definition- and section-level breadcrumbs carry the trail without drowning the code.

**Rationale:** D8's clean break removes the old name from code entirely; D11 restored a trail for the Go exported API. The same argument applies to every surface a reader might land on. A uniform, greppable breadcrumb at definition/section granularity provides that trail at minimal cost and stays out of the way of normal reading.

**Source:** User decision 2026-06-26 (follow-up to D11: "whenever we change the name in code or in docs or in specs we leave a quick note that this has been changed from …").

---

### D13: Artifacts ship as v1 prereleases `v1.x.x-alpha.x`, including the operator/CRDs (revises D8 release mechanics)

**Decision:** Every affected repo's published artifact is versioned as a **v1 prerelease** — `v1.0.0-alpha.N` (scheme `v1.x.x-alpha.x`) — for the duration of this rename rollout, explicitly including `opm-operator` and the CRD bundle it ships ("that includes the CRDs"). This **revises the release-axis mechanics of D8** only: D8's `v0.x` minor (`feat!:` under `bump-minor-pre-major: true`) is replaced by the v1-prerelease line. D8's hard-rename / no-alias conclusion and the `config.yaml.semver: major` design-impact classification **stand unchanged**.

Consequences of the v1 line:

- **core** — the CUE module advances from `opmodel.dev/core@v0` to `opmodel.dev/core@v1` (per `core/CLAUDE.md`, `@v0→@v1` *is* the CUE breaking-major mechanism; there is no `v1.x.x` that remains on the `@v0` path). Every downstream import `".../core@v0:core"` → `@v1`, and core's release-please `bump-minor-pre-major: true` no longer governs — the config must allow the `v1.0.0-alpha` line. This is an additional breaking surface (import paths) that D8 had deliberately avoided; it is accepted here as the cost of graduating the post-rename schema to its v1 baseline.
- **library / cli / opm-operator** — their published tags move to the same `v1.0.0-alpha.N` scheme; downstream pins (`task update-deps`, Go module requires, kustomize/OCI refs) advance to the v1 prerelease tags in dependency order (core → library → operator ‖ cli).
- **CRDs (K8s served apiVersion)** — unaffected. The served version (`v1alpha1`) is a Kubernetes-convention axis (`vNalphaM`), not a semver artifact axis, and cannot carry a `v1.x.x-alpha.x` string. "Includes the CRDs" means the operator *artifact* that bundles them is versioned on the v1-prerelease line, not that the served apiVersion changes.

**Alternatives considered:**

- **Keep D8's mechanics — core capped at `@v0`, ships as a `feat!:` `v0.x` minor.** Rejected: a `v0.x` tag understates the milestone and leaves core perpetually pre-`v1`. The rename is the breaking event that justifies declaring the v1 baseline; the user elected to graduate the family to a v1 line rather than take another v0 increment.
- **Ship a stable `v1.0.0` directly (no prerelease).** Rejected: the rename lands across four repos in sequence and wants a soak/iteration window before a stable commitment; `alpha` prereleases let the new vocabulary settle before `v1.0.0`.
- **Bump only the K8s CRD served apiVersion (e.g. `v1alpha1` → `v1alpha2`).** Rejected / non-applicable: this enhancement is a pure rename with no schema-shape change (a served-version bump exists to manage stored-object schema migration, which there is none of), and the served-version axis is unrelated to the `v1.x.x-alpha.x` artifact scheme the decision sets.

**Rationale:** The cross-cutting break is the natural moment to declare a v1 baseline; doing it as `v1.0.0-alpha` prereleases marks that milestone while preserving room to iterate across the four-repo rollout before a stable `v1.0.0`. Applying the one scheme to every artifact — including the operator/CRD bundle — keeps a single coherent version story across the family. D8 stays in the log; D13 revises only its release-axis mechanics.

**Source:** User decision 2026-06-26 ("I want the versions to be prereleases of v1. Meaning we name it v1.x.x-alpha.x, that includes the CRDs").

---

### D14: The catalog family is in scope; each catalog CUE module bumps `@v0 → @v1` on a forward-alpha line (extends D8/D13 scope)

**Decision:** The three downstream catalog repos — `catalog_opm` (`opmodel.dev/catalogs/opm`), `catalog_kubernetes` (`opmodel.dev/catalogs/kubernetes`), and `catalog_opm_experimental` (`opmodel.dev/catalogs/opm-experimental`) — are **added to this enhancement's scope** (`affects` gains `catalog`). They consume core's `#TransformerContext` and break the moment they pin `opmodel.dev/core@v1`, so the C1 core rename ripples into them. Four sub-conclusions:

1. **They are renamed, not left behind.** Each catalog pins `opmodel.dev/core@v1` (`v1.0.0-alpha.1`) and renames the consumed surface: transformer-context `#moduleReleaseMetadata` → `#moduleInstanceMetadata` (the only compile-required change; 50 refs in `catalog_opm`, 44 in `catalog_kubernetes`, 0 in the `catalog_opm_experimental` skeleton), plus every `core@v0` import → `@v1`.
2. **Full consistency rename, not compile-minimum.** Catalog-*local* vocabulary that mirrors the old name is also renamed for consistency with the new core vocabulary, even though it is not inherited from core and would still compile: `catalog_opm`'s helper field `#releasePrefix` → `#instancePrefix` (33 refs), "release" prose comments, and the `"test-release"` test fixture. This matches D12's principle that the rename is total across a renamed concept's sites.
3. **Each catalog CUE module advances `@v0 → @v1`.** Per the same `@v0→@v1`-is-the-breaking-major mechanism D13 invoked for core, the catalogs graduate to a `@v1` module path and ship on the v1 prerelease line.
4. **Forward-alpha tag reconciliation for the two repos already past `v1.0.0`.** `catalog_kubernetes` (latest git tag `v1.0.0`) and `catalog_opm_experimental` (`v1.1.0`) had crossed into git-`v1.x` while their CUE module path stayed `@v0` — a pre-existing axis mismatch (release-please bumped the tag-major independently of the CUE module-major). Rather than rewrite published tag history, the module-major is aligned **up** to the existing git-tag-major and the rename ships as the **next forward prerelease** on that line: `catalog_opm` `v1.0.0-alpha.1` (clean, from `v0.6.0`), `catalog_kubernetes` `v1.1.0-alpha.1` (forward of `v1.0.0`), `catalog_opm_experimental` `v1.2.0-alpha.1` (forward of `v1.1.0`). Each catalog's `release-please-config.json` adopts the same prerelease block core uses (`versioning: prerelease`, `prerelease: true`, `prerelease-type: alpha`, `bump-minor-pre-major: false`, fresh `bootstrap-sha`).

The `modules/` and `releases/` re-pin onto `catalog_opm@v1` stays **out of scope** here (consistent with the D9 ripple already excluded by `planned-changes.md`): the old `@v0` catalog tags remain published, so those consumers keep resolving against `core@v0` until migrated under separate tracking.

**Alternatives considered:**

- **Leave the catalogs out of 0002 and migrate them as standalone dep-refresh PRs.** Rejected: the break originates entirely in this enhancement's core rename; folding them in keeps the audit trail (which artifacts ship `v1.x.x-alpha.x`, why `#moduleReleaseMetadata` moved) in one design contract rather than scattering it across untracked PRs.
- **Compile-minimum only — rename `#moduleReleaseMetadata` and stop.** Rejected: leaves catalog-local `release` vocabulary (`#releasePrefix`, comments, fixtures) contradicting the new core vocabulary, the same split D12 exists to prevent.
- **Tag the two divergent repos `v1.0.0-alpha.x` to match `catalog_opm` exactly, or rewrite their `v1.x` tags.** Rejected: `1.0.0-alpha.1` sorts below their existing `v1.0.0`/`v1.1.0` releases (release-please cannot go backwards), and rewriting published tag history is destructive. Forward-alpha on the existing line is the only non-destructive, semver-valid path.
- **Jump the two repos to `@v2` / `v2.0.0-alpha.x`.** Rejected: skips `@v1` entirely for modules currently at `@v0`, fragmenting the family's version story for no benefit over aligning to the already-published `v1.x` tag-major.

**Rationale:** The catalogs are the first real downstream consumers of the renamed core context; bringing them in now (rather than discovering the break at `task update-deps` time) keeps the rename atomic per repo and the design contract complete. The forward-alpha reconciliation respects published history while still graduating every catalog to the `@v1` baseline that D13 set for the rest of the family.

**Source:** User decisions 2026-06-27 (scope: "add to enhancement 0002"; rename depth: "full consistency rename"; versioning: "bump catalogs @v0 → @v1 … tag is v1.0.0-alpha.x"; reconciliation: "align module @v0 → @v1, forward alpha").

---

## Open Questions

All four open questions are now resolved (2026-06-22). They were the crux that determined whether this stayed core-only or became cross-repo; the user chose the cross-repo, fully-consistent path, which is recorded in D2–D8.

- **OQ1: Does the `kind` discriminator string change from `"ModuleRelease"` to `"ModuleInstance"`?** Status: resolved-by-D3 (yes — `kind` strings move, including `BundleInstance` and the GitOps `ModulePackage` kind).

- **OQ2: Does the label domain change from `module-release.opmodel.dev/*` to `module-instance.opmodel.dev/*`?** Status: resolved-by-D4 (yes — label keys move everywhere defined and consumed).

- **OQ3: Hard rename, or a transition window with a `#ModuleRelease` alias in `core`?** Status: resolved-by-D8 (hard rename, no alias — pre-`v1` core, no external CLI/operator users).

- **OQ4: Confirm `config.yaml.semver: major` and the CUE-module tag mechanics.** Status: resolved-by-D8 (`semver: major` design impact), release-axis mechanics later revised by D13 (artifacts ship as `v1.x.x-alpha.x` prereleases; core advances to `opmodel.dev/core@v1`, superseding D8's `v0.x` minor).
