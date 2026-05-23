---
name: enhancements
description: Canonical workflow protocol for the OPM enhancements repo. Load before creating a new enhancement, editing any file under enhancements/NNNN/ (config.yaml, README, the six split documents, schemas/target.cue), promoting an enhancement's status (draft → accepted → implemented → superseded), appending history events after a slice ships, adding cross-references, or running any task in enhancements/Taskfile.yml. Skip only when reading an existing enhancement to learn it — then walk its README and 01..06.
user-invocable: true
---

# Enhancements Workflow

This skill is the **authoritative protocol** for working with OPM enhancement proposals under `enhancements/NNNN/`. The repo's `CLAUDE.md` is the orientation document; this skill is the binding workflow.

## When this skill applies

Load this skill when any of the following is true:

- Creating a new enhancement (about to invoke `task new` or write `enhancements/NNNN/` files).
- Editing an existing enhancement's `config.yaml`, `README.md`, or any of the six split documents (`01-problem.md` through `06-operational.md`).
- Editing `enhancements/NNNN/schemas/target.cue`.
- Promoting an enhancement's `status` (draft → accepted → implemented → superseded).
- Recording a new event in `config.yaml.history` after a slice ships.
- Adding or removing entries in `related`, `supersedes`, `superseded_by`.
- Running any of the workflow tasks (`task vet`, `task check`, `task new`, `task index`, `task graph`, etc.).
- Reviewing whether a design is ready to promote — the per-status checklist below is the binding gate.

Sibling skills carry parallel protocols you may also need to load:

- **`enhancement-experiments`** — when creating, updating, or validating experiments under `enhancements/NNNN/experiments/`.
- **`core-schema-edit`** (at `core/.claude/skills/core-schema-edit/`) — when implementing a slice that touches `core/*.cue`. The enhancement's accepted-to-implemented work routes there.

If your task is only to *read* an existing enhancement to learn what was decided, you do not need this skill — open its `README.md`, walk `01-problem.md` through `06-operational.md`, and inspect `schemas/target.cue`. The skill matters when you are about to *change* something.

## Repo rules — invariants

These hold across every enhancement in the repo. Violations fail PR review even if `task vet` does not catch them.

1. **`config.yaml` is the sole source of metadata.** Do not reintroduce a metadata table to `README.md`. The table was removed by design; `config.yaml` is canonical.
2. **Folder names are id-only.** `0001/`, `0042/` — four digits, zero-padded, no slug suffix. The slug lives in `config.yaml.slug` and surfaces in `INDEX.md`. `0000` is reserved for the template; never repurpose it.
3. **Schemas are pure CUE files.** Never write CUE inside a markdown fence longer than a few illustrative lines. The target schema lives in `NNNN/schemas/target.cue`, validated via `cue vet ./...` from that directory.
4. **History is append-only.** Never delete or reorder past events in `config.yaml.history`. Reversed conclusions get a new event recording the reversal; the original event stays.
5. **Decisions are append-only.** `D1`, `D2`, … never renumber. Reversed decisions get a new `DN` that supersedes the old one (e.g. "D9 supersedes D3"); D3 stays in place.
6. **Don't hard-wrap prose in `.md` files.** Workspace convention.
7. **Don't reference `library/enhancements/` content directly** when writing new entries. Those are frozen predecessors. Use the `legacy:NNN` cross-ref form in `related` / `supersedes` if the historical link matters.
8. **Don't fork content from the legacy library enhancements.** Fresh prose. The frozen predecessors are reference material for *why* the new design exists, not source code to copy.

## The workflow

```
new → fill problem + design → accrete decisions → freeze (accepted) → ship (implemented) → archive history
```

### Phase 1 — Create

```bash
task new SLUG=my-slug TITLE="My Title"
# Optional: AREA=cli  AUTHOR="Jane Doe"
```

What the task does:

- Computes the next id from the highest existing `NNNN/` directory (excluding `0000`).
- Copies `0000/` to `NNNN/`.
- Fills `config.yaml`: id, slug, title, area (defaults to `cross-cutting`), affects (defaults to `[area]`), created/updated to today, authors, and seeds `history` with `{date: today, event: "Drafted"}`.
- Replaces `{Enhancement Title}` placeholders across the six split documents + README.
- Updates `schemas/cue.mod/module.cue` to set `module: "enhancements.opmodel.dev/NNNN@v0"`.
- Prints the recommended next steps.

After `task new`:

