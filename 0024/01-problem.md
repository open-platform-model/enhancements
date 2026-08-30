# Problem Statement: CUE Testing and Conformance

## Current State

Almost everything OPM promises is the result of CUE evaluation: the core schema decides what an artifact may say, the catalogs decide what a component renders to, and (under 0019 D1) pure-CUE unification of instance, catalog and transformer is the render contract itself. How that behaviour is verified differs per repo, measured on 2026-08-25:

```
                       positive     negative     diagnostic    instance     cross-version
                       (accepts)    (rejects)    text          wiring       (cue / core)
 core/src              none         none         none          none         none
 catalog_opm/opm       163 _test*   none         none          hand-built   none
 catalog_opm/k8s       none         none         none          none         none
 modules               cue vet      none         none          n/a          none
 enhancements/schemas  examples.cue commented    none          hand-built   none
                                    out
 library (Go)          yes          yes          yes           yes          canary only
```

- `core` ships `task check` (format, vet, index freshness, SPEC inventory). None of those evaluates a single fixture against a definition. The seven behaviours of the 0019 D16 default flip (accepts, overrides, refuses an overlong name with the string in the diagnostic, accepts at the 63-rune bound) were verified by pasting cases into a scratch copy of the package and reading `cue vet` output by eye; nothing of that survives in the repo.
- `catalog_opm/opm` carries 163 `_test*` hidden fields across its transformers, each unifying a transformer's `#transform` with a fixture and pinning fields of the output, and every `output:` is unified with the upstream definition from `cue.dev/x/k8s.io` (`output: k8sappsv1.#Deployment & {…}`). This is real verification, positive-only, and invisible to anyone outside the module.
- `catalog_opm/k8s`, the raw passthrough family whose stated promise is "native Kubernetes APIs passed through as-is", types its inputs as open wrappers (`spec?: {…, ...}`), types its outputs against nothing, and carries no assertion. By rule it depends on `core` alone, so it cannot import the upstream definitions the abstraction family uses.
- `enhancements/NNNN/schemas/examples.cue` pins derived values with hidden assertions and states in its header that must-fail cases are "commented out with the exact error text observed on cue v0.17.1, so a reader can re-run them by hand".
- `library` has the only harness that can assert a rejection, a diagnostic's text, or a value's behaviour across CUE versions, all in Go: `schematest` fixtures against the published core, the parity harness against the pure-CUE oracle, and the `cueregression` canary, which exists because a CUE toolchain bump silently changed closedness behaviour and the catalog only renders today because an authoring rule keeps it off the trigger.

## Gap / Pain

**Rejection is unverified.** A schema's job is to make invalid artifacts unrepresentable (core constitution III). No committed test in `core` or either catalog asserts that anything is rejected, so a constraint can be loosened, or a hidden assertion silently disabled, without a failing test. The pure-CUE spellings evaluated for 0019 D16 included one whose assertion was inert: it unified an unresolved disjunction and passed for every input. That was caught by a control case run by hand, which is the only reason it was caught.

**Diagnostics are not part of any contract.** The same overlong name fails with `incomplete value =~"^[a-z0-9]…" & strings.MaxRunes(63)` under one spelling, and with `invalid value "aaa…-bbb…" (does not satisfy strings.MaxRunes(63))` under another. 0019 D16 chose the second, because the first names nothing an author can act on. Nothing records that choice as a behaviour, so the next CUE release, or the next schema edit, can revert it unnoticed.

**Drift across versions is invisible until a cluster sees it.** A `cue` toolchain bump, a core release, a catalog release and an upstream `k8s.io` snapshot can each change what an unchanged module renders to. The only mechanism that detects such a change today is the Go canary for one evaluator regression, built after the fact. 0019's own gate for the D15 sweep is "no default-named golden changes by a byte", and there is no golden.

**The raw family's conformance claim is untested.** `catalog_opm/k8s` mirrors upstream group versions at adoption (0010 D48: `apps/v1 → @v1`, `autoscaling/v2 → @v2`). But no check confirms that a member's `(apiVersion, kind)` exists upstream at any Kubernetes version, that its rendered object satisfies the upstream definition, or which upstream kinds have no member. "Each version of Kubernetes is represented, and represented correctly" is a belief.

## Concrete Example

Enhancement 0019 D16 changes `#Component.metadata.resourceName`'s default from `web` to `shop-web`. Its contract has seven observable behaviours, three of them refusals. Verifying them took a scratch copy of `core/src`, five hand-written cases, four candidate spellings, and reading twenty lines of `cue vet` output; the result is a table in an OpenSpec design document and nothing executable. When `library` re-pins that core release, its fixtures that pin `web.default.svc.cluster.local` fail, which is the first automated signal, one repo and one release removed from the change.

```
 today                                    with this entry
 ─────────────────────────────────────    ──────────────────────────────────────────
 scratch dir ──cue vet──▶ eyes            core/src: assertions beside #Component
 design.md table (prose)                    accepts shop-web / storefront / 63 runes
 library fixtures fail one release later    rejects Bad_Name / 71-rune default
                                          conformance suite, cell (cue v0.17.1, core alpha.N):
                                            expect: `_resourceNameDefaultFits: invalid value "aaa…-bbb…" (does not satisfy strings.MaxRunes(63))`
                                            replayed at (cue v0.18.0, core alpha.N): drift → fail
```

## User Stories

- As a core schema contributor, I want a committed case that says "this input is refused with this message" so that a later edit or toolchain bump cannot silently accept it or make the refusal illegible. Today: the case lives in a scratch directory and a design document.
- As a catalog author, I want the rendered output of every transformer checked against the upstream Kubernetes definition for its `apiVersion`/`kind`, for the raw family too, so that "passthrough" means passthrough. Today: only the abstraction family is typed, and the raw family cannot import the definitions by rule.
- As a release maintainer, I want a core, catalog or `cue` release to show me every rendered byte and every diagnostic it changed, before a fleet reconciles it. Today: the change is discovered by a consumer's test suite after the release, or by a cluster.

## Why Existing Workarounds Fail

- **Hand-run scratch cases** verify a change once and record nothing; the next contributor cannot re-run what the last one ran.
- **Commented-out must-fail cases** (the `examples.cue` convention) document an expectation the toolchain never checks; the comment cannot fail.
- **The abstraction family's in-module assertions** are the right idea in the wrong scope: they cannot express rejection, cannot see the raw family, and cannot compare versions, because a `cue.mod` pins exactly one core and one `k8s.io`.
- **Consumer-side detection in `library`** works but lags a release and reports the symptom in the wrong repo: a core default change surfaces as a Go fixture failure in the kernel.
- **Bespoke canaries** (`cueregression`) prove that cross-version drift is real and detectable, and also that building one per incident does not scale: each is a Go test for a shape someone already got burned by.
