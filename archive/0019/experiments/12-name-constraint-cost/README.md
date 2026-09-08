# 12-name-constraint-cost — Kernel render path parity with pure CUE

Status: Concluded

## Hypothesis

D21's `_nameConstraints` collection is a second walk over the three
attachment maps that `_matchLabelsFromPrimitives` already walks, plus one
hidden assertion per component. The question is what that costs per
component at evaluation time, and whether it is visible against the
per-render figures experiment 07 measured for the single build. Refuted if
the increment exceeds about 10% of experiment 07's marginal per-component
render cost, or grows faster than linearly in component count.

## Setup

Measured against the REAL `core` package on the
`core-name-types-and-constraint` working tree (branch
`feat/name-types-and-constraint`, 2026-08-26), not a stand-in: cue v0.17.1,
16 cores, `cue vet -c ./...` from `core/src` with a scratch fixture
generating N components. Each component attaches two resources (the pins
file's container answering `stateful`, so the D23 conditional constraint is
live, and an indifferent volumes resource), the Expose trait
(`#ServiceNameType`) and the stateful-workload blueprint (`#NameType`), so
every walk finds four slots and the conjunction is non-trivial.

- `bench_fixture.cue.txt` — the fixture, copied into `core/src` as
  `zz_bench.cue` for the run and deleted afterwards (`.txt` so this
  experiment directory is not itself a CUE package).
- `bench.sh` — the timing loop: N runs of `cue vet -c -t n=<N> ./...` per
  variant, reporting min and median wall clock.

Variants of `component.cue`, produced by deleting lines from the landed
file:

| Variant | Content |
| - | - |
| `without` | collection and assertion removed |
| `collect` | collection present, `_nameFits` removed |
| `with` | as landed |

A fourth run replaces the container's D23 list-index conditional with a
constant `#NameType`, to attribute the cost between the walk and the
conditional.

## Run

```bash
cd core/src
cp ../../enhancements/0019/experiments/12-name-constraint-cost/bench_fixture.cue.txt zz_bench.cue
# produce component.without.cue / component.collect.cue / component.with.cue in $VARIANTS
VARIANTS=/path/to/variants ../../enhancements/0019/experiments/12-name-constraint-cost/bench.sh
rm zz_bench.cue
```

## Outcome

**Hypothesis held: the increment is linear, about 0.16 to 0.22 ms per
component, and the collection is all of it.**

| N | without (median) | with (median) | increment | per component |
| - | - | - | - | - |
| 10 | 44.2 ms | 47.0 ms | +2.8 ms | 0.28 ms |
| 100 | 106.1 ms | 126.0 ms | +19.9 ms | 0.20 ms |
| 500 | 378.8 ms | 486.1 ms | +107 ms | 0.21 ms |
| 500 (7 runs) | 392.7 ms | 469.6 ms | +77 ms | 0.15 ms |
| 2000 | 1445 ms | 1752 ms | +306 ms | 0.15 ms |

Split at N=500 (7 runs): `without` 392.7 ms, `collect` 468.0 ms, `with`
469.6 ms. The three comprehensions cost the whole increment; the interpolated
assertion is within noise. Replacing the D23 conditional with a constant
constraint changes nothing (with: 478.9 ms against 469.6 ms, noise), so the
cost is the walk and the N-way unification of the hidden field, not the
list-index expression.

Relative to the fixture this is 20 to 30% of `cue vet` time, but the
fixture's components are otherwise empty: no `spec`, no transformer. Against
experiment 07's measured render costs the number is small: the single
build's marginal cost per rendered component is **7.7 to 34 ms** (raw to
blueprint-authored, fleet to complex), so the collection adds **0.5 to 2%**
of the per-component term, and under 0.3% of the fixed ~85 ms per-render
catalog cost. For the v2 staging fleet (single-digit components per module)
it is 1 to 2 ms per render.

Two things the numbers say about the design:

1. **A cheaper spelling would not be cheaper by much.** The cost is the
   per-primitive conjunct on one hidden field, the same shape as
   `_matchLabelsFromPrimitives`. Folding the two walks into one would save
   at most the walk's share of 0.15 ms and would couple two unrelated
   mechanisms; not worth it.
2. **D23's conditional is free.** Catalog primitives can compute their
   constraint from their own fields without a measurable cost, so the
   guidance to prefer the resource-owned conditional over the blueprint
   constant stands on correctness alone.

Not measured: the kernel's render path, which evaluates the same definition
through the Go API. Experiment 07 established the CUE evaluation cost model
that path follows; nothing in this block is evaluated differently there.
