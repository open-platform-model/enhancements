---
name: enhancement-open-questions
description: Interactive walk through an enhancement's Open Questions — present each OQ's context plus alternatives plus an evidence-bearing recommendation, then on user decision write a four-field `### DN:` block to `03-decisions.md`, rewrite the OQ's `Status:` line, optionally tighten `// OQN:` markers in `schemas/target.cue`, bump `config.yaml.updated`, and append a single rolled-up `history` event at the end. Load before invoking `/enhancement-open-questions`, when iterating an enhancement's decisions in Phase 2 of the enhancements workflow, or when patching unresolved OQs that `task check` flagged before promoting `draft → accepted`.
user-invocable: true
---

# Enhancement Open Questions Walk

This skill walks an enhancement's `## Open Questions` block interactively. It is a thin interactive layer on top of the canonical `enhancements` workflow protocol — that skill defines the four-field decision block format, the append-only invariants, and the per-status gates; this skill defines how to *resolve OQs one at a time* without skipping steps.

## When this skill applies

Load this skill when any of the following is true:

- You are invoking `/enhancement-open-questions ID=NNNN`.
- You are in Phase 2 (Iterate) of the enhancements workflow and the user wants to resolve one or more Open Questions interactively, not freehand-edit `03-decisions.md`.
- `task check ID=NNNN` flagged unresolved OQs and you are about to promote `draft → accepted` (per `enhancements` skill, every OQ must be resolved at promotion time).
- `task questions:open ID=NNNN` returns one or more rows and you need to clear them coherently.

Skip this skill when the user has already drafted a `### DN:` block externally and just wants you to wire it in — that is a direct edit, not a walk.

Sibling skills:

- **`enhancements`** (`.claude/skills/enhancements/SKILL.md`) — the binding workflow protocol. Decision block format, status gates, history conventions all live there. This skill defers to that one on conflicts.
- **`enhancement-experiments`** (`.claude/skills/enhancement-experiments/SKILL.md`) — experiments are a primary input for partial OQs (`informed-by-exp-NN` / `supported-by-exp-NN`). When walking such an OQ, read the experiment's `README.md` Outcome section before presenting.
- **`core-schema-edit`** (`core/.claude/skills/core-schema-edit/SKILL.md`) — load this only when the resulting decision will also land as an edit in `core/*.cue` in the same session. The walk itself doesn't touch `core/`.

## Invocation

```
/enhancement-open-questions ID=NNNN [OQ=N] [ONLY=N,M,...] [FORCE=1]
```

| Var | Meaning |
| --- | --- |
| `ID` | Four-digit zero-padded enhancement id. Required. |
| `OQ` | Optional. Start at this OQ id (number only — `OQ=4` for OQ4). All preceding OQs are skipped this session. |
| `ONLY` | Optional. Comma-separated list of OQ numbers to walk this session; everything else is skipped. Wins over `OQ`. |
| `FORCE` | Optional. Pass `FORCE=1` to allow walking an `implemented` enhancement (see State-aware behavior). |

## State-aware behavior

Read `config.yaml.status` first thing. Behavior by status:

| Status | Behavior |
| --- | --- |
| `draft` | Proceed normally. Primary use case. |
| `accepted` | Per `enhancements` skill, an accepted enhancement should have zero unresolved OQs. If `task questions:open` returns rows, that is a vet/check gap. Warn loudly, list the unresolved OQs, ask the user to confirm before proceeding. Proceed on confirmation. |
| `implemented` | Block by default. Resolving an OQ after code shipped means design intent changed; the canonical artefact for that is usually a new superseding enhancement, not a back-edit. Pass `FORCE=1` to override. When refusing, point the user at Phase 5 (Supersede) of the `enhancements` skill. |
| `superseded` | Refuse. No override. Point the user at the successor (`config.yaml.superseded_by`) and exit. |

## The per-OQ loop

### Preflight (once per session)

