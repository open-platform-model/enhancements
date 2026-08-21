---
name: enhancements
description: Canonical workflow protocol for the OPM enhancements repo. Load before creating a new enhancement, editing any file under enhancements/NNNN/ (config.yaml, README, the six split documents, schemas/, contracts/), promoting an enhancement's status (draft → accepted → implemented → superseded), appending history events as delivery milestones land, adding cross-references, or running any task in enhancements/Taskfile.yml. Skip only when reading an existing enhancement to learn it — then walk its README and 01..06.
user-invocable: true
---

# Enhancements Workflow

This skill is the **authoritative protocol** for working with OPM enhancement proposals under `enhancements/NNNN/`. The repo's `CLAUDE.md` is the orientation document; this skill is the binding workflow.

## When this skill applies

Load this skill when any of the following is true:

- Creating a new enhancement (about to invoke `task new` or write `enhancements/NNNN/` files).
- Editing an existing enhancement's `config.yaml`, `README.md`, or any of the six split documents (`01-problem.md` through `06-operational.md`).
- Editing anything under `enhancements/NNNN/schemas/` (the core-schema delta) or `enhancements/NNNN/contracts/` (non-core compilable CUE).
- Promoting an enhancement's `status` (draft → accepted → implemented → superseded).
- Recording a new event in `config.yaml.history` as a delivery milestone lands.
- Adding or removing entries in `related`, `supersedes`, `superseded_by`.
- Running any of the workflow tasks (`task vet`, `task check`, `task new`, `task index`, `task graph`, etc.).
- Reviewing whether a design is ready to promote — the per-status checklist below is the binding gate.

Sibling skills carry parallel protocols you may also need to load:

- **`enhancement-experiments`** — when creating, updating, or validating experiments under `enhancements/NNNN/experiments/`.
- **`enhancement-open-questions`** — when resolving an enhancement's Open Questions interactively (one OQ at a time, with context + alternatives + a decision write-back). The walk drafts the `### DN:` block, rewrites the OQ's `Status:` line, optionally tightens `// OQN:` markers in `schemas/target.cue`, and appends a single rolled-up `history` event.
- **`enhancement-compaction`** — the sole path for editing decision bodies on an `accepted` entry (weaving appended reversals into the decisions they reverse, including the mandatory pass immediately before the `implemented` flip), for stubbing a `superseded` entry, and for repairing legacy stacked reversals in older drafts. Routine in-place revision of a `draft` decision does **not** route through it — that is ordinary Phase 2 editing. Never applies to `implemented` entries.
- **`delivery-plans`** — when planning, tracking, or seeding the per-repo delivery of an enhancement via `plans/<slug>/plan.yaml`. Load before `task plans:new`, before editing an existing plan, before deciding whether a multi-repo entry needs one at the `draft → accepted` gate, or before `task plans:seed`. Plans cite this entry's decisions and Open Questions by number; this entry never cites a plan — the one-way rule.
- **`enhancement-diagrams`** — when a design discussion or Open-Questions walk would benefit from a diagram. Mermaid for relationships between enhancements/slices, ASCII for how a single enhancement's design/mechanism works — the two are never interchangeable by default. Load before sketching either, or before adding a diagram to `01-problem.md`/`02-design.md`/`05-risks.md`.
- **`core-schema-edit`** (at `core/.claude/skills/core-schema-edit/`) — when implementing a slice that touches `core/*.cue`. The enhancement's accepted-to-implemented work routes there.

If your task is only to *read* an existing enhancement to learn what was decided, you do not need this skill — open its `README.md`, walk `01-problem.md` through `06-operational.md`, and inspect the compilable CUE under `schemas/` (core entries) or `contracts/`. The skill matters when you are about to *change* something.

## Repo rules — invariants

These hold across every enhancement in the repo. Violations fail PR review even if `task vet` does not catch them.

