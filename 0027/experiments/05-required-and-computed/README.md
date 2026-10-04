# 05-required-and-computed: Self-Service Kinds from Published Modules

Status: Concluded

## Hypothesis

A served schema that marks a field required only when the consumer must supply it accepts every value set the module itself accepts, while one that marks defaulted or computed fields required does not. Backs D2 (the measured encoder constraints) and OQ21.

## Setup

- A required-versus-defaulted sample with 10 fixtures, including a computed field whose inputs have defaults.
- The 20 real modules of experiment 01, each with its own `debugValues` as a must-accept fixture.
- Encoders: `encoding/openapi`, the experiment 01 walker, and the candidate encoder of experiments 03 and 04 with this rule: a field is required iff it is marked `!`, or it is a regular field with no default that is neither concrete nor computed; a struct is required iff one of its children is.
- Validation and fixtures as in experiment 02.

## Run

From [`../harness/`](../harness/), with the environment of experiment 02:

```bash
go run . -only r01 -out out-r01 -live -kubeconfig /path/to/x1a-kubeconfig
go run . -corpus -fleet "$FLEET" -out out-corpus -live -kubeconfig /path/to/x1a-kubeconfig
```

The required-versus-defaulted sample is `cue/samples/r01-required`; the corpus run dry-runs each module's own `debugValues` against every encoder's CRD.

## Outcome

- `encoding/openapi` marks defaulted fields required (a `user` field defaulting to `app` lands in `required`), and fails to generate on an interpolation over a required field.
- The walker leaves defaulted fields optional but marks concrete constants, computed fields and all-defaulted structs required. It refuses the module's own `debugValues` on 19 of 20 real modules (`spec.image.reference: Required value`, the comprehension-computed field of every image).
- The walker also writes `x-opm-computed` and `x-opm-ui` into the CRD, which strict decoding refuses (experiment 02). Its 20 of 20 CRD acceptance in experiment 01 held only because no corpus module triggered those keys.
- The candidate rule accepts every real module's `debugValues` (20 of 20) and agrees with CUE on 8 of 10 sample fixtures.
- Both remaining disagreements are computed fields. A computed field's wrong value is admitted. A computed field whose inputs have defaults is frozen into a one-value enum, so setting a different input together with the matching computed value is refused although CUE accepts it. Every real module serves the image reference this way today.
- Emitting CUE defaults as CRD defaults breaks the struct-default reduction of experiment 04: that sample's CRD is invalid.

Hypothesis held. Candidate for OQ21: a defaulted field is not required and defaults are not emitted as CRD defaults (consistent with the OQ9 candidate). This experiment did not measure what replaces the one-value enum for computed fields; removing them from the consumer schema and serving them as unconstrained strings are both open in OQ21.