1. Read `$ID/config.yaml`, `$ID/02-design.md`, `$ID/03-decisions.md`, `$ID/schemas/target.cue`. Cache in session context. **Do not re-read on each OQ** — token discipline matters across long walks.
2. Capture mtimes of `$ID/03-decisions.md`, `$ID/schemas/target.cue`, `$ID/config.yaml`. Used for race detection before each per-OQ write.
3. Compute next decision number: highest `^### D[0-9]+:` in `03-decisions.md` plus 1. Append-only — never reuse, never backfill.
4. Run `task questions:open ID=$ID`. Filter the resulting TSV by `OQ=` / `ONLY=` if provided. This is the walk queue.
5. If the queue is empty, report and exit. Do not invent OQs.

### For each queued OQ

1. **Present.** Restate the OQ. Surface:
   - Gated design surface: `grep -n "OQ$K\b" 02-design.md` and excerpt the surrounding sentences.
   - Related decisions: `grep -nE "OQ$K\\b" 03-decisions.md` restricted to lines inside `## Decisions` (above `## Open Questions`).
   - Schema markers: `grep -nE "OQ$K\\b" schemas/target.cue`. Show line numbers with two lines of context above and below.
   - Experiment evidence (only if `Status: informed-by-exp-NN` or `supported-by-exp-NN`): read `experiments/NN-*/README.md` and quote the Outcome section.
   - Alternatives the OQ bullet enumerates.
   - **Recommendation** — include a `**Recommendation:** {…}` line *only* when evidence supports it (an experiment outcome, a prior decision that constrains the answer, a principle explicitly stated in `02-design.md`). If no such evidence exists, say so: "No strong recommendation — both A and B are live." Fabricating decisiveness is an anti-pattern; see below.
2. **Discuss.** Stay in this state until the user picks an outcome. Answer questions, surface additional context from the cached files, do not write anything.
3. **Decide.** User picks one of:
   - **Decide** — draft the full four-field `### DN:` block in chat (Decision / Alternatives considered / Rationale / Source). Echo the user's stated reasoning into Rationale verbatim where possible — paraphrase loses fidelity. Source defaults to `User decision YYYY-MM-DD` (today). Ask the user to confirm with `y`, reply with revised text to enter an edit round, or `skip` to abort.
   - **Defer** — ask: "Defer to which enhancement?" Empty answer → `Status: deferred` (no target). Otherwise → `Status: deferred-to-NNNN`. The skill does not validate that NNNN exists at write time; the target enhancement may not be filed yet. Surface a one-line warning if it doesn't.
   - **Answer** — the OQ does not need a decision; it just needs clarification (canonical example: OQ17 in 0001, `Status: answered`). Ask the user for the short explanation. Write `Status: answered. {explanation}` on the bullet's status line.
   - **Skip** — no edits. Move on. The OQ stays `open`.
4. **Write.** Before any write:
   - Re-stat the file. If mtime has advanced since the preflight capture and the skill did not write, surface "external edit detected — re-read or abort?" and stop. The append-only invariant is impossible to honour blindly through a stale view.
   - For a Decide outcome: insert the new `### DN:` block immediately before `^## Open Questions$` with a trailing `---\n\n` separator (matches the cadence used in `0001`). Rewrite the OQ's `Status:` line in place — keep the bullet text identical except for the `Status:` span.
   - For Defer / Answer: rewrite the `Status:` line only. No new DN block.
5. **Schema markers.** After a Decide outcome only: if `grep -nE "OQ$K\\b" schemas/target.cue` returned any matches, prompt:
   ```
   Found N references to OQ{K} in schemas/target.cue. Edit each?
     [r] rewrite marker to "// resolved-by-D{N}"
     [d] delete the OQ{K} reference, keep surrounding comment
     [k] keep as-is
     [s] show full file, I'll handle it
   ```
   On any edit: run `cd $ID/schemas && cue vet ./...`. On failure, show the error and offer revert. Keep pre-edit bytes in session memory for the revert path.
6. **Move on** to the next queued OQ.

