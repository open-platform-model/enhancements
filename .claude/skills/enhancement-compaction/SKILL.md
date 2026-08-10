---
name: enhancement-compaction
description: Compact an enhancement so it states what is true now — merge a reversing decision into the decision it reverses (lower number survives, vacated number keeps a tombstone), collapse resolved Open Question prose to a one-line status, hoist relation trailers out of headings into structured fields, and stub a superseded entry down to pointers at its successor. Produces a manifest for approval before writing anything, appends one rolled-up history event, and lands in its own commit. Load before merging, rewriting, or deleting anything under an existing DN / OQN, when `task compact:plan ID=NNNN` returns candidates, before promoting `draft → accepted`, or when superseding an entry. Refuses outright on `implemented` entries.
user-invocable: true
---

# Enhancement Compaction

Enhancements are epics. They run for weeks across several repos, and they accrete reversals: a decision made in week one gets amended in week six, an Open Question gets answered, a slice reveals that an earlier choice was wrong. If every reversal is only ever *stacked* on top of what it reverses, the document stops being safe to read linearly — someone who stops halfway comes away believing something a later entry already killed.

This skill weaves reversals back into what they reverse, so the entry states what is true now. Provenance is not lost: git holds every prior revision, and `config.yaml.history` — the one strictly append-only structure in the repo — records that the compaction happened and what it merged.

Rewriting a design record is a real risk, not a free lunch. An agent that can edit decisions can quietly edit them to agree with whatever it just built. Three things make that hard, and all three are mandatory: **a manifest approved before any write**, **one history event naming what changed**, and **a commit that contains nothing but the compaction**.

## When this skill applies

- `task compact:plan ID=NNNN` returned candidates.
- You are about to promote `draft → accepted` — the promotion gate already forces you to touch every Open Question, so collapsing resolved ones costs nothing extra.
- A slice landed that reverses an accepted decision, and you are recording the reversal.
- You are about to flip `accepted → implemented`. **This is the last chance** — the flip freezes the entry permanently.
- You are superseding an entry and need to collapse it to pointers at its successor.
- Any time you are about to merge, rewrite, or delete content under an existing `DN` or `OQN`.

Skip it when you are only *adding* — a new decision, a new Open Question, new prose. Growth is not compaction; use the `enhancements` skill.

Sibling skills:

- **`enhancements`** (`.claude/skills/enhancements/SKILL.md`) — the binding workflow protocol. Decision block format, status gates, history conventions live there. This skill defers to it on conflicts.
- **`enhancement-open-questions`** (`.claude/skills/enhancement-open-questions/SKILL.md`) — resolves OQs by *appending* decisions. This skill cleans up after it. If a walk has unresolved rows queued, run the walk first: compacting a half-resolved OQ block just means doing it twice.

## Invocation

```
/enhancement-compaction ID=NNNN [ONLY=D5,OQ3,...] [DRY=1]
```

| Var | Meaning |
| --- | --- |
| `ID` | Four-digit zero-padded enhancement id. Required. |
| `ONLY` | Optional. Comma-separated `DN` / `OQN` tokens to act on this session; everything else is left alone. |
| `DRY` | Optional. `DRY=1` prints the manifest and exits without writing. |

## State-aware behavior

Read `config.yaml.status` first thing, before anything else.

| Status | Behavior |
| --- | --- |
| `draft` | **WEAVE and TOMBSTONE only.** Leave Open Question prose alone — it is the active work surface, and its context paragraphs are what make the questions answerable. Collapsing them mid-design destroys work in progress. |
| `accepted` | **WEAVE, TOMBSTONE, COLLAPSE-OQ.** The primary use case. Stays available for the entire `accepted` period, including a deliberate final pass immediately before the flip to `implemented`. |
| `implemented` | **Refuse. No override, no `FORCE` flag.** The design shipped and the record is closed. What looks like a needed correction is either a new enhancement or a note in the successor. Say so and exit. |
| `superseded` | **STUB**, plus COLLAPSE-OQ and TOMBSTONE. The narrative documents collapse to pointers at the successor. `experiments/` and `research/` are never touched under any status. |

There is no override for `implemented`. If the user insists, the honest answer is that the entry is frozen by design and the fix belongs in a new entry — offer to draft that instead.

## The keep/drop test

One test governs every operation:

