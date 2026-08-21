---
name: delivery-plans
description: Protocol for planning, tracking, and seeding the per-repo delivery of OPM enhancements via plans/<slug>/plan.yaml. Load before scaffolding a plan with task plans:new, before adding or updating a slice's status/depends_on, before promoting draft → accepted on an entry whose affects spans more than one repo, or before invoking task plans:seed to hand a slice off to a target repo's own OpenSpec workflow.
user-invocable: true
---

# Delivery Plans

## The one-way rule (read first)

References flow in exactly one direction. **Plans cite enhancements** — `implements: ["NNNN"]`, `decisions: ["NNNN:D34"]`, `resolves: ["NNNN:OQ9"]` — and every citation is validated by `task plans:vet`. **Enhancements never cite plans**: no enhancement document, config field, or history event names a plan slug, a slice id, a plan file, or an OpenSpec change slug (a generic statement like "tracked in a delivery plan under `plans/`" is fine; a specific pointer is not — `task vet` fails a plan file inside an entry and `task check` warns on the file names in draft/accepted prose). When delivery completes, the enhancement records the plain fact — `implementation.status: complete`, a dated history event in plan-blind wording — without naming who delivered it.

This is why enhancements stay intent, evidence, and schema changes, while execution state churns freely here.

## When this skill applies

Load this skill when any of the following is true:

- An accepted enhancement's `06-operational.md ## Cross-Repo Coordination` names real ordering constraints and the landing order needs structural tracking.
- You are about to invoke `task plans:new`, `task plans:graph`, `task plans:ready`, or `task plans:seed`.
- You are editing `plans/<slug>/plan.yaml` — adding a slice, changing a `status`, adding a `depends_on` edge, setting `openspec_ref`, claiming a deferred OQ via `resolves`, or cancelling a slice.
- You are promoting an entry `draft → accepted` and `config.yaml.affects` lists more than one repo — this is the natural moment to decide whether a delivery plan is needed (`task plans:vet` nudges on accepted multi-repo entries no plan implements).
- You are about to hand a piece of an accepted enhancement's design to a target repo's own OpenSpec workflow and want a seed stub instead of writing the proposal from a blank page.

If your task is only to *read* an existing plan to understand the landing order, you don't need this skill — read `plans/<slug>/plan.yaml` directly, or the generated `plans/<slug>/PLAN.md`.

## What a delivery plan is, and is not

A delivery plan is the structured execution layer for one or more enhancement designs: which repo does each piece land in, which half of the work is it, what does it depend on, and what is its current status. A plan usually implements one enhancement; `implements` being a list is for the case where several tightly-coupled entries deliver together.

It is **not**:

- **A design document.** A slice's `concern` is one line. Full detail — the code paths touched, the tests required — lives in that slice's own OpenSpec change in the target repo. A plan is a table of contents for execution, not the execution itself.
- **A replacement for `06-operational.md ## Cross-Repo Coordination`.** That section states the ordering *constraints as design facts* (what must exist before what, and why); the plan encodes the resulting order and per-slice status. The enhancement side never names the plan.
- **Mandatory.** Most enhancements ship as one slice in one repo and never need a plan. Scaffold one only once an accepted entry's landing order actually needs tracking.

## The two phases

Every slice declares a `phase`, and the two are ordered: **implementation lands before migration.**

| Phase | What it is | Typical repos |
| --- | --- | --- |
| `implementation` | Defines the system. Schema, code and docs changes. | `core`, `library`, `cli`, `opm-operator`, `opmodel.dev` |
| `migration` | Moves already-published artifacts onto those definitions. | the official catalogs, the module fleet, the release pins |

> **The test is what the slice is FOR, not which files it touches.**

