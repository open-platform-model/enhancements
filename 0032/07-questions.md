# Open Questions: The Operator Becomes the Controller

**This file is the single canonical location for Open Questions.** An `## Open Questions` block anywhere else in the entry fails `task vet`. This is the entry's working question register: track unresolved questions surfaced during design. The validator requires this file for every entry; the `## Open Questions` block below (with or without entries) is required starting at `status: accepted`.

`OQ` numbers are permanent, never reused, never renumbered, like `DN` and `DN:Rn`, because decisions (`**Resolves:** OQ4`), `// OQN:` markers in `schemas/`/`contracts/` CUE, and delivery-log entries in `delivery.yaml` (`resolves: [OQ9]`) cite them. A vacated number keeps a one-line tombstone.

Each entry carries a `Status:` line; close it with `resolved-by-D##`, `deferred-to-NNNN`, `deferred-to-implementation`, or `answered` when the question resolves.

Each **unresolved** entry also carries a `Blocking:` field saying whether the question gates acceptance:

| Value | Meaning |
| --- | --- |
| `acceptance` | `task promote` refuses while this question is open. Give the reason inline (`Blocking: acceptance: determines config.yaml.semver`). |
| `deferrable` | May stay open at `accepted`. |
| `implementation` | Handed to delivery; the change that settles it claims it via `resolves: [OQ9]` in `delivery.yaml`. |

This is where per-question blocking rules live. They used to be prose in a separate gate document, one cross-reference away from the question they governed. On the question itself, they are visible to whoever answers it, and `task questions:open` and `task promote` can both read them.

`deferred-to-implementation` is the deferral register: an implementation-level question the design deliberately hands to whoever delivers it. Attach the context a future implementer needs (what is unclear, what evidence exists, what would settle it), but never name the inheritor. The change that picks it up claims it in this entry's `delivery.yaml` log entry (`resolves: [OQ9]`), and `task delivery:deferred` reports deferred questions no logged change has claimed. Contract-level questions cannot be deferred this way: they must be resolved before `accepted`.

While a question is open, its bullet is a working surface: edit the wording, sharpen the framing, add or drop alternatives freely. Numbers stay fixed (`schemas/target.cue` marks gated fields with `// OQN:` and decisions cite `resolves OQN`), but the prose is yours to change.

Once resolved, the bullet collapses to its question and its status. The answer now lives in the decision it points at (in `03-decisions.md`); restating it here is how this register grows into a second decision log. Collapsing happens at the `draft → accepted` compaction pass, not by hand mid-design.

## Open Questions

- **OQ1: Do the controller's objects keep the name prefix `opm-controller-` under the namespace `opm-system`?** Status: open. Blocking: acceptance: the prefix is part of every object name 0032:D1 publishes. The owner confirmed the Deployment and ServiceAccount name `opm-controller-manager` and the namespace `opm-system` on 2026-10-09. The prefix for the other objects (the roles and role bindings, cluster-scoped ones among them, and the metrics Service) was decided on 2026-10-05 together with the namespace `opm-controller-system`, and was not asked again when the namespace changed. Candidates: (a) keep `opm-controller-` for every object, which 0032:D1 states now; (b) a shorter prefix such as `opm-` inside `opm-system`, which would rename the confirmed Deployment and ServiceAccount; (c) no prefix on namespaced objects and `opm-controller-` on cluster-scoped ones only, which would rename them too. What would settle it: the owner's answer. Cluster-scoped objects need a prefix that names the component, and the confirmed workload name already carries it, which favours (a).
