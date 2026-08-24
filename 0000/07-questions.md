# Open Questions — {Enhancement Title}

This is the entry's working question register. Track unresolved questions surfaced during design. The validator requires this file for every entry; the `## Open Questions` block below (with or without entries) is required starting at `status: accepted`. **This file is the single canonical location** — an `## Open Questions` block anywhere else in the entry fails `task vet`.

`OQ` numbers are permanent — never reused, never renumbered, because decisions (`**Resolves:** OQ4`), `// OQN:` markers in `schemas/`/`contracts/` CUE, and delivery-log entries in `delivery.yaml` (`resolves: [OQ9]`) cite them. A vacated number keeps a one-line tombstone.

Each entry carries a `Status:` line; close it with `resolved-by-D##`, `deferred-to-NNNN`, `deferred-to-implementation`, or `answered` when the question resolves.

Each **unresolved** entry also carries a `Blocking:` field saying whether the question gates acceptance:

| Value | Meaning |
| --- | --- |
| `acceptance` | `task promote` refuses while this question is open. Give the reason inline (`Blocking: acceptance — determines config.yaml.semver`). |
| `deferrable` | May stay open at `accepted`. |
| `implementation` | Handed to delivery; the change that settles it claims it via `resolves: [OQ9]` in `delivery.yaml`. |

This is where per-question blocking rules live. They used to be prose in a separate gate document, one cross-reference away from the question they governed; on the question itself they are visible to whoever answers it, and `task questions:open` and `task promote` can both read them.

`deferred-to-implementation` is the deferral register: an implementation-level question the design deliberately hands to whoever delivers it. Attach the context a future implementer needs (what is unclear, what evidence exists, what would settle it) — but never name the inheritor: the change that picks it up claims it in this entry's `delivery.yaml` log entry (`resolves: [OQ9]`), and `task delivery:deferred` reports deferred questions no logged change has claimed. Contract-level questions cannot be deferred this way — they must be resolved before `accepted`.

While a question is open, its bullet is a working surface — edit the wording, sharpen the framing, add or drop alternatives freely. Numbers stay fixed (`schemas/target.cue` marks gated fields with `// OQN:` and decisions cite `resolves OQN`), but the prose is yours to change.

Once resolved, the bullet collapses to its question and its status — the answer now lives in the decision it points at (in `03-decisions.md`), and restating it here is how this register grows into a second decision log. Collapsing happens at the `draft → accepted` compaction pass, not by hand mid-design.

## Open Questions

- **OQ1: {Short question}.** Status: open. Blocking: {acceptance — why this gates promotion | deferrable | implementation}. {Context — what is unclear,
  what is blocked, what would resolve it.}
