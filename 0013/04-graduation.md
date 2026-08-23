# Graduation Criteria — Attribute-Declared Secret Fields

This document records the entry-specific gates that must hold before this design is frozen. Treat these as design acceptance criteria, not implementation milestones — delivery is derived from the plans side and read back with `task delivery`; this entry stores nothing about it.

## draft → accepted

The enhancement is ready to be implemented when:

- **OQ2 is resolved.** ✅ Met 2026-08-14: `experiments/03-kernel-omission` (Concluded) measured the arm rewrite against the real published kernel (library v1.0.0-alpha.12, re-verified on v1.0.0-alpha.13) — clean omission holds via both candidate mechanisms, override is structurally refused, one component-graph build suffices. Recorded as D16.
- OQ1 stays `resolved-by-D10` and `schemas/target.cue` carries no `OQ` marker comments.
- `cue vet ./...` passes from `schemas/`, and `schemas/examples.cue`'s `_assert*` fields still unify.
- Decisions D1..D17 are locked, each carrying the four-field format, with the supersession chain intact (D10 supersedes D1; D11 supersedes D4; D12 amends D9; D16 resolves OQ2; D17 fixes the rewrite mechanism from the experiment-04 measurement).
- Goals and Non-Goals in `02-design.md` are final and reviewed — in particular the encryption-at-rest boundary, revised by D14: SOPS support at the file seams is in scope, implementing cryptography is not; the operator-path plaintext-in-CR posture is stated by D15.
- `experiments/01-attribute-propagation`, `02-resolve-in-place`, `03-kernel-omission`, and `04-rewrite-performance` are `Status: Concluded`, and their outcomes are reflected in the decisions that cite them.
- `semver` in `config.yaml` is set. Expected `major`: `core` removes published definitions and narrows `#Secret`'s arms, and `catalog_opm` narrows `#SecretSchema.data` — both breaking for any consumer using them.
- `affects` is final; `area` appears in `affects`.
- `README.md ## Scope` carries `### In scope` and `### Out of scope`.
- The Cross-References table in `README.md` names the design documents and sibling entries a reader needs, and no implementation file paths.
- No `{Capitalised}` placeholder strings remain in any markdown file.
