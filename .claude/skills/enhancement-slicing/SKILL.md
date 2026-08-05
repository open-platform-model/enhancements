---
name: enhancement-slicing
description: Protocol for planning, tracking, and seeding the per-repo execution of an OPM enhancement via the optional enhancements/NNNN/plan.yaml. Load before scaffolding a plan.yaml with task new:plan, before adding or updating a slice's status/depends_on, before promoting draft → accepted on an entry whose affects spans more than one repo, or before invoking task slice:seed to hand a slice off to a target repo's own OpenSpec workflow.
user-invocable: true
---

# Enhancement Slicing

## When this skill applies

Load this skill when any of the following is true:

- `06-operational.md ## Cross-Repo Coordination` is turning into a hand-numbered dependency list (the pattern enhancement 0006 hit — "slice 4 consumes slices 2, 2a, 3") and you want the order tracked structurally instead of in prose.
- You are about to invoke `task new:plan`, `task plan:graph`, `task plan:ready`, or `task slice:seed`.
- You are editing `enhancements/NNNN/plan.yaml` — adding a slice, changing a `status`, adding a `depends_on` edge, setting `openspec_ref`, or cancelling a slice.
- You are promoting an entry `draft → accepted` and `config.yaml.affects` lists more than one repo — this is the natural moment to decide whether the enhancement needs a slice plan at all.
- You are about to hand a piece of an accepted enhancement's design to a target repo's own OpenSpec workflow and want a seed stub instead of writing the proposal from a blank page.

If your task is only to *read* an existing `plan.yaml` to understand the landing order, you don't need this skill — read the file directly, or read the generated `NNNN/PLAN.md`.

## What a slice plan is, and is not

A slice plan is the structured layer between a design (the enhancement, defined in `enhancements/NNNN/`) and its execution (one OpenSpec change per slice, landed in the target repo). It answers four questions a prose-only `06-operational.md` struggles to keep consistent as an enhancement grows: which repo does each piece land in, which half of the work is it, what does it depend on, and what is its current status.

It is **not**:

- **A design document.** A slice's `concern` is one line. Full detail — the actual integration points, the code paths touched, the tests required — lives in that slice's own OpenSpec change in the target repo, exactly as it does today. `plan.yaml` is a table of contents for execution, not the execution itself.
- **A replacement for `06-operational.md ## Cross-Repo Coordination`.** That section keeps the narrative rationale — *why* this order, what a hand-off produces for the next slice to consume. `plan.yaml` is the structured backing data the narrative refers to by slice id, the same relationship `03-decisions.md`'s prose already has to `schemas/target.cue`.
- **Mandatory.** Most enhancements ship as one slice in one repo and never need this file. Scaffold it only once `config.yaml.affects` spans more than one repo, or a single repo's work is large enough to need an explicit landing order.

## The two phases

Every slice declares a `phase`, and the two are ordered: **implementation lands before migration.**

| Phase | What it is | Typical repos |
| --- | --- | --- |
| `implementation` | Defines the system. Schema, code and docs changes. | `core`, `library`, `cli`, `opm-operator`, `opmodel.dev` |
| `migration` | Moves already-published artifacts onto those definitions. | the official catalogs, the module fleet, the release pins |

> **The test is what the slice is FOR, not which files it touches.**

That distinction does real work. A slice that edits source files *and* republishes is `migration` when republishing is its purpose — but the better move is usually to **split it so no slice straddles the boundary**, because authoring CUE is a reviewable source change while pushing bytes is irreversible. Enhancement 0010 does exactly this: `catalogs-identity-authoring` (implementation) commits `identity/identity.cue`, and `catalogs-republish` (migration) is the first act that changes a published artifact. An earlier revision bundled them into one slice, which hid the seam.

The converse also comes up: 0011's `catalogs-publish-cutover` edits a *catalog* repo but is `implementation`, because it repoints a release pipeline's configuration and publishes nothing itself. Phase is not derivable from `repo`, which is why it is a required field rather than an inferred one.

