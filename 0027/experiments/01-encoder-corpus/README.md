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

From this directory (`main.go`, `walker.go`, `modes.go`; the walker is the 365-line one measured here):

```bash
export WS=/path/to/workspace   # the checkout holding opm-modules/ and modules/
export CUE_REGISTRY=opmodel.dev=ghcr.io/open-platform-model,registry.cue.works
FLEET="$WS/opm-modules/*/module.cue,$WS/modules/*/module.cue"
```

1. Encoder comparison on each CUE version. `go.mod` pins v0.17.1; the third version is the master build carrying d54641bccb:

   ```bash
   for v in v0.17.1 v0.18.0-alpha.2 v0.18.0-alpha.2.0.20261001211534-0edbb5b800c3; do
     go get cuelang.org/go@$v && go mod tidy
     go run . out-$v "$WS/opm-modules/*/module.cue" "$WS/modules/*/module.cue" > out-$v.txt
   done
   git checkout go.mod go.sum
   ```

   Each `out-<version>.txt` prints, per module, the result of `encoding/openapi` with and without `ExpandReferences`, `jsonschema.Generate`, and the walker.

2. Structural validation and server dry-run of the CRDs, through the shared harness:

   ```bash
   cd ../harness
   go run . -corpus -fleet "$FLEET" -out out-corpus
   go run . -corpus -fleet "$FLEET" -out out-corpus -live -kubeconfig /path/to/x1a-kubeconfig
   ```

   `-live` refuses a kubeconfig whose path lacks `x1a`, so it only ever touches a throwaway cluster (kindest/node v1.34.3). For the master build's structural numbers, run step 2 after `go get cuelang.org/go@v0.18.0-alpha.2.0.20261001211534-0edbb5b800c3 && go mod tidy` in `../harness`, and restore `go.mod` and `go.sum` afterwards.

## Outcome

- `encoding/openapi` with `ExpandReferences` fails to generate on 19 of 20 on v0.17.1 and v0.18.0-alpha.2: `unsupported op for number &`, from the `int & >0 & <=65535 | *N` port pattern.
- Without expansion it fails 19 of 20 on a different bug: `#Image`'s `if digest != ""` comprehension (`required field missing: digest`).
- The unreleased master fix generates 20 of 20. Even after the harness rewrites `additionalProperties: {}` to preserve unknown fields, its output fails the structural validator on 19 of 20, every failure on cpu and memory: `number | string & =~...` becomes typeless `oneOf` branches. An earlier run that also rewrote those fields to int-or-string left 4 of 20 failing server dry-run; that second rewrite was not kept, so only the 19 of 20 reproduces here.
- `jsonschema.Generate` never emits `default`.
- The walker's CRDs were accepted by server dry-run for 20 of 20, identically on all three CUE versions.
- The walker as written also emits `x-opm-*` keys and marks computed fields required. Both are defects for a served kind: see experiments 02 and 05.

Hypothesis refuted. The stock encoder cannot produce the served schema on v0.17.1 or v0.18.0-alpha.2, so D2 names the schema's shape instead of an encoder and no longer rests on entry 0008.