> **Keep what would change a future decision. Drop what only records that we changed our mind.**

Concretely, *Alternatives considered* always survives — it is the expensive knowledge, the thing that stops a rejected option being re-litigated in six months. The narrative of how we arrived at the current answer does not survive; that is precisely what git holds.

When genuinely unsure whether a passage is load-bearing, keep it. A slightly-too-long entry is a much cheaper mistake than a lost constraint.

## The four operations

### WEAVE — merge a reversal into what it reverses

The surviving decision sits at the **lowest number involved** and holds the current truth. This is the whole point: a reader working through the log in order hits the lowest number first, and what they find there must already be correct. Forwarding them to a higher number would just reproduce the read-order hazard in miniature.

Rewrite the surviving decision's title and `**Decision:**` to state what is now decided, then:

- **Fold the overturned position into `**Alternatives considered:**`,** marked as previously chosen. This is the most important instruction in this skill. The old decision was not a hypothetical someone dreamed up — it was actually adopted, and *why it failed in practice* is stronger evidence than any speculative alternative. Losing it means the next person re-proposes it.
- **Keep the original `**Source:**`** and add a `**Revised:**` line naming the date and what was absorbed.
- **Add structured relation fields** (see below) rather than leaving relations in the heading.
- **Tombstone every higher number that was merged in.**

```markdown
### D28: Noun-first `opm operator` command group

**Decision:** The operator install surface is `opm operator install [--crds-only]` / `opm operator uninstall`. There are no `install` / `uninstall` verb groups.

**Alternatives considered:**

- Verb-first `opm install operator` / `opm install crds` / `opm uninstall operator` — **originally adopted here, then reversed.** It reads well in isolation but forces a top-level verb namespace that every future noun has to compete for.
- A separate `opm crds` group — rejected: CRDs are an implementation detail of the operator, not a peer noun.

**Rationale:** {why the current answer is right}

**Source:** User decision 2026-06-14 (RFC-0007 OQ-3)
**Revised:** 2026-07-29 — absorbed D32, which reversed the verb-first surface.
```

Narrative documents get the same treatment in the same pass. `01`–`06` routinely carry inline archaeology — `"(D31 reverses D13's plan to replace it…)"`, `"Release mechanics (D13, revising D8)"`, `"no longer slice 1 — reverted"`. After a weave, that prose states the current design directly. Parentheticals explaining what an earlier draft used to say are exactly what this skill exists to remove.

### TOMBSTONE — retire a vacated number

Numbers are never reused and never renumbered: other repos cite them from commit messages and OpenSpec change docs, and a dangling `0006-D32` is a broken link into the design record. A merged-away or dead-on-arrival number keeps a stub:

```markdown
### D32: (merged into D28, 2026-07-29)

Noun-first operator command group — content now in D28. Number retired.
```

Two lines. Never reuse the number, never renumber around the gap. `task compact:plan` counts tombstones when computing the next free `DN`, and so does the `enhancement-open-questions` walk.

### COLLAPSE-OQ — reduce a resolved question to its pointer

`accepted` and `superseded` only. A resolved Open Question keeps its number, its question, and its status token. Everything after the status token goes — the answer lives in the decision it points at, and restating it here is how this block grows into an unreadable second decision log.

```markdown
- **OQ8: `opm install operator` vs `opm operator install`?** Status: resolved-by-D28.
```

- `resolved-by-DN` — collapse fully.
- `deferred-to-NNNN` — collapse fully. The question now belongs to `NNNN`.
- **`answered` — keep the explanation.** An `answered` OQ has no decision to point at; its status line *is* the answer and exists nowhere else. Collapsing it destroys the content. Trim it to a sentence if it has sprawled, but never to a bare token.
- `open` / `partial` — untouched on `draft` and `accepted`; they are the active work surface.
- **`open` / `partial` on a `superseded` entry — collapse, and say where the question went.** Nobody will ever answer a question filed against a dead entry, so the context paragraph has no reader. What a reader *does* need is which successor inherited it: `Status: open at supersession — carried to 0010.` If no successor took it, say that too; an abandoned question is a real outcome and worth one line.

Keep the bullet's `- **OQN: …** Status: …` shape exactly. `task questions:list` and `task questions:open` parse it with an awk state machine that reads the `- **OQN:` prefix and the `Status:` token; a reformatted bullet drops out of the walk queue silently.

