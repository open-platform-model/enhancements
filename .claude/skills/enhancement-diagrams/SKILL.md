---
name: enhancement-diagrams
description: When and how to reach for a diagram while designing an OPM enhancement — Mermaid for relationship/dependency graphs between enhancements and for an entry's own architecture diagram, ASCII still accepted for mechanism detail inside the split documents. Load before sketching a diagram during an Open-Questions walk or general design discussion, before adding a diagram to README.md/01-problem.md/02-design.md/05-risks.md, or when unsure which medium a diagram calls for.
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

> **Mermaid is the default medium for both categories: relationships between enhancements, and
> how a single enhancement's design/mechanism works. ASCII remains accepted for mechanism detail
> inside the split documents, and is never converted wholesale. Medium follows content shape.**

The two categories are still genuinely different content, and the distinction decides what a
diagram may show, not which tool draws it:

- A **relationship** question has enhancements or entries as its nodes and
  `depends_on`/`amends`/`supersedes`/`revives` as its edges. This is exactly what `GRAPH.md` (cross-entry)
  already renders as generated Mermaid. A `depends_on` edge is earned,
  not sketched into being: it exists iff a decision in one entry carries a `**Depends:**` line
  naming a decision in the other. An `amends` edge is the same discipline for change: it exists
  iff a live decision carries a qualified `MMMM:DN` token on its `**Amends:**` / `**Supersedes:**`
  line, and `GRAPH.md` labels it `amends n/m` (n of the target's m live decisions changed).
  Relationship diagrams are never hand-authored into an entry: `GRAPH.md` is the only committed
  artifact for them, and a live sketch during discussion is scaffolding for the conversation.
- A **design/mechanism** question has actors, artifacts, data, states, or components as its nodes —
  how a deletion protocol resolves, how a rung ladder architecture is layered, how a request
  flows through a pipeline. **Every entry's `README.md` carries exactly one of these, in Mermaid,
  under `## How it works`**: it is the fastest thing a newcomer can read, and a rendered diagram
  beats an ASCII one on GitHub. Inside `01-problem.md`, `02-design.md` and `05-risks.md` either
  medium is fine; `enhancements/0012/02-design.md` is the ASCII reference and stays as it is.

**Why the README diagram is Mermaid and not ASCII.** It is read by people who have not yet decided
to read the entry, on GitHub, often on a phone. ASCII wraps, loses alignment at small widths, and
cannot be zoomed. The cost is real but bounded: a syntax error breaks the render, so every
hand-authored Mermaid block is checked before it lands (see `## Authoring Mermaid safely`).

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
| What is this entry about, in one picture? | Mermaid, in `README.md ## How it works` | One per entry, mandatory. The mechanism the entry designs. |
| How does this layered architecture fit together? | Mermaid `flowchart` with subgraphs, or ASCII | `0012`'s rung ladder (kernel emits, decides, acts, owns the CR). |
| How does data flow through this pipeline / protocol? | Mermaid `flowchart`, or ASCII | `0012`'s deletion protocol (inputs, plan, verdict). |
| Who calls whom, in what order? | Mermaid `sequenceDiagram` | A handoff between two frontends and a controller. |
| What states does this object move through? | Mermaid `stateDiagram-v2` | A claim that is pending, accepted, then active. |
| What does this look like before vs. after the change? | Mermaid subgraphs, or ASCII side-by-side | `02-design.md ## Before / After`. |

## Relationships → Mermaid

Sketch it **live, inline in the chat response** — no tool call needed at typical size. Reuse the
exact `classDef` palette already defined in `Taskfile.yml`'s `graph` task (entry status, plus the
`stub` and `category` node kinds `GRAPH.md`'s per-category sections and Overview use), so the
live preview looks like what the regenerated file will actually contain once the edit lands:

```
classDef draft       fill:#fef3c7,stroke:#b45309,color:#000
classDef accepted    fill:#dbeafe,stroke:#1d4ed8,color:#000
classDef rejected    fill:#fee2e2,stroke:#b91c1c,color:#7f1d1d,stroke-dasharray:4 2
classDef superseded  fill:#e5e7eb,stroke:#6b7280,color:#6b7280
classDef delivered   fill:#dcfce7,stroke:#15803d,color:#14532d
classDef legacy      fill:#fafafa,stroke:#9ca3af,color:#6b7280,stroke-dasharray:3 3
classDef stub        fill:#f3f4f6,stroke:#9ca3af,color:#374151
classDef category    fill:#ede9fe,stroke:#6d28d9,color:#000
```

`GRAPH.md` is partitioned by `config.yaml.category`: an Overview whose nodes are categories and whose
edge labels count cross-category `depends_on` edges, then one `graph TD` per category where an entry from
another category appears as a grey `stub` labelled `NNNN · <category>`. Closed entries (delivered,
superseded, rejected) appear only where a live entry's edge reaches them, and an edge between two
closed entries is not drawn. A live sketch of one entry's neighbourhood should use the same stub
convention for anything outside the entry's own category, and the same closed-entry rule.

This is a genuinely new capability, not a restatement of what already exists: today `GRAPH.md`
only exists *after* `task graph` runs against already-committed data.
A live sketch lets the user see the shape of a *proposed* edge or split — "what would the graph
look like if 0013 superseded 0007 instead of merely depending on it?" — before touching
`config.yaml` at all. Once the relationship decision is actually made, it is
encoded there and the real file is regenerated; the live sketch was scaffolding for the
conversation, not a new artifact to maintain. Never hand-edit `GRAPH.md` to match a
sketch — it carries a "do not edit by hand" header for a reason.

## Design/mechanism → Mermaid (or ASCII)

Mermaid in a ```` ```mermaid ```` fence is the default, and the only accepted medium for the
README's `## How it works`. ASCII in a plain fenced block is still accepted inside
`01-problem.md`, `02-design.md` and `05-risks.md`; existing ASCII diagrams are left alone, and
converting one is never busywork worth doing on its own.

Rules for either medium:

- **One concept per diagram** — same discipline as one concept per experiment. If you're drawing
  two things at once, split it.
- **Never bare.** Every diagram is paired with two to four sentences of prose — the diagram shows
  the shape, the prose says what to take from it.
- **Small.** 6 to 14 nodes. A diagram that needs a legend to stay readable is a sign to split it,
  not to add a legend.
- **Concepts, not construction.** Nodes are actors, artifacts, data and steps: `Platform spec`,
  `Registration CR`, `Render`. Never a file path, a package name, a function or a line number —
  those are the target repo's to choose, and naming one here is prescriptive mechanism (see
  `CLAUDE.md`).

