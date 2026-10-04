# Design: Gated Ownership Transfer from CLI to Operator

A transfer command returns, with the old gate chain plus the two gates whose absence removed it: who applies, and whether the operator can reach the module. The operator gains a refusal of its own, so a hand edit cannot do what the command refuses. Trade-offs live in `03-decisions.md`.

## Design Goals

- A CLI-owned instance can be handed to the operator with one command, and the operator's first reconcile adopts exactly what is running: same inventory, nothing pruned, nothing recreated.
- A transfer that would strand the instance refuses before it writes anything, naming what is missing. Stranding covers an applier that cannot apply, a module the operator cannot fetch, and a render the registry does not reproduce.
- The identity the operator applies as, and whether it prunes, are stated by the user at transfer and recorded on the instance. Nothing is inferred.
- The operator refuses to adopt an instance whose render was local, or the instance that deploys the operator itself, whichever way its owner field came to say `operator`.
- One gate set serves every path that moves an instance's management away from the CLI. Export (0014) reuses it rather than restating it.

## Non-Goals

- **A reverse transfer.** Operator to CLI stays out of scope, as 0006:D16 decided. A stalled transfer is repaired forward: fix the applier's rights, and the operator's next reconcile proceeds.
- **Private registry credentials.** The operator presents none today, so the transfer verifies what an anonymous fetch can reach. Credential plumbing is its own design.
- **Creating the applier account or its RBAC.** The transfer proves an identity can apply; it does not grant rights. Whether a helper should emit them is an open question.
- **Transferring the operator's own instance.** 0028 keeps it CLI-owned forever, and this entry refuses it at both ends.
- **GitOps export.** 0014 owns the exported tree; this entry owns only the shared gates.

## High-Level Approach

The transfer is a sequence of refusals, then one write, then a verdict.

```text
opm instance handoff <name> --service-account <sa> --prune=<bool>
  |
  |  gates, cheapest first; any refusal writes nothing
  |  1  cluster gates (CRDs, field floor, operator version ceiling)
  |  2  operator installed and ready
  |  3  record exists and is CLI-owned
  |  4  not the operator's own instance (0028)
  |  5  no local-provenance marker
  |  6  complete published coordinate
  |  7  no skipped contracts
  |  8  a recorded render digest
  |  9  the named identity can apply (and prune) every inventory entry
  | 10  the module resolves through the operator's reported registry mapping
  | 11  strict re-render (that mapping, an isolated cache, the cluster Platform)
  |     reproduces the recorded digest        <- the only gate force may skip
  | 12  the record's generation is unchanged since gate 3
  v
one write: owner=operator, module and values restated, applier identity, prune intent
  |
  v
verdict (0006:D40): Ready for the new generation, same inventory entry set,
revision incremented, nothing pruned; failure is reported, never reverted
```

The flags in the first line are illustrative; the decisions fix what the user must state, not how the CLI spells it.

The operator side is a backstop, not a second chain. Before it registers a finalizer on an instance whose owner says `operator`, it refuses if the record carries the local-provenance marker or is the operator's own instance. The refusal is a stalled status with the reason; the operator applies, prunes and finalizes nothing. The CLI's digest gate stays the authority on render parity. The backstop exists for the flip no CLI gate saw.

Two experiments run beside the design and constrain decisions that stay open until they report:

- `experiments/01-provenance-digest-reachability/` measures which CLI render paths produce bytes that are not a registry artifact, whether the strict re-render catches a republished or unreachable coordinate, and whether a fetch from the CLI with the operator's mapping predicts the operator's own fetch.
- `experiments/02-applier-identity-and-field-transfer/` measures whether an access review over the recorded inventory predicts the operator's apply, including RBAC objects under escalation prevention. It also measures what server-side-apply field ownership looks like after the flip and the first operator reconcile.

## Schema / API Surface

No `opmodel.dev/core` definition changes, and the `ModuleInstance` CRD already carries every field the transfer writes: owner, module, values, applier service account and prune.

- **New report on the cluster Platform's status (D4).** The operator reports the module registry mapping it resolves with, beside the operator version it already reports there. It is additive and read-only for every client.
- **Operator adoption refusal (D5).** A new stalled reason on a `ModuleInstance` whose owner is `operator`. Its spelling is the operator's to choose; that it is a stalled status naming the reason is the contract.
- **Local-provenance marker (D6).** The existing annotation, `module-instance.opmodel.dev/source: local`, with a wider trigger. Its key and value are unchanged.
- **The transfer command (D1).** `opm instance handoff` returns as a CLI command. The user-facing inputs it requires are an applier service account and a prune intent (D3); `--force` keeps its old meaning, skipping only the digest comparison (D2).

## Affected Surfaces

- **cli.** `opm instance handoff` returns with the gate set in D2. Every render that is not a pure registry artifact carries the local marker (D6). Operator-owned thin edits keep refusing local renders as they do today (0006:D18). Docs that say no command moves an instance change with the command.
- **opm-operator.** The operator reports its effective module registry mapping on the cluster Platform's status (D4). It refuses to adopt a local-provenance instance, or its own instance, with a stated stalled reason and no finalizer (D5). The ownership spec's "flip adopts" requirement narrows to "flip adopts unless refused".
- **core.** Concept docs only: the page on who owns an instance says no command moves one, and that stops being true. No schema change.
- **enhancements (0014).** Export depends on this entry's gate set instead of citing the removed command (D7). The 0014 edit rides its own change.

## Before / After

The `grafana` example from `01-problem.md`, locally applied, then handed over.

| Step | Before | After |
| --- | --- | --- |
| Transfer of a local render | No command; a hand patch is accepted | `opm instance handoff grafana` refuses at gate 5: the render was local; publish, re-apply from the registry, then hand off |
| Hand patch of the owner field | Operator adopts, fetches registry bytes, applies as its own identity | Operator stalls with a stated reason: the render was local; nothing applied, no finalizer |
| Transfer after publishing and re-applying | No command | Gates 9 to 11 prove the named account can apply every entry and the operator's mapping reproduces the digest; one write; inventory-stable reconcile |
| Transfer with no applier named | Old command flipped anyway, instance stranded | Refused before any write: name the account the operator should apply as |
| Transfer of the operator's own instance (0028) | A hand patch makes the operator able to delete itself | Refused by the CLI at gate 4, and by the operator if patched by hand |
