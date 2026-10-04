# Graduation Criteria: Gated Ownership Transfer from CLI to Operator

These are design acceptance criteria, not implementation milestones. Delivery is logged in this entry's `delivery.yaml` and read back with `task delivery`. Repo-wide checks (semver set, placeholders gone, cross-refs resolve) live in `gates.cue` and `task vet`.

## draft → accepted

- Both experiments are concluded, and their outcomes are cited from the decisions they constrain: experiment 01 from D2, D4 and D6; experiment 02 from D2 and D3.
- OQ1 to OQ4 are resolved. Each either confirms its decision's requirements as drafted or revises them in place with the measured reason folded into *Alternatives considered*.
- D3's access review is shown, by experiment 02, to refuse every inventory the operator then fails to apply, or the decision names the cases it cannot catch and how the transfer reports them.
- OQ7 has an answer or is deferred with its context: how the CLI and the operator recognise the instance 0028:D4 keeps CLI-owned, so D2 gate 4 and D5 R2 can be met even when a marker on the record was removed.
- The 0014 coordination edit (D7) is drafted, so 0014 no longer cites the removed command at the moment this entry is accepted.
- Every requirement can be observed from outside one repo: by the user running the transfer, by an administrator reading the instance's status, or by a reader of the Platform's status.
- `config.yaml.semver` records the CRD-visible change: an additive report on the Platform's status and a new stalled reason on instances.
