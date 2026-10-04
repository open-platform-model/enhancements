# Design: Gated Ownership Transfer from CLI to Operator

A transfer command returns, with the old gate chain plus the two checks whose absence removed it: who applies, and whether the operator can reach the module. The CLI proves who applies before it writes; the operator proves it can fetch and reproduce the render before it adopts. The operator also refuses on its own, so a hand edit cannot do what the command refuses. Trade-offs live in `03-decisions.md`.

## Design Goals

- A CLI-owned instance can be handed to the operator with one command, and the operator's first reconcile adopts exactly what is running: same inventory, the same render, nothing pruned, nothing recreated.
- A transfer that would strand the instance refuses before the operator touches anything, naming what is missing. Stranding covers an applier that cannot apply, a module the operator cannot fetch, and a render the registry does not reproduce.
- The identity the operator applies as, and whether it prunes, are stated by the user at transfer and recorded on the instance. Nothing is inferred.
- The operator refuses to adopt an instance whose render it cannot reproduce, an instance whose render was local, or the instance that deploys the operator itself, whichever way its owner field came to say `operator`.
- After a transfer, the operator alone manages the instance's objects, so a later module version can remove what it no longer sets.
- One gate set serves every path that moves an instance's management away from the CLI. Export (0014) reuses it rather than restating it.

## Non-Goals

- **A reverse transfer.** Operator to CLI stays out of scope, as 0006:D16 decided. A stalled transfer is repaired forward: fix the applier's rights, and the operator's next reconcile proceeds.
- **Private registry credentials.** The operator presents none today, so the operator's own fetch at adoption is the whole of what a transfer can prove. Credential plumbing is its own design.
- **Creating the applier account or its RBAC.** The transfer proves an identity can apply; it does not grant rights. Whether a helper should emit them is OQ6.
- **Transferring the operator's own instance.** 0028 keeps it CLI-owned forever, and this entry refuses it at both ends.
- **GitOps export.** 0014 owns the exported tree; this entry owns only the shared gates.
- **Pinning module content after the transfer.** The transfer verifies what a tag serves at transfer time; what the operator renders after a later cache miss is OQ9.

## High-Level Approach

The transfer is a sequence of refusals, one conditional write, an adoption check by the operator, a verdict, and a release of the CLI's field ownership.

```text
opm instance handoff <name> --service-account <sa> --prune=<bool>
  |
  |  CLI gates, cheapest first; any refusal writes nothing
  |  1  cluster gates (CRDs, field floor, operator version ceiling)
  |  2  operator installed and ready
  |  3  record exists and is CLI-owned
  |  4  not the operator's own instance (0028; fixed name and namespace)
  |  5  no local-provenance marker
  |  6  complete published coordinate
  |  7  no skipped contracts
  |  8  a recorded render digest
  |  9  the named identity can apply (and prune) every recorded entry,
  |     escalation rules for roles and bindings included
  | 10  the running operator performs the adoption check
  | 11  strict re-render (registries only, isolated cache, the cluster
  |     Platform) reproduces the recorded digest   <- the only gate force may skip
  | 12  the same review for any entry the render adds to the inventory
  | 13  the record is unchanged except the operator's status conditions
  |     (a condition on the write)
  v
one conditional write: owner=operator, module and values restated,
  applier identity, prune intent, the digest the operator must reproduce
  |
  v
operator, before any finalizer:
  marker or own instance?               -> stalled, nothing applied (D5)
  CLI-applied record or stated digest?  -> render via its own registries:
    cannot render yet (registry, Platform) -> retry, nothing applied
    module not found, or digest differs    -> stalled, nothing applied (D4)
  |
  v  adopt: finalizer, apply as the named account
verdict: Ready for the written generation, same entry set, revision
  incremented, nothing pruned, the operator's digest == the stated one;
  failure is reported, never reverted
  |
  v
release: the CLI's field manager lets go of every field on every object (D8)
```

The flags in the first line are illustrative; the decisions fix what the user must state, not how the CLI spells it.

The operator side has two parts. The backstop (D5) refuses a marked instance and the operator's own instance before any render. The adoption check (D4) renders the instance through the operator's own registries and compares the digest to the one the transfer stated, or for a hand flip to the one the CLI recorded. Both run before the finalizer, so a refused instance is still as easy to delete or hand back as a CLI-owned one.

### What the experiments changed

Both experiments have concluded and are cited from the decisions they constrain.