### STUB — collapse a superseded entry

`superseded` only. The design intent now belongs to the successor; this entry becomes the record that it existed and what it settled.

- **`README.md`** — keep the `> **Superseded by NNNN (YYYY-MM-DD).**` banner and its migration paragraph. Keep `## Scope`. Everything else reduces to a short statement of what the entry still usefully holds.
- **`01`, `02`, `04`, `05`, `06`** — each collapses to a few sentences: what it covered, which successor owns it now. A stubbed document is not an empty one; a reader who lands here from a cross-reference needs to know where to go.
- **`03-decisions.md`** — keep every `### DN:` heading, a one-or-two-sentence `**Decision:**`, and `**Alternatives considered:**` in full. Drop `**Rationale:**`. Keep `**Source:**` when it cites an `experiments/` or `research/` file that still lives in the entry, so the pointer is not orphaned.
- **`experiments/` and `research/`** — never touched. The measurements are usually the expensive part of a superseded entry and they remain valid evidence for the successor.

### Relation fields — hoist relations out of headings

Relations belong in structured fields, not in a 120-character `### DN:` heading where they are neither readable nor greppable. During any weave, hoist them:

```markdown
### D22: Solo-cluster `Platform` write-if-absent uses a plain `Create`

**Supersedes:** D12
**Resolves:** OQ13
```

Use `**Supersedes:**` (the other decision is dead), `**Amends:**` (it survives, narrowed), and `**Resolves:**` (an OQ). This is also what makes the `vet` reference-integrity check cheap — it can find every citation without parsing prose.

## The protocol

### 1. Preflight

1. Read `config.yaml`. Branch on `status` per the table above; refuse `implemented` here, before doing any other work.
2. Run `task questions:open ID=$ID`. If it returns rows and the status is `accepted`, stop — unresolved OQs at `accepted` are a gate failure. Route to `enhancement-open-questions` first.
3. Run `task compact:plan ID=$ID`. This is the candidate list, not the plan: it finds relation phrases, resolved OQs still carrying prose, and heading trailers. It has no judgment about which ones should merge.
4. Read `03-decisions.md` and the narrative documents in full. Cache them. Compaction needs whole-document context — a merge decided from grep output alone will get the alternatives wrong.
5. Capture mtimes of every file you intend to write.

### 2. Manifest — approval gate

Present the complete plan **before touching any file**, as a table:

```
OP         TARGET      ACTION
WEAVE      D28 ← D32   noun-first surface into D28; verb-first folded into Alternatives
TOMBSTONE  D32         merged into D28
TOMBSTONE  D4          dead via D13 (shared inventory package never shipped)
COLLAPSE   OQ8         drop 340 chars of decision archaeology after Status:
COLLAPSE   OQ14        drop 1,180 chars; keep resolved-by-D21
NARRATIVE  06-operational.md §Cross-Repo  restate slice order without the "no longer slice 1" aside
```

Then stop and wait. Do not batch the approval with the writes, and do not proceed on silence.

**Size the manifest to what a human can review.** A single pass that rewrites a 120 KB document produces a diff nobody will read, and unreviewable is exactly how a laundered decision gets through. If the manifest runs past roughly a dozen operations, split it: propose the highest-value subset now and the rest as a follow-up pass.

### 3. Apply

- Re-stat each file before writing. If an mtime advanced since preflight and this skill did not write it, stop and ask — a merge computed against a stale view can silently drop a decision that landed in between.
- Apply operations in the order listed, one file at a time.
- Never renumber. Never reuse a number. Never delete a heading without leaving a tombstone.

### 4. Record

Append **exactly one** rolled-up event to `config.yaml.history` naming what was merged, and bump `updated`:

```yaml
- {date: 2026-07-29, event: "Compacted: D32 woven into D28, D4 tombstoned (dead via D13), OQ8/OQ14 collapsed"}
```

This is not bookkeeping. `history` is the one append-only structure in the repo, so this event is what makes a compaction auditable without diffing — a reader who wonders why D32 is a tombstone finds the answer in metadata rather than in git archaeology. It is mandatory on every pass.

### 5. Verify