1. Write `01-problem.md` first — full prose. The Concrete Example section is the most important — it makes the problem tangible.
2. Write `02-design.md` next — full prose. Goals and Non-Goals together define the boundary; the High-Level Approach should be understandable without deep implementation knowledge.
3. Sketch the target schema in `schemas/target.cue`. Mark unresolved fields with `// OQN:` comments pointing at the corresponding Open Question in `03-decisions.md`.
4. Seed `03-decisions.md ## Open Questions` with the questions the design surfaces. Fill `## Decisions` iteratively as choices land.
5. Update `04-graduation.md`, `05-risks.md`, `06-operational.md` as the design firms up. They start as scaffolds and mature alongside the decision log.
6. Before opening a PR: `task vet:one ID=NNNN && task index`.

### Phase 2 — Iterate

Every meaningful edit:

- Bumps `config.yaml.updated` to today's date (ISO 8601, `YYYY-MM-DD`).
- May add a new event to `history` if the edit captures a milestone (e.g. "Decisions D1..D5 locked", "Schema spike concluded", "Open Question OQ3 resolved by D7"). Don't add history events for typo fixes or routine prose edits.
- Tightens `schemas/target.cue` as decisions resolve `OQ` markers.

Decisions are written **after** they are made, not speculatively. The format is fixed:

```markdown
### DN: {Decision Title}

**Decision:** {What was decided. State it as a fact.}

**Alternatives considered:**

- {Alternative A and why it was not chosen}
- {Alternative B and why it was not chosen}

**Rationale:** {Why this decision was made.}

**Source:** {User decision YYYY-MM-DD | URL | file path | experiment outcome}
```

Source is specific. "User decision 2026-05-23" beats "discussion"; an experiment outcome reference (`enhancements/NNNN/experiments/01-name/`) beats a vague "validated".

### Phase 3 — Promote `draft → accepted`

The hard gate:

```bash
task vet:one ID=NNNN          # MUST pass
task check ID=NNNN            # SHOULD pass; document any deferred warnings in the PR body
```

Before promoting:

- Every Open Question is resolved (`resolved-by-D##`, `deferred-to-NNNN`, or `answered`).
- Every decision (D1..DN) has the four-field format.
- `schemas/target.cue` captures the target shape end-to-end and compiles cleanly.
- `config.yaml.semver` is set (`major | minor | none`).
- `config.yaml.affects` lists every repo that ships code/schema/content changes; `area` appears in `affects`.
- `README.md ## Scope` has `### In scope` + `### Out of scope`.
- `04-graduation.md` has both `## draft → accepted` and `## accepted → implemented` sections filled.
- `05-risks.md` has concrete content (not placeholders) for Risks / Drawbacks / Alternatives.
- `06-operational.md` answers the five PRR prompts.
- Cross-References table in `README.md` lists every file path the implementation will touch (verify each exists today).

Append a history event:

```yaml
history:
  - ...
  - {date: <today>, event: "Accepted", semver: <major|minor|none>}
```

Bump `updated`. Flip `status: accepted`.

### Phase 4 — Implement

Implementation lands in the affected repos (named in `config.yaml.affects`), not here. The enhancement entry is the design contract; the slices that satisfy it live in `core/`, `library/`, `catalog/`, etc.

As code ships:

- Append `history` events naming each landing milestone. Use the optional `slice` field to reference an OpenSpec change slug if the target repo uses OpenSpec:
  ```yaml
  - {date: <today>, event: "Library kernel rewired", slice: "library/2026-06-15-add-materialize-step"}
  ```
- For slices that land in `core/*.cue`: **load `core-schema-edit` first.** That skill enforces the SPEC.md co-update protocol. Skipping it gets the commit rejected by the pre-commit hook + CI gate.
- When everything in scope has shipped:
  - Set `implementation.status: complete` with `date` matching the final landing date.
  - Add the `> **Implementation status (YYYY-MM-DD).**` quote block to `README.md` with the same date.
  - Fill `## Deviations from Design` in `README.md` (or write "None").
  - Flip `status: implemented`.

### Phase 5 — Supersede

When a newer enhancement fully replaces this one, both sides record the link:

- New entry: `supersedes: ["NNNN"]`, `status: draft` (or whatever its current status is).
- Old entry: `superseded_by: "MMMM"`, `status: superseded`.
- Old entry's README gets a top-of-file quote block:
  ```markdown
  > **Superseded by MMMM (YYYY-MM-DD).** Brief migration paragraph: what the new entry changes, where to look for the replacement design, whether any of this entry's decisions carry forward.
  ```