That distinction does real work. A slice that edits source files *and* republishes is `migration` when republishing is its purpose — but the better move is usually to **split it so no slice straddles the boundary**, because authoring CUE is a reviewable source change while pushing bytes is irreversible. The artifact-identity plan does exactly this: `catalogs-identity-authoring` (implementation) commits `identity/identity.cue`, and `catalogs-republish` (migration) is the first act that changes a published artifact. Conversely, the artifact-publishing plan's `catalogs-publish-cutover` edits a *catalog* repo but is `implementation`, because it repoints a release pipeline's configuration and publishes nothing itself. Phase is not derivable from `repo`, which is why it is a required field rather than an inferred one.

**Ordering is enforced as an edge rule, not a barrier.** `task plans:vet` fails if any `implementation` slice `depends_on` a `migration` slice — locally or across plans. Checking direct edges is sufficient, since a transitive implementation→…→migration path always contains at least one direct one. What it deliberately does *not* do is block a migration slice whose own dependencies are satisfied merely because unrelated implementation work is still open; `task plans:ready` surfaces that as an annotation instead.

**Not the `enhancements` workflow's Phases 1–5.** That numbering (Create / Iterate / Promote / Implement / Supersede) describes an *entry's* lifecycle. A slice's `phase` describes one *slice's* kind.

## Core rules

1. **A slice is thin.** `id`, `repo`, `phase`, one-line `concern`, `depends_on`, `status` — that's the whole shape (plus optional `decisions`, optional `resolves`, optional `openspec_ref`, and on a cancelled slice `cancelled_reason`). Task breakdowns and code-level detail belong in the target repo's OpenSpec change. `concern` is capped at 240 runes so that rule is checked rather than remembered.
2. **`id` is a stable kebab-case slug, unique within the plan.** Never reused, even if the slice is cancelled — other slices' `depends_on` may already cite it. Choose an id that reads well as `<repo>/<id>` once it becomes an `openspec_ref`.
3. **`repo` must be a member of some implemented entry's `affects`.** `task plans:vet` enforces this against the union across `implements`. If a slice needs a repo not yet listed, the enhancement's `affects` is wrong — fix it there first.
4. **`depends_on` accepts two forms:** a local slice id (resolved within the same plan), or a cross-plan reference `"<plan-slug>:<slice-id>"` pointing at a slice in another plan under `plans/`. Cross-plan refs must resolve — a dangling plan slug is a typo, not a planning gap.
5. **Status has four values: `planned | in-progress | done | cancelled`.** There is no stored `blocked` state — whether a slice is blocked is *derived* from whether its dependencies are `done` (`task plans:ready` computes this). A stored blocked flag would go stale the moment a dependency lands; deriving it never does.
6. **A cancelled slice keeps its id and records why.** Set `status: cancelled` and `cancelled_reason: "..."` — mirrors the enhancements repo's tombstone convention for a vacated `DN`/`OQN`. Do not delete a cancelled slice's entry if anything else's `depends_on` cites it.
7. **The plan is the landing record.** `status` and `openspec_ref` change here when a slice lands. The enhancement's `history` may record the milestone in its own words, but it never cites the slice or the OpenSpec slug — the one-way rule. (The legacy `history[].slice` field predates this rule; never write it in new events.)
8. **`phase` is required, deliberate, and ordered.** Classify by what the slice is *for*, never by which repo it lands in — a `catalog` slice can be either. When a slice would straddle the boundary, split it rather than picking a phase for it.
9. **Decision citations live in `decisions`, not in `concern`, always fully qualified.** A slice lists the decisions it implements as `"NNNN:D34"` — qualified because a plan may implement several entries. `task plans:vet` checks every number resolves; `task plans:uncovered` inverts it and reports a decision **no slice in any plan carries**. A decision that genuinely needs no slice goes in the plan's top-level `unsliced` map (qualified key, reason as value). Measured 2026-08-05, before the field existed: the median `concern` was 205 of 240 runes with up to 41 spent on an inline citation tail.
10. **Deferred Open Questions are claimed via `resolves`.** An enhancement may close acceptance with implementation-level OQs marked `Status: deferred-to-implementation` (context attached, no inheritor named). The slice that picks one up claims it as `resolves: ["NNNN:OQ9"]`; `task plans:deferred` reports deferred OQs no slice claims. Resolve the claimed question inside the slice's OpenSpec change and record the outcome there.

