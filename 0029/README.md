# Enhancement 0029: Gated Ownership Transfer from CLI to Operator

An instance deployed by the OPM command-line tool (the CLI) cannot safely be handed to the OPM operator today. The old command stranded instances under an identity that could not apply them. This entry brings the command back with gates that prove the operator can fetch, render and apply exactly what runs, and makes the operator refuse unsafe adoptions itself.

All entries: [INDEX.md](../INDEX.md). How this one relates to others: [GRAPH.md](../GRAPH.md). Metadata: [config.yaml](config.yaml).

## Summary

**The transfer command returns, forward only (D1).** `opm instance handoff` moves a CLI-owned instance to the operator, never back, as entry 0006 decided (0006:D16).

**Twelve gates must pass before anything is written (D2).** They include a module the operator can fetch, a re-render that reproduces the recorded fingerprint of what was applied, and an unchanged record. Success means the operator reconciled with the same set of resources and pruned nothing (0006:D40).

**The user names who applies (D3).** The transfer requires a service account and a prune choice, and asks the cluster whether that account can apply every recorded resource.

**The operator says where it fetches modules (D4).** It reports its registry mapping on the cluster Platform, the cluster-wide settings object it owns, so the CLI checks reachability with the operator's mapping.

**The operator refuses unsafe adoptions (D5, D6).** It will not adopt a locally rendered instance or the instance that runs the operator, so a hand edit cannot bypass the gates. Every render not wholly from a registry is marked local.

**Export reuses these gates (D7).** Entry 0014 depends on them.

<!--
Do NOT add an implementation-status block here. Whether this design has been
delivered is DERIVED from this entry's `delivery.yaml` log: run `task delivery ID=NNNN`. A
status block written here is a snapshot that goes stale the moment another change
lands, which is exactly the drift the implementation axis was removed to stop.
-->

## How it works

```mermaid
flowchart LR
    user["User names applier account and prune choice"] --> gates
    record["Instance record: coordinate, values, digest, inventory"] --> gates
    report["Operator's registry mapping on the Platform status"] --> gates
    registry["Registry"] --> gates
    gates["CLI gate chain, cheapest first"] -->|"any refusal"| untouched["Record untouched, reason and remedy shown"]
    gates -->|"all pass"| write["One write: owner operator, applier, prune"]
    write --> backstop["Operator backstop: local or self instance?"]
    backstop -->|"yes"| stalled["Stalled with reason, no finalizer"]
    backstop -->|"no"| adopt["Operator adopts: same resources, nothing pruned"]
```

The CLI does the expensive proof: it reads the record, asks the cluster about the named account, and re-renders the module through the operator's own registry mapping. Only when every gate passes does it write once. The operator's backstop runs on every adoption, including one a person made by editing the owner field by hand, which is why it refuses on its own.

## Documents

1. [01-problem.md](01-problem.md): why the old transfer was removed, and what a hand flip of the owner field does today
1. [02-design.md](02-design.md): the gate chain, the operator backstop, and the before/after for one locally developed module
1. [03-decisions.md](03-decisions.md): the decision log, D1 to D7
1. [04-graduation.md](04-graduation.md): what must hold before `draft` becomes `accepted`
1. [05-risks.md](05-risks.md): risks, drawbacks, alternatives not taken
1. [06-operational.md](06-operational.md): rollout, versioning, rollback, cross-repo ordering
1. [07-questions.md](07-questions.md): the open-questions register, OQ1 to OQ7

[`experiments/`](experiments/) holds two runnable checks: whether local renders are marked and remote fetches predicted correctly, and whether an access review predicts the operator's apply and what field ownership looks like after the flip.

## Scope

### In scope

- A forward-only CLI command that transfers a CLI-owned instance to the operator.
- The gate set every transfer runs, including applier identity and operator-side reachability.
- Recording the applier account and prune choice on the instance at transfer.
- The operator reporting its module registry mapping on the cluster Platform.
- The operator refusing to adopt a locally rendered instance or its own instance.
- Marking every non-registry render as local.

### Out of scope

- Not a reverse transfer from operator to CLI, and not the GitOps export of entry 0014.
- Transferring the operator's own instance, which entry 0028 keeps CLI-owned forever.
- Registry credentials for the operator; transfers verify what an anonymous fetch reaches.
- Creating the applier account or its RBAC (an open question, not a decision).

## Deviations from Design

None at this stage. Update this section when implementation lands and any deliberate divergences from the design need to be documented.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| [`../archive/0006/03-decisions.md`](../archive/0006/03-decisions.md) | The original transfer (D7), forward-only rule (D16), local provenance (D38) and success criterion (D40) this entry amends or rests on |
| [`../0028/`](../0028/) | The operator as an OPM module; defines the operator's own instance this entry refuses to transfer |
| [`../0014/`](../0014/) | Export to GitOps, which reuses this entry's gate set |
| [`../0012/03-decisions.md`](../0012/03-decisions.md) | D6, the runtime-neutral render digest that OQ5 waits on |
| `cli/openspec/changes/archive/2026-08-31-remove-instance-handoff/` | Why the first transfer command was removed |
| `cli/openspec/changes/archive/2026-07-20-cli-instance-handoff/` | The first transfer command's design and gate chain |

<!--
## Agent Instructions

To create a new enhancement, run `task new` rather than copying this directory by
hand; it picks the next id, fills `config.yaml`, substitutes the title and seeds
the out-of-scope boundary from your `NOT=` answer.

Then:

1. Overwrite every `{Capitalised}` placeholder across this README and the seven
   split documents. `task vet` fails while one remains.
2. Keep the README in plain English. Say "where it came from" not "provenance",
   "the fields a user sees" not "the surface", "turned into" not "projected".
   Keep the OPM nouns (Module, Component, Resource, Trait, Blueprint, Platform,
   Transformer, Catalog) and define each on first use.
3. Write `01-problem.md` and `02-design.md` first, in full prose. Decisions
   accrete in `03-decisions.md` as choices get settled; `05-risks.md` and
   `06-operational.md` mature alongside them.
4. Replace the `## How it works` diagram with this entry's own mechanism. Load
   the `enhancement-diagrams` skill before drawing it.
5. If the enhancement adds or changes `opmodel.dev/core` definitions
   (`config.yaml.core_schema: true`), sketch the delta in `schemas/target.cue`;
   `examples.cue` and `spec.md` are required before `draft → accepted`.
   Otherwise there is no `schemas/`, and non-core compilable CUE goes in
   `contracts/` via `task new:contracts ID=NNNN`.
6. Do not strip these HTML-comment Agent Instructions when copying. They are the
   in-template guidance for the next author.

The workflow protocol lives in the `enhancements` skill, not here: status
lifecycle, decision-body mutability, compaction, experiments, research and the
delivery log are all documented there and in `CLAUDE.md`. This template holds
only the shape of an entry README.
-->