### Compound decisions

Real patterns from `0001/03-decisions.md`:

- **One decision resolves multiple OQs.** OQ9 and OQ10 both `resolved-by-D7`. When the user signals "same decision as the prior OQ" (or "OQ8 and OQ16 are one"), do not draft a new DN block — reuse the existing or in-session DN id. Update each OQ's status line to point at the shared DN.
- **One OQ resolved by multiple decisions.** OQ19 `resolved-by-D2/D3`. Prompt for the slash-separated list of DN ids. Validate each exists; if any don't, surface and ask. Write the slash-separated form on the status line — this is the de-facto convention in the repo; do not invent new syntax.

## Decision block format

Defer to `enhancements` skill `## Phase 2 — Iterate`. The skill mandates exactly four fields: **Decision**, **Alternatives considered**, **Rationale**, **Source**. Reproduce that format in the auto-draft. Do not deviate. Do not introduce additional fields.

If the user's revised text drops a field, surface it: "Source field is empty — the skill convention is `Source: User decision YYYY-MM-DD` or an experiment / URL reference. Keep blank?" Default to filling with today's date if the user shrugs.

## OQ status vocabulary

Three buckets (the parser in `task questions:open` classifies based on these):

| Bucket | Status values | Walk behavior |
| --- | --- | --- |
| `open` | exactly `open` | Walked. |
| `partial` | `informed-by-exp-NN`, `supported-by-exp-NN` | Walked. Read the experiment's Outcome section before presenting; the walk's job is to formalize the experiment evidence into a `### DN:` block. OQ15 in 0001 is the canonical example: experiment 05 informed the answer but a formal D is still pending. |
| `resolved` | `resolved-by-D##`, `resolved-by-D##/D##` (compound), `deferred`, `deferred-to-NNNN`, `answered` | Skipped by the walk. Listed in the end-of-walk summary for context. |

Any other status string renders as `unknown` and is omitted from the queue. If the user wants to walk an `unknown`-status OQ, fix the status spelling first.

## Schema marker handling

The `// OQN:` form in `schemas/target.cue` is a comment marking a field that the OQ gates. Examples:

```cue
range?: string  // SemVer constraint, e.g. ">=1.0.0 <2.0.0". OQ2 / OQ3.
```

Comments can reference multiple OQs. When OQ2 resolves but OQ3 is still open, the right edit is usually to remove the `OQ2` reference and keep the rest of the comment intact (`[d]` option). When both have resolved, `[r]` to rewrite to `// resolved-by-D{N1}/D{N2}` is one valid form; outright deleting the comment is another.

The skill **must** run `cd $ID/schemas && cue vet ./...` after any schema edit. The `[H]` hard gate in the `enhancements` skill at promotion time is "schemas/ compiles via `cue vet ./...`". Catching breakage inline beats discovering it at PR time. Keep pre-edit bytes in session memory so revert is one-step.

If the comment gates a *block* of fields (e.g. lines 88-95 in `0001/schemas/target.cue` document a struct under OQs 8-12), the right edit is often to delete the comment block entirely once all gated OQs are resolved. The skill cannot reliably tell when a block-comment is "fully resolved"; offer `[s]` (show full file, user handles it) and step back.

## End-of-walk gates

After the queue is exhausted (or the user exits early):

1. **`task vet:one ID=$ID`** — always. Even on a no-decisions walk, an incidental status-line rewrite or experiment-status edit may have landed. Surface failures; do not auto-fix.
2. **History event** — ask: "Append a single rolled-up `history` event? [y/n]". On `y`, draft an event matching the 0001 convention:
   ```yaml
   - {date: 2026-05-24, event: "OQ walk: D14–D16 locked — OQ4/OQ5/OQ7 resolved-by-D##; OQ22 deferred"}
   ```
   Confirm with the user before appending. Single rolled-up event (not per-decision) — matches the 0001 precedent and keeps the timeline scannable. If the walk produced no writes, skip this step.
