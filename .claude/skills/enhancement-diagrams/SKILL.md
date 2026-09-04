---
name: enhancement-diagrams
description: When and how to reach for a diagram while designing an OPM enhancement — Mermaid for relationship/dependency graphs between enhancements, ASCII for how a single enhancement's design/mechanism actually works. Load before sketching a diagram during an Open-Questions walk or general design discussion, before adding a diagram to 01-problem.md/02-design.md/05-risks.md, or when unsure which medium a diagram calls for.
user-invocable: true
---

# Enhancement Diagrams

Enhancement design discussion is full of things worth drawing: how a new entry relates to the
thirteen others already in the graph, how a deletion protocol's inputs resolve to a verdict, what
a layered architecture looks like once a rung is removed. None of that currently happens by
default — no enhancement document in this repo has ever carried a hand-authored diagram, and
neither `enhancement-open-questions` nor the main `enhancements` skill mentions one. This skill
exists to make reaching for a diagram the default move at the right moments, not an afterthought.

## The core split

> **Mermaid is for relationships between enhancements. ASCII is for how a single
> enhancement's design/mechanism works. Medium follows content shape — never a blanket default,
> and never swapped for the other.**

The two categories are not a style preference; they map onto genuinely different content:

- A **relationship** question has enhancements or entries as its nodes and
  `depends_on`/`supersedes`/`revives` as its edges. This is exactly what `GRAPH.md` (cross-entry)
  already renders as generated Mermaid. Mermaid is a natural fit because that is what it's
  for: named nodes, directed edges, `classDef`-based coloring. A `depends_on` edge is earned,
  not sketched into being: it exists iff a decision in one entry carries a `**Depends:**` line
  naming a decision in the other.
- A **design/mechanism** question has functions, data, states, or components as its nodes —
  how a deletion protocol resolves, how a rung ladder architecture is layered, how a request
  flows through a pipeline. This is what `enhancements/0012/02-design.md` already draws by hand,
  in ASCII, three times over (a layered rung diagram, a data-flow diagram, an integration-points
  mapping) — the existing house style for this content, consistent with the workspace's
  `openspec-explore`/`openspec-onboard` skills ("Visualize freely... ASCII diagrams liberally").

## When this skill applies

Load this skill when any of the following is true:

- You are walking an enhancement's Open Questions (`enhancement-open-questions` is loaded) and an
  OQ concerns either category above.
- You are in Phase 2 (Iterate) of the `enhancements` workflow, discussing `02-design.md`'s
  High-Level Approach, Schema/API Surface, Integration Points, or Before/After with the user.
- You are weighing a `depends_on`/`supersedes` edge, or whether to split or merge
  enhancements, before committing the edit to `config.yaml`.
- You are unsure which medium a diagram calls for — re-read `## The core split` above before
  drawing anything.

Skip this skill when the diagram question is already answered by a *generated* file — if
`GRAPH.md` already shows what's being asked, point at it (regenerating via
`task graph` if it's stale) rather than hand-drawing a duplicate.

## Reaching for a diagram

A concrete trigger list, so this is a default reflex rather than a vague encouragement:

| Question shape | Reach for | Example |
| --- | --- | --- |
| Should this entry `depends_on`/`supersedes` another? | Mermaid relationship sketch | "If 0013 supersedes 0007, does the graph still make sense with 0005 still pointing at 0007?" |
| Should we split this enhancement into two, or merge two into one? | Mermaid relationship sketch, before/after | Visualize the graph both ways before deciding. |
| How does this layered architecture fit together? | ASCII layered diagram | `0012`'s rung ladder (kernel emits → decides → acts → owns the CR). |
| How does data flow through this pipeline / protocol? | ASCII flow diagram | `0012`'s deletion protocol (inputs → `DeletionPlan()` → verdict). |
| What does this look like before vs. after the change? | ASCII side-by-side | `02-design.md ## Before / After`. |
| How do the touched repos' new packages depend on each other? | ASCII component mapping | `02-design.md ## Integration Points`. |

## Relationships → Mermaid

Sketch it **live, inline in the chat response** — no tool call needed at typical size. Reuse the
exact `classDef` palette already defined in `Taskfile.yml`'s `graph` task (entry status), so the
live preview looks like what the regenerated file will actually contain once the edit lands:

```
classDef draft       fill:#fef3c7,stroke:#b45309,color:#000
classDef accepted    fill:#dbeafe,stroke:#1d4ed8,color:#000
classDef rejected    fill:#fee2e2,stroke:#b91c1c,color:#7f1d1d,stroke-dasharray:4 2
classDef superseded  fill:#e5e7eb,stroke:#6b7280,color:#6b7280
classDef legacy      fill:#fafafa,stroke:#9ca3af,color:#6b7280,stroke-dasharray:3 3
```

This is a genuinely new capability, not a restatement of what already exists: today `GRAPH.md`
only exists *after* `task graph` runs against already-committed data.
A live sketch lets the user see the shape of a *proposed* edge or split — "what would the graph
look like if 0013 superseded 0007 instead of merely depending on it?" — before touching
`config.yaml` at all. Once the relationship decision is actually made, it is
encoded there and the real file is regenerated; the live sketch was scaffolding for the
conversation, not a new artifact to maintain. Never hand-edit `GRAPH.md` to match a
sketch — it carries a "do not edit by hand" header for a reason.

