# 03-kernel-omission — Attribute-Declared Secret Fields

Status: Concluded

## Hypothesis

The resolve-in-place rewrite (D11) survives the real `library/opm/kernel` build path when implemented as **omission** — assembling the render build without the deployer's original values conjunct — such that: the raw-values instance builds and validates as its own artifact; overriding (filling the resolved arm over the raw-baked package) is refuted by the closed-arm collision; both candidate omission mechanisms named in OQ2 (fill-style and bake-style) produce a clean, concrete render instance whose secret paths carry `{ref, key}` only; and the plaintext is structurally absent from the render artifact's values. This is OQ2 — the sole `draft → accepted` blocker.

## Setup

Everything runs against **published, pinned artifacts** — no local `replace`, no modification outside this directory:

- **`go.mod`** pins `github.com/open-platform-model/library` at a published, immutable Go-module-proxy version (currently `v1.0.0-alpha.13`; first run measured `v1.0.0-alpha.12`) — satisfying the copy-never-reference rationale: the claim is validated against fixed bytes. A `replace` to the workspace checkout is exactly what the experiments protocol forbids.
- The kernel resolves **`opmodel.dev/core@v2` → `v2.0.0-alpha.4`** from GHCR at run time (reads only, per the workspace Registry Policy); `fixture/cue.mod/module.cue` pins the same version for the CUE-side imports.
- **`fixture/secretmod/`** — a minimal core-v2 `#Module` whose `#config` carries the narrowed two-arm `#Secret` **defined locally in the module**: core v2 still ships the old `$`-field vocabulary, and this experiment measures the kernel path, not the core slice — `#config: _` is author-defined, so a module-local contract type is legal today. Disjunction shape copied from `../../schemas/target.cue`; minimal-module shape copied from `testdata/synth/fixture.cue` of the pinned library version. Two secrets: `db.password` (exercised in the supplied arm) and `tls.cert` (exercised in the referenced arm).
- **`fixture/instance/`** — a hand-authored `#ModuleInstance` package split across `instance.cue` + `values.cue` (the exact split `LoadInstancePackage` documents), so the deployer's raw values are **baked into the loaded package** — the hard case OQ2 names. `values.cue` supplies `db.password: {value: "hunter2"}` and `tls.cert: {ref: "wildcard-cert", key: "tls.crt"}`.
- **`main.go`** drives five measurements through public kernel entry points only (`kernel.New`, `LoadModulePackage`, `LoadInstancePackage`, `ProcessModuleInstance`, `Kernel.Validate`, `loaderfile.BuildInstanceOverlayAt`):
  - **M1 baseline** — the raw-baked instance builds (`ProcessModuleInstance`, no fill) and `Kernel.Validate` accepts the raw values: statement A lives in the validate artifact.
  - **M2 negative control** — `ProcessModuleInstance(rawBakedSpec, resolvedValues)` must fail: the production fill seam collides the two closed arms (case 3 of the disjunction demo, at kernel scale), proving the rewrite must be omission, not override.
  - **M3 fill-style** — load the instance with `values.cue` overlaid empty, hand the resolved values to `ProcessModuleInstance` — the kernel's **existing** `ValidateConfig` + `FillPath` seam. Must build clean and concrete.
  - **M4 bake-style** — bake the resolved values at load time via `BuildInstanceOverlayAt` (the same overlay mechanism `synth.Instance` uses), then `ProcessModuleInstance` with no fill. Must build clean and concrete.
  - **M5 absence** (asserted inside M3 and M4) — on each render artifact: the literal resolved to `{ref: "myapp-secrets", key: "db_password"}`, the deployer-written ref passed through as itself, `values.db.password.value` does **not exist**, and the plaintext string is absent from the exported values subtree.

The `ModuleInstance` CR door maps onto M3: an operator decodes CR values into data and hands them to the kernel as a parameter — the same seam, values never baked into a loaded package.

## Run

```bash
export CUE_REGISTRY='opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'
go run .
```

First run fetches the library from the Go module proxy and `opmodel.dev/core@v2` from GHCR (anonymous reads). Exit code 0 with `RESULT: all assertions passed`; any failed assertion exits 1.

## Outcome

**Hypothesis held — all 17 assertions passed** (2026-08-14, library v1.0.0-alpha.12, core v2.0.0-alpha.4, CUE v0.17.1). **Re-verified same day against library v1.0.0-alpha.13** (released after the first run): 17/17 again, no changes to fixture or driver beyond the pin.

- **M1** — raw-baked instance built; `Kernel.Validate` accepted the raw values; `values.db.password.value == "hunter2"` in the validate artifact. Statement A has a home and it is not the render build.
- **M2** — the override attempt failed exactly as the disjunction demo predicted, through the production seam: `filling values into instance spec: values.db.password: 3 errors in empty disjunction` — the closed-arm collision, at kernel scale. **Omission is required, and the kernel's own fill seam enforces it.**
- **M3 (fill-style)** — clean. Notably, `ProcessModuleInstance` **already is** the fill mechanism: values arrive as a parameter and `FillPath` into the spec, so fill-style omission needs no new kernel machinery at all — only that the render spec is loaded without the raw values conjunct.
- **M4 (bake-style)** — clean, through `BuildInstanceOverlayAt`, the loader entry point `synth.Instance` already uses; so bake-style also needs no new machinery.
- **M5** — on both render artifacts: `values.db.password == {ref: "myapp-secrets", key: "db_password"}` (arm rewritten), `values.tls.cert.ref == "wildcard-cert"` (ref passed through — the arms converge), no `.value` field exists on the resolved secret, and `"hunter2"` is absent from the exported values subtree.

**Consequences for the design:** OQ2 resolves. The pipeline shape is **one component-graph build** — the deployer's raw values are validated in their own evaluation (the existing, separate `Kernel.Validate` phase), and the render build carries the resolved statement only; no second graph build exists or is needed. Both candidate mechanisms are viable today through public entry points; the implementation may choose either (fill-style is the natural fit for parameter-carried values — CLI flags, CR decode; bake-style for package-staged loads). Recorded as **D16** in `../../03-decisions.md`.
