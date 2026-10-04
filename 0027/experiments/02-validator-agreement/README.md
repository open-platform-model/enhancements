# 02-validator-agreement: Self-Service Kinds from Published Modules

Status: Concluded

## Hypothesis

Validating a generated CRD offline with the Kubernetes apiextensions library gives the same accept or refuse verdict as a live API server, so an offline check can gate CRD acceptance. Backs D2 (R3, the refusal at acceptance) and OQ18 (the readers that must agree on validity).

## Setup

- Ground truth for every value fixture: CUE itself, `(#config & values)` validated concrete and final, cue v0.17.1.
- Offline: `k8s.io/apiextensions-apiserver` v0.37.1, strict decode, structural conversion, structural validation and full CRD validation.
- Live: a throwaway kind cluster (kindest/node v1.34.3, private kubeconfig, deleted afterwards). Server dry-run of each CRD, then the CRD applied, then server dry-run of each value fixture.
- Inputs: 28 sample `#config` packages (secrets, unions, defaults), 27 CEL-cost probes, and the 20 real modules of experiment 01. Encoders: the four of experiment 01 plus the candidate encoder of experiments 03 and 04.

## Run

From [`../harness/`](../harness/):

```bash
export WS=/path/to/workspace   # the checkout holding opm-modules/ and modules/
export CUE_REGISTRY=opmodel.dev=ghcr.io/open-platform-model,registry.cue.works
FLEET="$WS/opm-modules/*/module.cue,$WS/modules/*/module.cue"
```

```bash
go run . -out out                                    # offline: every sample, every encoder
go run . -out out -live -kubeconfig /path/to/x1a-kubeconfig
go run . -corpus -fleet "$FLEET" -out out-corpus -live -kubeconfig /path/to/x1a-kubeconfig
```

Each run writes `results.json` (per encoder and sample: offline structural verdict, CRD validation, live verdict, and every fixture's CUE and API verdicts) and prints one summary line per pair. The offline run needs no cluster; the live runs need a throwaway kind cluster (kindest/node v1.34.3) whose kubeconfig path contains `x1a`. Totals in the recorded run: 403 CRDs and 451 fixture dry-runs on the samples, plus 80 corpus CRDs and 80 corpus dry-runs.

## Outcome

- Offline and live agreed on all 403 CRD verdicts.
- The API server restarted under load during the run. The harness retried transport errors only, never a schema verdict, and no transport error remained in the final run.
- Strict decoding refuses a CRD carrying an unknown key such as `x-opm-ui` ("unknown field"); lenient decoding drops it silently. An encoder that writes presentation hints into the CRD therefore produces a CRD the API server refuses or prunes.

Hypothesis held. Offline structural validation is a sound gate for CRD acceptance. Instance verdicts still need a live server or the API server's validation library.