**Ordering is enforced as an edge rule, not a barrier.** `task vet` fails if any `implementation` slice `depends_on` a `migration` slice — locally or across entries. Checking direct edges is sufficient, since a transitive implementation→…→migration path always contains at least one direct one. What it deliberately does *not* do is block a migration slice whose own dependencies are satisfied merely because unrelated implementation work is still open; `task plan:ready` surfaces that as an annotation instead.

**Not the `enhancements` workflow's Phases 1–5.** That numbering (Create / Iterate / Promote / Implement / Supersede) describes the *entry's* lifecycle. A slice's `phase` describes one *slice's* kind. The two never appear in the same sentence, and neither constrains the other.

## Core rules

1. **A slice is thin.** `id`, `repo`, `phase`, one-line `concern`, `depends_on`, `status` — that's the whole shape (plus optional `openspec_ref` and, on a cancelled slice, `cancelled_reason`). If you're tempted to add a task breakdown or code-level detail to a slice entry, that belongs in the target repo's OpenSpec change instead.
2. **`id` is a stable kebab-case slug, unique within the entry's `plan.yaml`.** Never reused, even if the slice is cancelled — other slices' `depends_on` may already cite it. Choose an id that reads well as `<repo>/<id>` once it becomes an `openspec_ref` (e.g. `cli-kernel-adoption`, landing as `cli/2026-07-18-cli-kernel-adoption`).
3. **`repo` must be a member of `config.yaml.affects`.** `task vet` enforces this. If a slice needs a repo not yet listed in `affects`, add it to `affects` first.
4. **`depends_on` accepts two forms:** a local slice id (resolved within the same `plan.yaml`), or a cross-enhancement reference `"NNNN:slice-id"` pointing at a slice declared in another entry's `plan.yaml` — e.g. enhancement 0006's `cli-kernel-adoption` depending on enhancement 0001's `library` slice. Cross-enhancement refs are checked against the other entry's `plan.yaml` **only when that file exists**; its absence means the upstream isn't sliced yet, which is a planning gap to flag in review, not a schema violation.
5. **Status has four values: `planned | in-progress | done | cancelled`.** There is no stored `blocked` state — whether a slice is blocked is *derived* from whether its dependencies are `done` (`task plan:ready` computes this). A stored blocked flag would go stale the moment a dependency lands; deriving it never does.
6. **A cancelled slice keeps its id and records why.** Set `status: cancelled` and `cancelled_reason: "..."` — mirrors the tombstone convention for a vacated `DN`/`OQN`. Do not delete a cancelled slice's entry if anything else's `depends_on` cites it.
7. **`status` and `openspec_ref` change in the same commit that appends the `history` event citing the same slice.** `config.yaml.history` (append-only, per the main `enhancements` skill) and `plan.yaml` (mutable, current-state) must always agree on what has landed. If they drift, `plan.yaml` is wrong — the history event is the permanent record.
8. **`phase` is required, deliberate, and ordered.** Classify by what the slice is *for* (see `## The two phases`), never by which repo it lands in — a `catalog` slice can be either. No `implementation` slice may depend on a `migration` slice; `task vet` enforces it. When a slice would straddle the boundary, split it rather than picking a phase for it.

## Lifecycle

| Status | Meaning | Next |
| --- | --- | --- |
| `planned` | Declared, not started. Ordering and repo are settled; nothing has landed. | Once its `depends_on` are all `done`, it surfaces in `task plan:ready` — start it. |
| `in-progress` | A target-repo OpenSpec change is open for this slice. | Land it, then flip to `done` and set `openspec_ref` in the same commit as the `history` event. |
| `done` | Landed. `openspec_ref` set. | Terminal — other slices' `depends_on` may now resolve against it. |
| `cancelled` | Will not ship. `cancelled_reason` set. | Terminal — id retained for any `depends_on` still citing it. |

## Create

```bash
# from enhancements/, or via the workspace include `task enhancements:new:plan …`
task new:plan ID=NNNN
```

Scaffolds `NNNN/plan.yaml` with an empty `slices: []`. Refuses if the file already exists. After scaffolding, add one entry per slice — see `0000/README.md ## Slice Plan` for the field reference and a worked example.

Deciding whether an enhancement needs this at all is the real first step, not the command. Read `06-operational.md ## Cross-Repo Coordination` first: if the sequence is a single hand-off or two, prose is enough and `plan.yaml` is overhead. If it's already numbering slices with cross-references between them, scaffold the plan.

