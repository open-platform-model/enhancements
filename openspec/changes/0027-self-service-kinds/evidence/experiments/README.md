# Experiments: Self-Service Kinds from Published Modules

Measurements behind the served-schema decision (D2) and the candidate answers to its open questions (OQ17 to OQ22). This file is the hand-maintained index. Per-experiment status lives in each `NN-*/README.md`'s `Status:` line.

All six ran on 2026-10-04. Experiment 06 is a write-up of measurements taken with scratch harnesses that are not kept; it uses neither its own program nor `harness/`. Experiment 01 carries its own encoder-comparison program. Experiments 02 to 05 are views on one run of the shared harness in [`harness/`](harness/), kept once rather than copied four times. This is a deliberate exception to the rule that an experiment touches nothing outside its own directory: experiments 02 to 05, and step 2 of experiment 01, run in and write to `harness/`.

The harness:

- `main.go` encodes every sample (or, with `-corpus`, every fleet module) with each encoder, wraps the schema in a CRD, validates it offline, and with `-live` applies it to a throwaway cluster and dry-runs every fixture. CUE is the ground truth for each fixture.
- `cand.go` is the candidate encoder (CEL mode `cand-cel`, `oneOf`/`not` mode `cand-oneof`); `walker.go` is experiment 01's walker, unchanged.
- `cue/` holds three copies of core's `#Secret` (`coreold`, `corev2`, `corev2w2`) and 61 sample `#config` packages with their fixtures. `gen_samples.py` regenerates the 28 non-cost samples byte for byte; the 33 `zcost-*` CEL-cost probes were generated ad hoc and are committed as they ran.

The fleet runs read the workspace's `opm-modules/` and `modules/` checkouts, so they reproduce against the fleet's current state, not the released versions measured on 2026-10-04. Their Run commands set `CUE_REGISTRY` so the fleet's dependencies resolve from GHCR.

| # | Concept | Backs | Status |
| - | ------- | ----- | ------ |
| 01 | encoder-corpus | D2 | Concluded |
| 02 | validator-agreement | D2, OQ18 | Concluded |
| 03 | secret-encoding | OQ19 | Concluded |
| 04 | struct-unions | OQ20 | Concluded |
| 05 | required-and-computed | D2, OQ21, OQ22 | Concluded |
| 06 | presentation-metadata | OQ17 | Concluded |
