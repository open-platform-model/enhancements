# Enhancement 0002 — Rename the Release artifact family to Instance vocabulary (cross-cutting)

See [`config.yaml`](config.yaml) for the metadata contract — it is the sole source of metadata; no parallel metadata table lives here.

## Summary

OPM's deployable artifact is `#ModuleRelease` today. "Release" is Helm's word for the same construct and foregrounds a shipping event, when the construct's defining property is *multiplicity* — one `#Module` materialized as many concrete deployments. The word recurs, inconsistently, all the way down the stack: a CUE definition family in `core`, Go identifiers in `library`, two Kubernetes CRDs in `opm-operator`, and a command group in `cli`.

This enhancement renames the whole family to `Instance` vocabulary **cross-cutting** (`affects: [core, library, opm-operator, cli]`). The `core` family (`#ModuleRelease`, `#ReleaseIdentity`, `#ctx.release`, `#Component.#release`, transformer `#moduleRelease*`) → `Instance` names; the library Go surface follows; the operator's `ModuleRelease` CRD → `ModuleInstance` and its GitOps `Release` CRD → `ModulePackage`; the wire `kind` strings, the `module-release.opmodel.dev/*` label domain, and the `releases.opmodel.dev` API group all move; the CLI `opm release …` → `opm instance …` and `BundleRelease` → `BundleInstance`. Behavior is unchanged; the gain is one coherent vocabulary and distance from Helm's lexicon.

> **Note:** an earlier scope (D1) kept this core-only and explicitly preserved the operator's `Release` CRD. **D2 supersedes that** — the scope is now cross-cutting and the GitOps CRD is renamed to `ModulePackage`. D1 remains in the decision log as the original, reversed conclusion.

## Documents

1. [01-problem.md](01-problem.md) — Why "Release" mis-teaches the model (Helm overlap + under-described multiplicity), and the four inconsistent spellings across the stack
2. [02-design.md](02-design.md) — The cross-cutting rename mapping and the three-layer (identifier / wire / cluster) analysis
3. [03-decisions.md](03-decisions.md) — D1..D12 (D2 reverses D1 → cross-cutting + `ModulePackage`; D3–D8 resolve the wire/group/CLI/bundle/semver questions; D9–D11 add the `release.cue`→`instance.cue` convention, the rename-every-file policy, and the Go `// Was:` docstring breadcrumb; D12 generalizes that breadcrumb to every rename site across code, docs, and specs)
4. [04-graduation.md](04-graduation.md) — Per-status gates (draft → accepted → implemented), with per-repo slice criteria
5. [05-risks.md](05-risks.md) — API-group orphan risk, lockstep sequencing, breaking-rename drawbacks, alternatives
6. [06-operational.md](06-operational.md) — PRR-lite (semver, reinstall-based rollback, cross-repo sequencing)

Pure-CUE schema in [`schemas/target.cue`](schemas/target.cue).

## Scope

### In scope

- **core** — the deployable-artifact construct and supporting identity types: `#ModuleRelease` → `#ModuleInstance`, `#ModuleReleaseMap` → `#ModuleInstanceMap`, `#ReleaseIdentity` → `#InstanceIdentity`, `#ctx.release` → `#ctx.instance`, `#Component.#release` → `#Component.#instance`, transformer `#moduleRelease*` → `#moduleInstance*`; `SPEC.md` co-update + `INDEX.md` regen.
- **library** — the Go `Release` surface (`Release` type + methods, `ReleaseMetadata`/`ReleaseView`, `synth.Release`/`ReleaseInput`, kernel `ProcessModuleRelease`/`SynthesizeRelease`/kind-detection, `Compiled.Release`/`Resource.Release()`) → `Instance` names; kind literal + label literals.
- **opm-operator** — `ModuleRelease` CRD → `ModuleInstance`; GitOps `Release` CRD → `ModulePackage` (D2); API group `releases.opmodel.dev` → `opmodel.dev` (D5) + finalizer key; reconcilers, render constant, label constants, regenerated CRDs/RBAC/`PROJECT`/samples/fixtures.
- **cli** — `opm release …` → `opm instance …` (alias `inst`, D6); `BundleRelease` → `BundleInstance` (D7); kind-detection, label constants, examples/docs.
- **wire** — `kind` strings (D3) and the `module-instance.opmodel.dev/*` label domain (D4) move in lockstep.
- **conventions (all slices)** — every `release`-named file/directory is `git mv`'d to its instance/package equivalent (D10); the CLI instance-file name `release.cue` → `instance.cue` (D9); and every rename site across code, docs, and specs carries a short old-name breadcrumb — a `// Was:` doc/line comment on each renamed Go (D11) and CUE definition, and a "Renamed from …" note on each renamed doc / `SPEC.md` / `spec.md` section (D12 generalizes D11 from Go-exported-only to every surface and every definition).

### Out of scope