1. **`config.yaml` is the sole source of metadata.** Do not reintroduce a metadata table to `README.md`. The table was removed by design; `config.yaml` is canonical.
2. **Folder names are id-only.** `0001/`, `0042/` — four digits, zero-padded, no slug suffix. The slug lives in `config.yaml.slug` and surfaces in `INDEX.md`. `0000` is reserved for the template; never repurpose it.
3. **Compilable CUE is pure CUE files, and `schemas/` means exactly one thing: the core-schema delta.** Never write CUE inside a markdown fence longer than a few illustrative lines. `NNNN/schemas/` exists **iff** `config.yaml.core_schema: true` — the enhancement adds or changes `opmodel.dev/core` definitions — and holds `target.cue` (the proposed delta; import published `opmodel.dev/core@vN` for unchanged referenced types where practical, fully restate changed definitions with a delta-manifest header), `examples.cue` (concrete instances + assertions whose unification is the actual test), and `spec.md` (the specification changes, one section per construct in core SPEC.md's four-part Definition/Shape/Constraints/Rationale format — pre-drafting the SPEC.md co-update the core slice will need). `examples.cue` + `spec.md` are hard-required from `accepted`; a compiling `target.cue` suffices at `draft`; `implemented`/`superseded` entries are grandfathered. `core_schema: true` implies `core ∈ affects`. All other compilable CUE — decision procedures, kernel-behaviour contracts, CLI command contracts, taxonomies — lives in the optional `NNNN/contracts/` (`task new:contracts ID=NNNN`), which vet compiles when present but never requires. (One-time exception on record: the 2026-08-20 full-sweep migration to this rule restructured frozen entries' folders and metadata — structure only, no content rewrites; see `CLAUDE.md ## Repository Rules`.)
4. **`config.yaml.history` is append-only.** Never delete or reorder past events. Reversed conclusions get a new event recording the reversal; the original event stays. This is the only strictly append-only structure in the repo — it is short, structured, and it is where provenance is supposed to live.
5. **Decision and OQ *numbers* are immutable; body mutability is status-gated.** `D1`, `D2`, `OQ1`, … are never reused and never renumbered — other repos cite them from commit messages and OpenSpec changes. A number vacated by a merge or retraction keeps a one-line tombstone (`### D18: (merged into D3, YYYY-MM-DD)`) so the citation still resolves. What may happen to the prose under a number depends on `status`:
   - **`draft`** — decision bodies are freely revised **in place**. The log never contains two conflicting decisions: a changed choice is an edit to the existing `DN`, not a new one. If the replaced position was backed by real evidence (an experiment outcome, an explicit user decision), fold it into *Alternatives considered* before overwriting; a mere sketch may be replaced outright.
   - **`accepted`** — decision bodies are **protected**. A change lands as a *new* `DN` carrying `**Amends:**` / `**Supersedes:**` relation fields; the only path to edit an existing body is the `enhancement-compaction` skill (manifest + own commit), at latest in the mandatory weave immediately before the `implemented` flip.
   - **`implemented`** — frozen. **`superseded`** — stubbed via compaction.
6. **`implemented` entries are frozen.** No compaction, no merging, no rewriting. The design shipped; the record is closed. Corrections go in a new enhancement.
7. **Don't hard-wrap prose in `.md` files.** Workspace convention.
8. **Don't reference `library/enhancements/` content directly** when writing new entries. Those are frozen predecessors. Use the `legacy:NNN` cross-ref form in `related` / `supersedes` if the historical link matters.
9. **Don't fork content from the legacy library enhancements.** Fresh prose. The frozen predecessors are reference material for *why* the new design exists, not source code to copy.

## The workflow

```
new → fill problem + design → accrete decisions → freeze (accepted) → ship (implemented) → archive history
```

### Phase 1 — Create

```bash
task new SLUG=my-slug TITLE="My Title"
# Optional: AREA=cli  AUTHOR="Jane Doe"  CORE_SCHEMA=true
```

What the task does:

- Computes the next id from the highest existing `NNNN/` directory (excluding `0000`).
- Copies `0000/` to `NNNN/` — keeping `schemas/` only when `CORE_SCHEMA=true` (the enhancement adds or changes `opmodel.dev/core` definitions); `contracts/` is never auto-copied.
- Fills `config.yaml`: id, slug, title, area (defaults to `cross-cutting`), affects (defaults to `[area]`, plus `core` when `CORE_SCHEMA=true`), `core_schema`, created/updated to today, authors, and seeds `history` with `{date: today, event: "Drafted"}`.
- Replaces `{Enhancement Title}` placeholders across the six split documents + README (+ `schemas/spec.md` when kept).
- Updates `schemas/cue.mod/module.cue` to set `module: "enhancements.opmodel.dev/NNNN/schemas@v0"`.
- Prints the recommended next steps.

