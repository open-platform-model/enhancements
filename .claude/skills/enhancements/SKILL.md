---
name: enhancements
description: Canonical workflow protocol for the OPM enhancements repo. Load before creating a new enhancement, editing any file under enhancements/NNNN/ (config.yaml, README, the six split documents, schemas/, contracts/), promoting an enhancement's status (draft to accepted via task promote, or killing it via task reject), appending history events, adding depends_on / **Depends:** edges, or running any task in enhancements/Taskfile.yml. Skip only when reading an existing enhancement to learn it — then walk its README and 01..07.
user-invocable: true
---

# Enhancements Workflow

This skill is the **authoritative protocol** for working with OPM enhancement proposals under `enhancements/NNNN/`. The repo's `CLAUDE.md` is the orientation document; this skill is the binding workflow.

## When this skill applies

Load this skill when any of the following is true:

- Creating a new enhancement (about to invoke `task new` or write `enhancements/NNNN/` files).
- Editing an existing enhancement's `config.yaml`, `README.md`, or any of the seven split documents (`01-problem.md` through `07-questions.md`).
- Editing anything under `enhancements/NNNN/schemas/` (the core-schema delta) or `enhancements/NNNN/contracts/` (non-core compilable CUE).
- Promoting an enhancement's `status` (`draft → accepted` via `task promote`, or killing it via `task reject`).
- Appending an event to `config.yaml.history` (history records design milestones; landings go to the entry's `delivery.yaml`).
- Adding or removing entries in `depends_on`, `supersedes`, `superseded_by`, `revives`, or a `**Depends:**` line in a decision.
- Running any of the workflow tasks (`task vet`, `task check`, `task new`, `task index`, `task graph`, etc.).
- Reviewing whether a design is ready to promote — the per-status checklist below is the binding gate.

Sibling skills carry parallel protocols you may also need to load:

- **`enhancement-gates`** — the admission rubric (`gates.cue`). Load before creating an entry and before promoting; it is the only path to the `.gates/NNNN.yaml` verdict `task promote` requires.
- **`enhancement-experiments`** — when creating, updating, or validating experiments under `enhancements/NNNN/experiments/`.
- **`enhancement-open-questions`** — when resolving an enhancement's Open Questions interactively (one OQ at a time, with context + alternatives + a decision write-back). The walk drafts the `### DN:` block, rewrites the OQ's `Status:` line, optionally tightens `// OQN:` markers in `schemas/target.cue`, and appends a single rolled-up `history` event.
- **`enhancement-compaction`** — the sole path for editing decision bodies on an `accepted` entry (weaving appended reversals into the decisions they reverse, including the mandatory pass before the entry derives `implemented`), for stubbing a `superseded` entry, and for repairing legacy stacked reversals in older drafts. Routine in-place revision of a `draft` decision does **not** route through it — that is ordinary Phase 2 editing. Never applies to `implemented` entries.
- **`delivery-log`**: the protocol for the entry's append-only implementation log (`NNNN/delivery.yaml`). Load before running `task delivery:log` (after archiving an OpenSpec change, or for a PR/commit landing), before editing any `delivery.yaml` or its `no_work` map, or before writing an `enhancement.yaml` declaration into a target repo's change. The log records landed changes only; nothing is written before work lands.
- **`enhancement-diagrams`** — when a design discussion or Open-Questions walk would benefit from a diagram. Mermaid for relationships between enhancements, ASCII for how a single enhancement's design/mechanism works — the two are never interchangeable by default. Load before sketching either, or before adding a diagram to `01-problem.md`/`02-design.md`/`05-risks.md`.
- **`core-schema-edit`** (at `core/.claude/skills/core-schema-edit/`) — when implementing a change that touches `core/*.cue`. The enhancement's accepted-to-implemented work routes there.

If your task is only to *read* an existing enhancement to learn what was decided, you do not need this skill — open its `README.md`, walk `01-problem.md` through `07-questions.md`, and inspect the compilable CUE under `schemas/` (core entries) or `contracts/`. The skill matters when you are about to *change* something.

## Repo rules — invariants

These hold across every enhancement in the repo. Violations fail PR review even if `task vet` does not catch them.

1. **`config.yaml` is the sole source of metadata.** Do not reintroduce a metadata table to `README.md`. The table was removed by design; `config.yaml` is canonical.
2. **Folder names are id-only.** `0001/`, `0042/` — four digits, zero-padded, no slug suffix. The slug lives in `config.yaml.slug` and surfaces in `INDEX.md`. `0000` is reserved for the template; never repurpose it.
3. **Compilable CUE is pure CUE files, and `schemas/` means exactly one thing: the core-schema delta.** Never write CUE inside a markdown fence longer than a few illustrative lines. `NNNN/schemas/` exists **iff** `config.yaml.core_schema: true` — the enhancement adds or changes `opmodel.dev/core` definitions — and holds `target.cue` (the proposed delta; import published `opmodel.dev/core@vN` for unchanged referenced types where practical, fully restate changed definitions with a delta-manifest header), `examples.cue` (concrete instances + assertions whose unification is the actual test), and `spec.md` (the specification changes, one section per construct in core SPEC.md's four-part Definition/Shape/Constraints/Rationale format — pre-drafting the SPEC.md co-update the core change will need). `examples.cue` + `spec.md` are hard-required from `accepted`; a compiling `target.cue` suffices at `draft`; an entry that already derives `implemented` is exempt, its spec having landed in `core/SPEC.md`. `core_schema: true` implies `core ∈ affects`. All other compilable CUE — decision procedures, kernel-behaviour contracts, CLI command contracts, taxonomies — lives in the optional `NNNN/contracts/` (`task new:contracts ID=NNNN`), which vet compiles when present but never requires. (One-time exception on record: the 2026-08-20 full-sweep migration to this rule restructured frozen entries' folders and metadata — structure only, no content rewrites; see `CLAUDE.md ## Repository Rules`.)
4. **`config.yaml.history` is append-only.** Never delete or reorder past events. Reversed conclusions get a new event recording the reversal; the original event stays. This is the only strictly append-only structure in the repo — it is short, structured, and it is where provenance is supposed to live.
5. **Decision and OQ *numbers* are immutable; body mutability is status-gated.** `D1`, `D2`, `OQ1`, … are never reused and never renumbered — other repos cite them from commit messages and OpenSpec changes. A number vacated by a merge or retraction keeps a one-line tombstone (`### D18: (merged into D3, YYYY-MM-DD)`) so the citation still resolves. What may happen to the prose under a number depends on `status`:
   - **`draft`** — decision bodies are freely revised **in place**. The log never contains two conflicting decisions: a changed choice is an edit to the existing `DN`, not a new one. If the replaced position was backed by real evidence (an experiment outcome, an explicit user decision), fold it into *Alternatives considered* before overwriting; a mere sketch may be replaced outright.
   - **`accepted`** — decision bodies are **protected**. A change lands as a *new* `DN` carrying `**Amends:**` / `**Supersedes:**` relation fields; the only path to edit an existing body is the `enhancement-compaction` skill (manifest + own commit), at latest in the mandatory weave before the entry derives `implemented`.
   - **implemented** (derived, not a status) — closed. `task compact:plan` refuses it. **`superseded`** — archived via `task supersede`, then stubbed via compaction. **`rejected`** — archived as it stood. Both terminal states ALWAYS live in `archive/NNNN/`; `task vet` fails a terminal entry left in place.
6. **An implemented design is closed.** No compaction, no merging, no rewriting: `task delivery` reports the derived state and `task compact:plan` refuses the entry. Corrections go in a new enhancement.
7. **The entry stores rules and intent; every changing fact is derived.** Delivery state derives from the entry's own append-only `delivery.yaml` log (the one execution record an entry carries, and it is append-only facts, not status churn), maturity from the published artifact's `apiVersion`, the gate verdict from a walk bound to a content hash. Before adding a field to `config.yaml`, ask whether its value would need updating after the design is done. If yes, it does not belong.
7. **Don't hard-wrap prose in `.md` files.** Workspace convention.
8. **Don't reference `library/enhancements/` content directly** when writing new entries. Those are frozen predecessors. Use the `legacy:NNN` cross-ref form in `supersedes` / `revives` if the historical link matters; `depends_on` cannot target a legacy entry, because a dependency resolves to a decision heading and the legacy entries have none.
9. **Don't fork content from the legacy library enhancements.** Fresh prose. The frozen predecessors are reference material for *why* the new design exists, not source code to copy.

## The workflow

```
admit (gates) → new → problem + design → accrete decisions → walk gates → promote (accepted) → implement in repos, log landings in delivery.yaml
```

### Phase 0 — Admit

**Before scaffolding anything, decide whether this is an enhancement at all.** An enhancement is a new feature, or the rework of an existing one. It is not a chore, not a logbook, and not a place to prescribe how a repo builds something.

Load `enhancement-gates` and walk the `creation` rules from `gates.cue`: `feature`, `contract`, `single-question`, `prior-art`. Check `task archive:data` — if this restates a rejected idea, set `revives: ["NNNN"]` and say what changed, or drop it.

If it fails `feature`, it becomes a GitHub issue labelled `idea` (the form at `.github/ISSUE_TEMPLATE/idea.yml` applies the label). The label exists so this gate has somewhere to send what it declines; without it, a declined idea gets scaffolded anyway and becomes the scratchpad.

### Phase 1 — Create

```bash
task new SLUG=my-slug TITLE="My Title" \
  SUMMARY="the capability OPM will have and does not today" \
  NOT="what this is explicitly not"
# Optional: AREA=cli  AUTHOR="Jane Doe"  CORE_SCHEMA=true  ISSUE=<idea issue number>
```

`SUMMARY` and `NOT` are **required**. They are the `feature` gate's answer and the scope boundary, made durable: `SUMMARY` becomes `config.yaml.summary` (which `task list`, `INDEX.md` and the archive listing all render), and `NOT` seeds `README.md ### Out of scope`. Scaffolding eight files without them is where the drift starts.

What the task does:

- Computes the next id from the highest existing `NNNN/` directory, **`archive/` included** — an id is never reused, because reissuing a killed one would silently retarget every citation of it.
- Copies `0000/` to `NNNN/` — keeping `schemas/` only when `CORE_SCHEMA=true` (the enhancement adds or changes `opmodel.dev/core` definitions); `contracts/` is never auto-copied.
- Fills `config.yaml`: id, slug, title, area (defaults to `cross-cutting`), affects (defaults to `[area]`, plus `core` when `CORE_SCHEMA=true`), `core_schema`, created/updated to today, authors, and seeds `history` with `{date: today, event: "Drafted"}`.
- Replaces `{Enhancement Title}` placeholders across the seven split documents + README (+ `schemas/spec.md` when kept).
- Updates `schemas/cue.mod/module.cue` to set `module: "enhancements.opmodel.dev/NNNN/schemas@v0"`.
- Prints the recommended next steps.

After `task new`:

1. Write `01-problem.md` first — full prose. The Concrete Example section is the most important — it makes the problem tangible.
2. Write `02-design.md` next — full prose. Goals and Non-Goals together define the boundary; the High-Level Approach should be understandable without deep implementation knowledge.
3. Core-schema entries (`core_schema: true`): sketch the delta in `schemas/target.cue` — delta-manifest header (each definition marked NEW or CHANGED vs core), unresolved fields marked with `// OQN:` comments pointing at the corresponding Open Question in `07-questions.md`. Grow `examples.cue` and `spec.md` alongside; both are required before `draft → accepted`. Non-core entries with compilable-CUE needs: `task new:contracts ID=NNNN`.
4. Seed `07-questions.md ## Open Questions` with the questions the design surfaces. Fill `03-decisions.md ## Decisions` iteratively as choices land. The register is the **single canonical location** — `task vet` fails an `## Open Questions` block in `03-decisions.md` or `README.md`.
5. Update `04-graduation.md`, `05-risks.md` and `06-operational.md` as the design firms up. They start as scaffolds and mature alongside the decision log. `04-graduation.md` carries only the criteria specific to THIS design — repo-wide checks live in `gates.cue` and `task vet`, and per-question blocking rules live on the question in `07-questions.md`.
6. Before opening a PR: `task vet:one ID=NNNN && task index`.

### Phase 2 — Iterate

Every meaningful edit:

- Bumps `config.yaml.updated` to today's date (ISO 8601, `YYYY-MM-DD`).
- May add a new event to `history` if the edit captures a milestone (e.g. "Decisions D1..D5 locked", "Schema spike concluded", "Open Question OQ3 resolved by D7"). Don't add history events for typo fixes or routine prose edits.
- Tightens the CUE under `schemas/` (and `contracts/`) as decisions resolve `OQ` markers; on core entries, keeps `examples.cue` exercising every changed definition and `spec.md` in step with the delta.

Decisions are written **after** they are made, not speculatively, and only if they pass the **Kind admission test**: *if every affected repo were rewritten from scratch, would this decision still bind the result?* Three kinds pass — `contract` (changes what a consumer can observe or rely on), `policy` (a posture OPM commits to), `scope` (a boundary decision). A *mechanism* decision (how a repo achieves the contract) fails the test and belongs in the implementing OpenSpec change in the target repo. Measured evidence that constrains a contract stays here, attached to the decision it constrains. The format is fixed:

```markdown
### DN: {Decision Title}

**Kind:** {contract | policy | scope}

**Depends:** {MMMM:DN, MMMM:DN; only when this decision rests on another entry's decision}

**Decision:** {What was decided. State it as a fact.}

**Alternatives considered:**

- {Alternative A and why it was not chosen}
- {Alternative B and why it was not chosen}

**Rationale:** {Why this decision was made.}

**Source:** {User decision YYYY-MM-DD | URL | file path | experiment outcome}
```

Source is specific. "User decision 2026-05-23" beats "discussion"; an experiment outcome reference (`enhancements/NNNN/experiments/01-name/`) beats a vague "validated".

`**Depends:**` is optional and tokens-only (`MMMM:DN`, comma-separated, no prose). It is owed when the decision rests on another entry's decision: *if that decision were reversed, would this one need an `Amends:`?* A citation for precedent, contrast, or a delegated enforcement site is prose, not a dependency. Every entry the lines name goes in `config.yaml.depends_on`, and nothing else does; `task vet` enforces both directions, requires each target to be a live heading in that entry's log, and refuses a cycle.

**While the entry is `draft`, a changed decision is an in-place edit.** Rewrite the affected `### DN:` block to state the new choice — never append a second decision that conflicts with an existing one. When the position being replaced was backed by real evidence (an experiment outcome, an explicit user decision), fold it into *Alternatives considered* marked as previously adopted, and optionally add a `**Revised:** YYYY-MM-DD — {what changed}` line; a position that was only ever a sketch may be replaced outright. The keep/drop test applies at write time: keep what would change a future decision, drop what only records that we changed our mind. A decision that is genuinely retracted — nothing replaces it — keeps its number as a tombstone (`### DN: (retracted, YYYY-MM-DD)` plus one line on why), never a deleted heading.

**When resolving Open Questions interactively, load `enhancement-open-questions`.** It walks each OQ one at a time, drafts the four-field decision block in the format above, rewrites the OQ's `Status:` line, prompts for `// OQN:` marker edits in the `schemas/`/`contracts/` CUE (with `cue vet` in the same pass), and appends a single rolled-up `history` event at the end. Use `task questions:open ID=NNNN` to inspect the walk queue without entering the skill.

**Reach for a diagram during design discussion, not just during the OQ walk.** Discussing High-Level Approach, Schema/API Surface, Integration Points, or Before/After is exactly where a picture often settles a question faster than prose. Load `enhancement-diagrams` — Mermaid for how this entry relates to others, ASCII for how its design/mechanism actually works.

### Phase 3 — Promote `draft → accepted`

Promotion is no longer a hand edit to `status:`. It is a command that refuses:

```bash
task gate ID=NNNN             # what the rubric asks, and what already fails
# walk the rubric with the `enhancement-gates` skill -> writes .gates/NNNN.yaml
task promote ID=NNNN          # refuses unless everything below holds
```

`task promote` checks four things itself, so this list is enforced rather than remembered:

- `task vet:one` passes.
- No Open Question is still marked `Blocking: acceptance` in `07-questions.md`. (Implementation-level questions close as `deferred-to-implementation` with the context a future implementer needs, never naming the inheritor; the change that later picks one up claims it via `resolves` in its `delivery.yaml` log entry.)
- `config.yaml.semver` is set.
- `.gates/NNNN.yaml` records a **pass for every promotion gate**, with an `entry_hash` matching current content. Edit the entry after the walk and the verdict is void; re-walk.

What the gate walk does not check, and you still should:

- Every decision carries `**Kind:**` and passes the admission test — mechanism decisions moved to the implementing changes.
- Core entries (`core_schema: true`): `schemas/` compiles, `examples.cue` exercises every NEW/CHANGED definition, `spec.md` drafts the delta. `task vet` enforces file presence at `accepted` unless the entry already derives `implemented`.
- `04-graduation.md ## draft → accepted` is filled with the criteria specific to THIS design and every one of them holds. Repo-wide checks do not belong there (`gates.cue` owns those) and neither do per-question blocking rules (`07-questions.md` owns those) — what belongs is what is true of this entry and no other.
- `README.md ## Scope` has `### In scope` + `### Out of scope`.
- `05-risks.md` and `06-operational.md` carry concrete content.
- `config.yaml.affects` lists every repo that ships changes; `area ∈ affects`.
- **Scaffold nothing delivery-side.** There is no forecast layer: the work is decomposed when each OpenSpec change is cut in its target repo, with source in context. Sequencing constraints, where real, are design prose in `06-operational.md ## Cross-Repo Coordination` (constraints only, never a plan).
- **Run a compaction pass** (`task compact:plan ID=NNNN`, then `enhancement-compaction`) as a separate commit before the flip. A draft maintained under the in-place rule should have no stacked reversals; if there are any, weave them now, because acceptance protects decision bodies.

`task promote` appends the `Accepted.` history event and bumps `updated` for you.

### Phase 4 — Deliver

Implementation lands in the affected repos, and **each landing is logged in the entry's `delivery.yaml`**, the one execution record an entry carries. There is no implementation field and no stored `implemented` status: `task delivery ID=NNNN` derives the state from the log, and `implemented` requires every live decision carried by a logged change or excused in `no_work`.

That derivation is the whole reason the axis was removed. A stored progress field attracts progress prose — `0001.implementation.notes` grew to 1.5KB of dated commentary before it was deleted — and a derived one cannot go stale. The log is append-only facts (what landed, when, carrying which decisions), never status churn, and a forgotten append only under-reports; it can never produce a false `implemented`.

As code ships:

- **When cutting an OpenSpec change in a target repo, declare its enhancement in `<change-dir>/enhancement.yaml`** at creation time, while the enhancement is in context (`#ChangeDeclaration` in `schema.cue`). See `delivery-log`.
- **When the change is archived, log the landing:** the repo's archive guidance points at `task delivery:log FROM=<change-dir> SUMMARY="..."`, run from the enhancements repo. PR/commit landings in repos without OpenSpec use explicit mode. Nothing else about delivery is recorded in the entry.
- Append a `history` event here **only when the design itself reaches a milestone** — a decision amended, a question resolved, scope changed. Never what landed where: that is the log's job, and an event saying it is the logbook coming back. New events are capped at 200 runes by the schema.
- For changes that land in `core/*.cue`: **load `core-schema-edit` first.** The pre-commit hook and CI gate reject the commit otherwise.
- Decision bodies are **protected** while the entry is `accepted`. A change lands as a new `DN` with `**Amends:**` / `**Supersedes:**` (and `**Depends:**` when it rests on another entry's decision), never as a direct edit. Weave the stacked reversals via `enhancement-compaction` as they land, or at latest before the entry derives `implemented`; `task compact:plan` refuses an implemented entry, so anything left stacked stays stacked.

There is no flip at the end. An entry whose live decisions are all carried or excused simply reads `implemented` in `task delivery` and `task list`.

### Phase 5 — Supersede

When a newer enhancement fully replaces this one, the supersession is a command, not a hand edit — and like rejection, it **always archives** the entry:

```bash
# 1. Record the successor's half of the link first:
#    MMMM/config.yaml: supersedes: ["NNNN"]
# 2. Optionally write a rich hand-authored banner into NNNN/README.md
#    (task supersede writes a default one only if none exists).
task supersede ID=NNNN BY=MMMM
```

What the task does — and refuses:

- Refuses unless the old entry is `accepted` (a draft replaced by a newer idea is killed with `task reject ID=NNNN REASON="superseded by MMMM: …"` instead — its design was never agreed, so there is nothing to hand over), unless `semver` is set, and unless `MMMM`'s `supersedes` already includes `NNNN` — both halves of the link exist before the move.
- Sets `status: superseded` and `superseded_by: "MMMM"`, appends the history event, banners the README if no `> **Superseded by …**` quote block exists yet, and moves the entry to `archive/NNNN/`.

The banner is a top-of-file quote block; write it by hand before running the task when the migration story deserves more than the default line:

```markdown
> **Superseded by MMMM (YYYY-MM-DD).** Brief migration paragraph: what the new entry changes, where to look for the replacement design, whether any of this entry's decisions carry forward.
```

After the move, fix relative links in the archived documents (`../MMMM/` → `../../MMMM/` for live entries) and run `task vet && task index && task graph`.

Terminal state — the design intent is now `MMMM`'s. Don't keep developing the entry, but do **compact it** (`enhancement-compaction`): the narrative documents collapse to pointers at the successor, while the decision log keeps its numbers and its *Alternatives considered* so `MMMM` does not re-litigate ground this entry already settled. The stub pass runs on the archived entry — `task compact:plan` resolves into `archive/`. `experiments/` and `research/` stay untouched — the measurements are usually the expensive part and they remain valid evidence.

## Cross-references between entries

**`depends_on`** is directed and earned: an edge exists iff a decision depends on a decision. An entry lists `MMMM` only when a live `### DN:` block in its `03-decisions.md` carries `**Depends:** MMMM:DN`, and it lists every entry those lines name. Four-digit ids only. `task vet` enforces both directions, requires each target to be a live heading, and refuses a cycle, so `GRAPH.md` is a DAG. Shared topic, reading order, or a prose mention is not an edge.

**`supersedes`, `superseded_by` and `revives`** are lifecycle links and accept two token forms:

- **`"NNNN"`** — workspace-root four-digit id. Resolves to `enhancements/NNNN/`.
- **`"legacy:NNN"`** — frozen library predecessor. Resolves to `library/enhancements/NNN-*/`. Use when the historical link is informative — e.g. the new entry inherits the problem statement from a frozen library design but the conclusions diverge.

The validator (`task vet`) flags dangling references. Once the library predecessors are deleted, any `legacy:NNN` reference will start failing — fix or remove at that point.

## Per-status checklist — the binding gate

Notation: **[H]** = hard, enforced by `task vet` (PR-blocking). **[S]** = soft, enforced by `task check` (warns, pre-PR aid).

### `draft`

The cheap-entry state. Be lenient — this is where ideas form.

- **[H]** `id` matches directory name (four digits, no slug suffix)
- **[H]** the seven mandatory documents (`README.md`, `01-problem.md`, `02-design.md`, `03-decisions.md`, `04-graduation.md`, `05-risks.md`, `06-operational.md`, `07-questions.md`) exist
- **[H]** no `{Capitalised}` placeholder strings outside code fences, HTML comments, or single-line backtick spans
- **[H]** `area ∈ affects`
- **[H]** `created` set, `updated >= created`
- **[H]** cross-refs (`supersedes`, `superseded_by`) resolve to existing entries (workspace `NNNN/` or `library/enhancements/NNN-*/`)
- **[H]** `depends_on` ids exist and are not the entry itself; each is carried by a `**Depends:**` line in a live decision whose target heading exists in that entry's log and is not a tombstone; the `depends_on` graph is acyclic
- **[H]** `summary` set (one line, ≤200 runes); `revives` resolves into `archive/`
- **[H]** `core_schema` set; `schemas/` exists **iff** it is `true`, contains `target.cue`, and compiles via `cue vet ./...`; when `true`, `core ∈ affects`
- **[H]** `contracts/`, when present, is non-empty and compiles via `cue vet ./...`
- **[H]** if `experiments/` exists: index `README.md` is present and every `NN-*/` subdirectory has its own `README.md`
- **[H]** no `plan.yaml` or `PLAN.md` inside the entry (forecast plans are retired; the delivery record is `delivery.yaml`)
- **[H]** `delivery.yaml`, when present, validates against `#Delivery`; every cited `DN`/`OQN` resolves; every `no_work` key is live, not tombstoned, and not also carried by a log entry (carried or excused, never both)
- **[H]** no `## Open Questions` block in `03-decisions.md` or `README.md` — the register lives in `07-questions.md` only

Not required at draft: `semver`, scope section, decisions content, resolved Open Questions.

### `accepted`

Design frozen, ready for slicing.

Everything `draft` requires, plus:

- **[H]** `semver: major | minor | none` set
- **[H]** if `core_schema: true`: `schemas/spec.md` exists and `schemas/` has at least one companion `.cue` beside `target.cue` (convention: `examples.cue`) — unless the entry already derives `implemented`, whose spec landed in `core/SPEC.md`
- **[S]** `README.md` contains `## Scope` with `### In scope` and `### Out of scope`
- **[S]** `03-decisions.md` contains at least one `### DN:` heading
- **[S]** `07-questions.md` contains `## Open Questions` block (may say "None")
- **[S]** `04-graduation.md` has a `## draft → accepted` section and no `## accepted → implemented` section
- **[S]** no Open Question left marked `Blocking: acceptance` (`task promote` refuses on one)
- **[S]** no `*.md` names a plan file (`plan.yaml` / `PLAN.md`; forecast plans are retired), every decision carries `**Kind:**` (checked on drafts), mechanism smells and missing evidence warned (see `task check`'s summary); `task check` also warns when a `delivery.yaml` log entry's repo is outside `affects[]` (fine for cross-entry carriage, a typo otherwise)

### `rejected`

The idea was not accepted. Terminal, and cheap on purpose.

- **[H]** the entry lives in `archive/NNNN/` (and nothing live does)
- **[H]** `rejected_reason` set
- **[S]** `README.md` carries a `> **Rejected (YYYY-MM-DD).**` quote block
- **Reduced validation:** none of the prose gates apply. A killed draft is incomplete by definition, and a kill path more expensive than the finish path is one nobody uses.

### implemented (derived, not a status)

Not written anywhere. `task delivery ID=NNNN` computes it from the entry's `delivery.yaml`: every live decision (tombstones excluded) carried by a logged change's `decisions` **or** excused in `no_work`. The failure direction is safe: a forgotten log entry leaves the state at `in-progress`; the derivation can never produce a false `implemented`.

- The entry is closed: `task compact:plan` refuses it.
- It is exempt from the `examples.cue` / `spec.md` requirement — the spec landed in `core/SPEC.md`.

### `superseded`

Terminal state, and archived like `rejected` — `task supersede` does the move.

- **[H]** the entry lives in `archive/NNNN/` (and nothing live does)
- **[H]** `superseded_by` set (non-null); `semver` set (the design was agreed, so its impact was assessed)
- **[H]** the replacement enhancement's `supersedes` includes this id
- **[S]** `README.md` has top-of-file `> **Superseded by NNNN (YYYY-MM-DD).**` quote block with short migration paragraph
- **Reduced validation** otherwise, same as `rejected`: the entry is a stubbed record whose live design is its successor's, so the prose gates have nothing left to gate.

## The Taskfile

All tasks runnable from `enhancements/` directly (`cd enhancements && task <name>`) or via the workspace include (`task enhancements:<name>`).

| Task | Use when |
| --- | --- |
| `task list` | Picking up unfamiliar work — first thing to read. Status table across every entry. |
| `task show ID=NNNN` | Need full metadata + history list + document list for one entry. |
| `task vet` | About to open a PR that touches `enhancements/`. Hard gate; PR-blocking. |
| `task vet:one ID=NNNN` | After editing one entry, before committing. Same hard gate, single entry. |
| `task check [ID=NNNN]` | Before opening a PR. Soft gate; pre-PR aid. `task gate` is the promotion view. |
| `task new SLUG=foo TITLE="Foo Bar" [AREA=cli] [AUTHOR=…]` | Scaffolding a new entry from `0000/`. |
| `task new:experiment ID=NNNN NAME=concept-name` | Scaffolding an experiment inside an entry. **Load `enhancement-experiments` skill first.** |
| `task experiments:list ID=NNNN` | Browsing experiments for one entry; parses `Status:` from each per-experiment README. |
| `task questions:list ID=NNNN` | Listing the `07-questions.md` register for one entry — grouped by `### ` subheading, classified into open / partial / resolved buckets. Human-readable. |
| `task questions:open ID=NNNN` | TSV of unresolved Open Questions (open + partial). Consumed by the `enhancement-open-questions` skill walk. |
| `task compact:plan ID=NNNN` | TSV of compaction candidates — stacked reversals, resolved OQs still carrying prose, relation trailers in headings. Consumed by the `enhancement-compaction` skill. Read-only; it proposes nothing and writes nothing. |
| `task delivery [ID=NNNN]` | Answering "what is done?". Derived per entry from its `delivery.yaml` log (`not-started` / `in-progress` / `implemented`); this is what replaced the implementation field. `task delivery:data` is the TSV. |
| `task gate ID=NNNN` | Before promoting. Mechanical checks + probe hits + the questions to walk. **Load `enhancement-gates`.** |
| `task promote ID=NNNN` | The sanctioned `draft → accepted` path. Refuses on an open gate. |
| `task supersede ID=NNNN BY=MMMM` | Superseding an accepted entry. Sets the link, banners the README, archives it. Refuses unless `MMMM.supersedes` already includes `NNNN`. |
| `task reject ID=NNNN REASON="…"` | Killing an idea. Archives it with its reason; the id is never reused. |
| `task archive:list` / `archive:data` | Checking a new idea against prior art (the `prior-art` gate). Lists both terminal states — rejected with reasons, superseded with successors. |
| `task index` | After any `config.yaml` edit — `INDEX.md` is generated, not hand-edited. |
| `task graph` | After any `depends_on` / `supersedes` / `revives` edit. `GRAPH.md` is generated, not hand-edited. |
| `task delivery:log FROM=<change-dir> SUMMARY="…"` | Logging an archived OpenSpec change into every enhancement its `enhancement.yaml` declares. Explicit mode (`ID= REPO= KIND=openspec\|pr\|commit CHANGE=/NUMBER=/SHA= SUMMARY= [DECISIONS=] [RESOLVES=]`) covers repos without OpenSpec. **Load the `delivery-log` skill first.** |
| `task delivery:uncovered [ID=NNNN]` | Live decisions no logged change carries and `no_work` does not excuse. Not a gate; read it when logging and before expecting `implemented`. |
| `task delivery:deferred` | Every `deferred-to-implementation` OQ and whether a log entry claims it via `resolves`. |
| `task delivery:reconcile` | Drift detection: archived changes in sibling repos that declared an enhancement but were never logged. Report-only; the printed `task delivery:log` command is the fix. |

## Working with OpenSpec repos

OpenSpec is the per-repo workflow for implementing a design defined here (in `enhancements/NNNN/`) as one or more discrete changes in target repos. Each affected repo (`core/`, `library/`, `cli/`, `opm-operator/`, etc.) has its own `openspec/` workspace, and that workspace is the source of truth for its change's content.

The OpenSpec skills (`openspec-new-change`, `openspec-explore`, `openspec-continue-change`, `openspec-apply-change`, `openspec-verify-change`, `openspec-archive-change`, `openspec-propose`, plus utilities) handle the change lifecycle inside each target repo. `config.yaml` carries no slices field and no forecast: a change declares which enhancement it implements in `<change-dir>/enhancement.yaml` at creation time (`#ChangeDeclaration` in `schema.cue`), and at archive time the repo's archive guidance points at `task delivery:log FROM=<change-dir>`, which reads the declaration and appends the landing to the entry's `delivery.yaml`. The entry's log is the landing record; `history` records design milestones only.

Workflow:

1. Design the enhancement here (`enhancements/NNNN/`).
2. Promote to `accepted`.
3. For each affected repo, `cd <repo>` and use the openspec skills to draft the change, writing an `enhancement.yaml` declaration (`implements: [{enhancement: "NNNN", decisions: [D7], resolves: []}]`) while the enhancement is in context. Decompose the work now, at cut time, with source in front of you; nothing is pre-planned on the enhancements side.
4. Implement the change there; archive on completion.
5. On archive, run `task delivery:log FROM=<change-dir> SUMMARY="…"` from the enhancements repo to append the record. History events remain design milestones; the log carries the landing.

## Common pitfalls

- **Forgetting to re-run `task index` after editing `config.yaml`.** `INDEX.md` is generated. Stale `INDEX.md` is the most common drift; run `task index` whenever any `config.yaml` changes.
- **Forgetting to re-run `task graph` after editing `depends_on` / `supersedes` / `revives`.** Same story for `GRAPH.md`.
- **Writing CUE inside a markdown fence instead of a compilable file.** Defeats the validator. If you find yourself pasting a CUE block longer than a few illustrative lines into `02-design.md`, that block belongs in a `.cue` file with a one-line markdown reference — in `schemas/` when it is (part of) the core-schema delta, in `contracts/` otherwise.
- **Putting non-core CUE in `schemas/`, or a core delta in `contracts/`.** `schemas/` has exactly one meaning — the `opmodel.dev/core` delta gated by `core_schema` — and vet enforces its presence in both directions. A decision procedure or Go-behaviour contract wearing `#Def` syntax is `contracts/` material; a proposed core definition hiding in `contracts/` dodges the examples/spec.md gate.
- **Scaffolding an entry for something that is not an enhancement.** A chore, a cleanup, a dependency bump, a note-to-self. Walk the `creation` gates first; if it fails `feature`, it is a GitHub issue labelled `idea`. This is the pitfall the whole rubric exists for, and the cheapest place to catch it is before eight files exist.
- **Narrating delivery in history or prose.** The log is the only delivery record: what shipped goes to `delivery.yaml` via `task delivery:log`, and `task delivery` reads it back. History events stay design milestones (capped at 200 runes); an entry narrating its own delivery in prose is the logbook this repo removed.
- **Re-proposing a rejected idea silently.** `task archive:data` is one command. A returning idea is legitimate; an unacknowledged one wastes the argument that killed it the first time.
- **Hand-editing `status: accepted`.** `task promote` is the path, and it checks four things you would otherwise have to remember. A hand edit also leaves no verdict file, which `task vet` can see.
- **Hand-editing `status: superseded`, or leaving a terminal entry live.** `task supersede` is the path — it checks both halves of the link and does the archive move. A terminal entry (`rejected` or `superseded`) always lives in `archive/NNNN/`; `task vet` fails one left in place.
- **Filling decisions speculatively.** On a draft the fix is cheap — revise the block in place — but until then a wrong decision misleads whoever reads the log next, and once the entry is `accepted` unwinding it costs an amending `DN` plus a compaction pass. Only record decisions after they are made, with their alternatives and source. If unsure, leave it as an Open Question.
- **Revising a draft decision carelessly.** In-place revision is the normal Phase 2 move, but it has two hard edges: an evidence-backed old position folds into *Alternatives considered* (deleting it guarantees someone re-proposes it), and a retracted number keeps a tombstone heading — it never silently disappears.
- **Editing an `accepted` entry's decision body directly.** Protected means protected: the change is a new `DN` with a relation field, and existing bodies move only through `enhancement-compaction` with its manifest and its own commit. A direct edit after acceptance is exactly how a design record gets quietly laundered to agree with whatever was just built.
- **Half-filling Open Questions.** Each OQ should be a specific question with enough context that someone unfamiliar can answer it. "How does X work?" is too vague — name the design surface, the constraint, and what would resolve it.
- **Editing `library/enhancements/`.** Those entries are frozen predecessors. Any new design intent goes here in `enhancements/NNNN/`.
- **Forking content from the frozen library entries.** Fresh prose. The frozen predecessors are reference material for *why* the new design exists, not source code to copy.
- **Promoting status without running both gates.** `task vet` is mechanical and must pass. `task check` is prose-shape; failing it is acceptable only if the warning is documented in the PR body with a reason for deferring.
- **Editing `core/*.cue` as part of an implementation change without loading the `core-schema-edit` skill first.** That skill is binding. The pre-commit hook + CI gate will reject the commit. Reading the skill first means the SPEC section format is ready when you write it.
- **Treating `INDEX.md` or `GRAPH.md` as hand-maintained.** They are generated. Hand-edits get clobbered on the next `task index` / `task graph`.
- **Listing an entry in `depends_on` because it is on the same topic.** The field is an index of `**Depends:**` lines, nothing more; `task vet` fails an id no live decision carries. Reading order and shared area are `INDEX.md`'s job.
- **Naming a plan file in the entry.** Forecast plans are retired: no `plan.yaml` or `PLAN.md` lives inside an entry (`task vet` fails the file), and prose naming one is a stale pointer at nothing (`task check` warns; delete or reword it). The delivery record is `delivery.yaml`.
- **Pre-planning slices at all.** There is no forecast layer any more; both large plans it produced sat at 100% `planned` with zero execution feedback. Decompose the work when cutting each OpenSpec change in its target repo; sequencing constraints stay design prose in `06-operational.md ## Cross-Repo Coordination`.
- **Recording a mechanism decision.** If it would not bind a from-scratch rewrite of the affected repos, it is not a `DN` — it belongs in the implementing OpenSpec change. `task check` flags path and identifier references in an entry's prose as smells.
- **Prescribing a name, a file or a layout.** An entry never says what a file is called, how an identifier is spelled, how a directory is laid out, or how code is structured — in any of its documents. Those belong to the repo that ships them. Naming a path as *evidence* (to prove a claim, or to say where something is emitted today) is wanted; naming one as *instruction* is not. Test: would deleting the path change what an implementer is obliged to do, or only what a reader can verify? A name that is itself part of the published contract — one that reaches a key or a command's surface — is a contract statement and stays; the file holding it is not.
- **Using Mermaid for a design/mechanism diagram, or ASCII for an entity-relationship graph.** The medium follows content shape — see `enhancement-diagrams`. Swapping either direction is the specific mistake that skill exists to prevent.
- **A bordered ASCII diagram whose alignment drifted after an edit.** Fixed-width box borders are fragile — `0012/02-design.md`'s rung ladder (73 characters wide) is the cautionary example. Re-check row widths after any edit, or prefer arrow/column layouts that don't have this failure mode.

## Source of truth precedence

- Workspace root `/CLAUDE.md` governs cross-repo routing and the area vocabulary.
- `enhancements/CLAUDE.md` orients agents to the repo; this skill is the authoritative protocol.
- Each target repo's own `CLAUDE.md` governs its source code; implementation changes follow those rules.
- When a change touches `core/`, `core-schema-edit` (at `core/.claude/skills/core-schema-edit/`) is the binding protocol for SPEC.md co-updates.

When guidance conflicts, the most-specific source wins: target repo skill > this skill > target repo CLAUDE.md > workspace root CLAUDE.md.

## Cross-references

- `enhancements/CLAUDE.md` — repo orientation; points here for the full protocol.
- `enhancements/0000/README.md` — template; carries the canonical rules text duplicated inside each new entry.
- `enhancements/schema.cue` — CUE contract that `task vet` validates each `config.yaml` against; it also validates every `delivery.yaml` (`#Delivery`) and defines the target-repo `enhancement.yaml` declaration shape (`#ChangeDeclaration`).
- `enhancements/Taskfile.yml` — workflow tasks source.
- `enhancement-gates` skill (sibling) — the admission rubric walk; the only path to the verdict file `task promote` requires.
- `enhancements/gates.cue` — the rubric itself, as data.
- `enhancements/.github/ISSUE_TEMPLATE/idea.yml`: the idea issue form; a declined idea goes to the issue tracker under label `idea` (`task ideas` lists open ones).
- `enhancement-experiments` skill (sibling, under `enhancements/.claude/skills/`) — the experiments protocol.
- `enhancement-open-questions` skill (sibling, under `enhancements/.claude/skills/`) — the interactive OQ-walk protocol; load when resolving Open Questions one at a time, especially before promoting `draft → accepted`.
- `enhancement-compaction` skill (sibling, under `enhancements/.claude/skills/`) — the compaction protocol; the only body-edit path on `accepted` entries. Load before weaving an appended reversal into the decision it reverses, collapsing resolved OQ prose, or stubbing a superseded entry.
- `delivery-log` skill (sibling, under `enhancements/.claude/skills/`): the delivery-log protocol; load before `task delivery:log`, before touching any `NNNN/delivery.yaml`, or before writing an `enhancement.yaml` declaration into a target repo's change.
- `enhancement-diagrams` skill (sibling, under `enhancements/.claude/skills/`) — the diagram protocol; load before sketching a relationship (Mermaid) or design/mechanism (ASCII) diagram, live or persisted.
- `core-schema-edit` skill (`core/.claude/skills/core-schema-edit/`) — the SPEC.md co-update protocol for changes that touch `core/*.cue`.
- `openspec-*` skills (per-repo, under each target repo's `.claude/skills/` or `.opencode/skills/`) — the change lifecycle in each target repo.