- Any behavioral, evaluation-semantic, or field-shape change.
- Renaming `#Module`, `#Platform`, `#Component`, `#Trait`, `#Resource`, `#Blueprint`. The `Platform` CRD keeps its kind (it only moves to the new API group with its siblings).
- A compatibility-alias / deprecation window in any repo (D8 — hard rename).
- A follow-up sweep of `modules/` and `releases/` fixtures naming the old identifiers (required, but tracked outside the four `affects` repos).

## Deviations from Design

None at this stage. Updated when implementation lands.

## Cross-References

Per-repo implementation touch-points, grouped by subsystem. This list was rebuilt from an exhaustive re-scan (2026-06-26) of all four repos and is materially fuller than the original draft table; it is still representative rather than line-complete for the large test-fixture and generated-manifest sets, which are called out by directory. Every path below exists today.

Three cross-cutting conventions apply to **every** file listed:

- **D10 — rename the file too.** Any path whose name carries `release` is `git mv`'d to its instance/package equivalent (e.g. `modulerelease_types.go` → `moduleinstance_types.go`, `internal/releasefile/` → `internal/instancefile/`, `test/fixtures/releases/` → `modulepackages/`). The tables note the destination where non-obvious.
- **D9 — `release.cue` → `instance.cue`.** The CLI instance-file convention and every fixture/example that uses it move; this ripples into the out-of-scope `modules/` and `releases/` repos (tracked as the closing sweep).
- **D11 — `// Was:` docstring breadcrumb.** In the three Go repos, every renamed exported func/method/type gets its doc comment rewritten to instance vocabulary plus a trailing `// Was: <OldName>` tag.

### Protocol & design

| Document | Purpose |
| -------- | ------- |
| `core/.claude/skills/core-schema-edit/SKILL.md` | Binding protocol for the `SPEC.md` co-update gated by pre-commit hook + CI; load before the core slice. |
| [`../0001/`](../0001/) | Source of the `#ctx.release` wiring (0001 D1/D3/D4); this rename makes its prose use the old names — left intact as historical record (decision: do not edit 0001). |

### core (`affects: core`) — publish first; `feat!:` v0.x tag

| Path | Change |
| ---- | ------ |
| `core/src/module_release.cue` | **git mv** → `module_instance.cue`; `#ModuleRelease`/`#ModuleReleaseMap`, `kind`, `#ctx: instance:` wiring, label keys. |
| `core/src/module_context.cue` | `#ReleaseIdentity` → `#InstanceIdentity`. |
| `core/src/module.cue` | `#ctx.release` → `#ctx.instance`; `#release` projection → `#instance`. |
| `core/src/component.cue` | `#release` → `#instance`; `#names.dns` references. |
| `core/src/transformer.cue` | `#moduleRelease`/`#moduleReleaseMetadata` → instance names; label key. |
| `core/SPEC.md`, `core/src/INDEX.md` | Normative spec co-update (pre-commit/CI gated) + regenerated definition index (`task generate:index`). |
| `core/README.md`, `core/docs/constructs.md`, `core/docs/adapters.md`, `core/docs/definition-types.md` | Prose/diagram/table references (`#ModuleRelease`, `#moduleReleaseMetadata`, mermaid). |
| `core/CHANGELOG.md` | Two artifact references only; the rest (release-please version entries) is incidental — not a target. |

### library (`affects: library`) — pin new `core`

| Path | Change |
| ---- | ------ |
| `library/opm/module/release.go` | **git mv** → `instance.go`; `type Release` → `Instance`; `ReleaseName`/`ReleaseUUID`/`NewReleaseFromValue` methods. |
| `library/opm/schema/{metadata,decode,context,paths,loader,consts}.go` | `ReleaseMetadata` → `InstanceMetadata`, `ReleaseView` → `InstanceView`, `DecodeReleaseMetadata`, kind dispatch. |
| `library/opm/helper/synth/release.go` | **git mv** → `instance.go`; `synth.Release`/`ReleaseInput`, error sentinels, `"#ModuleRelease"` lookup; label literals in `render.go`. |
| `library/opm/helper/loader/file/release.go` | **git mv** → `instance.go`; `LoadReleasePackage`; `internal/shape/shape.go` `ReleaseSpec.ExpectedKind = "ModuleRelease"` → `"ModuleInstance"`. |
| `library/opm/kernel/{process,synth,compile,wrappers,validate_typed,phases,inputs,doc}.go` | `ProcessModuleRelease`, `SynthesizeRelease`, `LoadReleasePackage`, `ValidateReleaseValues*` + kind-detection and package docs. |
| `library/opm/core/{resource,compiled}.go` | `Resource.Release()` interface method + `Compiled.Release` field. |
| `library/opm/{compile,errors,materialize}/*.go` | Release context references through the compile/match/error paths. |
| `library/**/*_test.go`, test fixtures (~24 kind fixtures), `release_integration_test.go` | Kind literals `"ModuleRelease"` → `"ModuleInstance"`, label assertions; test files `git mv`'d alongside their sources. |
| `library/README.md`, `library/CLAUDE.md`, `library/MIGRATIONS.md`, `library/docs/**`, `library/openspec/specs/**` (esp. `release-synthesis/spec.md`) | Doc/spec references; `MIGRATIONS.md` audited (mostly historical software-release notes — only artifact refs change). |