## Lifecycle

| Status | Meaning | Next |
| --- | --- | --- |
| `planned` | Declared, not started. Ordering and repo are settled; nothing has landed. | Once its `depends_on` are all `done`, it surfaces in `task plans:ready` — start it. |
| `in-progress` | A target-repo OpenSpec change is open for this slice. | Land it, then flip to `done` and set `openspec_ref`. |
| `done` | Landed. `openspec_ref` set. | Terminal — other slices' `depends_on` may now resolve against it. |
| `cancelled` | Will not ship. `cancelled_reason` set. | Terminal — id retained for any `depends_on` still citing it. |

When the whole plan completes (every slice `done` or `cancelled`), close the loop on the enhancement side under its own skill: `implementation.status: complete`, the dated history event, the README snapshot block — in plan-blind wording.

## Create

```bash
# from enhancements/, or via the workspace include `task enhancements:plans:new …`
task plans:new SLUG=<slug> IMPLEMENTS=NNNN[,NNNN]
```

Scaffolds `plans/<slug>/plan.yaml` with the `implements` list and an empty `slices: []`. Refuses if the plan already exists. Name the plan after the enhancement's slug when it implements one entry; give a coordinating plan its own name. See `plans/README.md` for the field reference and a worked example.

Deciding whether an enhancement needs a plan at all is the real first step, not the command. Read its `06-operational.md ## Cross-Repo Coordination` first: a single hand-off or two needs no plan; real ordering constraints across repos do.

## Update

Adding a slice, changing its status, or wiring a dependency are all direct edits to `plan.yaml` — the shape is small enough to hand-edit safely. After any edit:

```bash
task plans:vet SLUG=<slug>
```

Validates schema conformance, `implements` resolution, `id` uniqueness, `repo ∈` the implemented entries' affects, every `depends_on`/`decisions`/`resolves`/`unsliced` reference resolving, no dependency cycle, and the phase edge rule.

When a slice lands: set `status: done` and `openspec_ref: <repo>/<openspec-slug>`, then re-render the views below. When a slice is cancelled and the cancellation reverses something the *design* decided, that reversal is the enhancement's business — an amending `DN` under its own protocol; `cancelled_reason` here states the delivery-side fact.

## Views

```bash
task plans:graph SLUG=<slug>       # regenerate plans/<slug>/PLAN.md — Mermaid DAG + table, one subgraph per phase
task plans:ready SLUG=<slug>       # slices whose depends_on are all `done`, grouped by phase
task plans:uncovered SLUG=<slug>   # decisions of the implemented entries no slice carries — the coverage inverse
task plans:deferred                # deferred-to-implementation OQs no slice claims
```

`plans:graph` is generated — it carries a "do not edit by hand" header and regenerates from `plan.yaml` on demand. Run it after any edit that changes structure, phase or status. Nodes are grouped into one Mermaid `subgraph` per phase; a phase with no slices emits no subgraph. Cross-plan peripheral nodes sit outside both, since they belong to neither phase of this plan.

`plans:ready` is the order-of-procedure answer: it computes the topological frontier directly. A cross-plan dependency counts as satisfied only if the other plan marks that slice `done`. The migration header reports how many implementation slices remain open — **informational, not a gate.**

`plans:uncovered` and `plans:deferred` are read at plan-authoring time and again before the enhancement's `implemented` flip. Neither is a gate: `plans:vet` checks that citations *resolve*; whether every decision is *carried* and every deferred question *claimed* is a readiness judgement.

## Seeding a slice's OpenSpec change

```bash
task plans:seed SLUG=<slug> SLICE=<slice-id>
```

Prints a short stub — repo, phase, concern, status, the implemented entries with their titles, unresolved dependencies (a warning, not a block) — sized to hand to that repo's own `openspec new` (or whichever workflow it uses).

