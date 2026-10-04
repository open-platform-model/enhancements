# Experiments: Self-Service Kinds from Published Modules

Measurements behind the served-schema decision (D2) and the candidate answers to its open questions (OQ18 to OQ21). This file is the hand-maintained index. Per-experiment status lives in each `NN-*/README.md`'s `Status:` line.

All five ran on 2026-10-04 as throwaway harnesses outside this repo (about 1,500 lines of Go plus a Python sample generator, too large to copy in usefully). Each README records the method and the measured numbers. Reproducing one means rebuilding its harness from the method it states.

| # | Concept | Backs | Status |
| - | ------- | ----- | ------ |
| 01 | encoder-corpus | D2 | Concluded |
| 02 | validator-agreement | D2, OQ18 | Concluded |
| 03 | secret-encoding | OQ19 | Concluded |
| 04 | struct-unions | OQ20 | Concluded |
| 05 | required-and-computed | D2, OQ21 | Concluded |
