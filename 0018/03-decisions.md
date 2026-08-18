# Design Decisions — Documentation Architecture

This document records every significant design choice with its reasoning
and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they
are made. **Numbers are permanent** — never reused, never renumbered, because
other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** How that stays true depends on the entry's `status`:

- While the entry is **`draft`**, decisions are living text: a changed choice is an **in-place edit** to the existing `DN`, and the log never contains two conflicting decisions. If the replaced position was backed by real evidence (an experiment outcome, an explicit user decision), fold it into *Alternatives considered* — marked as previously adopted — before overwriting; a mere sketch may be replaced outright. A decision retracted outright keeps its number as a one-line tombstone (`### DN: (retracted, YYYY-MM-DD)`).
- Once **`accepted`**, decision bodies are **protected**. A change lands as a *new* `DN` with `**Amends:**` / `**Supersedes:**` relation fields; existing bodies are edited only through the `enhancement-compaction` skill, which weaves stacked reversals into the decisions they reverse (lower number survives, vacated number keeps a tombstone) — at latest in the mandatory pass immediately before the `implemented` flip.
- **`implemented`** entries are frozen; **`superseded`** entries are stubbed via compaction.

Either way the log stays safe to read linearly: a reader who stops halfway should never come away believing something a later entry already killed.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source. The Source field is specific — `"User decision YYYY-MM-DD"`, a URL, or a file path — so the provenance of a choice never gets lost. A decision revised in place or by a merge keeps its original `Source:` and gains a `Revised: YYYY-MM-DD` line; *Alternatives considered* always survives revision and compaction, because it is what stops a rejected option being re-litigated later.

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