This is the boundary to respect: **`plans/` produces the seed; it does not reach into another repo's tooling.** `plans:seed` never shells out to a target repo and never writes files outside `plans/`. Copy the printed stub into the target repo and run that repo's own OpenSpec skill.

## Anti-patterns

- **Scaffolding a plan for every new enhancement.** An empty or single-slice plan is noise; add it only when the coordination need actually surfaces.
- **Putting implementation detail in `concern`.** A `concern` bloating past one line is a sign the content belongs in the target repo's OpenSpec change. The 240-rune cap will tell you.
- **Writing decision citations into `concern` prose.** They go in `decisions`, qualified, where they can be checked and inverted.
- **Bare decision refs.** `D34` is ambiguous in a plan that may implement several entries; every ref is `NNNN:D34`. The schema enforces it.
- **Using `unsliced` to quiet a report you don't want to read.** Each entry is a claim that the decision needs no work, reviewed like any other line. If you cannot write the reason in a sentence, the decision probably does need a slice.
- **Storing a `blocked` status.** There isn't one. Blocked-ness is computed by `task plans:ready`.
- **Writing a plan pointer into the enhancement.** No history event cites a slice or OpenSpec slug, no doc names a plan file — the one-way rule. The plan is the landing record; the enhancement records milestones in its own words.
- **Renumbering or deleting a cancelled slice's id.** Other slices may cite it in `depends_on`. Cancel in place with `cancelled_reason`.
- **Expecting `task plans:seed` to talk to another repo.** It only prints. The actual OpenSpec change is scaffolded in the target repo, under its own skill.
- **An implementation slice depending on a migration slice.** `task plans:vet` rejects it. If the dependency is real, one of the two is misclassified, or the implementation slice is doing migration work that should be split out.
- **Classifying by repo instead of by purpose.** A `catalog`/`modules` slice is not automatically `migration`, and a slice is not `implementation` merely because it edits committed source.
- **Restating the phase split in `plan.yaml`'s header comments.** The field is the source of truth and `task plans:graph` renders it. Keep the comments for *why* the seam falls where it does.

## Where things live

| Artefact | Path | Authority |
| --- | --- | --- |
| Delivery plan | `plans/<slug>/plan.yaml` | Hand-authored. Validated by `#DeliveryPlan` in `plans/schema.cue` plus the cross-referential checks in `plans/Taskfile.yml`. |
| Rendered DAG | `plans/<slug>/PLAN.md` | Generated by `task plans:graph` — do not hand-edit. |
| Schema | `plans/schema.cue` (`#DeliveryPlan`, `#Slice`, `#SliceStatus`, `#SliceRefStr`, `#DecisionRefStr`, `#OQRefStr`) | CUE contract for `plan.yaml`. |
| Rules canonical text | `plans/README.md` | The field reference, worked example, and the one-way rule stated from the plans side. |
| Narrative counterpart | `enhancements/NNNN/06-operational.md ## Cross-Repo Coordination` | Ordering constraints as design facts — never a plan pointer. |
| Workflow tasks | `plans/Taskfile.yml` (`new`, `vet`, `graph`, `ready`, `uncovered`, `deferred`, `seed`) | Tooling source. |
| This skill | `enhancements/.claude/skills/delivery-plans/SKILL.md` | Workflow guidance — the file you are reading. |

## Cross-references

- `enhancements/CLAUDE.md` — repo guide; points to this skill alongside the other sibling skills.
- `enhancements/.claude/skills/enhancements/SKILL.md` — the authoritative workflow protocol for the design side; its Phase 3 (`draft → accepted`) checklist is where deciding on a delivery plan belongs, and its `## OpenSpec — sister workflow` section is what `task plans:seed`'s output feeds into.
- `plans/README.md` — canonical rules text and a worked example.
- `enhancement-experiments` skill (sibling) — the closest precedent for an optional, structurally-validated, non-mandatory artefact; the "don't scaffold until needed" discipline is shared.
- `enhancement-compaction` skill (sibling) — governs decision-body edits on the design side; a cancellation that reverses a design decision routes through it (or an amending `DN`), never through this plan alone.
