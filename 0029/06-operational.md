# Operational Concerns: Gated Ownership Transfer from CLI to Operator

The OPM Production Readiness Review (PRR-lite). Five fixed prompts, each answered.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

- **Transfer refusals.** Each gate in D2 refuses with its own reason and remedy, before any write. A digest mismatch reports both digests and, where the CLI can tell, which input moved (D2 R7). An access-review refusal names every denied entry and right, escalation rights included (D3 R3, R7), because the operator's own condition names only the first.
- **Transfer verdict.** The bounded wait reports 0006:D40's inventory-stable verdict, including the managed-by relabel, and whether the operator's recorded render digest equals the stated one (D2 R12). A failure after the write says the instance is now operator-owned and points at its status and the operator's logs (D1 R3).
- **Operator adoption refusals.** A stalled status on the instance naming the reason: a module not found at its coordinate or a render that does not reproduce the expected digest (D4), the local marker, or the operator's own instance (D5). A render that cannot run yet, because a registry did not answer or the Platform is not ready, is a waiting status, not a stall (D4 R11). It is visible with `kubectl describe` and through the CLI's status reads. A refusal caused by a stale operator cache says to evict it.
- **Field ownership.** After a successful transfer the CLI's field manager is gone from the instance's objects (D8), which `kubectl get --show-managed-fields` shows.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

No `opmodel.dev/core` change. The `ModuleInstance` CRD gains at most one additive field, if the repos choose a spec field over an annotation to carry the expected digest (D4). The Platform CRD is unchanged. The CLI gains a command, which is additive.

Three behaviour changes are observable. The operator refuses to adopt a marked or self instance that it adopted before (D5). It refuses to adopt a hand-flipped instance whose render does not reproduce what the CLI applied (D4). The CLI marks more renders local than before (D6), which makes the operator-owned thin edit refuse in cases it accepted. Each refuses something unsafe rather than change a result, so the expected `semver` is `minor` for the CLI and the operator; it is set before acceptance.

## Deprecation

**What gets removed and when? What replaces it?**

Nothing is removed. The hand flip of the owner field stays possible, narrowed by the operator's refusals. The CLI's end-to-end suite reaches operator ownership by a merge-patch flip of the owner after a CLI apply (`cli/tests/e2e/instance_operator_owned_test.go`). After this entry such a flip is adopted only when the operator reproduces the digest the CLI recorded (D4 R8). Today that never matches, because both runtimes digest the managed-by value; it matches once the operator compares under 0012:D6's shared digest or re-stamps its render with the CLI's runtime name. An operator release that ships D4 without either refuses every hand flip, so the suite keeps passing only if that release carries one of them; otherwise it moves to the transfer command in the same CLI release. Docs that say no command moves an instance are replaced by the command's page.

## Rollback

**If this lands and proves bad, what's the rollback story?**

- **The CLI command** is removed by a CLI release, as cli PR 196 did once. Instances already transferred stay operator-owned; the command has no state of its own.
- **The operator refusals** are reverted by an operator release. Instances it refused then adopt on their next reconcile, which is exactly the pre-entry behaviour, so a rollback should be paired with setting the owner of any refused instance back to `cli` first. That is safe because a refused instance carries no operator finalizer.
- **The wider local marker** reverts with a CLI release. Instances marked under the wider rule keep the marker until their next registry apply.
- **The expected digest on a record** is harmless to an operator that does not read it.

## Cross-Repo Coordination

**Which repos must coordinate, and what constrains the order?**

- The operator's adoption check (D4) must be in a released operator before the CLI's transfer can pass gate 10. A CLI released first refuses every transfer, naming the upgrade, so the order is safe either way but useful only operator first.
- The operator's refusals of D4 and D5 change what a hand flip does, so they ship in one operator release; shipping the marker refusal alone would leave the stripped-marker and inline-module cases open.
- The operator's own-instance refusal (D5) needs 0028's definition of the operator's own instance (0028:D4); OQ7 holds which signals identify it. The local-marker half needs nothing new.
- The wider local marker (D6) should ship no later than the transfer command, so a render path it adds is never transferred unmarked. The digest checks cover the gap if it does not.
- **Digest-definition skew between the CLI and the operator.** D4 compares a digest one runtime recorded with a render the other computes, so both must use one definition. When 0012:D6 changes the definition, it ships in the CLI and the operator together, or the operator keeps accepting the old definition for the hand-flip comparison until the CLI's recorded digests are rewritten. A CLI that does not know the running operator's definition refuses the transfer at gate 10 (D4 R14). A record whose digest predates the change fails the hand-flip comparison once; the remedy is one CLI re-apply.
- The 0014 coordination edit (D7) follows this entry's acceptance; it changes 0014's citations, not its behaviour. 0028:D5's rationale, which points at the dropped registry-mapping report, is edited in 0028.
- Docs that promise no transfer, or that the CLI never changes an owner, change in the same release as the command:
  - core: `core/docs/site/concepts/who-owns-an-instance.md` and `core/docs/site/concepts/modules-and-instances.md`;
  - opm: `opm/docs/site/start/what-is-opm.md`, `opm/docs/site/start/what-opm-does-not-do.md`, `opm/docs/site/start/opm-for-kubernetes-users.md` and the owner entry in `opm/docs/site/reference/glossary.md`;
  - cli: the README, the quickstart and the operator-lifecycle spec;
  - opm-operator: `opm-operator/docs/site/diagnostics/operator-conditions.md`, which gains the new stalled and waiting reasons of D4 and D5.