## Design/mechanism → ASCII

Plain fenced code blocks, no language tag — matching `0012` and `hatch/DESIGN.md` precedent.
Two contrasting real examples from `0012/02-design.md` show the craft difference that matters:

- **Lines 80-94, the deletion-protocol data flow** — simple columns and `──▶` arrows. Cheap to
  edit: shifting a label doesn't require re-counting anything.
- **Lines 28-43, the rung ladder** — a fully bordered box, already 73 characters wide. Fragile:
  any edit to the text inside risks breaking the border alignment, and nothing catches that
  automatically.

**Prefer the first style whenever the diagram is likely to be revised** — arrows and columns, not
borders. If a bordered box is genuinely the right shape (it groups things visually in a way arrows
can't), fix one column width up front and reuse it for every row rather than hand-fitting text to
a border line by line, and re-verify alignment after any edit.

Beyond that:

- **One concept per diagram** — same discipline as one concept per experiment. If you're drawing
  two things at once, split it.
- **Never bare.** Every diagram is paired with a sentence or two of prose — the diagram shows the
  shape, the prose says what to take from it.
- **Small.** A diagram that needs a legend to stay readable is a sign to split it, not to add a
  legend.

## Live, during discussion

For either medium, produce the diagram directly inline in the chat response — no `Artifact` call
needed at typical size, for either ASCII or Mermaid. Escalate to the `Artifact` tool only when the
user wants something kept or revisited across a long session, or a diagram has genuinely grown too
large for a plain chat fence to stay readable — ask before switching presentation; don't assume
the user wants a rendered page just because a diagram exists.

## Persisting into documents

Design/mechanism ASCII diagrams belong in:

- `01-problem.md ## Concrete Example` — current-state architecture, when a picture makes the gap
  obvious faster than prose.
- `02-design.md ## High-Level Approach` / `## Schema / API Surface` / `## Integration Points` /
  `## Before / After` — target-state architecture, data flow, component mapping.
- `05-risks.md ## Alternatives` — sparingly, illustrating the shape of a rejected alternative when
  the shape itself is the reason it was rejected.

**Never in `03-decisions.md`.** The decision log's four-field format (Decision / Alternatives
considered / Rationale / Source) is deliberately compact and text-only — see the main
`enhancements` skill. If a decision needs to point at a diagram, reference the section of
`02-design.md` that carries it; don't embed one in the decision body.

Relationship Mermaid sketches are not persisted by hand anywhere — see `## Relationships →
Mermaid` above. The generated `GRAPH.md` is the only committed artifact for
that category.

## Anti-patterns

- **Using Mermaid for a design/mechanism diagram, or ASCII for an entity-relationship graph.**
  The swap in either direction is exactly what this skill exists to prevent. If you're not sure
  which category a diagram is, re-read `## The core split`.
- **A bare diagram with no surrounding prose.** The reader needs to be told what to take from it,
  not left to reverse-engineer the point.
- **One diagram trying to cover two concepts.** Split it — a reader who needs to hold two ideas in
  frame at once will hold neither.
- **A bordered ASCII diagram whose alignment silently drifted after an edit.** If you touched the
  text inside a bordered box, re-check every row's width before presenting it.
- **A diagram in `03-decisions.md`.** Keep the decision log text-only; point at `02-design.md`.
- **Hand-editing `GRAPH.md` to match a live sketch.** It is generated; encode the
  decision in `config.yaml` and regenerate instead.
- **Treating a diagram as optional decoration rather than the fastest way to answer the question
  on the table.** If the user is asking "how does X relate to Y" or "how does this flow," a
  diagram is very often the actual answer — prose describing a picture is a worse picture.

## Where things live

| Artefact | Path | Authority |
| --- | --- | --- |
| Relationship diagrams (generated) | `enhancements/GRAPH.md` | Generated by `task graph`. Never hand-edited. Live sketches during discussion should visually match it. |
| Mermaid `classDef` palette (entry status) | `enhancements/Taskfile.yml :: graph` | Source of the status palette to reuse in a live relationship sketch. |
| Design/mechanism diagrams (hand-authored) | `enhancements/NNNN/01-problem.md`, `02-design.md`, `05-risks.md` | Plain ASCII fenced blocks, authored in place, mutable like any other prose. |
| Reference example | `enhancements/0012/02-design.md` (lines 28-43, 80-94) | The existing ASCII convention this skill formalizes — study before drawing a new one. |
| This skill | `enhancements/.claude/skills/enhancement-diagrams/SKILL.md` | The protocol — the file you are reading. |

## Cross-references

- `enhancements/CLAUDE.md` — repo guide; lists this skill under sibling skills.
- `enhancements/.claude/skills/enhancements/SKILL.md` — the authoritative workflow protocol;
  `## Phase 2 — Iterate` is where general design discussion happens and this skill applies.
- `enhancements/.claude/skills/enhancement-open-questions/SKILL.md` — the OQ-walk's Present step
  is the primary trigger for a live diagram during a walk.
- `enhancements/0000/README.md ## Diagrams` — canonical rules text reproduced in each new entry's
  template.