### Authoring Mermaid safely

A syntax error does not degrade; it replaces the whole diagram with an error box on GitHub. The
traps that actually bite, all of them learned from real breakage:

- **Quote every label containing punctuation**: `A["Render (one build)"]`, not `A[Render (one
  build)]`. Parentheses, colons, commas, slashes and quotes all need the surrounding `"`.
- **No `#` in a label.** Mermaid reads `#` as the start of an entity code, so write `Module`, not
  `#Module`. Same for `@` at the start of a word.
- **No node id starting with `o` or `x`**, and none named `graph`, `end`, `set`, `class` or
  `style`: `A-->oB` parses as a circle arrowhead, and the keywords are reserved.
- **No `|` or `;` inside a label**, and no colon or parenthesis in an *edge* label.
- **ASCII only.** No unicode arrows, box-drawing characters or emoji, per `STYLE.md`.
- **Check before landing.** Render it, or read the block on the PR's Files-changed view, which
  renders Mermaid. Never commit a block nobody has seen rendered.

ASCII, when you choose it: prefer arrows and columns over bordered boxes, which are fragile to
realign after an edit. `0012/02-design.md` holds both styles and is the reference.

## Live, during discussion

For either medium, produce the diagram directly inline in the chat response — no `Artifact` call
needed at typical size, for either ASCII or Mermaid. Escalate to the `Artifact` tool only when the
user wants something kept or revisited across a long session, or a diagram has genuinely grown too
large for a plain chat fence to stay readable — ask before switching presentation; don't assume
the user wants a rendered page just because a diagram exists.

## Persisting into documents

Design/mechanism diagrams belong in:

- `README.md ## How it works` — **exactly one, in Mermaid, on every entry.** The one picture a
  reader who has not committed to the entry will look at. It shows the mechanism the entry
  designs, in the reader's vocabulary, not the entry's internal one.
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

- **Hand-authoring a relationship diagram into an entry.** `depends_on` and `amends` edges are
  earned in `config.yaml` and rendered by `task graph`. A hand-drawn copy inside an entry goes
  stale the first time an edge changes and nothing catches it.
- **A README diagram in ASCII, or more than one diagram in a README.** The `## How it works`
  section is one Mermaid block, full stop. A second mechanism belongs in `02-design.md`.
- **Committing a Mermaid block nobody rendered.** A syntax error replaces the whole diagram with
  an error box. Re-read `### Authoring Mermaid safely`.
- **File paths, package names or functions as diagram nodes.** That is prescriptive mechanism.
  Nodes are actors, artifacts and steps.
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
| Mermaid `classDef` palette (entry status, `stub`, `category`) | `enhancements/Taskfile.yml :: graph` | Source of the palette to reuse in a live relationship sketch. |
| The entry's architecture diagram | `enhancements/NNNN/README.md ## How it works` | Exactly one Mermaid block per entry, in a ```` ```mermaid ```` fence, paired with two to four sentences. |
| Design/mechanism diagrams (hand-authored) | `enhancements/NNNN/01-problem.md`, `02-design.md`, `05-risks.md` | Mermaid or plain ASCII fenced blocks, authored in place, mutable like any other prose. |
| Reference example | `enhancements/0012/02-design.md` (lines 28-43, 80-94) | The ASCII convention this skill still accepts — study before drawing a new one. |
| This skill | `enhancements/.claude/skills/enhancement-diagrams/SKILL.md` | The protocol — the file you are reading. |

## Cross-references

- `enhancements/CLAUDE.md` — repo guide; lists this skill under sibling skills.
- `enhancements/.claude/skills/enhancements/SKILL.md` — the authoritative workflow protocol;
  `## Phase 2 — Iterate` is where general design discussion happens and this skill applies.
- `enhancements/.claude/skills/enhancement-open-questions/SKILL.md` — the OQ-walk's Present step
  is the primary trigger for a live diagram during a walk.
- `enhancements/0000/README.md ## Diagrams` — canonical rules text reproduced in each new entry's
  template.
