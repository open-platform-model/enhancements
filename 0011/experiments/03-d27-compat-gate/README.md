# 03-d27-compat-gate — Module and Catalog Publishing

Status: Concluded

## Hypothesis

D9 gives `opm catalog publish` a compatibility gate enforcing enhancement 0010 D27's additive-only promise: *inside one `apiVersion` a contract may add but never remove; a newly added field must be optional or defaulted; an existing field's default is immutable.* D9 names no implementation, and says why — *"whether `cue.Value.Subsume` can express the rule reliably across two builds — with CUE's closedness and default handling in play — is unmeasured"* — and `04-graduation.md` makes sequencing that measurement a gate rather than a nicety, because **a gate that cannot be built as described would send 0010 D27 back to publisher discipline.**

This experiment is that measurement.

This experiment measures it, and tests three claims:

1. A single `Subsume` call — in **either** direction — does not implement D27.
2. A three-rule field-wise walk does.
3. That walk can be level-aware per D34, enforcing at beta and GA while waving alpha through.

## Setup

Pure Go against `cuelang.org/go v0.17.1`; `go.mod` copied from enhancement 0010's `experiments/02-primitive-closedness-skew` and renamed. (This experiment was authored under 0010 while D36/D37 were being settled and moved here on 2026-08-01, since the question it answers is D9's and nothing in 0010 cited it.) No registry, no network, no fixtures on disk — every case is a pair of compiled CUE strings, so the whole comparison surface is readable in `main.go`.

`cases` enumerates the change classes D27 names, each tagged with whether D27 permits it, plus nested variants and the two label cases OQ16 turns on (a narrowed label disjunction, a changed label value).

`compat.go` holds the candidate gate. Three rules:

1. **Structs** — recurse. A field present in the previous build and missing from the next is `field removed`. A field only in the next must be optional or carry a default.
2. **Leaves** — `next.Subsume(prev)`. Correct at this position: widening passes, narrowing and changed concrete values refuse.
3. **Defaults** — compared explicitly at every level, because subsume is blind to them in both directions.

`level.go` implements D34's ladder (`v1alpha1` → `v1beta1` → `v1`) and gates rule application on it.

## Run

```bash
./run.sh
```

## Outcome

**Part 1 — neither subsume direction implements D27.** Agreement across 14 cases: `next.Subsume(prev)` **10/14**, `prev.Subsume(next)` **8/14**. Neither reaches 14, and they fail on disjoint sets:

| change | D27 | `next.Subsume(prev)` | `prev.Subsume(next)` |
| --- | --- | --- | --- |
| add defaulted field | legal | **refused** | accepted |
| add required field | illegal | refused | **accepted** |
| remove field | illegal | **accepted** | refused |
| widen disjunction | legal | accepted | **refused** |
| narrow disjunction | illegal | refused | **accepted** |
| **change default** | illegal | **accepted** | **accepted** |

The reason is structural rather than incidental. Adding a field to a struct makes a value **more specific**; adding an option to a disjunction makes it **less specific**. D27 calls both "additive", so the rule spans both directions of the lattice while a subsume call tests one. The forward call is right about disjunctions and wrong about struct fields; the reverse call is exactly inverted. There is no third direction.

`change default` is missed by both, because a default does not change what a value *accepts* — only which value it settles on when unconstrained. Subsume is blind to it by construction. This independently confirms `02-primitive-closedness-skew`'s finding that a changed default is the one violation the consumer side cannot catch, now from the producer side.

**Part 2 — the field-wise walk implements it: 14/14**, including both label cases and the nested cases. Violations come back path-located (`metadata.labels.wt: domain narrowed`, `s.b: field removed`, `t: default changed ("a" -> "b")`), which is most of what 0011's refusal-message gate asks for. The walk is roughly 100 lines.

**Part 3 — level-awareness works.** The same field removal is accepted at `v1alpha1` and `v1alpha2`, refused at `v1beta1`, `v1` and `v2`. The alpha case is the one worth asserting: a gate that checks everything passes every beta test while silently contradicting D34.

**Hypothesis held on all three claims, and the graduation gate is satisfied in the direction that matters.** D9's own text makes the stakes explicit: a gate that could not be built as described would send 0010 D27 back to publisher discipline. It can be built — just not by the primitive D9 gestured at. **0010 D27 therefore stands unchanged**, and D9 gains an implementation shape rather than losing its premise.

The comparator here is a **demonstration, not the shipped gate.** The real one belongs in `library` — pure `cue.Value` logic, so `opm catalog publish`, `opm catalog registry check --compat` (D7) and any CI action share one implementation. Predecessor selection already exists there too: `library/opm/materialize/enumerate.go`'s `enumerateVersions` lists published versions for a module path, and `filter.go:112`'s `highestStable` implements the right selection (skip `-dev.*` and prereleases, fall back to highest overall). **Enhancement 0010 D14 deletes `filter.go`, and `highestStable` with it** — that should be a move rather than a delete-then-rewrite.

