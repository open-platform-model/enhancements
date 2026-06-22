# Enhancement 0002 — Rename the Release artifact family to Instance vocabulary (cross-cutting)

See [`config.yaml`](config.yaml) for the metadata contract — it is the sole source of metadata; no parallel metadata table lives here.

## Summary

OPM's deployable artifact is `#ModuleRelease` today. "Release" is Helm's word for the same construct and foregrounds a shipping event, when the construct's defining property is *multiplicity* — one `#Module` materialized as many concrete deployments. The word recurs, inconsistently, all the way down the stack: a CUE definition family in `core`, Go identifiers in `library`, two Kubernetes CRDs in `opm-operator`, and a command group in `cli`.

This enhancement renames the whole family to `Instance` vocabulary **cross-cutting** (`affects: [core, library, opm-operator, cli]`). The `core` family (`#ModuleRelease`, `#ReleaseIdentity`, `#ctx.release`, `#Component.#release`, transformer `#moduleRelease*`) → `Instance` names; the library Go surface follows; the operator's `ModuleRelease` CRD → `ModuleInstance` and its GitOps `Release` CRD → `ModulePackage`; the wire `kind` strings, the `module-release.opmodel.dev/*` label domain, and the `releases.opmodel.dev` API group all move; the CLI `opm release …` → `opm instance …` and `BundleRelease` → `BundleInstance`. Behavior is unchanged; the gain is one coherent vocabulary and distance from Helm's lexicon.

> **Note:** an earlier scope (D1) kept this core-only and explicitly preserved the operator's `Release` CRD. **D2 supersedes that** — the scope is now cross-cutting and the GitOps CRD is renamed to `ModulePackage`. D1 remains in the decision log as the original, reversed conclusion.

## Documents

1. [01-problem.md](01-problem.md) — Why "Release" mis-teaches the model (Helm overlap + under-described multiplicity), and the four inconsistent spellings across the stack
2. [02-design.md](02-design.md) — The cross-cutting rename mapping and the three-layer (identifier / wire / cluster) analysis
3. [03-decisions.md](03-decisions.md) — D1..D8 (D2 reverses D1 → cross-cutting + `ModulePackage`; D3–D8 resolve the wire/group/CLI/bundle/semver questions)
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

### Out of scope

- Any behavioral, evaluation-semantic, or field-shape change.
- Renaming `#Module`, `#Platform`, `#Component`, `#Trait`, `#Resource`, `#Blueprint`. The `Platform` CRD keeps its kind (it only moves to the new API group with its siblings).
- A compatibility-alias / deprecation window in any repo (D8 — hard rename).
- A follow-up sweep of `modules/` and `releases/` fixtures naming the old identifiers (required, but tracked outside the four `affects` repos).

## Deviations from Design

None at this stage. Updated when implementation lands.

## Cross-References

Representative implementation touch-points per repo. The lists are not exhaustive (the full inventory is large) but every path below exists today.

### Protocol & design

| Document | Purpose |
| -------- | ------- |
| `core/.claude/skills/core-schema-edit/SKILL.md` | Binding protocol for the `SPEC.md` co-update gated by pre-commit hook + CI; load before the core slice. |
| [`../0001/`](../0001/) | Source of the `#ctx.release` wiring (0001 D1/D3/D4); this rename makes its prose use the old names — left intact as historical record. |

### core (`affects: core`)

| Path | Change |
| ---- | ------ |
| `core/src/module_release.cue` | Renamed to `module_instance.cue`; `#ModuleRelease`/`#ModuleReleaseMap`, `kind`, `#ctx: instance:` wiring, label keys. |
| `core/src/module_context.cue` | `#ReleaseIdentity` → `#InstanceIdentity`. |
| `core/src/module.cue` | `#ctx.release` → `#ctx.instance`; `#release` projection → `#instance`. |
| `core/src/component.cue` | `#release` → `#instance`; `#names.dns` references. |
| `core/src/transformer.cue` | `#moduleRelease`/`#moduleReleaseMetadata` → instance names; label key. |
| `core/SPEC.md`, `core/src/INDEX.md` | Normative spec co-update + regenerated definition index. |

### library (`affects: library`)

| Path | Change |
| ---- | ------ |
| `library/opm/module/release.go` | `type Release` → `Instance`; `ReleaseName`/`ReleaseUUID`/`NewReleaseFromValue` methods. |
| `library/opm/schema/metadata.go` | `ReleaseMetadata` → `InstanceMetadata`, `ReleaseView` → `InstanceView`. |
| `library/opm/helper/synth/release.go` | `synth.Release`/`ReleaseInput`, error sentinels, `"#ModuleRelease"` lookup, label literals. |
| `library/opm/helper/loader/internal/shape/shape.go` | `ReleaseSpec.ExpectedKind = "ModuleRelease"` → `"ModuleInstance"`. |
| `library/opm/kernel/process.go` | `ProcessModuleRelease` + sibling kernel entry points (`compile.go`, `synth.go`, `wrappers.go`, `phases.go`, `inputs.go`). |
| `library/opm/core/resource.go` | `Resource.Release()` interface method (+ `Compiled.Release` in `compiled.go`). |

### opm-operator (`affects: opm-operator`)

| Path | Change |
| ---- | ------ |
| `opm-operator/api/v1alpha1/modulerelease_types.go` | `ModuleRelease[Spec/Status/List]` → `ModuleInstance*`; status `ReleaseUUID` → `InstanceUUID`; group marker → `opmodel.dev`. |
| `opm-operator/api/v1alpha1/release_types.go` | GitOps `Release[Spec/Status/List]` → `ModulePackage*` (D2); group marker → `opmodel.dev`. |
| `opm-operator/internal/controller/modulerelease_controller.go`, `release_controller.go` | Reconciler renames + RBAC markers (`modulereleases`/`releases` → `moduleinstances`/`modulepackages`, group `opmodel.dev`). |
| `opm-operator/internal/render/release.go` | `KindModuleRelease = "ModuleRelease"` → `KindModuleInstance = "ModuleInstance"`. |
| `opm-operator/pkg/core/labels.go` | `LabelModuleRelease*` → `LabelModuleInstance*` with `module-instance.opmodel.dev/*` values; finalizer key → `opmodel.dev/cleanup`. |
| `opm-operator/PROJECT` | Regenerated for the renamed kinds/group (+ `ModulePackage` resource entry). |

### cli (`affects: cli`)

| Path | Change |
| ---- | ------ |
| `cli/internal/cmd/release/release.go` | Package → `internal/cmd/instance/`; `Use: "release"` → `"instance"`, alias `rel` → `inst`; nine subcommands. |
| `cli/pkg/bundle/release.go` | `BundleRelease` family → `BundleInstance` (D7). |
| `cli/pkg/loader/release_kind.go`, `cli/internal/releasefile/get_release_file.go` | `DetectReleaseKind` + `KindModuleRelease` literals → `"ModuleInstance"`/`"BundleInstance"`. |
| `cli/pkg/module/release.go` | `Release`/`ReleaseMetadata` types. |
| `cli/pkg/core/labels.go` | `LabelModuleRelease*` → instance domain (mirrors operator). |
