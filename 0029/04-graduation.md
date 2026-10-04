# Graduation Criteria: Gated Ownership Transfer from CLI to Operator

These are design acceptance criteria, not implementation milestones. Delivery is logged in this entry's `delivery.yaml` and read back with `task delivery`. Repo-wide checks (semver set, placeholders gone, cross-refs resolve) live in `gates.cue` and `task vet`.

## draft → accepted

- Both experiments are concluded and cited from the decisions they constrain: experiment 01 from D2, D4, D5, D6 and D8; experiment 02 from D1, D2, D3, D5 and D8.
- OQ1 to OQ5 are resolved by decisions that rest on the measurements.
- OQ8 is answered by the owner: whether a reachability refusal by the operator after the owner write is acceptable, or which of the other options replaces it. D4 and D2 are revised in place to match the answer.
- D3's access review is shown, by experiment 02, to refuse every inventory the operator then fails to apply, or the decision names the cases it cannot catch and how the transfer reports them. Experiment 02 meets this once escalation is modelled (D3 R7, R8); the residual case is a later module version (05-risks.md).
- OQ7 has an answer or is deferred with its context: how the CLI and the operator recognise the instance 0028:D4 keeps CLI-owned, so D2 gate 4 and D5 R2 can be met even when a marker on the record was removed.
- The 0014 coordination edit (D7) is drafted, so 0014 no longer cites the removed command at the moment this entry is accepted.
- Every requirement can be observed from outside one repo: by the user running the transfer, by an administrator reading the instance's status or its objects' field managers.
- `config.yaml.semver` records the CRD-visible change: new stalled reasons on instances, and at most one additive instance field for the expected digest.
