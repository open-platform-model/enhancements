# Experiments — The Operator Ships as an OPM Module

Self-contained proofs-of-concept validating specific claims from the
design. See the enhancement's `02-design.md` for the claims being
tested. This file is the hand-maintained index — add a row per
experiment. Per-experiment status lives in each `NN-*/README.md`'s
`Status:` line.

| # | Concept | Status |
| - | ------- | ------ |
| 01 | [operator-module-render](01-operator-module-render/): whether the first-party catalog renders the operator's 19-object install with no cluster, names and specs equal, CRDs and RBAC generated and drift-checked | Concluded |
| 02 | [cli-bootstrap-install](02-cli-bootstrap-install/): whether "apply the module's CRDs, then a CLI-owned instance" installs, reinstalls, upgrades and deletes the operator, migrates a manifest install, and survives a self-transfer | Concluded |