After `task new`:

1. Write `01-problem.md` first — full prose. The Concrete Example section is the most important — it makes the problem tangible.
2. Write `02-design.md` next — full prose. Goals and Non-Goals together define the boundary; the High-Level Approach should be understandable without deep implementation knowledge.
3. Core-schema entries (`core_schema: true`): sketch the delta in `schemas/target.cue` — delta-manifest header (each definition marked NEW or CHANGED vs core), unresolved fields marked with `// OQN:` comments pointing at the corresponding Open Question in `03-decisions.md`. Grow `examples.cue` and `spec.md` alongside; both are required before `draft → accepted`. Non-core entries with compilable-CUE needs: `task new:contracts ID=NNNN`.
4. Seed `03-decisions.md ## Open Questions` with the questions the design surfaces. Fill `## Decisions` iteratively as choices land.
5. Update `04-graduation.md`, `05-risks.md`, `06-operational.md` as the design firms up. They start as scaffolds and mature alongside the decision log.
6. Before opening a PR: `task vet:one ID=NNNN && task index`.

### Phase 2 — Iterate

Every meaningful edit:

- Bumps `config.yaml.updated` to today's date (ISO 8601, `YYYY-MM-DD`).
- May add a new event to `history` if the edit captures a milestone (e.g. "Decisions D1..D5 locked", "Schema spike concluded", "Open Question OQ3 resolved by D7"). Don't add history events for typo fixes or routine prose edits.
- Tightens the CUE under `schemas/` (and `contracts/`) as decisions resolve `OQ` markers; on core entries, keeps `examples.cue` exercising every changed definition and `spec.md` in step with the delta.

Decisions are written **after** they are made, not speculatively, and only if they pass the **Kind admission test**: *if every affected repo were rewritten from scratch, would this decision still bind the result?* Three kinds pass — `contract` (changes what a consumer can observe or rely on), `policy` (a posture OPM commits to), `scope` (a boundary decision). A *mechanism* decision (how a repo achieves the contract) fails the test and belongs in the implementing slice's OpenSpec change in the target repo. Measured evidence that constrains a contract stays here, attached to the decision it constrains. The format is fixed:

```markdown
### DN: {Decision Title}

**Kind:** {contract | policy | scope}

**Decision:** {What was decided. State it as a fact.}

**Alternatives considered:**

- {Alternative A and why it was not chosen}
- {Alternative B and why it was not chosen}

**Rationale:** {Why this decision was made.}

**Source:** {User decision YYYY-MM-DD | URL | file path | experiment outcome}
```

Source is specific. "User decision 2026-05-23" beats "discussion"; an experiment outcome reference (`enhancements/NNNN/experiments/01-name/`) beats a vague "validated".

**While the entry is `draft`, a changed decision is an in-place edit.** Rewrite the affected `### DN:` block to state the new choice — never append a second decision that conflicts with an existing one. When the position being replaced was backed by real evidence (an experiment outcome, an explicit user decision), fold it into *Alternatives considered* marked as previously adopted, and optionally add a `**Revised:** YYYY-MM-DD — {what changed}` line; a position that was only ever a sketch may be replaced outright. The keep/drop test applies at write time: keep what would change a future decision, drop what only records that we changed our mind. A decision that is genuinely retracted — nothing replaces it — keeps its number as a tombstone (`### DN: (retracted, YYYY-MM-DD)` plus one line on why), never a deleted heading.

**When resolving Open Questions interactively, load `enhancement-open-questions`.** It walks each OQ one at a time, drafts the four-field decision block in the format above, rewrites the OQ's `Status:` line, prompts for `// OQN:` marker edits in the `schemas/`/`contracts/` CUE (with `cue vet` in the same pass), and appends a single rolled-up `history` event at the end. Use `task questions:open ID=NNNN` to inspect the walk queue without entering the skill.