## Update

Adding a slice, changing its status, or wiring a dependency are all direct edits to `plan.yaml` — there is no interactive walk analogous to `enhancement-open-questions`, because the shape is small enough to hand-edit safely. After any edit:

```bash
task vet:one ID=NNNN
```

Validates schema conformance, `id` uniqueness, `repo ∈ affects`, every `depends_on` resolving, and no dependency cycle. This is folded into the existing hard gate — `plan.yaml` is checked whenever it is present, never required when absent, so entries without a slice plan are unaffected.

When a slice lands:

1. Set `status: done` and `openspec_ref: <repo>/<openspec-slug>` in `plan.yaml`.
2. In the same commit, append a `history` event to `config.yaml` citing the same `openspec_ref` in its `slice` field (per the main `enhancements` skill, Phase 4).
3. Re-render the views (below) so `PLAN.md` and the ready-list reflect the new state.

When a slice is cancelled, set `status: cancelled` and `cancelled_reason`, and record the cancellation as a decision in `03-decisions.md` if it reverses something already decided (e.g. "D31 reverts D9's inventory-package split; slice `library-inventory-pkg` cancelled").

## Views

```bash
task plan:graph ID=NNNN   # regenerate NNNN/PLAN.md — Mermaid DAG + table, one subgraph per phase
task plan:ready ID=NNNN   # slices whose depends_on are all `done`, grouped by phase
```

`plan:graph` is generated — like `INDEX.md`/`GRAPH.md`, it carries a "do not edit by hand" header and regenerates from `plan.yaml` on demand. Run it after any `plan.yaml` edit that changes structure, phase or status; nothing enforces freshness automatically. Nodes are grouped into one Mermaid `subgraph` per phase, so the implementation-then-migration split is the first thing the diagram shows; a phase with no slices emits no subgraph at all rather than an empty box (0011 renders one, not two). Cross-enhancement peripheral nodes sit outside both, since they belong to neither phase of that plan. The table below the diagram carries a `Phase` column and lists implementation rows first.