### opm-operator (`affects: opm-operator`) — pin new `core`+`library`; heaviest slice

| Path | Change |
| ---- | ------ |
| `opm-operator/api/v1alpha1/modulerelease_types.go` | **git mv** → `moduleinstance_types.go`; `ModuleRelease[Spec/Status/List]` → `ModuleInstance*`; status `ReleaseUUID` → `InstanceUUID`. |
| `opm-operator/api/v1alpha1/release_types.go` | **git mv** → `modulepackage_types.go`; GitOps `Release[Spec/Status/List]` → `ModulePackage*` (D2). |
| `opm-operator/api/v1alpha1/{groupversion_info,common_types,conditions}.go` | `+groupName` → `opmodel.dev` (D5), `GroupVersion` var, finalizer const `opmodel.dev/cleanup`, condition strings. |
| `opm-operator/internal/controller/{modulerelease,release,platform}_controller.go` | **git mv** the renamed ones; reconciler types + RBAC markers (`modulereleases`/`releases` → `moduleinstances`/`modulepackages`, group `opmodel.dev`). |
| `opm-operator/internal/reconcile/{modulerelease,release}.go` | **git mv** → `moduleinstance.go`/`modulepackage.go`; constants, functions, finalizer/label use (release.go ≈ 119 refs). |
| `opm-operator/internal/render/{kernel_release_renderer,release,module,renderer}.go` | `KindModuleRelease` → `KindModuleInstance`, render constants, import aliases. |
| `opm-operator/internal/{status,inventory,source,apply,moduleacquire}/*.go` | Kind/label/finalizer references across status counters/digests/history, inventory, source resolution, prune. |
| `opm-operator/pkg/core/{labels,resource,compiled_adapter}.go` | `LabelModuleRelease*` → `LabelModuleInstance*` with `module-instance.opmodel.dev/*` values; kind strings. |
| `opm-operator/cmd/main.go` | Type registration / `ReconcilerFor` wiring. |
| `opm-operator/config/{crd/bases,rbac,samples}/**`, `PROJECT`, `dist/**` | Aggregated RBAC role files + samples `git mv`'d (group/kind in names); `PROJECT` hand-edited; CRD bases, `role.yaml`, `zz_generated.deepcopy.go`, `dist/install.yaml` **regenerated** via `make manifests generate` + installer task. |
| `opm-operator/test/**` (incl. `fixtures/releases/` → `modulepackages/`), `.tasks/*.yaml`, `docs/design/release-vs-modulerelease-render-divergence.md` | ~19 test files, fixture dir move, task references, design doc retitle. ADRs 003/007 + archived OpenSpec left as historical record. |

### cli (`affects: cli`) — pin new `core`+`library`; parallel with operator

| Path | Change |
| ---- | ------ |
| `cli/internal/cmd/release/**` | **git mv** → `internal/cmd/instance/`; `Use: "release"` → `"instance"`, alias `rel` → `inst`; all nine subcommands + `root.go` wiring. |
| `cli/pkg/bundle/release.go` | **git mv** → `instance.go`; `BundleRelease` family → `BundleInstance` (D7). |
| `cli/pkg/render/{process_bundlerelease,process_modulerelease}.go` | **git mv** → `process_bundleinstance.go`/`process_moduleinstance.go`; `ProcessBundleRelease`/`ProcessModuleRelease` → instance forms. |
| `cli/pkg/loader/{release_kind,release_file,*}.go`, `cli/internal/releasefile/` | **git mv** → `instance_*`/`internal/instancefile/`; `DetectReleaseKind`, `KindModuleRelease`/`KindBundleRelease`, `GetReleaseFile`, and `release.cue` → `instance.cue` detection (D9). |
| `cli/pkg/module/release.go` | **git mv** → `instance.go`; `Release`/`ReleaseMetadata` types. |
| `cli/internal/cmdutil/{release_arg,release_target}.go` | **git mv** → `instance_arg.go`/`instance_target.go`. |
| `cli/internal/workflow/**` (render, apply, query) | Import-path + type renames (`releasefile` → `instancefile`, `module.Release` → `module.Instance`); ~100+ refs. |
| `cli/internal/{inventory,kubernetes}/*.go`, `cli/pkg/ownership/ownership.go`, `cli/pkg/core/labels.go` | `LabelModuleRelease*` → instance domain (mirrors operator) + dependent selectors. |
| `cli/examples/releases/**/release.cue`, `cli/tests/**` (`integration/rel-*` → `inst-*`, `e2e/testdata/vet-errors/release/`), `cli/openspec/specs/**` (25+ dirs), ADRs/RFCs/docs | **git mv** to instance names (D9/D10); example, integration, e2e fixtures and spec dirs. `.goreleaser.yml` is binary-release tooling — not a target. |