**Reach for a diagram during design discussion, not just during the OQ walk.** Discussing High-Level Approach, Schema/API Surface, Integration Points, or Before/After is exactly where a picture often settles a question faster than prose. Load `enhancement-diagrams` — Mermaid for how this entry relates to others, ASCII for how its design/mechanism actually works.

### Phase 3 — Promote `draft → accepted`

The hard gate:

```bash
task vet:one ID=NNNN          # MUST pass
task check ID=NNNN            # SHOULD pass; document any deferred warnings in the PR body
```

Before promoting:

- Every **contract-level** Open Question is resolved (`resolved-by-D##`, `deferred-to-NNNN`, or `answered`); implementation-level questions may instead close as `deferred-to-implementation` with the context a future implementer needs attached — never naming the inheritor (the slice that picks one up claims it from the plans side; `task plans:deferred` reports unclaimed ones). Use `task questions:open ID=NNNN` to check the queue; if it returns rows, walk them with the `enhancement-open-questions` skill before promoting.
- Every decision (D1..DN) has the `**Kind:**` line (contract | policy | scope) and the four-field format, and passes the admission test — mechanism decisions have been moved to the implementing slices.
- Core entries (`core_schema: true`): `schemas/` compiles cleanly, `examples.cue` carries concrete instances exercising every NEW/CHANGED definition, and `spec.md` drafts the full spec delta — `task vet` hard-enforces the file presence the moment `status` flips to `accepted`. Non-core entries: no `schemas/` exists; any `contracts/` compiles.
- `config.yaml.semver` is set (`major | minor | none`).
- `config.yaml.affects` lists every repo that ships code/schema/content changes; `area` appears in `affects`.
- `README.md ## Scope` has `### In scope` + `### Out of scope`.
- `04-graduation.md` has both `## draft → accepted` and `## accepted → implemented` sections filled.
- `05-risks.md` has concrete content (not placeholders) for Risks / Drawbacks / Alternatives.
- `06-operational.md` answers the five PRR prompts.
- Cross-References table in `README.md` lists the design documents and sibling entries the reader needs — not implementation file paths (that construction detail belongs to the delivery plan's slices).
- **If `config.yaml.affects` spans more than one repo, decide whether the design needs a delivery plan.** Not required — but this is the natural moment: `06-operational.md ## Cross-Repo Coordination` states the ordering constraints, and if they are real, load `delivery-plans` and run `task plans:new SLUG=<slug> IMPLEMENTS=NNNN`. The plan lives under `plans/` and cites this entry; this entry never cites the plan. `task plans:vet` nudges (does not block) when an accepted multi-repo entry has no plan.
- **Run a compaction pass** (`task compact:plan ID=NNNN`, then the `enhancement-compaction` skill) as a separate commit before the flip. The gate already forces you to touch every Open Question, so collapsing resolved OQ prose costs nothing extra. A draft maintained under the in-place rule should have no stacked reversals to weave; if `compact:plan` finds some anyway (legacy entries, imported habits), weave them now — the flip to `accepted` protects decision bodies.

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

- Append `history` events naming each landing milestone **in plan-blind wording** — say what became true ("Library kernel rewired: acquire-time version check shipped"), never which plan, slice, or OpenSpec change delivered it. The one-way rule: plans cite enhancements; enhancements never cite plans. (The legacy `slice` field on history events predates this rule — never write it in new events.)
- **The delivery record lives on the plans side.** If a delivery plan implements this entry, the landed slice's `status: done` and `openspec_ref` are set in `plans/<slug>/plan.yaml` — see the `delivery-plans` skill. This entry only accumulates its own milestones.
- For slices that land in `core/*.cue`: **load `core-schema-edit` first.** That skill enforces the SPEC.md co-update protocol. Skipping it gets the commit rejected by the pre-commit hook + CI gate.
- Decision bodies are **protected** while the entry is `accepted` — slices routinely reveal that an earlier choice was wrong, and that change lands as a *new* `DN` with `**Amends:**` / `**Supersedes:**` relation fields, never as a direct edit to the old body. The appended decision is visible in review and shows up in `task plans:uncovered` until a slice carries it. Weave the stacked reversals into the decisions they reverse via `enhancement-compaction` (own commit) as they land, or at latest in the mandatory pre-flip pass. **This is the last chance:** the flip to `implemented` freezes the entry permanently, so anything left stacked stays stacked.
- When everything in scope has shipped:
  - Run a final compaction pass **before** the flip, while the entry is still `accepted`.
  - Set `implementation.status: complete` with `date` matching the final landing date.
  - Add the `> **Implementation status (YYYY-MM-DD).**` quote block to `README.md` with the same date.
  - Fill `## Deviations from Design` in `README.md` (or write "None").
  - Flip `status: implemented`. **The entry is now frozen** — no further compaction, ever. Corrections go in a new enhancement.

### Phase 5 — Supersede

When a newer enhancement fully replaces this one, both sides record the link:

- New entry: `supersedes: ["NNNN"]`, `status: draft` (or whatever its current status is).
- Old entry: `superseded_by: "MMMM"`, `status: superseded`.
- Old entry's README gets a top-of-file quote block:
  ```markdown
  > **Superseded by MMMM (YYYY-MM-DD).** Brief migration paragraph: what the new entry changes, where to look for the replacement design, whether any of this entry's decisions carry forward.
  ```

Terminal state — the design intent is now `MMMM`'s. Don't keep developing the entry, but do **compact it** (`enhancement-compaction`): the narrative documents collapse to pointers at the successor, while the decision log keeps its numbers and its *Alternatives considered* so `MMMM` does not re-litigate ground this entry already settled. `experiments/` and `research/` stay untouched — the measurements are usually the expensive part and they remain valid evidence.

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
- **[H]** `core_schema` set; `schemas/` exists **iff** it is `true`, contains `target.cue`, and compiles via `cue vet ./...`; when `true`, `core ∈ affects`
- **[H]** `contracts/`, when present, is non-empty and compiles via `cue vet ./...`
- **[H]** if `experiments/` exists: index `README.md` is present and every `NN-*/` subdirectory has its own `README.md`
- **[H]** no `plan.yaml` or `PLAN.md` inside the entry — delivery plans live in `plans/<slug>/` (the one-way rule)

Not required at draft: `semver`, scope section, decisions content, Open Questions list, implementation block.

### `accepted`

Design frozen, ready for slicing.

Everything `draft` requires, plus:

- **[H]** `semver: major | minor | none` set
- **[H]** `implementation.status ∈ {not-started, in-progress, partial}`
- **[H]** if `core_schema: true`: `schemas/spec.md` exists and `schemas/` has at least one companion `.cue` beside `target.cue` (convention: `examples.cue`)
- **[S]** `README.md` contains `## Scope` with `### In scope` and `### Out of scope`
- **[S]** `03-decisions.md` contains at least one `### DN:` heading
- **[S]** `03-decisions.md` contains `## Open Questions` block (may say "None")
- **[S]** `04-graduation.md` contains both `## draft → accepted` and `## accepted → implemented` sections
- **[S]** no `*.md` names a plan file, every decision carries `**Kind:**` (checked on drafts), mechanism smells and missing evidence warned (see `task check`'s summary); the delivery-plan coverage nudge for accepted multi-repo entries lives in `task plans:vet` (see `delivery-plans`)

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
| `task questions:list ID=NNNN` | Listing `## Open Questions` for one entry — grouped by `### ` subheading, classified into open / partial / resolved buckets. Human-readable. |
| `task questions:open ID=NNNN` | TSV of unresolved Open Questions (open + partial). Consumed by the `enhancement-open-questions` skill walk. |
| `task compact:plan ID=NNNN` | TSV of compaction candidates — stacked reversals, resolved OQs still carrying prose, relation trailers in headings. Consumed by the `enhancement-compaction` skill. Read-only; it proposes nothing and writes nothing. |
| `task index` | After any `config.yaml` edit — `INDEX.md` is generated, not hand-edited. |
| `task graph` | After any cross-reference edit. `GRAPH.md` is generated, not hand-edited. |
| `task plans:*` | Delivery-plan tasks (`new`, `vet`, `graph`, `ready`, `uncovered`, `deferred`, `seed`) — operate on `plans/<slug>/`, never inside an entry. **Load the `delivery-plans` skill first.** |

## OpenSpec — sister workflow for slicing

OpenSpec is the per-repo workflow for breaking a single design (defined here, in `enhancements/NNNN/`) into one or more **slices** that land as discrete changes in target repos. Each affected repo (`catalog/`, `library/`, `opm-operator/`, `orca/`, etc.) has its own `openspec/` workspace.

The OpenSpec skills (`openspec-new-change`, `openspec-explore`, `openspec-continue-change`, `openspec-apply-change`, `openspec-verify-change`, `openspec-archive-change`, `openspec-ff-change`, plus utilities) handle the slice lifecycle inside each target repo. `config.yaml` carries no `slices[]` field, and the delivery plan lives in `plans/<slug>/` (see `delivery-plans`) — not inside the entry. The landing record is the plan; the enhancement's `history` records milestones in plan-blind wording; each affected repo's own OpenSpec workspace is the source of truth for that slice's content.

Workflow:

1. Design the enhancement here (`enhancements/NNNN/`).
2. Promote to `accepted`. If `affects` spans more than one repo and the landing order needs tracking, scaffold a delivery plan (`task plans:new SLUG=<slug> IMPLEMENTS=NNNN`, under the `delivery-plans` skill).
3. For each affected repo, `cd <repo>` and use the openspec skills to draft a slice referencing the enhancement id in its proposal. If a plan slice exists for it, `task plans:seed SLUG=<slug> SLICE=<id>` prints a stub to hand to that repo's `openspec new`.
4. Implement the slice; archive on completion.
5. Record the landing on the plans side (`status: done` + `openspec_ref` in `plans/<slug>/plan.yaml`). Append a milestone `history` event here only when the entry itself reaches a milestone worth recording — in plan-blind wording, never citing the slice or the OpenSpec slug.

## Common pitfalls

- **Forgetting to re-run `task index` after editing `config.yaml`.** `INDEX.md` is generated. Stale `INDEX.md` is the most common drift; run `task index` whenever any `config.yaml` changes.
- **Forgetting to re-run `task graph` after editing cross-references.** Same story for `GRAPH.md`.
- **Writing CUE inside a markdown fence instead of a compilable file.** Defeats the validator. If you find yourself pasting a CUE block longer than a few illustrative lines into `02-design.md`, that block belongs in a `.cue` file with a one-line markdown reference — in `schemas/` when it is (part of) the core-schema delta, in `contracts/` otherwise.
- **Putting non-core CUE in `schemas/`, or a core delta in `contracts/`.** `schemas/` has exactly one meaning — the `opmodel.dev/core` delta gated by `core_schema` — and vet enforces its presence in both directions. A decision procedure or Go-behaviour contract wearing `#Def` syntax is `contracts/` material; a proposed core definition hiding in `contracts/` dodges the examples/spec.md gate.
- **Filling decisions speculatively.** On a draft the fix is cheap — revise the block in place — but until then a wrong decision misleads whoever reads the log next, and once the entry is `accepted` unwinding it costs an amending `DN` plus a compaction pass. Only record decisions after they are made, with their alternatives and source. If unsure, leave it as an Open Question.
- **Revising a draft decision carelessly.** In-place revision is the normal Phase 2 move, but it has two hard edges: an evidence-backed old position folds into *Alternatives considered* (deleting it guarantees someone re-proposes it), and a retracted number keeps a tombstone heading — it never silently disappears.
- **Editing an `accepted` entry's decision body directly.** Protected means protected: the change is a new `DN` with a relation field, and existing bodies move only through `enhancement-compaction` with its manifest and its own commit. A direct edit after acceptance is exactly how a design record gets quietly laundered to agree with whatever was just built.
- **Half-filling Open Questions.** Each OQ should be a specific question with enough context that someone unfamiliar can answer it. "How does X work?" is too vague — name the design surface, the constraint, and what would resolve it.
- **Editing `library/enhancements/`.** Those entries are frozen predecessors. Any new design intent goes here in `enhancements/NNNN/`.
- **Forking content from the frozen library entries.** Fresh prose. The frozen predecessors are reference material for *why* the new design exists, not source code to copy.
- **Promoting status without running both gates.** `task vet` is mechanical and must pass. `task check` is prose-shape; failing it is acceptable only if the warning is documented in the PR body with a reason for deferring.
- **Editing `core/*.cue` as part of an implementation slice without loading the `core-schema-edit` skill first.** That skill is binding. The pre-commit hook + CI gate will reject the commit. Reading the skill first means the SPEC section format is ready when you write it.
- **Treating `INDEX.md` or `GRAPH.md` as hand-maintained.** They are generated. Hand-edits get clobbered on the next `task index` / `task graph`. Same for `plans/<slug>/PLAN.md` — generated by `task plans:graph`.
- **Writing a plan pointer into the entry.** No history event cites a slice or OpenSpec slug, no doc names a plan file, no `plan.yaml` lives inside an entry — `task vet` fails the file, `task check` warns on the prose. Plans cite enhancements; enhancements never cite plans.
- **Scaffolding a delivery plan for every multi-repo entry regardless of need.** Same discipline as `experiments/`: only add one once `06-operational.md`'s ordering constraints are real, not upfront.
- **Recording a mechanism decision.** If it would not bind a from-scratch rewrite of the affected repos, it is not a `DN` — it belongs in the implementing slice's OpenSpec change. `task check` flags file:line refs and function() tokens in the decision log as smells.
- **Using Mermaid for a design/mechanism diagram, or ASCII for an entity-relationship graph.** The medium follows content shape — see `enhancement-diagrams`. Swapping either direction is the specific mistake that skill exists to prevent.
- **A bordered ASCII diagram whose alignment drifted after an edit.** Fixed-width box borders are fragile — `0012/02-design.md`'s rung ladder (73 characters wide) is the cautionary example. Re-check row widths after any edit, or prefer arrow/column layouts that don't have this failure mode.

## Source of truth precedence

- Workspace root `/CLAUDE.md` governs cross-repo routing and the area vocabulary.
- `enhancements/CLAUDE.md` orients agents to the repo; this skill is the authoritative protocol.
- Each target repo's own `CLAUDE.md` governs its source code; implementation slices follow those rules.
- When a slice touches `core/`, `core-schema-edit` (at `core/.claude/skills/core-schema-edit/`) is the binding protocol for SPEC.md co-updates.

When guidance conflicts, the most-specific source wins: target repo skill > this skill > target repo CLAUDE.md > workspace root CLAUDE.md.

## Cross-references

- `enhancements/CLAUDE.md` — repo orientation; points here for the full protocol.
- `enhancements/0000/README.md` — template; carries the canonical rules text duplicated inside each new entry.
- `enhancements/schema.cue` — CUE contract that `task vet` validates each `config.yaml` against (`plans/schema.cue` is the plan-side counterpart).
- `enhancements/Taskfile.yml` — workflow tasks source.
- `enhancement-experiments` skill (sibling, under `enhancements/.claude/skills/`) — the experiments protocol.
- `enhancement-open-questions` skill (sibling, under `enhancements/.claude/skills/`) — the interactive OQ-walk protocol; load when resolving Open Questions one at a time, especially before promoting `draft → accepted`.
- `enhancement-compaction` skill (sibling, under `enhancements/.claude/skills/`) — the compaction protocol; the only body-edit path on `accepted` entries. Load before weaving an appended reversal into the decision it reverses, collapsing resolved OQ prose, or stubbing a superseded entry.
- `delivery-plans` skill (sibling, under `enhancements/.claude/skills/`) — the delivery-plan protocol; load before scaffolding or editing `plans/<slug>/plan.yaml`, or before `task plans:seed`.
- `enhancement-diagrams` skill (sibling, under `enhancements/.claude/skills/`) — the diagram protocol; load before sketching a relationship (Mermaid) or design/mechanism (ASCII) diagram, live or persisted.
- `core-schema-edit` skill (`core/.claude/skills/core-schema-edit/`) — the SPEC.md co-update protocol for slices that touch `core/*.cue`.
- `openspec-*` skills (per-repo, under each target repo's `.claude/skills/` or `.opencode/skills/`) — the slice lifecycle in each target repo.
