# Open Questions: Self-Describing Modules

**This file is the single canonical location for Open Questions.** An `## Open Questions` block anywhere else in the entry fails `task vet`. This is the entry's working question register: track unresolved questions surfaced during design.

`OQ` numbers are permanent, never reused, never renumbered, because decisions (`**Resolves:** OQ4`), `// OQN:` markers in `schemas/` CUE, and delivery-log entries in `delivery.yaml` (`resolves: [OQ9]`) cite them. A vacated number keeps a one-line tombstone.

Each entry carries a `Status:` line; close it with `resolved-by-D##`, `deferred-to-NNNN`, `deferred-to-implementation`, or `answered` when the question resolves. Each **unresolved** entry also carries a `Blocking:` field: `acceptance` (with the reason inline; `task promote` refuses while open), `deferrable` (may stay open at `accepted`), or `implementation` (handed to delivery; the change that settles it claims it via `resolves` in `delivery.yaml`). Contract-level questions cannot be deferred to implementation.

While a question is open, its bullet is a working surface: edit the wording, sharpen the framing, add or drop alternatives freely. Once resolved, the bullet collapses to its question and its status at the `draft → accepted` compaction pass.

**OQ1 to OQ12 and OQ16 belong to entry 0027**, under the same numbers, so a citation of `0025 OQ7` resolves by changing only the entry id. OQ13 to OQ15 are the live questions here.

## Open Questions

- **OQ1: What is the kind name of the platform-owned definition object?** Status: deferred-to-0027, same number.

- **OQ2: Does the binding layer ship as a product on its own, or only as an implementation slice of the kind layer?** Status: deferred-to-0027, same number.

- **OQ3: What is the update-policy vocabulary on a definition, what is its default, and what does each value do to live instances?** Status: deferred-to-0027, same number.

- **OQ4: May a definition serve two module majors at once, and if so how do instances move between them?** Status: deferred-to-0027, same number.

- **OQ5: What is the status contract of a served-kind instance?** Status: deferred-to-0027, same number.

- **OQ6: Is `#config` structural-ness also gated at publish time?** Status: deferred-to-0027, same number.

- **OQ7: Is the projected `ModuleInstance` a real object in the cluster, or in-memory only?** Status: deferred-to-0027, same number.

- **OQ8: What is the tenant guardrail, and how does tenancy map through the projection?** Status: deferred-to-0027, same number.

- **OQ9: Do `#config` defaults become CRD defaults?** Status: deferred-to-0027, same number.

- **OQ10: May a definition bind values the consumer never sees, and is the served schema `#config` minus the bound fields?** Status: deferred-to-0027, same number.

- **OQ11: What happens to a definition's deletion, and to its instances, when instances exist?** Status: deferred-to-0027, same number.

- **OQ12: Who installs the served CRD: the operator at runtime, or rendered output the platform applies?** Status: deferred-to-0027, same number.

- **OQ13: How does a declaration-only module trait state its fulfilment?** Status: open. Blocking: acceptance: `fulfilment` is contract on the trait and the inventory (D14) reads it. The offering declaration in entry 0027 and the lifecycle trait in entry 0009 are consumed outside the render path, by the CLI, a reconciler and the execution half, and no transformer ever handles them. `"catalog"` claims the declaring catalog implements it, which is false; `"provider"` demands exactly one platform transformer, which is worse. Candidates: a third value naming a non-render consumer, or `optional: bool | *true` with `"catalog"` and a rule that the inventory does not count a trait no module transformer in the same catalog requires. The first is honest and adds a value to a vocabulary 0010 D32 fixed; the second reuses what exists and leaves the falsehood in the field.

- **OQ14: Does `#ctx` gain an `aspects` projection beside `components`?** Status: open. Blocking: deferrable. `#ctx.components` exists so a component's spec can reference another component's computed names. No module trait this entry's fixtures declare needs an aspect's `resourceName` from elsewhere in the module, and `#ctx` is open, so the projection can be added later without breaking a module body. Add it when a trait needs it, not before.

- **OQ15: Does `#ModuleInstance` get an aspect slot of its own?** Status: open. Blocking: deferrable. Instance-scoped operational intent (suspend, pause, a maintenance window) is plausibly an attachment on the instance rather than the module. The candidate answer is no for this entry: aspects describe the module; what an instance does is 0009's, which attaches at the instance's transitions. Recorded so the boundary is stated rather than assumed.

- **OQ16: May the `offering` trait carry suggested bound values the platform definition inherits?** Status: deferred-to-0027, same number.
