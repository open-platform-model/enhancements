# Enhancement 0002 — Rename `#ModuleRelease` to `#ModuleInstance`

See [`config.yaml`](config.yaml) for the metadata contract — it is the sole source of metadata; no parallel metadata table lives here.

## Summary

OPM's deployable artifact is `#ModuleRelease` today. "Release" is Helm's word for the same construct and foregrounds a shipping event, when the construct's defining property is *multiplicity* — one `#Module` materialized as many concrete deployments. This enhancement proposes renaming the `core` artifact family (`#ModuleRelease`, `#ReleaseIdentity`, `#ctx.release`, `#Component.#release`, transformer `#moduleRelease*`) to `Instance` vocabulary. Behavior is unchanged; the gain is conceptual clarity and distance from Helm's lexicon. The operator's `Release` reconciliation CRD is deliberately **not** renamed (it models the act of releasing, not an instance — see D1).

## Documents

1. [01-problem.md](01-problem.md) — Why "Release" mis-teaches the model (Helm overlap + under-described multiplicity)
2. [02-design.md](02-design.md) — The rename mapping and the three-layer containment analysis
3. [03-decisions.md](03-decisions.md) — D1 (scope) + open questions on the wire contract
4. [04-graduation.md](04-graduation.md) — Per-status gates (draft → accepted → implemented)
5. [05-risks.md](05-risks.md) — Split-brain risk, breaking-rename drawback, alternatives
6. [06-operational.md](06-operational.md) — PRR-lite (semver, rollback, cross-repo sequencing)

Pure-CUE schema in [`schemas/target.cue`](schemas/target.cue).

## Scope

### In scope

- Renaming the `core` deployable-artifact construct and its supporting identity types: `#ModuleRelease` → `#ModuleInstance`, `#ModuleReleaseMap` → `#ModuleInstanceMap`, `#ReleaseIdentity` → `#InstanceIdentity`, `#ctx.release` → `#ctx.instance`, `#Component.#release` → `#Component.#instance`, transformer `#moduleRelease`/`#moduleReleaseMetadata` → `#moduleInstance`/`#moduleInstanceMetadata`.
- Co-updating `core/SPEC.md` and regenerating `core/INDEX.md`.
- Deciding (not necessarily executing) the fate of the `kind: "ModuleRelease"` discriminator string and the `module-release.opmodel.dev/*` label domain (OQ1, OQ2) — these are wire contracts, not core-internal.

### Out of scope

- Renaming the operator's `Release` CRD (`opm-operator/api/v1alpha1/release_types.go`) — it is the GitOps reconciliation resource, not the instance (D1).
- Any behavioral, evaluation-semantic, or field-shape change.
- Renaming any other core construct (`#Module`, `#Platform`, `#Component`, …).

## Deviations from Design

None at this stage. Updated when implementation lands.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `core/CLAUDE.md`, `core/CONSTITUTION.md` | Core repo guide + design principles governing the CUE change. |
| `core/.claude/skills/core-schema-edit/SKILL.md` | Binding protocol for the `SPEC.md` co-update gated by pre-commit hook + CI. |
| `core/src/module_release.cue` | Renamed to `module_instance.cue`; `#ModuleRelease`/`#ModuleReleaseMap`, `kind`, `#ctx: instance:` wiring, label keys. |
| `core/src/module_context.cue` | `#ReleaseIdentity` → `#InstanceIdentity`. |
| `core/src/module.cue` | `#ctx.release` slot → `#ctx.instance` (`:68`); `#release: #ctx.release` → `#instance: #ctx.instance` (`:47`). |
| `core/src/component.cue` | `#release: #ReleaseIdentity` → `#instance: #InstanceIdentity` (`:39`); DNS references (`:52-53`). |
| `core/src/transformer.cue` | `#moduleRelease`/`#moduleReleaseMetadata` → instance names; label key (`:147`). |
| `core/SPEC.md`, `core/INDEX.md` | Normative spec co-update + regenerated definition index. |
| [`../0001/`](../0001/) | Source of the `#ctx.release` wiring (0001 D1/D3/D4); this rename makes its prose use the old names — left intact as historical record. |
| `library/opm/helper/synth/release.go`, `opm-operator/api/v1alpha1/release_types.go` | Wire consumers of `kind`/identity — touched only if OQ1/OQ2 resolve toward moving the wire contract. |
