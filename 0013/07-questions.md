# Open Questions — Attribute-Declared Secret Fields

## Open Questions

- **OQ1: Which surface chooses between the supplied and referenced fulfilment kinds?** Status: resolved-by-D10.

  Resolved by keeping the choice in the field's *type*. D1 had removed the disjunction along with the routing metadata, leaving nowhere for the deployer to express "this object already exists"; D10 restores a narrowed `#Secret` whose two arms are exactly that choice, so CUE resolves it by unification as it does today. The three candidate surfaces this question weighed — an attribute argument, a scheme-prefixed value string, and a sibling block on `#ModuleInstance` — are all rejected in D10's alternatives, the first because it bakes a cluster fact into a published module, the other two because they cost more than the disjunction they were replacing.

- **OQ2: Is replacing a user-supplied arm with the kernel-resolved arm a clean value replacement?** Status: resolved-by-D16.

  The kernel rewrites `values.<path>` from `{value: …}` to `{ref: …, key: …}` (D11). `experiments/02-resolve-in-place` performs this by decode → mutate → encode, which sidesteps unification entirely and works. What is unverified is whether anything downstream re-unifies the *original* values against the rewritten ones — the instance file's own conjunct on the `values` vertex, a `ModuleInstance` CR round-trip, or `kernel.Validate` running against real values in the same build — and produces a conflict, since `{value: …} & {ref: …, key: …}` is bottom under `#Secret`'s closed arms.

  Resolving this requires a measurement against the real `library/opm/kernel` path rather than a synthetic one, and it determines whether the kernel needs two builds (one to validate against supplied values, one to render against resolved values) or can do both in one. It is a research item rather than a judgement call, and it is the last mechanical unknown in the design.

  Two candidate implementations to measure: bake-style (the `synth.Instance` path already writes `values.cue` into the build — write the *resolved* values instead, validating the raw values separately) and fill-style (build the instance package with the `values` vertex unset, then `FillPath` the resolved values into the empty slot). Three doors to check for original-conjunct leakage: the file-loaded instance package, the synth path, and a `ModuleInstance` CR round-trip. If the measurement rules out clean omission on every candidate, the recorded fallback is the `#SecretBase` coexistence fill in D11's alternatives — accepting plaintext-in-graph as convention — not `#ctx.secrets`, which additionally moves the author wiring.

  Was the sole blocker to `draft → accepted`. **Measured 2026-08-14 by `experiments/03-kernel-omission/` against the published kernel: clean omission holds on both candidates, override is refuted by the kernel's own fill seam, one graph build suffices. The fallbacks are not needed. Resolved by D16.**
