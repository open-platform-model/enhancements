# Risks, Drawbacks, Alternatives: Gated Ownership Transfer from CLI to Operator

The largest risk is a gate that passes while the operator fails, because a failed transfer cannot be undone. Per-decision alternatives live in `03-decisions.md`.

## Risks and Mitigations

- **The access review passes and the operator's apply is still refused.** Escalation prevention on roles, binding rights, and the difference between what a review asks and what a server-side apply issues can each let a review pass that the apply fails. The instance is then operator-owned and stalled, with no reverse. **Mitigation:** experiment 02 measures the gap before acceptance (OQ2), and D3 R3's wording follows the measurement. The stall is repaired forward: grant the missing right and the next reconcile proceeds.
- **The CLI reaches a registry the operator cannot.** A fetch through the operator's mapping from the user's machine can succeed where the operator's fetch fails, for example over a VPN. **Mitigation:** D4 R4 fetches without credentials, as the operator does; experiment 01 measures the network-position gap (OQ1); an operator-side resolve stays the fallback design.
- **A marker stripped by hand passes the backstop.** The marker is an annotation, and D5 trusts its absence. A hand flip that also strips it gets the operator to apply registry bytes. **Mitigation:** none at the operator today; the CLI's digest gate is the authority for the command path. OQ5 records the operator-side digest check that would close it once 0012:D6 lands. The exposure is no worse than before this entry, when the operator read nothing.
- **Every pre-upgrade instance fails the digest gate once.** When the digest definition changes, as 0012:D6 changes it, a digest recorded before the change never matches a re-render after it. **Mitigation:** D2 R7 reports which input moved; the remedy is one CLI re-apply, which rewrites the digest, then the transfer.
- **The operator's first reconcile after a transfer rolls the workload.** 0006:D40 confirmed the managed-by relabel is metadata only. A Platform change between the CLI's apply and the transfer could still change the render. **Mitigation:** gate 11 renders against the cluster Platform and refuses a mismatch, so any change surfaces before the write.
- **A later module version adds a kind the applier cannot apply.** The gate proves rights over the recorded inventory, not over future versions. **Mitigation:** the operator stalls with an impersonated-apply refusal on that version, its normal path; the transfer's report says the proof covers what is deployed now.

## Drawbacks

- **The transfer needs administrator rights.** Reviewing another identity's access, reading the cluster Platform and reading the operator's readiness are not namespace-tenant rights. 0006:D17 already accepted this for the transfer.
- **The user must state two things the CLI used to leave unset.** The applier account and the prune intent become required inputs, so the transfer is one more decision for the user than the removed command was.
- **The operator gains a refusal path.** An instance that was adoptable by a hand flip before now stalls if it carries the marker. That is the point, and it is still a behaviour change a user can observe.
- **A new field on the Platform's status.** It is additive, and a CLI talking to an older operator refuses the transfer until the operator is upgraded.

## Alternatives

- **No transfer; export to GitOps is the only path off the CLI.** A user who wants the operator, not Git, would have to commit a tree to get there. **Why not:** the owner chose to revive the transfer.
- **Operator-side gates only, through an admission webhook.** It refuses even the hand edit. **Why not:** the operator would need a second render path for the digest gate, and a webhook outage blocks every instance write.
- **Make the operator self-describe everything the CLI needs, and let the CLI only flip.** It removes the CLI's gate logic. **Why not:** the digest gate is a CLI self-comparison by 0006:D40, and only the CLI holds the render it recorded.
