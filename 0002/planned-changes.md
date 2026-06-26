# Planned Spec Changes — Enhancement 0002

High-level slice plan: the spec changes to create across the affected repos (`core`, `library`, `opm-operator`, `cli`), their dependency relationships, and the order to apply them. This is a routing map, not a design — each change is drafted later using this list together with the enhancement docs (`01-problem.md` … `06-operational.md`, `03-decisions.md`) and the current codebase in the target repo. The authoritative file-level touch inventory lives in [`README.md`](README.md) (Cross-References); this document governs *how that work is sliced into spec-tracked changes*.

Conventions:

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

A closing **enhancements-wording** step (Part B) follows all code slices — see the final section; it is not a spec change and has no table row.

## Change descriptions

### C1 — core `core-rename-modulerelease-to-moduleinstance` (regular SPEC.md)

Atomic rename of the whole core family: `#ModuleRelease` → `#ModuleInstance`, `#ModuleReleaseMap` → `#ModuleInstanceMap`, `#ReleaseIdentity` → `#InstanceIdentity`, `#ctx.release` → `#ctx.instance`, `#Component.#release` → `#instance`, transformer `#moduleRelease*` → `#moduleInstance*`; wire `kind: "ModuleRelease"` → `"ModuleInstance"`; label keys `module-release.opmodel.dev/*` → `module-instance.opmodel.dev/*`. `git mv src/module_release.cue → src/module_instance.cue`. Co-update `SPEC.md` §3.5 (+ §3.1/§3.2 rationale cross-refs) under the `core-schema-edit` four-part format; update `.tasks/spec-tracked.txt` (`#ModuleRelease` → `#ModuleInstance`); regenerate `src/INDEX.md`; refresh prose in `README.md` and `docs/{constructs,adapters,definition-types}.md`. No split — the definitions cross-reference and the hook requires CUE + SPEC.md in one commit. Gate: `task fmt vet check` green → release-please publishes the `feat!:` `v0.x` tag that unblocks L1. (D8; conventions D9–D12.)

### L1 — library `rename-release-to-instance`

Pin the new `core`, then rename the Go surface: `Release` → `Instance` (type + `ReleaseName`/`ReleaseUUID`/`NewReleaseFromValue` methods), `ReleaseMetadata`/`ReleaseView`/`ReleaseInput` → instance forms, `synth.Release` → `synth.Instance`, kernel `ProcessModuleRelease`/`SynthesizeRelease`/`LoadReleasePackage`/`ValidateReleaseValues*` → instance forms, `Resource.Release()` → `Resource.Instance()` (+ `Compiled.Release` field), shape `ReleaseSpec.ExpectedKind "ModuleRelease"` → `"ModuleInstance"`, label literals, ~24 kind fixtures. `git mv` the `release.go` (+`_test.go`) files across `opm/module`, `opm/helper/synth`, `opm/helper/loader/file`. One change — library is a single cohesive Go module with no strong internal concern boundary. Capabilities (MODIFIED; rename the dir where the name carries "release"): `release-synthesis` → `instance-synthesis`, `kernel-runtime`, `artifact-types`, `helper-packages`. Gate: `task fmt vet test` green; publish the library tag that unblocks O\* and X\*. (D8, D10, D11, D12.)

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

## Ordering and waves

```
C1 (core, SPEC.md)  ──publish core feat!: v0.x tag──▶
  L1 (library)      ──publish library tag──▶
     opm-operator:  O1 → O2 → O3              (one PR, bulk-archive)
     cli:           X1 → { X2, X3, X4 }       (one PR, bulk-archive)    [operator ‖ cli]
        ──▶ Part B: enhancements wording  (0008 → 0006 → 0007)
```

- **C1 is the root.** Nothing downstream starts until the `core` `feat!:` tag is **published**, not merely merged — every other slice pins it.
- **L1 is the second hard gate.** `opm-operator` and `cli` both pin the published `library` tag; once it lands they proceed **in parallel**.
- **Within `opm-operator`:** rename the kinds (O1, O2) before moving them all to the new API group (O3). All three are implemented in one PR and bulk-archived.
- **Within `cli`:** X1 is the foundation (types + loader + instance-file convention); X2/X3/X4 each depend on X1 but are independent of each other. One PR, bulk-archived.
- **Verification per slice** lives in `06-operational.md` / the spec-change catalog; each ends with the repo's green gate (`task check` / `task test` / `make manifests generate` + `task dev:test`) and `openspec-verify-change` before archive.

## Closing step (not a spec change)

### Part B — enhancements `0002` wording cleanup of draft entries

After the four code slices land, update the **draft** enhancements' old-vocabulary prose **and** their `schemas/target.cue` (which must still compile), in this order: **0008** first (its `schemas/target.cue` is a codegen input — must consume `#ModuleInstance` / group `opmodel.dev` before any 0008 work), then **0006** (clean its narrative + the `planned-changes.md` task `operator-modulerelease-owner-marker`), then **0007** (extends 0006). Leave **0001** as historical record (per decision); `0000` template and `0003`–`0005` are already clean. Load the `enhancements` skill; run `task vet` after each edit. The `modules/` + `releases/` `release.cue` sweep (the D9 ripple into out-of-`affects` repos) is intentionally **out of scope** here and tracked separately.