```bash
task vet:one ID=$ID                        # hard gate — includes reference integrity
task check ID=$ID                          # soft gate — prose shape survived
task questions:list ID=$ID                 # OQ parser still sees every bullet
cd $ID/schemas && cue vet ./...            # OQN markers still compile
task index                                 # config.yaml changed
```

`task questions:list` before and after should show the same rows with the same statuses. If a bullet vanished from the listing, COLLAPSE-OQ broke the bullet shape.

### 6. Commit

Compaction lands in **its own commit**, containing nothing else:

```
compact(0004): weave D5 into D3, collapse 6 resolved OQs
```

Mixing compaction into a content change makes the two indistinguishable in review, and the whole safety argument here rests on a reviewer being able to see a compaction *as* a compaction. Follow the repo's attribution rule: an optional plain `Co-Authored-By: Claude <noreply@anthropic.com>` trailer only — no session links, no generated-with footers.

## Anti-patterns

- **Writing before the manifest is approved.** The manifest is the control. Skipping it turns this skill into an unsupervised rewrite of a design record.
- **Dropping the overturned position instead of demoting it to an alternative.** The single most damaging failure mode. A decision that was tried and reversed is the strongest evidence in the document; deleting it guarantees someone re-proposes it. Fold it into *Alternatives considered*, marked as previously adopted.
- **Compacting an `implemented` entry.** Frozen means frozen. There is no flag.
- **Collapsing Open Questions on a `draft`.** Their context paragraphs are the working surface. Wait for the promotion pass.
- **Collapsing an `answered` OQ to a bare token.** Its status line *is* the answer; nothing points at a decision. This deletes content that exists nowhere else.
- **Renumbering to close tombstone gaps.** The gaps are the point. Other repos cite these numbers.
- **Reformatting OQ bullets.** The awk parser in `Taskfile.yml` reads a specific shape; a "tidier" bullet silently disappears from `questions:open`.
- **Touching `experiments/` or `research/`.** Never, under any status. Gathered evidence and runnable proofs outlive the prose that cited them.
- **Merging on grep output.** Read the whole decision and its neighbours. Alternatives get mangled by agents working from a three-line window.
- **One giant pass over a large entry.** Split it. If the diff cannot be reviewed, the compaction cannot be trusted.
- **Editing prose "while I'm in here".** Improving unrelated wording during a compaction defeats the own-commit rule just as thoroughly as bundling a feature change.

## Where things live

| Artefact | Path | Authority |
| --- | --- | --- |
| Decision log | `enhancements/NNNN/03-decisions.md ## Decisions` | Numbers immutable, bodies mutable. Merged content sits at the lowest number; vacated numbers hold tombstones. |
| Open Questions | `enhancements/NNNN/03-decisions.md ## Open Questions` (canonical) or `README.md` (fallback) | Bullet shape is parser-bound. Only resolved/deferred bullets collapse. |
| Narrative documents | `enhancements/NNNN/01-problem.md` … `06-operational.md` | Mutable. Must state current truth after a weave. |
| Provenance | `enhancements/NNNN/config.yaml history` + git | The only append-only structure. One rolled-up event per compaction pass, mandatory. |
| Candidate detection | `enhancements/Taskfile.yml :: compact:plan` | Read-only. Finds candidates; exercises no judgment. |
| Reference integrity | `enhancements/Taskfile.yml :: vet / vet:one` | Hard gate. Every cited `DN` / `OQN` must resolve to a heading or tombstone. |
| Evidence | `enhancements/NNNN/experiments/`, `research/` | Out of scope permanently. |
| This skill | `enhancements/.claude/skills/enhancement-compaction/SKILL.md` | The compaction protocol — the file you are reading. |

## Cross-references

- `enhancements/CLAUDE.md` — repo orientation; lists this skill under sibling skills.
- `enhancements/.claude/skills/enhancements/SKILL.md` — the canonical workflow protocol. `## Repo rules` defines the numbering invariants this skill preserves; `## Phase 3 — Promote` and `## Phase 5 — Supersede` are where compaction passes belong.
- `enhancements/.claude/skills/enhancement-open-questions/SKILL.md` — resolves OQs by appending decisions; run it to completion before collapsing an OQ block.
- `enhancements/0000/03-decisions.md` — the template preamble carrying the numbering and compaction rules into every new entry.
- `enhancements/README.md ## Compaction` — the human-facing statement of the same model.
