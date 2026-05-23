# Enhancements repo — agent guide

This repo holds OPM enhancement proposals. Each entry under `NNNN/` is a complete design package: problem, design, decisions, graduation gates, risks, operational concerns, plus a pure-CUE target schema. The repo is the source of truth for design intent across every OPM area (core, library, catalog, cli, opm-operator, opmodel.dev, orca, modules, releases).

## When this guide applies

- Creating a new enhancement.
- Editing an existing enhancement's documents, schemas, or `config.yaml`.
- Promoting an enhancement's `status` (draft → accepted → implemented → superseded).
- Recording a new history event after a slice ships.
- Adding cross-references between entries.
- Implementing the design — touching code in `core/`, `library/`, `catalog/`, `opm-operator/`, etc.

If your task is only to *read* an existing enhancement, you don't need this guide — read its README, then walk `01-problem.md` through `06-operational.md`.

## Skill to load — the authoritative protocol

**Always load the `enhancements` skill before doing workflow work.**

```
enhancements/.claude/skills/enhancements/SKILL.md
```

This file (`CLAUDE.md`) is the orientation document. The `enhancements` skill is the **binding protocol** — the full create / iterate / promote / implement / supersede lifecycle, the per-status hard/soft gate checklist (the contract `task vet` and `task check` enforce), the decision-log format, the cross-reference resolution rules, the common pitfalls, and the source-of-truth precedence.

Trigger to load: any task that matches one of the bullets in *When this guide applies* above, or any time you are about to invoke `task new`, `task vet`, `task check`, `task index`, `task graph`, or edit a `config.yaml`.

Sibling skills carry parallel protocols you may also need to load:

- **`enhancement-experiments`** (`enhancements/.claude/skills/enhancement-experiments/SKILL.md`) — when creating, updating, validating, or concluding experiments under `enhancements/NNNN/experiments/`. Load whenever you are about to invoke `task new:experiment` or `task experiments:list`, or edit any file under `experiments/`.
- **`core-schema-edit`** (`core/.claude/skills/core-schema-edit/SKILL.md`) — when implementing a slice that touches `core/*.cue`. Enforces the SPEC.md co-update protocol. Required reading before editing the core schema; the pre-commit hook and CI gate will refuse the commit otherwise.
- **`openspec-*`** (per-repo, under each target repo's `.claude/skills/` or `.opencode/skills/`) — when slicing the enhancement's accepted design into per-repo OpenSpec changes for execution.

## Repo rules — invariants

These hold across every enhancement; violations fail PR review even if `task vet` does not catch them. The `enhancements` skill carries the full rule text and the rationale.

- **`config.yaml` is the sole source of metadata.** No metadata table in `README.md`.
- **Folder names are id-only.** `0001/`, `0042/` — no slug suffix. `0000` is reserved for the template.
- **Schemas are pure CUE files** under `NNNN/schemas/`, never fenced code blocks longer than a few illustrative lines.
- **History and decisions are append-only.** Reversed conclusions get a new entry; the original stays.
- **Don't hard-wrap prose in `.md` files.**
- **Don't reference `library/enhancements/` content directly** in new entries. Use the `legacy:NNN` cross-ref form when historical link matters.
- **Don't fork content from the frozen library entries.** Fresh prose.

## The workflow — high level

```
new → fill problem + design → accrete decisions → freeze (accepted) → ship (implemented) → archive history
```

| Phase | Command / action | Skill section |
| --- | --- | --- |
| 1. Create | `task new SLUG=foo TITLE="Foo Bar"` | `enhancements ## Phase 1 — Create` |
| 2. Iterate | Edit `01..06`, `schemas/target.cue`, append `history`, bump `updated` | `enhancements ## Phase 2 — Iterate` |
| 3. Promote `draft → accepted` | `task vet:one` + `task check`; resolve every OQ; set `semver` | `enhancements ## Phase 3 — Promote` |
| 4. Implement | Slice into target repos; append `history` events; set `implementation.status: complete` | `enhancements ## Phase 4 — Implement` |
| 5. Supersede | New entry sets `supersedes`; old entry sets `superseded_by` + `status: superseded` | `enhancements ## Phase 5 — Supersede` |

Each phase has gating criteria and a concrete checklist. The `enhancements` skill is the authoritative source; load it before promoting any status.

## The Taskfile — workflow tasks

All tasks runnable from `enhancements/` directly (`cd enhancements && task <name>`) or from workspace root via the include (`task enhancements:<name>`).

| Task | Purpose |
| --- | --- |
| `task list` | Status table — id, status, semver, area, impl status, impl date, title. First thing to read when picking up unfamiliar work. |
| `task show ID=NNNN` | Full metadata + history list + document list for one entry. |
| `task vet` | **Hard gate** (PR-blocking). CUE schema validation, cross-ref existence, placeholder absence, `area ∈ affects`, `schemas/` compiles, experiments structure when present. |
| `task vet:one ID=NNNN` | Same gate, single entry. |
| `task check [ID=NNNN]` | **Soft gate** (pre-PR aid). Per-status prose conventions: scope section, decision headings, OQ block, implementation snapshot, deviations, supersession quote block. |
| `task new SLUG=foo TITLE="Foo Bar" [AREA=cli] [AUTHOR=…]` | Scaffold a new entry from `0000/`. |
| `task new:experiment ID=NNNN NAME=concept-name` | Scaffold an experiment inside an entry. Load `enhancement-experiments` skill first. |
| `task experiments:list ID=NNNN` | List experiments for one entry; parses `Status:` from each per-experiment README. |
| `task index` | Regenerate `INDEX.md` (browse aid for opaque NNNN folders). Run after any `config.yaml` edit. |
| `task graph` | Regenerate `GRAPH.md` with a Mermaid relationship diagram. Run after any cross-ref edit. |

## Source of truth precedence

- Workspace root `/CLAUDE.md` governs cross-repo routing and the area vocabulary.
- This `CLAUDE.md` orients agents to the repo; the `enhancements` skill is the authoritative workflow protocol.
- Each target repo's own `CLAUDE.md` governs its source code; implementation slices follow those rules.
- When a slice touches `core/`, the `core-schema-edit` skill at `core/.claude/skills/core-schema-edit/` is the binding protocol for SPEC.md co-updates.
- When working on experiments, `enhancement-experiments` is the binding protocol.

When guidance conflicts, the most-specific source wins: target-repo skill > enhancements skill > target-repo `CLAUDE.md` > this `CLAUDE.md` > workspace root `CLAUDE.md`.
