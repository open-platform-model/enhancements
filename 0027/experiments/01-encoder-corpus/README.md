# 01-encoder-corpus: Self-Service Kinds from Published Modules

Status: Concluded

## Hypothesis

CUE's stock `encoding/openapi` encoder, the one entry 0008 chose for core's own CRDs, produces a structural CRD schema for the `#config` of real published OPM modules. Backs D2.

## Setup

- Corpus: the 20 modules published from `opm-modules` (12) and `modules` (8), at their released versions.
- Encoders: `encoding/openapi` with `ExpandReferences: true`, the same without expansion, `encoding/jsonschema`, and a 365-line walker over `cue.Value` written for the measurement.
- CUE versions: v0.17.1, v0.18.0-alpha.2, and an unreleased master build carrying upstream commit d54641bccb (cue-lang/cue issues 4305 and 3043).
- Acceptance: the Kubernetes structural-schema validator, then `kubectl apply --dry-run=server` against a throwaway kind cluster (kindest/node v1.34.3).

## Run

Harness not committed (see the index). For each module and encoder: generate the schema for `#config`, wrap it in a CRD, run the structural validator, then server dry-run the CRD.

## Outcome

- `encoding/openapi` with `ExpandReferences` fails to generate on 19 of 20 on v0.17.1 and v0.18.0-alpha.2: `unsupported op for number &`, from the `int & >0 & <=65535 | *N` port pattern.
- Without expansion it fails 19 of 20 on a different bug: `#Image`'s `if digest != ""` comprehension (`required field missing: digest`).
- The unreleased master fix generates 20 of 20. Its output fails the structural validator on all 20 until `additionalProperties: {}` is rewritten, and on 4 of 20 after that (`number | string & =~...` for cpu and memory becomes typeless `oneOf` branches).
- `jsonschema.Generate` never emits `default`.
- The walker's CRDs were accepted by server dry-run for 20 of 20, identically on all three CUE versions.
- The walker as written also emits `x-opm-*` keys and marks computed fields required. Both are defects for a served kind: see experiments 02 and 05.

Hypothesis refuted. The stock encoder cannot produce the served schema on any released CUE, so D2 names the schema's shape instead of an encoder and no longer rests on entry 0008.