3. **Bump `config.yaml.updated`** to today's date. Single bump at end, not per OQ. Only if any write landed.
4. **Recommend `task index`** if `config.yaml` was touched. Recommend, don't auto-run — `INDEX.md` regen is mechanical but its diff belongs in the user's PR.
5. **Summary** — list decisions made (DNs), OQs deferred / answered / skipped, and any schema edits. One screen of output, no preamble.

## Anti-patterns

- **Fabricating recommendations.** When evidence is thin, the model will be tempted to rank A and B confidently. Resist. "No strong recommendation; both are live" is a valid output and the right one when the user has nuanced context the cached files don't carry.
- **Pushing back after the user decides.** The decision is ground truth once made. If the user picks the option the skill didn't recommend, write the decision as stated. Do not re-argue.
- **Summarizing the user's reasoning instead of echoing it.** Auto-drafted Rationale should reproduce the user's words. Paraphrase loses the specific framing that makes the decision interpretable in three months.
- **Renumbering or reordering decisions.** `### D1:`, `### D2:` are append-only. The walk only ever inserts new `### DN:` blocks at the end of `## Decisions` (immediately before `## Open Questions`). Never touch existing decisions.
- **Editing OQ bullet text.** The walk rewrites only the `Status:` span. The bullet's title and context paragraph stay verbatim — they are historical record.
- **Re-reading the whole decisions file per OQ.** Cache once at preflight. The mtime check is what catches external edits; re-reading mid-walk is wasted tokens.
- **Touching `library/enhancements/`.** Frozen predecessors. Never edited from this skill or any other.
- **Auto-running `task index` / `task graph`.** Recommend, don't run. The diff belongs in the user's PR.
- **Writing a `history` event per decision.** The 0001 precedent is one rolled-up event per coherent session ("Decisions D5–D11 locked from experiment evidence. …"). Match that.

## Where things live

| Artefact | Path | Authority |
| --- | --- | --- |
| Open Questions block | `enhancements/NNNN/03-decisions.md ## Open Questions` (canonical) or `enhancements/NNNN/README.md ## Open Questions` (fallback) | Source of truth for what's unresolved. Walk modifies only the `Status:` line of each bullet. |
| Decision log | `enhancements/NNNN/03-decisions.md ## Decisions` | Append-only. Walk appends `### DN:` blocks immediately before `## Open Questions`. |
| Decision block format | `.claude/skills/enhancements/SKILL.md ## Phase 2 — Iterate` | Four-field shape. This skill defers to that one verbatim. |
| Schema markers | `enhancements/NNNN/schemas/target.cue` | `// OQN:` comments. Walk edits these only with user confirmation; validates via `cue vet`. |
| Metadata + history | `enhancements/NNNN/config.yaml` | `updated` bumps at end of walk. `history` event appended at end. |
| Walk queue source | `enhancements/Taskfile.yml :: questions:list / questions:open` | Parses Open Questions, classifies into open / partial / resolved. |
| End-of-walk validator | `enhancements/Taskfile.yml :: vet:one` | Hard gate, runs after the walk completes. |
| This skill | `enhancements/.claude/skills/enhancement-open-questions/SKILL.md` | The interactive walk protocol — the file you are reading. |

## Cross-references

- `enhancements/CLAUDE.md` — repo guide; lists this skill under sibling skills.
- `enhancements/.claude/skills/enhancements/SKILL.md` — the canonical workflow protocol. `## Phase 2 — Iterate` defines the decision block format this skill follows; `## Phase 3 — Promote` defines the OQ-resolved gate this skill exists to satisfy.
- `enhancements/.claude/skills/enhancement-experiments/SKILL.md` — experiment outcomes feed `informed-by-exp-NN` / `supported-by-exp-NN` partial OQs; the walk reads experiment READMEs when presenting those.
- `core/.claude/skills/core-schema-edit/SKILL.md` — sister skill governing SPEC.md co-update when a decision from this walk lands as a real schema change in `core/*.cue`.
