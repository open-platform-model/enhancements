# Graduation Criteria — Rename #ModuleRelease to #ModuleInstance

Gates that must hold before this enhancement advances. Design acceptance criteria, not implementation milestones — implementation progress lives in `config.yaml.implementation` and `history`.

## draft → accepted

Ready to implement when:

- Goals and Non-Goals in `02-design.md` are final and reviewed.
- **OQ1–OQ4 in `03-decisions.md` are all resolved.** ✅ Done (2026-06-22): OQ1→D3, OQ2→D4, OQ3→D8, OQ4→D8.
- Every decision (D1..DN) is locked with the four-field shape — including D2, which supersedes D1's scope.
- `schemas/target.cue` compiles (`cue vet ./...` from `schemas/`) and captures the renamed surface end-to-end, with no `// OQ#` markers left unresolved.
- `config.yaml.semver` is set (`major`).
- `config.yaml.affects` is `[core, library, opm-operator, cli]`; `area` (`core`) appears in `affects`.
- `related` (`0001`) is final and resolves.
- No placeholder strings remain in any markdown file.
- The Cross-References table in `README.md` lists every file the implementation will touch, and each path exists today.

## accepted → implemented

Shipped when **all four slices** have landed, each tracked as a `history` event with a `slice:` ref:

- **core** — every `core/src` target renamed to match `schemas/target.cue` (incl. the `module_release.cue` → `module_instance.cue` file move); `SPEC.md` co-updated under the `core-schema-edit` protocol; `INDEX.md` regenerated; `core task fmt vet check` green. Published as a `feat!:` `v0.x` tag.
- **library** — Go `Release`→`Instance` identifiers, the `"ModuleRelease"` kind literal → `"ModuleInstance"`, and `module-release.opmodel.dev/*` labels → `module-instance.opmodel.dev/*`; ~24 kind fixtures migrated; pins new `core`; `task fmt vet test` green.
- **opm-operator** — `ModuleRelease` CRD → `ModuleInstance`, GitOps `Release` CRD → `ModulePackage` (D2), API group → `opmodel.dev` (D5), finalizer key, RBAC, labels; CRDs/RBAC/`PROJECT` regenerated (`task dev:manifests dev:generate`); samples + fixtures updated; `task dev:fmt dev:vet dev:test` green (note if e2e skipped — needs Kind).
- **cli** — `opm release` → `opm instance` command group (D6), `BundleRelease` → `BundleInstance` (D7), kind-detection, labels, examples/docs; pins new `core`+`library`; `task build fmt lint test` green.
- All old names deleted, not aliased (D8).
- `config.yaml.implementation.status = complete` with `date` = final landing date; `history` carries every slice's milestone.
- `README.md` carries the `> **Implementation status (YYYY-MM-DD).**` block (date matches `implementation.date`).
- `## Deviations from Design` in `README.md` lists every divergence (or "None").
