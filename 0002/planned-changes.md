# Planned Spec Changes — Enhancement 0002

High-level slice plan: the spec changes to create across the affected repos (`core`, `library`, `opm-operator`, `cli`), their dependency relationships, and the order to apply them. This is a routing map, not a design — each change is drafted later using this list together with the enhancement docs (`01-problem.md` … `06-operational.md`, `03-decisions.md`) and the current codebase in the target repo. The authoritative file-level touch inventory lives in [`README.md`](README.md) (Cross-References); this document governs *how that work is sliced into spec-tracked changes*.

Conventions:

- **Branch per change.** Every change in the table below is implemented on its own dedicated branch (one branch per `C1`/`L1`/`O1`/… slice), never on a shared or default branch. Branch off the upstream's published state once its dependency gate is satisfied; the branch is the unit that carries one slice's atomic PR (per-repo bulk-archive slices still land as one PR, hence one branch, per repo).
- **Major semver → v1 prereleases (D13).** This enhancement is a breaking rename of a published schema family, CRDs, and a wire contract (`config.yaml.semver: major`). Per D13, every affected artifact ships as a **v1 prerelease** — `v1.0.0-alpha.N` (`v1.x.x-alpha.x`) — **including the `opm-operator` artifact that bundles the CRDs**. For `core` this advances the CUE module `opmodel.dev/core@v0` → `@v1` (the `@v0→@v1` break D8 had avoided; release-please `bump-minor-pre-major` no longer governs). `library`/`cli`/`opm-operator` tags move to the same `v1.0.0-alpha.N` line; downstream pins advance in dependency order. The K8s CRD served apiVersion (`v1alpha1`) is a separate axis and is unchanged. (Supersedes D8's `v0.x` minor mechanics; D8's hard-rename / no-alias conclusion stands.)
- **`core` uses no OpenSpec.** Its change is a *regular* `SPEC.md` co-update bundled in the **same commit** as the `.cue` edits, gated by the `core-schema-edit` pre-commit hook + CI. Load `core/.claude/skills/core-schema-edit/SKILL.md` first.
- **`library` / `opm-operator` / `cli` use OpenSpec.** Each change lands in the named repo's own `openspec/` workspace (use that repo's `openspec-new-change` skill). Names below are working slugs; the date prefix (`YYYY-MM-DD-…`) is assigned at archive time per the repo's convention.
- **Split-by-concern, atomic per repo.** A pure rename cannot be split into separately *mergeable* PRs (intermediate states don't compile). The `opm-operator` and `cli` sub-changes are therefore authored as separate spec-tracked units but **implemented in one atomic PR per repo and bulk-archived** (`openspec-bulk-archive-change`) — honoring those repos' small-batch CONSTITUTION for spec authoring without shipping broken commits.
- Every change's proposal references this enhancement id (`0002`) and the decisions it implements; each archived slice is recorded back as a `history` event in `config.yaml` (optional `slice:` field).
- **Cross-cutting conventions apply to every change** (don't repeat per slice): rename every `release`-named file/dir on disk (D10); `release.cue` → `instance.cue` instance-file name (D9, cli); old-name breadcrumb at every rename site across code/docs/specs (`// Was:` / "Renamed from …", D11/D12).
- "Depends on" = the listed change(s) must be applied **and the upstream repo published/tagged** first (a downstream slice pins the new upstream artifact). "Gate" would mark a cross-enhancement dependency — there are none here.

## Changes

| ID | Repo | Change name | Depends on | Implements |
| -- | ---- | ----------- | ---------- | ---------- |
| C1 | core | `core-rename-modulerelease-to-moduleinstance` *(regular SPEC.md)* | — | core family of D8; D9–D12 conventions |
| L1 | library | `rename-release-to-instance` | C1 *(published tag)* | D8, D10, D11, D12 |
| O1 | opm-operator | `rename-modulerelease-crd-to-moduleinstance` | L1 *(published tag)* | D3, D10, D11, D12 |
| O2 | opm-operator | `rename-gitops-release-crd-to-modulepackage` | L1 *(published tag)* | D2, D10, D11, D12 |
| O3 | opm-operator | `migrate-api-group-and-label-domain` | O1, O2 | D4, D5, D10, D12 |
| X1 | cli | `rename-module-instance-types-and-loader` | L1 *(published tag)* | D9, D10, D11, D12 |
| X2 | cli | `rename-bundlerelease-to-bundleinstance` | X1 | D7, D10, D11, D12 |
| X3 | cli | `rename-release-command-group-to-instance` | X1 | D6, D10, D11, D12 |
| X4 | cli | `migrate-label-domain-and-inventory` | X1 | D4, D9, D10, D12 |
| K1 | catalog (`catalog_opm`) | `rename-modulereleasemetadata-and-bump-core-v1` | C1 *(published tag)* | D8, D12, D14 |
| K2 | catalog (`catalog_kubernetes`) | `rename-modulereleasemetadata-and-bump-core-v1` | C1 *(published tag)* | D8, D12, D14 |
| K3 | catalog (`catalog_opm_experimental`) | `bump-core-v1-skeleton` | C1 *(published tag)* | D8, D14 |

The K\* catalog slices depend only on **C1 (core@v1, already published)** — they are independent of L1 and of one another (no cross-catalog imports), and run as their own wave parallel to library/operator/cli. They are CUE-module repos with no OpenSpec workspace, so each lands as a single atomic per-repo PR (change names above are working slugs, not OpenSpec change ids).

A closing **enhancements-wording** step (Part B) follows all code slices — see the final section; it is not a spec change and has no table row.

## Change descriptions

### C1 — core `core-rename-modulerelease-to-moduleinstance` (regular SPEC.md)

Atomic rename of the whole core family: `#ModuleRelease` → `#ModuleInstance`, `#ModuleReleaseMap` → `#ModuleInstanceMap`, `#ReleaseIdentity` → `#InstanceIdentity`, `#ctx.release` → `#ctx.instance`, `#Component.#release` → `#instance`, transformer `#moduleRelease*` → `#moduleInstance*`; wire `kind: "ModuleRelease"` → `"ModuleInstance"`; label keys `module-release.opmodel.dev/*` → `module-instance.opmodel.dev/*`. `git mv src/module_release.cue → src/module_instance.cue`. Co-update `SPEC.md` §3.5 (+ §3.1/§3.2 rationale cross-refs) under the `core-schema-edit` four-part format; update `.tasks/spec-tracked.txt` (`#ModuleRelease` → `#ModuleInstance`); regenerate `src/INDEX.md`; refresh prose in `README.md` and `docs/{constructs,adapters,definition-types}.md`. No split — the definitions cross-reference and the hook requires CUE + SPEC.md in one commit. Gate: `task fmt vet check` green → release-please publishes the `feat(schema)!:` tag that unblocks L1. (D8; D13 versioning; conventions D9–D12.)

**✅ Landed (2026-06-26).** Merged via PR #17; published `opmodel.dev/core@v1` **`v1.0.0-alpha.1`**. release-please cuts the alpha line via `versioning: prerelease` + `bootstrap-sha` (first-run anchor). This is the gate L1 now pins.

### L1 — library `rename-release-to-instance`

Pin the new `core`, then rename the Go surface: `Release` → `Instance` (type + `ReleaseName`/`ReleaseUUID`/`NewReleaseFromValue` methods), `ReleaseMetadata`/`ReleaseView`/`ReleaseInput` → instance forms, `synth.Release` → `synth.Instance`, kernel `ProcessModuleRelease`/`SynthesizeRelease`/`LoadReleasePackage`/`ValidateReleaseValues*` → instance forms, `Resource.Release()` → `Resource.Instance()` (+ `Compiled.Release` field), shape `ReleaseSpec.ExpectedKind "ModuleRelease"` → `"ModuleInstance"`, label literals, ~24 kind fixtures. `git mv` the `release.go` (+`_test.go`) files across `opm/module`, `opm/helper/synth`, `opm/helper/loader/file`. One change — library is a single cohesive Go module with no strong internal concern boundary. Capabilities (MODIFIED; rename the dir where the name carries "release"): `release-synthesis` → `instance-synthesis`, `kernel-runtime`, `artifact-types`, `helper-packages`. Gate: `task fmt vet test` green; publish the library tag that unblocks O\* and X\*. (D8, D10, D11, D12.)

**✅ Implemented (2026-06-27).** OpenSpec change `rename-release-to-instance` authored, applied, verified, and archived (`library/openspec/changes/archive/2026-06-27-rename-release-to-instance`); `task check` green (fmt + vet + lint 0-issues + all tests). Rebased onto `library` `main` @ `0.7.0`, reconciling PR #25 (`refactor(materialize)!: federate native transformer surfaces`). Two deviations vs this plan: (1) **6 capability deltas, not 4** — added `schema-dispatch` (kind detection + `#moduleInstanceMetadata` context path) and `config-validation` (`ValidateInstanceValues*`), since both materially named renamed symbols; (2) **CUE language level bumped to `v0.17.0-alpha.1`** (toolchain already there). Also retired one obsolete `core@v0.4.0` synth negative-control test (incompatible with `core@v1`-only targeting). **Still pending the gate:** open the library PR → merge → publish the `v1.0.0-alpha.N` tag (the actual unblock for O\*/X\*) → record the `history` event in `config.yaml`. **Downstream finding (scope gap):** the published `opmodel.dev/catalogs/opm` catalog still uses old `module-release` / `#moduleReleaseMetadata` vocabulary and is **not** in `affects` — it needs its own Release→Instance slice before O\*/X\* (or any platform) lean on it against `core@v1`.

### O1 — opm-operator `rename-modulerelease-crd-to-moduleinstance`

CRD `ModuleRelease` → `ModuleInstance`: `ModuleRelease[Spec/Status/List]` → `ModuleInstance*`, status `ReleaseUUID` → `InstanceUUID`, reconciler, render const `KindModuleRelease` → `KindModuleInstance`, CRD shortName `mr` → `mi`, samples/fixtures, aggregated RBAC role files. `git mv` `modulerelease_types.go` → `moduleinstance_types.go`, the controller, and `internal/reconcile/modulerelease.go` → `moduleinstance.go`. Capabilities (MODIFIED): `module-release-synthesis` → `module-instance-synthesis`, `module-renderer-interface` (`ModuleReleaseParams`), `kernel-module-renderer`, `reconcile-loop-assembly`, `platform-gated-rendering`, `history-tracking`. Depends on L1. (D3, D10, D11, D12.)

### O2 — opm-operator `rename-gitops-release-crd-to-modulepackage`

GitOps `Release` CRD → `ModulePackage` (D2): `Release[Spec/Status/List]` → `ModulePackage*`, CRD shortName `rel` → `mpkg`, kind detection, source resolution. `git mv` `release_types.go` → `modulepackage_types.go`, `release_controller.go` → `modulepackage_controller.go`, `internal/reconcile/release.go` → `modulepackage.go`, `internal/render/kernel_release_renderer.go`. Capabilities (MODIFIED): `release-reconcile-loop` → `modulepackage-reconcile-loop`, `release-artifact-loading`, `release-depends-on`, `release-kind-detection`, `release-kernel-rendering`. Depends on L1. (D2, D10, D11, D12.)

### O3 — opm-operator `migrate-api-group-and-label-domain`

API group `releases.opmodel.dev` → `opmodel.dev` (D5) across all three CRDs (`groupversion_info.go` `+groupName`, every `//+kubebuilder:rbac` marker, `PROJECT`, kustomize bases); finalizer `releases.opmodel.dev/cleanup` → `opmodel.dev/cleanup` (`common_types.go` + consumers); label domain `module-release.opmodel.dev/*` → `module-instance.opmodel.dev/*` (D4, `pkg/core/labels.go` + prune/inventory selectors). The `Platform` CRD moves group (kind unchanged). Regenerate CRD bases, `role.yaml`, `zz_generated.deepcopy.go`, `dist/install.yaml` (`make manifests generate` + installer task); hand-edit `PROJECT`; move `test/fixtures/releases/` → `modulepackages/`. Capabilities (MODIFIED): `finalizer-and-deletion`, `prune-stale-resources`, `inventory-bridge`, `ssa-apply`, `platform-crd` + cross-cutting RBAC. Depends on O1, O2 (rename the kinds before moving them all to the new group). (D4, D5, D10, D12.)

### X1 — cli `rename-module-instance-types-and-loader`

Foundation slice: `pkg/module/release.go` → `instance.go` (`Release`/`ReleaseMetadata` types); kind detection `DetectReleaseKind` → `DetectInstanceKind` (`pkg/loader/release_kind.go`); `internal/releasefile/` → `internal/instancefile/` (`GetReleaseFile` → `GetInstanceFile`); kind literals `"ModuleRelease"`/`"BundleRelease"` → instance forms; the **D9 instance-file convention** `release.cue` → `instance.cue` detection. Capabilities (MODIFIED + rename): `module-release-type` → `module-instance-type`, `module-release-parsing`/`-processing`/`-receiver-methods`, `release-file-loading`, `release-building`, `loader-api`, `module-synthetic-release` → `module-synthetic-instance`, `mod-release-optional`, `validation-gates`. Depends on L1. (D9, D10, D11, D12.)

### X2 — cli `rename-bundlerelease-to-bundleinstance`

`BundleRelease` → `BundleInstance` (D7): `pkg/bundle/release.go` → `instance.go`, `pkg/render/process_bundlerelease.go` → `process_bundleinstance.go` (`ProcessBundleRelease` → `ProcessBundleInstance`), `"BundleRelease"` kind string. Capability (MODIFIED + rename): `bundle-release-processing` → `bundle-instance-processing`. Depends on X1's renamed types. (D7, D10, D11, D12.)

### X3 — cli `rename-release-command-group-to-instance`

User-facing surface: `internal/cmd/release/` → `internal/cmd/instance/` (D6) — `Use: "release"` → `"instance"`, alias `rel` → `inst`, all nine subcommands + `root.go` wiring + help/examples; `internal/cmdutil/release_{arg,target}.go` → `instance_*`; `internal/workflow/**` import-path + type renames. Capabilities (MODIFIED + rename): `rel-commands` → `inst-commands`, `cmd-structure`, and the `mod-list`/`mod-status`/`mod-events`/`mod-apply` references to release. Depends on X1. (D6, D10, D11, D12.)

### X4 — cli `migrate-label-domain-and-inventory`

Label domain `module-release.opmodel.dev/*` → `module-instance.opmodel.dev/*` (D4, `pkg/core/labels.go`) and its consumers in `internal/inventory/*`, `internal/kubernetes/*`, `pkg/ownership/ownership.go`, selectors. Plus the fixture/example moves: `examples/releases/**/release.cue` → `examples/instances/**/instance.cue` (D9/D10), `tests/integration/rel-*` → `inst-*`, `tests/e2e/testdata/vet-errors/release/`, `openspec/specs` dir renames. Capabilities (MODIFIED): `release-identity-labeling`, `release-inventory`, `inventory-ownership`, `deploy`, `mod-apply`. Depends on X1. `.goreleaser.yml` (binary releases) is **not** touched. (D4, D9, D10, D12.)

### K1 — catalog `catalog_opm` `rename-modulereleasemetadata-and-bump-core-v1`

Pin `opmodel.dev/core@v1` (`v1.0.0-alpha.1`) and rename the consumed surface. Compile-required: transformer-context `#context.#moduleReleaseMetadata` → `#moduleInstanceMetadata` (50 refs across 11 files in `src/transformers/`, including the test-context struct at `src/transformers/sa_resource_transformer.cue`); every `c "opmodel.dev/core@v0"` import → `@v1` (~50 files). Full-consistency (D14 §2, D12): catalog-local helper `#releasePrefix` → `#instancePrefix` (33 refs — `src/transformers/container_helpers.cue` defs/usages + the deployment/daemonset/cronjob/job/statefulset transformers that pass it), 6 "release" prose comments (`src/resources/{configmap,secret}.cue`, `src/transformers/{configmap,secret}_transformer.cue`), and the `"test-release"` fixture → `"test-instance"`. Module bump: `module: "opmodel.dev/catalogs/opm@v0"` → `@v1`. Versioning: `release-please-config.json` adopts core's prerelease block; target tag **`v1.0.0-alpha.1`** (`feat!`, from `v0.6.0`). `// Was:` breadcrumbs at rename sites (D12). Gate: `task check` green. Depends on C1. (D8, D12, D14.)

### K2 — catalog `catalog_kubernetes` `rename-modulereleasemetadata-and-bump-core-v1`

Same shape as K1, transformer-heavy: `#context.#moduleReleaseMetadata` → `#moduleInstanceMetadata` (44 refs across 26 transformers in `src/transformers/`); every `core@v0` import → `@v1` (~56 files); module `"opmodel.dev/catalogs/kubernetes@v0"` → `@v1`; consistency prose at `src/CLAUDE.md`. Versioning: prerelease block; **forward-alpha reconciliation** (D14 §4) — current git tag is `v1.0.0` while module path was `@v0`, so target tag is **`v1.1.0-alpha.1`** (`feat`, forward of `v1.0.0`, *not* `v1.0.0-alpha.x` which would sort backwards). `// Was:` breadcrumbs. Gate: `task check`. Depends on C1. (D8, D12, D14.)

### K3 — catalog `catalog_opm_experimental` `bump-core-v1-skeleton`

Skeleton catalog (empty `#transformers`) — no `#moduleReleaseMetadata` refs, so a near-pure dep bump: pin `opmodel.dev/core@v1` (`v1.0.0-alpha.1`) in `src/cue.mod/module.cue` (from `core@v0 v0.4.0`); `src/catalog.cue` import `@v0` → `@v1`; module `"opmodel.dev/catalogs/opm-experimental@v0"` → `@v1`; verify `src/identity/identity.cue` for any `ReleaseIdentity`/`#release` usage and rename if present; doc `@v0` → `@v1` refs in `README.md`, `CLAUDE.md`, `Taskfile.yml` comment; regenerate `src/INDEX.md`. Versioning: prerelease block; **forward-alpha reconciliation** (D14 §4) — current git tag `v1.1.0`, so target tag **`v1.2.0-alpha.1`** (`feat`, forward). Gate: `task check`. Depends on C1. (D8, D14.)

## Ordering and waves

```
C1 (core, SPEC.md)  ──publish core@v1 v1.0.0-alpha tag──▶
  L1 (library)      ──publish library tag──▶
     opm-operator:  O1 → O2 → O3              (one PR, bulk-archive)
     cli:           X1 → { X2, X3, X4 }       (one PR, bulk-archive)    [operator ‖ cli]
  catalog:          { K1, K2, K3 }            (one PR each)              [catalog wave ‖ L1]
        ──▶ Part B: enhancements wording  (0008 → 0006 → 0007)
```

- **C1 is the root.** Nothing downstream starts until the `core` `feat!:` tag is **published**, not merely merged — every other slice pins it.
- **L1 is the second hard gate.** `opm-operator` and `cli` both pin the published `library` tag; once it lands they proceed **in parallel**.
- **The catalog wave (K1, K2, K3) hangs off C1 directly,** not L1 — the catalogs depend only on `core`, so they run in parallel with the whole library→operator‖cli chain. The three are mutually independent (no cross-catalog imports); each is one atomic per-repo PR. The `modules/` + `releases/` re-pin onto `catalog_opm@v1` is the **separately-tracked, out-of-scope ripple** (old `@v0` catalog tags stay published, so those consumers keep resolving against `core@v0` until migrated) — same exclusion as the D9 `modules/`+`releases/` sweep in the closing step.
- **Within `opm-operator`:** rename the kinds (O1, O2) before moving them all to the new API group (O3). All three are implemented in one PR and bulk-archived.
- **Within `cli`:** X1 is the foundation (types + loader + instance-file convention); X2/X3/X4 each depend on X1 but are independent of each other. One PR, bulk-archived.
- **Verification per slice** lives in `06-operational.md` / the spec-change catalog; each ends with the repo's green gate (`task check` / `task test` / `make manifests generate` + `task dev:test`) and `openspec-verify-change` before archive.

## Closing step (not a spec change)

### Part B — enhancements `0002` wording cleanup of draft entries

After the four code slices land, update the **draft** enhancements' old-vocabulary prose **and** their `schemas/target.cue` (which must still compile), in this order: **0008** first (its `schemas/target.cue` is a codegen input — must consume `#ModuleInstance` / group `opmodel.dev` before any 0008 work), then **0006** (clean its narrative + the `planned-changes.md` task `operator-modulerelease-owner-marker`), then **0007** (extends 0006). Leave **0001** as historical record (per decision); `0000` template and `0003`–`0005` are already clean. Load the `enhancements` skill; run `task vet` after each edit. The `modules/` + `releases/` `release.cue` sweep (the D9 ripple into out-of-`affects` repos) is intentionally **out of scope** here and tracked separately.