- **The registry-mapping report was dropped (D4).** [`experiments/01-provenance-digest-reachability/`](experiments/01-provenance-digest-reachability/) showed the operator's mapping names hosts only the cluster network resolves, and that a coordinate two registries serve differently passes every CLI gate and then swaps bytes silently. The same experiment showed the CLI can predict the operator's render digest exactly, by rendering with the operator's runtime name. The reverse, the operator matching a digest the CLI recorded under its own name, was not measured and cannot match while both digests include the runtime name; D4 depends on 0012:D6 for it, and until that lands the operator digests a render stamped with the CLI's runtime name instead. So the operator checks its own render at adoption. This moves the reachability refusal after the owner write, which OQ8 puts to the owner.
- **The verdict gained a digest check (D2).** The old inventory-stable verdict scored two broken adoptions as success in experiment 01: a hybrid object and a silent swap.
- **The isolated verification cache is required (D2).** With a warm cache the verification passed a republished tag; with a fresh one it refused. A cold verification of a one-object module took about 3 seconds.
- **The access review models RBAC escalation (D3).** [`experiments/02-applier-identity-and-field-transfer/`](experiments/02-applier-identity-and-field-transfer/) showed a review of the apply verbs alone passes a role the operator's apply is then refused for escalation. With escalation modelled, the prediction matched the operator in every case. The operator names only the first refused object, so the transfer reports the full table.
- **The write is conditional (D2).** A stale flip silently reverted a concurrent apply; a write conditioned on the record version the gates read was refused instead.
- **The CLI releases its field ownership after the verdict (D8).** After a flip the CLI co-owned every field, and a field later dropped from the module stayed on the object while the operator reported Ready.
- **The local marker's property was confirmed (D6).** A module copied into the instance's own package rendered without a marker and was caught only by the digest.

## Schema / API Surface

No `opmodel.dev/core` definition changes. The `ModuleInstance` CRD already carries the owner, module, values, applier service account and prune fields the transfer writes.

- **The digest the operator must reproduce (D4).** The transfer's write states it on the instance's record. Whether it is a spec field or an annotation is the repos' choice; a new spec field would be an additive CRD change. Its lifetime is a contract (D4 R12, R13): it binds one adoption and is consumed by it.
- **Which actor recorded the status (D4 R10).** The operator must be able to tell an inventory and digest the CLI recorded from ones it recorded itself. Whether an existing field already says so or a new one does is the repos' choice.
- **Operator adoption refusals (D4, D5).** New stalled reasons on a `ModuleInstance` whose owner is not `cli`: a render that does not reproduce the expected digest or does not resolve, a local-provenance marker, and the operator's own instance. Their spelling is the operator's to choose; that each is a stalled status naming the reason, with no finalizer, is the contract.
- **Local-provenance marker (D6).** The existing annotation, `module-instance.opmodel.dev/source: local`, with a wider trigger. Its key and value are unchanged.
- **The transfer command (D1).** `opm instance handoff` returns as a CLI command. The user-facing inputs it requires are an applier service account and a prune intent (D3); `--force` keeps its old meaning, skipping only the CLI's digest comparison (D2).

## Affected Surfaces

- **cli.** `opm instance handoff` returns with the gate set in D2, the access review of D3, the conditional write, the verdict with the digest check, and the field release of D8. Every render that is not a pure registry artifact carries the local marker (D6). Operator-owned thin edits keep refusing local renders as they do today (0006:D18). Docs that say no command moves an instance change with the command.
- **opm-operator.** Before adopting an instance whose owner is not `cli`, the operator refuses a marked instance or its own instance (D5), and, for a record the CLI applied or a transfer stated a digest for, renders and compares the digest (D4), all before the finalizer. The ownership spec's "flip adopts" requirement narrows to "flip adopts unless refused".
- **core.** Concept docs only: the pages on who owns an instance and on modules and instances say no command moves one, and that stops being true. No schema change.
- **opm.** Site pages that promise no command moves an instance and that the CLI never changes an owner: what OPM is, what OPM does not do, OPM for Kubernetes users, and the glossary's owner entry (06-operational.md lists them).
- **enhancements (0014).** Export depends on this entry's gate set instead of citing the removed command (D7). The 0014 edit rides its own change.
- **enhancements (0028).** 0028:D5's rationale points at an operator report of its registry mapping that this entry designed and then dropped (D4). The edit to that rationale is 0028's.

## Before / After

The `grafana` example from `01-problem.md`, locally applied, then handed over.

| Step | Before | After |
| --- | --- | --- |
| Transfer of a local render | No command; a hand patch is accepted | `opm instance handoff grafana` refuses at gate 5: the render was local; publish, re-apply from the registry, then hand off |
| Hand patch of the owner field | Operator adopts, fetches registry bytes, applies them over the local ones, reports Ready | Operator stalls with a stated reason: the render was local, or its render does not reproduce what the CLI applied; nothing applied, no finalizer |
| Transfer after publishing and re-applying | No command | Gates 9 and 11 prove the named account can apply every entry and the registry reproduces the digest; one write; the operator reproduces the same digest; inventory-stable reconcile; the CLI lets go of its fields |
| Transfer when only the CLI's registry has the module | Old command flipped; the operator failed resolution and the instance stranded | One write, then the operator refuses the adoption with the reason and touches nothing; the owner can be set back by hand (OQ8) |
| Transfer with no applier named | Old command flipped anyway, instance stranded | Refused before any write: name the account the operator should apply as |
| Transfer of the operator's own instance (0028) | A hand patch makes the operator able to delete itself | Refused by the CLI at gate 4, and by the operator if patched by hand |
