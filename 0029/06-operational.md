# Operational Concerns: Gated Ownership Transfer from CLI to Operator

The OPM Production Readiness Review (PRR-lite). Five fixed prompts, each answered.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

- **Transfer refusals.** Each gate in D2 refuses with its own reason and remedy, before any write. A digest mismatch reports both digests and, where the CLI can tell, which input moved (D2 R7). An access-review refusal names the entry and the missing right (D3 R3).
- **Transfer verdict.** The bounded wait reports 0006:D40's inventory-stable verdict, including the managed-by relabel. A failure after the write says the instance is now operator-owned and points at its status and the operator's logs (D1 R3).
- **Operator adoption refusal.** A stalled status on the instance naming the marker or the operator's own instance as the reason (D5). It is visible with `kubectl describe` and through the CLI's status reads.
- **Registry mapping report.** The Platform's status shows the mapping the operator resolves with (D4). It is useful beyond the transfer: it answers "where does my operator pull modules from" without reading Deployment arguments.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

No `opmodel.dev/core` change. The `ModuleInstance` CRD is unchanged: the transfer writes fields it already has. The Platform CRD gains one additive status field. The CLI gains a command, which is additive.

Two behaviour changes are observable. The operator refuses to adopt a marked or self instance that it adopted before (D5). The CLI marks more renders local than before (D6), which makes the operator-owned thin edit refuse in cases it accepted. Both refuse something unsafe rather than change a result, so the expected `semver` is `minor` for the CLI and the operator; it is set before acceptance.

## Deprecation

**What gets removed and when? What replaces it?**

Nothing is removed. The hand flip of the owner field stays possible, narrowed by the operator's refusal. The CLI's end-to-end suite reaches operator ownership by a hand patch; the transfer command replaces that shortcut where a test needs the gated path. Docs that say no command moves an instance are replaced by the command's page.

## Rollback

**If this lands and proves bad, what's the rollback story?**

- **The CLI command** is removed by a CLI release, as cli PR 196 did once. Instances already transferred stay operator-owned; the command has no state of its own.
- **The operator refusal** is reverted by an operator release. Instances it refused then adopt on their next reconcile, which is exactly the pre-entry behaviour, so a rollback should be paired with setting the owner of any refused instance back to `cli` first. That is safe because a refused instance carries no operator finalizer.
- **The wider local marker** reverts with a CLI release. Instances marked under the wider rule keep the marker until their next registry apply.
- **The Platform status field** stays harmless if no CLI reads it.

## Cross-Repo Coordination

**Which repos must coordinate, and what constrains the order?**

- The operator's registry mapping report (D4) must be in a released operator before the CLI's transfer can pass gate 10. A CLI released first refuses every transfer, naming the upgrade, so the order is safe either way but useful only operator first. The new field is additive, so no operator release comes to need a newer CLI.
- The operator's adoption refusal (D5) needs 0028's definition of the operator's own instance (0028:D4). The local-marker half needs nothing new.
- The wider local marker (D6) should ship no later than the transfer command, so a render path it adds is never transferred unmarked. The digest gate covers the gap if it does not.
- The 0014 coordination edit (D7) follows this entry's acceptance; it changes 0014's citations, not its behaviour.
- Docs that promise no transfer change in the same release as the command: the core concepts page on instance ownership, the CLI's README and quickstart, and the CLI's operator-lifecycle spec.
