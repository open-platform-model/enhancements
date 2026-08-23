---
name: enhancement-gates
description: Walk the admission rubric in enhancements/gates.cue against one entry, one rule at a time, and record evidence-backed verdicts to .gates/NNNN.yaml. Load before creating an enhancement (the creation gates) and before promoting draft → accepted (the promotion gates), or whenever `task gate ID=NNNN` reports gates not yet walked. `task promote` refuses without a current verdict file.
user-invocable: true
---

# Enhancement Admission Gates

This skill decides **whether something is an enhancement at all**, and whether a draft is fit to freeze. It is the only path to a verdict file, and `task promote` refuses to flip `draft → accepted` without one.

## Why this exists

An enhancement is a new feature, or the rework of an existing one. It is **not** a logbook, not a scratchpad, and not a place to prescribe how a repo builds something. Those three drifts are what this rubric catches, and none of them is catchable by regex alone: "is this a feature or a chore?" and "is this contract or mechanism?" are judgment calls.

So the enforcement is split. `task gate` runs the deterministic half — `vet`, blocking Open Questions, delivery, and the probes declared in `gates.cue`. This skill runs the judgment half. **Never spend a walk on what the probes already answer.**

## The rule that makes this a gate and not a ritual

> **A verdict without a quote is invalid.**

Every verdict names the evidence its rule demands, quoted from the entry. An agent asked "does this entry look okay?" rubber-stamps. An agent asked "quote the three sentences that most read as a logbook" cannot, because either the quotes exist or they do not.

Two supporting rules:

- **Frame the walk adversarially.** Your job on each rule is to find the failure, not to confirm the pass. Default to `fail` under uncertainty and let the author argue you out of it.
- **Do not soften a fail into a pass with a caveat.** A rule with a real counterexample is `fail`. The author fixes it or overrides deliberately; both are better than a hedged pass nobody reads.

## Procedure

### 1. Read the rubric and the mechanical state

```bash
task gate ID=NNNN              # promotion gates (default)
task gate ID=NNNN WHEN=creation
```

This prints every applicable rule with its question and evidence requirement, plus the probe hits. Read the probe hits before you read the entry: they are candidate evidence, already located.

### 2. Walk one rule at a time

For each rule, in the order `task gate` printed them:

1. State the rule's question back, in one line, as it applies to *this* entry.
2. Gather the evidence the rule demands. Probe hits are candidates, not verdicts: a hit inside a `**Source:**` line is provenance and passes, a hit inside a design claim is prescription and fails.
3. Give the verdict: `pass` or `fail`, with the quote and one sentence of reasoning.
4. On `fail`, name the rule's `redirect` destination concretely — which repo's OpenSpec change, which plan, `IDEAS.md`, or the specific edit that would fix it.

Do not batch the rules into one answer. The value is in each being asked separately; a combined verdict is where "mostly fine" hides.

### 3. Record the verdict file

Write `.gates/NNNN.yaml`:

```yaml
entry: "0012"
entry_hash: "<output of ./scripts/entry_hash.sh 0012>"
walked: "YYYY-MM-DD"
verdicts:
  - gate: feature
    verdict: pass
    evidence: "summary: 'Move the Kubernetes runtime surface into the kernel …'"
    reasoning: "Names a capability the kernel does not have; both frontends fork it today."
  - gate: rewrite
    verdict: fail
    evidence: "02-design.md:44 'pkg/core/{labels,resource,convert}.go … are deleted, not aliased'"
    reasoning: "Prescribes package deletions. The contract statement is 'the kernel is the only implementation'; the file list belongs to the slice."
```

The file is **overwritten, never appended** — it states the current verdict, not a history of walks. It lives outside the entry on purpose: a gate report accumulating inside `NNNN/` would be the logbook this rubric exists to prevent.

It is **committed**, so the evidence quotes appear in the PR diff where a human reads them. That is the check on this skill: a fabricated pass is a quote that does not support its claim, visible to a reviewer.

`entry_hash` binds the walk to the content. Edit the entry afterwards and `task promote` refuses until you re-walk. The hash covers the six documents and the design-bearing config fields, not `updated` or `history`, so bookkeeping edits do not void a walk.

### 4. Act on the result

- **All pass** — `task promote ID=NNNN`. It re-checks vet, blocking questions, and semver on its own.
- **Any fail** — fix or redirect, then re-walk. The hash makes this mandatory rather than optional.

## At creation

The `creation` gates (`feature`, `contract`, `single-question`, `prior-art`) run **before** `task new`, because the cheapest place to decline an idea is before eight files exist.

`task new` already forces the `feature` answer by requiring `SUMMARY`, and the `NOT` answer by requiring the out-of-scope line. What it cannot do mechanically is `prior-art`: run `task archive:data`, compare, and if this restates a rejected idea, either set `revives: ["NNNN"]` and state what changed, or drop it. A rejected idea legitimately returns when circumstances change; re-proposing one silently is what the gate stops.

**If the idea fails `feature` at creation, it has somewhere to go.** A one-line entry in `IDEAS.md` costs nothing and rots nothing, because there is no structure in it to rot. Scaffolding an entry for a half-formed idea is what produces the scratchpad.

## What this skill does not do

- It does not evaluate whether the *design is good*. That is the Open Questions walk (`enhancement-open-questions`) and review.
- It does not check prose conventions. That is `task check`.
- It does not touch decision bodies. That is `enhancement-compaction`.
- It has no authority over a hand-edited `status:` field. `task promote` is the sanctioned path and `task vet` flags an accepted entry with no matching verdict file, but this is a lock, not a wall. That limit is deliberate and worth stating out loud rather than pretending otherwise.

## Cross-references

- `enhancements/gates.cue` — the rubric itself; the authority on rule text.
- `enhancements/scripts/entry_hash.sh` — what `entry_hash` must equal.
- `enhancements` skill — the surrounding workflow protocol; this skill is its Phase 1 and Phase 3 gate.
- `enhancement-open-questions` — resolve `Blocking: acceptance` questions before walking the promotion gates; they refuse promotion independently.