Terminal state. Don't re-edit the rest of the file; the design intent is now `MMMM`'s.

## Cross-references between entries

The `related`, `supersedes`, and `superseded_by` fields accept two token forms:

- **`"NNNN"`** — workspace-root four-digit id. Resolves to `enhancements/NNNN/`.
- **`"legacy:NNN"`** — frozen library predecessor. Resolves to `library/enhancements/NNN-*/`. Use when the historical link is informative — e.g. the new entry inherits the problem statement from a frozen library design but the conclusions diverge.

The validator (`task vet`) flags dangling references. Once the library predecessors are deleted, any `legacy:NNN` reference will start failing — fix or remove at that point.

## Per-status checklist — the binding gate

Notation: **[H]** = hard, enforced by `task vet` (PR-blocking). **[S]** = soft, enforced by `task check` (warns, pre-PR aid).

### `draft`

The cheap-entry state. Be lenient — this is where ideas form.

- **[H]** `id` matches directory name (four digits, no slug suffix)
- **[H]** the six mandatory documents (`README.md`, `01-problem.md`, `02-design.md`, `03-decisions.md`, `04-graduation.md`, `05-risks.md`, `06-operational.md`) exist
- **[H]** no `{Capitalised}` placeholder strings outside code fences, HTML comments, or single-line backtick spans
- **[H]** `area ∈ affects`
- **[H]** `created` set, `updated >= created`
- **[H]** cross-refs (`related`, `supersedes`, `superseded_by`) resolve to existing entries (workspace `NNNN/` or `library/enhancements/NNN-*/`)
- **[H]** `implementation.status ≠ complete` (`complete` is reserved for `implemented`)
- **[H]** `schemas/` compiles via `cue vet ./...`
- **[H]** if `experiments/` exists: index `README.md` is present and every `NN-*/` subdirectory has its own `README.md`

Not required at draft: `semver`, scope section, decisions content, Open Questions list, implementation block.

### `accepted`

Design frozen, ready for slicing.

Everything `draft` requires, plus:

- **[H]** `semver: major | minor | none` set
- **[H]** `implementation.status ∈ {not-started, in-progress, partial}`
- **[S]** `README.md` contains `## Scope` with `### In scope` and `### Out of scope`
- **[S]** `03-decisions.md` contains at least one `### DN:` heading
- **[S]** `03-decisions.md` contains `## Open Questions` block (may say "None")
- **[S]** `04-graduation.md` contains both `## draft → accepted` and `## accepted → implemented` sections

### `implemented`

Code has landed. Status is retrospective — written when the last slice archived.

Everything `accepted` requires, plus:

- **[H]** `implementation.status: complete`
- **[H]** `implementation.date` set
- **[S]** `README.md` contains `> **Implementation status (YYYY-MM-DD).**` quote block, date matching `implementation.date`
- **[S]** `README.md` contains `## …Deviation…` section (may say "None")

### `superseded`

Terminal state.

- **[H]** `superseded_by` set (non-null)
- **[H]** the replacement enhancement's `supersedes` includes this id
- **[S]** `README.md` has top-of-file `> **Superseded by NNNN (YYYY-MM-DD).**` quote block with short migration paragraph

## The Taskfile

All tasks runnable from `enhancements/` directly (`cd enhancements && task <name>`) or via the workspace include (`task enhancements:<name>`).

| Task | Use when |
| --- | --- |
| `task list` | Picking up unfamiliar work — first thing to read. Status table across every entry. |
| `task show ID=NNNN` | Need full metadata + history list + document list for one entry. |
| `task vet` | About to open a PR that touches `enhancements/`. Hard gate; PR-blocking. |
| `task vet:one ID=NNNN` | After editing one entry, before committing. Same hard gate, single entry. |
| `task check [ID=NNNN]` | Before promoting a status (draft → accepted, accepted → implemented). Soft gate; pre-PR aid. |
| `task new SLUG=foo TITLE="Foo Bar" [AREA=cli] [AUTHOR=…]` | Scaffolding a new entry from `0000/`. |
| `task new:experiment ID=NNNN NAME=concept-name` | Scaffolding an experiment inside an entry. **Load `enhancement-experiments` skill first.** |
| `task experiments:list ID=NNNN` | Browsing experiments for one entry; parses `Status:` from each per-experiment README. |
| `task index` | After any `config.yaml` edit — `INDEX.md` is generated, not hand-edited. |
| `task graph` | After any cross-reference edit. `GRAPH.md` is generated, not hand-edited. |

