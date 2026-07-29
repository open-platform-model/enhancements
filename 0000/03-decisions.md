# Design Decisions — {Enhancement Title}

This document records every significant design choice with its reasoning
and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they
are made. **Numbers are permanent** — never reused, never renumbered, because
other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** When a later decision reverses or
amends an earlier one, record it as its own `DN` while the design is in
motion, then weave it into the decision it changes at the next compaction
pass — the merged decision keeps the lower number, and the vacated number
keeps a one-line tombstone pointing at where its content went. This keeps the
log safe to read linearly: a reader who stops halfway should never come away
believing something a later entry already killed. Compaction is governed by
the `enhancement-compaction` skill; it never touches an `implemented` entry.

Each decision uses the same four-field shape: Decision, Alternatives
considered, Rationale, Source. The Source field is specific — `"User
decision YYYY-MM-DD"`, a URL, or a file path — so the provenance of a
choice never gets lost. A decision revised by a merge keeps its original
`Source:` and gains a `Revised: YYYY-MM-DD` line; *Alternatives considered*
always survives compaction, because it is what stops a rejected option being
re-litigated later.

---

## Decisions

### D1: {Decision Title}

**Decision:** {What was decided. State it as a fact, not a question.}

**Alternatives considered:**

- {Alternative A and why it was not chosen}
- {Alternative B and why it was not chosen}

**Rationale:** {Why this decision was made. Reference design goals,
constraints, prior art, or user input.}

**Source:** {Where the decision originated — user decision with date,
design discussion, external reference, or prior art.}

---

## Open Questions

Track unresolved questions surfaced during design. The validator (future)
requires this block (with or without entries) starting at `status:
accepted`, in either this file or `README.md`. Each entry should carry a
`Status:` line; close it with `resolved-by-D##`, `deferred-to-NNNN`, or
`answered` when the question resolves.

While a question is open, its bullet is a working surface — edit the wording,
sharpen the framing, add or drop alternatives freely. Numbers stay fixed
(`schemas/target.cue` marks gated fields with `// OQN:` and decisions cite
`resolves OQN`), but the prose is yours to change.

Once resolved, the bullet collapses to its question and its status — the
answer now lives in the decision it points at, and restating it here is how
this block grows into an unreadable second decision log. Collapsing happens
at the `draft → accepted` compaction pass, not by hand mid-design.

- **OQ1: {Short question}.** Status: open. {Context — what is unclear,
  what is blocked, what would resolve it.}
