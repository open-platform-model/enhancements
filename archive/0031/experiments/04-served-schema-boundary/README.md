# 04-served-schema-boundary — Module Presentation Contract

Status: Concluded

## Hypothesis

The structural schema a served kind can carry is a lossy subset of `#config` that cannot hold presentation, so presentation must be checked through CUE and must travel beside the schema, never inside it.

This experiment records only the numbers this entry uses. The full measurement is evidence for entry 0027's served-schema questions (0027:OQ19 to 0027:OQ21), whose answers this entry does not give.

## Setup

Measured 2026-10-04 (experiment X1a of the portal design work).

- cue v0.17.1. Ground truth per fixture: the CUE verdict of `#config` unified with the values, validated concrete.
- Inputs: three versions of core's `#Secret` shape, 28 sample `#config` packages carrying 129 fixtures, 27 CEL-cost probes, and the 20 real modules, each with its own debug values as a fixture it must accept.
- Encoders compared: CUE's OpenAPI encoder (with and without reference expansion), CUE's JSON Schema encoder, a hand-written structural walker of `#config`, and a candidate encoder.
- Validation two ways: offline with `k8s.io/apiextensions-apiserver` v0.37.1 (strict decode, structural checks, CRD validation), and live on a throwaway kind cluster (kindest/node v1.34.3) by server dry-run: 403 CRDs and 451 fixture dry-runs, plus 80 corpus CRDs and 80 corpus dry-runs. The cluster was deleted afterwards.

The harness lived in a scratch directory and is not kept here.

## Run

1. Generate the sample packages and fixtures; take each fixture's CUE verdict.
2. Encode every sample with every encoder; validate each CRD offline and live.
3. Apply each accepted CRD and dry-run every fixture against it; compare with the CUE verdict.

## Outcome

**Offline equals live.** The offline validator and the live API server agreed on all 403 CRD verdicts.

**Presentation keys break a CRD.** The walker emitted `x-opm-ui` and `x-opm-computed` into its schemas, and the API server refused the whole CRD for them under strict decoding. Its earlier 20/20 corpus result held only because no corpus module triggered those keys. Evidence for 0031:OQ10.

**The structural schema is lossy.** The walker lost cross-arm rules and comprehension-guarded fields. Its required-field rule refused its own modules' debug values on 19 of 20 real modules, on the comprehension-computed image reference. A computed field whose inputs have defaults was frozen into a single-value enum, which refuses values CUE accepts. Evidence for 0031:D6 checking presets through the projection rather than the served schema.

**Type-level shapes hide behind references.** For a field typed by an imported definition, the field's expression showed only the reference and hid the definition's disjunction arms and scalar bounds until the value was evaluated. The same reference-following need as experiment 01's catalog-type hints.

**Secrets are found by tag, never by shape.** Looking up core's hidden secret tag reported scalar, map, list and nested secret paths with no values present, and reported neither a tag-less look-alike nor the old shape.

**No plaintext echo.** None of the 451 fixture dry-runs, accepted or refused, echoed a literal secret value. The API server echoes a value only on a pattern or enum failure, and a type error prints only the type name. Evidence for 0031:OQ12.

Hypothesis held: presentation cannot ride inside the served CRD, and a check that must agree with CUE has to run through CUE.