## OpenSpec — sister workflow for slicing

OpenSpec is the per-repo workflow for breaking a single design (defined here, in `enhancements/NNNN/`) into one or more **slices** that land as discrete changes in target repos. Each affected repo (`catalog/`, `library/`, `opm-operator/`, `orca/`, etc.) has its own `openspec/` workspace.

The OpenSpec skills (`openspec-new-change`, `openspec-explore`, `openspec-continue-change`, `openspec-apply-change`, `openspec-verify-change`, `openspec-archive-change`, `openspec-ff-change`, plus utilities) handle the slice lifecycle inside each target repo. The enhancements repo does not enforce a `slices[]` field in `config.yaml` (dropped intentionally — too noisy to maintain across repos). The audit trail lives in `history` events; each affected repo's own OpenSpec workspace is the source of truth for that slice's content.

Workflow:

1. Design the enhancement here (`enhancements/NNNN/`).
2. Promote to `accepted`.
3. For each affected repo, `cd <repo>` and use the openspec skills to draft a slice referencing the enhancement id in its proposal.
4. Implement the slice; archive on completion.
5. Append a `history` event to `enhancements/NNNN/config.yaml` with the slice slug in the optional `slice` field.

## Common pitfalls

- **Forgetting to re-run `task index` after editing `config.yaml`.** `INDEX.md` is generated. Stale `INDEX.md` is the most common drift; run `task index` whenever any `config.yaml` changes.
- **Forgetting to re-run `task graph` after editing cross-references.** Same story for `GRAPH.md`.
- **Writing CUE inside a markdown fence instead of `schemas/target.cue`.** Defeats the validator. If you find yourself pasting a CUE block longer than a few illustrative lines into `02-design.md`, that block belongs in `schemas/target.cue` with a one-line markdown reference.
- **Filling decisions speculatively.** The append-only log means a wrong decision lives forever in the history. Only record decisions after they are made, with their alternatives and source. If unsure, leave it as an Open Question.
- **Half-filling Open Questions.** Each OQ should be a specific question with enough context that someone unfamiliar can answer it. "How does X work?" is too vague — name the design surface, the constraint, and what would resolve it.
- **Editing `library/enhancements/`.** Those entries are frozen predecessors. Any new design intent goes here in `enhancements/NNNN/`.
- **Forking content from the frozen library entries.** Fresh prose. The frozen predecessors are reference material for *why* the new design exists, not source code to copy.
- **Promoting status without running both gates.** `task vet` is mechanical and must pass. `task check` is prose-shape; failing it is acceptable only if the warning is documented in the PR body with a reason for deferring.
- **Editing `core/*.cue` as part of an implementation slice without loading the `core-schema-edit` skill first.** That skill is binding. The pre-commit hook + CI gate will reject the commit. Reading the skill first means the SPEC section format is ready when you write it.
- **Treating `INDEX.md` or `GRAPH.md` as hand-maintained.** They are generated. Hand-edits get clobbered on the next `task index` / `task graph`.

## Source of truth precedence

- Workspace root `/CLAUDE.md` governs cross-repo routing and the area vocabulary.
- `enhancements/CLAUDE.md` orients agents to the repo; this skill is the authoritative protocol.
- Each target repo's own `CLAUDE.md` governs its source code; implementation slices follow those rules.
- When a slice touches `core/`, `core-schema-edit` (at `core/.claude/skills/core-schema-edit/`) is the binding protocol for SPEC.md co-updates.

When guidance conflicts, the most-specific source wins: target repo skill > this skill > target repo CLAUDE.md > workspace root CLAUDE.md.

## Cross-references

- `enhancements/CLAUDE.md` — repo orientation; points here for the full protocol.
- `enhancements/0000/README.md` — template; carries the canonical rules text duplicated inside each new entry.
- `enhancements/schema.cue` — CUE contract that `task vet` validates each `config.yaml` against.
- `enhancements/Taskfile.yml` — workflow tasks source.
- `enhancement-experiments` skill (sibling, under `enhancements/.claude/skills/`) — the experiments protocol.
- `core-schema-edit` skill (`core/.claude/skills/core-schema-edit/`) — the SPEC.md co-update protocol for slices that touch `core/*.cue`.
- `openspec-*` skills (per-repo, under each target repo's `.claude/skills/` or `.opencode/skills/`) — the slice lifecycle in each target repo.