`plan:ready` is the order-of-procedure answer: instead of walking the DAG in your head (or in prose, per 0006's `06-operational.md`), it computes the topological frontier directly. A cross-enhancement dependency counts as satisfied only if the other entry's `plan.yaml` marks that slice `done`; if that entry has no `plan.yaml` yet, the dependency is treated as unresolved. Output is grouped into `IMPLEMENTATION` and `MIGRATION` sections, and the migration header reports how many implementation slices have not yet reached `done`/`cancelled` — **informational, not a gate.** Readiness stays purely DAG-derived, so a migration slice whose own dependencies are satisfied is still listed while unrelated implementation work is open. The hard rule lives in `task vet`.

## Seeding a slice's OpenSpec change

```bash
task slice:seed ID=NNNN SLICE=<slice-id>
```

Prints a short stub — repo, phase, concern, status, unresolved dependencies (a warning, not a block: the stub still prints even if a dependency isn't `done`, since sometimes work legitimately starts early against risk) — sized to hand to that repo's own `openspec new` (or whichever workflow it uses).

This is the boundary to respect: **`enhancements/` produces the seed; it does not reach into another repo's tooling.** `slice:seed` never shells out to a target repo, never invokes another repo's OpenSpec skill, and never writes files outside `enhancements/`. Copy the printed stub into the target repo and run that repo's own `openspec-new-change` (or equivalent) skill — see the main `enhancements` skill's `## OpenSpec — sister workflow for slicing` section for that hand-off.

The stub is intentionally information-dense but not directive: it names the enhancement, links back to the design documents for full context, and reminds the author to close the loop (`status: done` + `openspec_ref` in `plan.yaml`, plus the matching `history` event) — it does not attempt to draft the OpenSpec proposal's own problem/design/tasks sections. That's the target repo's job, informed by its own conventions.

## Anti-patterns

- **Scaffolding `plan.yaml` on every new enhancement.** Don't — same rule as `experiments/`. An empty or single-slice `plan.yaml` is noise; add it only when the coordination need actually surfaces.
- **Putting implementation detail in `concern`.** A `concern` field bloating past one line is a sign the design belongs in the target repo's OpenSpec change, not in `plan.yaml`.
- **Storing a `blocked` status.** There isn't one. Blocked-ness is computed from `depends_on` + dependency status by `task plan:ready`; a hand-maintained blocked flag drifts the moment a dependency lands.
- **Letting `plan.yaml` and `config.yaml.history` disagree.** If a slice shows `done` in `plan.yaml` but no `history` event cites its `openspec_ref` (or vice versa), one of them is stale — fix it before moving on, not in a later cleanup pass.
- **Renumbering or deleting a cancelled slice's id.** Other slices may cite it in `depends_on`. Cancel in place with `cancelled_reason`, same as a vacated `DN`/`OQN` keeps a tombstone.
- **Expecting `task slice:seed` to talk to another repo.** It only prints. If you want the actual OpenSpec change scaffolded, that command runs in the target repo, under its own skill.
- **Treating a missing upstream `plan.yaml` as a hard failure.** `task vet` deliberately does not fail a `"NNNN:slice-id"` reference when `NNNN` has no `plan.yaml` yet — that upstream may simply not be sliced. It's a planning gap to notice in review, not a schema violation to block on.
- **An implementation slice depending on a migration slice.** `task vet` rejects it. If the dependency is real, one of the two is misclassified, or the implementation slice is doing migration work that should be split out.
- **Classifying by repo instead of by purpose.** A `catalog`/`modules` slice is not automatically `migration` — 0011's `catalogs-publish-cutover` repoints a release pipeline and publishes nothing, so it is `implementation`. Conversely a slice is not `implementation` merely because it edits committed source; 0010's `catalogs-republish` exists to push bytes.
- **Restating the phase split in `plan.yaml`'s header comments.** The field is the source of truth and `task plan:graph` renders it. Prose enumerating which slices are in which phase drifts the moment one moves — keep the comments for *why* the seam falls where it does.

## Where things live

| Artefact | Path | Authority |
| --- | --- | --- |
| Slice plan | `enhancements/NNNN/plan.yaml` | Hand-authored, optional. Validated by `#SlicePlan` in `schema.cue` plus the cross-referential checks in `Taskfile.yml`. |
| Rendered DAG | `enhancements/NNNN/PLAN.md` | Generated by `task plan:graph` — do not hand-edit. |
| Schema | `enhancements/schema.cue` (`#SlicePlan`, `#Slice`, `#SliceStatus`, `#SliceRefStr`) | CUE contract for `plan.yaml`, same file that validates `config.yaml`. |
| Rules canonical text | `enhancements/0000/README.md ## Slice Plan` | The field reference and worked example, duplicated into each new entry's template. |
| Narrative counterpart | `enhancements/NNNN/06-operational.md ## Cross-Repo Coordination` | Prose rationale for the order `plan.yaml` encodes structurally. |
| Workflow tasks | `enhancements/Taskfile.yml` (`new:plan`, `plan:graph`, `plan:ready`, `slice:seed`, plus the `plan_errors` checks inside `vet`/`vet:one`) | Tooling source. |
| This skill | `enhancements/.claude/skills/enhancement-slicing/SKILL.md` | Workflow guidance — the file you are reading. |

## Cross-references

- `enhancements/CLAUDE.md` — repo guide; points to this skill alongside the other sibling skills.
- `enhancements/.claude/skills/enhancements/SKILL.md` — the authoritative workflow protocol; its Phase 3 (`draft → accepted`) checklist is where deciding on a slice plan belongs, and its `## OpenSpec — sister workflow for slicing` section is what `task slice:seed`'s output feeds into.
- `enhancements/0000/README.md ## Slice Plan` — canonical rules text and a worked example, reproduced in each enhancement's template.
- `enhancement-experiments` skill (sibling) — the closest existing precedent for an optional, structurally-validated, non-mandatory sub-directory; the "don't scaffold until needed" discipline is shared.
- `enhancement-compaction` skill (sibling) — governs `03-decisions.md`/Open-Question compaction; a cancelled slice's `cancelled_reason` should usually point at the `DN` a compaction pass would otherwise weave in.
