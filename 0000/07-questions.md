# Open Questions — {Enhancement Title}

This is the entry's working question register. Track unresolved questions surfaced during design. The validator requires this file for every entry; the `## Open Questions` block below (with or without entries) is required starting at `status: accepted`. **This file is the single canonical location** — an `## Open Questions` block anywhere else in the entry fails `task vet`.

`OQ` numbers are permanent — never reused, never renumbered, because decisions (`**Resolves:** OQ4`), `// OQN:` markers in `schemas/`/`contracts/` CUE, and delivery plans (`resolves: ["NNNN:OQ9"]`) cite them. A vacated number keeps a one-line tombstone.

Each entry carries a `Status:` line; close it with `resolved-by-D##`, `deferred-to-NNNN`, `deferred-to-implementation`, or `answered` when the question resolves.

`deferred-to-implementation` is the deferral register: an implementation-level question the design deliberately hands to whoever delivers it. Attach the context a future implementer needs (what is unclear, what evidence exists, what would settle it) — but never name the inheritor: the slice that picks it up claims it from the plans side (`resolves: ["NNNN:OQ9"]`), and `task plans:deferred` reports deferred questions no slice has claimed. Contract-level questions cannot be deferred this way — they must be resolved before `accepted`.

While a question is open, its bullet is a working surface — edit the wording, sharpen the framing, add or drop alternatives freely. Numbers stay fixed (`schemas/target.cue` marks gated fields with `// OQN:` and decisions cite `resolves OQN`), but the prose is yours to change.

Once resolved, the bullet collapses to its question and its status — the answer now lives in the decision it points at (in `03-decisions.md`), and restating it here is how this register grows into a second decision log. Collapsing happens at the `draft → accepted` compaction pass, not by hand mid-design.

## Open Questions

- **OQ1: {Short question}.** Status: open. {Context — what is unclear,
  what is blocked, what would resolve it.}
