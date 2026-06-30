# Risks, Drawbacks, Alternatives — OPM Module Publishing Workflow

This document records the honest costs of the proposed design. Risks describe what could go wrong; Drawbacks describe what definitely costs something; Alternatives describe the high-level paths not taken (per-decision detail lives in `03-decisions.md`).

## Risks and Mitigations

- **Migration breaks consumers pinned to a non-conforming path.** Republishing `web-app` from `…/web-app@v1` to `…/web_app@v0` (and any other non-conforming module from OQ4) changes the registry address; anything that imports the old path breaks. Blast radius: in-repo fixtures and any release pinning the old coordinate. **Mitigation:** inventory non-conforming modules before accepting (OQ4 gate), migrate in-repo consumers in the same slice, and treat it as a hard switch only for modules not yet relied upon externally; publish the new coordinate before deleting the old where a window is needed.

- **A bare import does not bind to the snake-named package on every CUE toolchain version.** If `import "path@vN"` with a snake leaf does not resolve to the same-named package without a `:pkgName` qualifier, the render path emits an import that fails. Blast radius: every synthesized release. **Mitigation:** OQ2 must be verified empirically against the kernel-pinned CUE toolchain before accept; the library helper emits the explicit `:nameSnakeCase` qualifier if bare resolution is not guaranteed.

- **The convention is only enforced for modules published via `opm publish`.** A module pushed by other tooling can still violate D1 and be unimportable by metadata. Blast radius: third-party modules. **Mitigation:** the registry loader verifies resolved coordinates against `#CanonicalModuleRef` and surfaces a typed, actionable mismatch error (OQ5), rather than a downstream `module not found`.

## Drawbacks

- **`opm publish` gains a validation step authors must satisfy.** Publishing a module now requires its `cue.mod` path and package name to match its identity — one more way a push can be rejected. Accepted: it converts a silent, late render failure into an early, explicit publish failure.
- **One more name to keep in mind.** `nameSnakeCase` is derived and authors never set it, but contributors must understand that the registry leaf and package name are projections of `name`, not free choices. Accepted: the constraint is the point — it removes the drift that motivated the enhancement.

## Alternatives

- **Thread the registry reference through `synth.InstanceInput` / record it on `*module.Module`, with no convention.** Mechanically correct for all modules including non-conforming ones. **Why not (as the sole fix):** it solves consumption but not authoring — modules can still be published at arbitrary paths, so the ecosystem never gains the "metadata → address" guarantee; recording the fetched reference is retained as a possible safety net under OQ3, not the primary mechanism.
- **Enforce `metadata.name == registry leaf == package name` (identity, no projection).** Simplest rule. **Why not:** `name` is kebab-case and may contain hyphens, which are invalid in a CUE package name, so identity cannot be the package name; a projection (`nameSnakeCase`) is required.
- **Leave addressing free-form and document a best-practice.** Zero tooling. **Why not:** documentation without enforcement is exactly today's state — the drift already happened (`zot`, `web-app`), so only a checked convention removes it.
