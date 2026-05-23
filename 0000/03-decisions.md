# Design Decisions — {Enhancement Title}

This document records every significant design choice with its reasoning
and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they
are made. The log is **append-only** — never remove or renumber existing
entries. If a decision is reversed, add a new decision that supersedes it
(e.g. "D8 supersedes D3") and leave D3 in place as historical context.

Each decision uses the same four-field shape: Decision, Alternatives
considered, Rationale, Source. The Source field is specific — `"User
decision YYYY-MM-DD"`, a URL, or a file path — so the provenance of a
choice never gets lost.

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

- **OQ1: {Short question}.** Status: open. {Context — what is unclear,
  what is blocked, what would resolve it.}
