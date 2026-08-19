# Experiment 08: concurrent-render-at-scale

Status: Concluded

## Hypothesis

Experiment 06's concurrency answers were all measured on the same two-component module experiment 04 used, whose renders churn about 60 MB. Experiment 07 then measured that a 129-component module churns about **900 MB per render**. Sixteen workers each doing that is a different memory-bandwidth and garbage-collection regime, and nothing has checked it. The enhancement's standing recommendation, a fresh `cue.Context` per render with nothing shared between renders, rests on 06's numbers holding at the sizes 07 showed the collapse is actually good at.

The claim: **module size does not change 06's answers.** Concretely, and pre-registered as thresholds in `main.go`:

1. **Scaling survives.** Peak speedup at `P>=4` stays above **2x** at every module size, including 129 components. Refuted below that at any size.
2. **Memory grows with workers, not super-linearly.** Peak resident memory from `P=4` to `P=16` grows by no more than **6x** (four times the workers, plus headroom). Refuted above that.
3. **Retention is still per render, and still fatal to a reused context.** `S1` retains proportionally to renders at these sizes too, and the per-render figure is far above the 37.5 MB 06 measured, because the render is far larger. Reported rather than thresholded; the interesting number is whether it is survivable at all.
4. **Concurrency still does not change the answer.** Every concurrent render's digest matches that strategy's own sequential `P=1` render, at every size and worker count.

The counter-hypothesis worth naming, because it is the reason to run this at all: at 129 components a single render's working set may be large enough that P concurrent renders spend their time in the allocator and the collector rather than in CUE, in which case the throughput curve flattens early and the right operator design is a small worker pool rather than one per core.

### Why this is a new experiment and not an arm on 06 or 07

The protocol is one concept per experiment, and this is a third concept: not "does it parallelise" (06) and not "what does size cost" (07), but "does the first answer survive the second's inputs". The precedent is 06 itself, which was spun out of 04's residue rather than added to 04, and which copied 04's fixtures rather than growing them. This does the same one level up.

## Setup

| Path | Role |
| --- | --- |
| `fixtures/`, `gen.go`, `fixtures.go`, `arms.go` | **copied byte for byte from `experiments/07-module-scale-cost/`**, with only the module path renamed |
| `strategies.go` | the three strategies, the worker pool and the memory sampler, copied from `experiments/06-concurrent-render/` |
| `main.go` | the sweep, the report, and the four pre-registered verdicts |
| `race_on.go` / `race_off.go` | the build-tag pair that lets a run state whether the detector was on |

Copying 07's fixtures rather than importing them is what makes "06's questions at 07's sizes" a fact rather than a claim: the modules, the platform, the render glue and both render paths are the same bytes 07 measured, so a difference here is attributable to concurrency.

### The three strategies

| ID | Shape | Why it is here |
| --- | --- | --- |
| `S2` | a fresh `cue.Context` per render | the shape experiments 04 and 06 leave standing, and the one this experiment exists to stress |
| `S1` | one `cue.Context` per worker, reused across that worker's renders | 06 disqualified it on retention (37.5 MB per render on a 2-component module). At 129 components the same shape should be dramatic, and this turns an extrapolation into a measurement |
| `SB` | today's path: platform held once, one `cue.Context`, **one mutex** | the honest yardstick. 06 measured the *concurrent* form of today's path producing 2321 data races, so what an operator can safely run today is the serialised version, and that is what S2 has to beat |

06's S3 (one shared context for every worker) and S4/S5 (ADR-002's shared held platform) are deliberately absent. 06 answered them: S3 is race-clean but retains like S1, and S4/S5 race. Re-running them here would be re-asking 06's question rather than asking this one.

### The sweep

Fleet fixture, blueprint authoring (the heavier of 07's two styles, so the memory question is asked in its worst case), at **2, 9, 33 and 129 components**, across **P = 1, 2, 4, 8, 16** on 16 cores.

Renders per point fall as the module grows (64, 64, 48, 32), because a 129-component render takes about two seconds and a fixed count would make the largest points dominate the run. The count is printed per row, and speedup is only ever computed within one size, where the count is constant.

### Guards

- **Output count.** Every render must produce exactly the size's expected pair count.
- **Correctness under concurrency.** Each strategy's `P=1` point IS its sequential reference: every render at higher `P` must produce the same digest for the same index. Using `P=1` rather than a separate reference pass halves the run, which at these sizes is the difference between a ten-minute experiment and a twenty-minute one.
- **Cross-strategy agreement.** The `P=1` references are themselves compared across strategies, which is the check a strategy compared only against itself could never make. Strict and list-order-insensitive digests are reported separately, because experiment 07 found finalization reorders map-derived lists.
- **An RSS ceiling.** A strategy that retains per render can exhaust the machine inside one point at these sizes. The sampler stops the point when resident memory crosses `-max-rss-gb` (default 24) and the row is marked `CAPPED`. That turns "this does not fit" into a measurement where an OOM kill would be a lost run.

### What this does not measure

- **Safety of the shapes 06 disqualified.** 06 owns that. The race detector runs here only to check that size does not change 06's answer for the shapes that survived it.
- **Cost per render.** 07 owns that, and this experiment's per-render latencies are contended and not comparable to 07's.
- **A real operator's scheduling.** The pool hands each index to whichever worker is free, which is what a work queue does, but there is no admission control, no per-tenant fairness, and no backpressure.

## Run

```bash
./run.sh                    # the full sweep
./run.sh --fresh            # rebuild the scratch tree first
./run.sh --race             # the safety half: detector on, one size, few renders
./run.sh -sizes 128 -renders 16 -workers 1,16 -strategy S2
```

`run.sh` sets `CUE_REGISTRY` if unset, materializes the tree once with `-setup-only`, then measures with `-reuse`. **Delete `_out/run` (or pass `--fresh`) after editing `gen.go`** — the reuse check is structural.

Requires the `cue` CLI on `PATH` (setup only) and network access on the first run. The full sweep holds several GB resident at `P=16`; `-max-rss-gb` bounds it.

## Outcome

**All four claims held, and the counter-hypothesis was wrong: module size does not change experiment 06's answers at all.** The more useful result is one the experiment was not looking for. Once the safety constraint 06 established is applied, experiment 07's crossover disappears: `S2` beats what an operator can safely run today at **every** size, including the sizes where 07 measured the single build costing more per render.

Measured on an AMD Ryzen AI 7 350 (8 physical cores, 16 threads), Go 1.26.5, `cue v0.17.1`, 4 sizes x 3 strategies x 5 worker counts, 2688 renders, zero failures. Full output in [`_out/results.txt`](_out/results.txt).

### Scaling is flat in module size

Speedup over each strategy's own `P=1`, renders per second in the left half of each cell:

```
S2-ctx-per-render
     K   COMPS         P=1         P=2         P=4         P=8        P=16
     1       2    8.7/1.0x   16.0/1.8x   27.1/3.1x   36.1/4.2x   37.1/4.3x
     8       9    4.6/1.0x    8.6/1.9x   14.2/3.1x   19.1/4.1x   19.9/4.3x
    32      33    1.8/1.0x    3.3/1.8x    5.5/3.1x    7.2/4.0x    7.7/4.2x
   128     129    0.5/1.0x    1.0/1.9x    1.6/3.1x    2.1/4.0x    2.1/4.0x
```

Peak speedup is **4.28x, 4.33x, 4.24x, 4.05x** at 2, 9, 33 and 129 components. A 129-component render churns about 900 MB and it scales within 5% of a 2-component render that churns 60 MB. The counter-hypothesis, that a large module's working set would push P workers into the allocator and flatten the curve early, is simply not what happens.

The curve saturates at `P=8` and `P=16` buys nothing, which is the machine rather than CUE: 8 physical cores with SMT. Read that way it is close to perfect physical-core scaling, and it reproduces experiment 06's "about 4x on eight cores" exactly, at 64 times the module size.

### The measurement 07 could not make

Experiment 07 compared the single build against today's path **sequentially**, and found the crossover at 4.6 to 14.2 components. But experiment 06 established that today's path cannot be run concurrently: ADR-002's shared held platform produces thousands of data races. So the honest comparison is `S2` concurrent against today's path **serialised**, which is what `SB` measures:

```
     K   COMPS        S2_best        SB_best     RATIO
     1       2          37.07          14.95     2.48x
     8       9          19.92           4.88     4.09x
    32      33           7.65           1.46     5.26x
   128     129           2.10           0.38     5.49x
```

**There is no crossover.** At 2 components, where 07 measured the single build costing 1.74x more per render, `S2` still delivers 2.48x the throughput, because it can use the other seven cores and today's path cannot. The advantage then grows with module size to 5.49x, since 07's per-render advantage compounds with the parallelism.

This is the number that matters operationally, and neither 06 nor 07 could produce it: 06 had the concurrency but not the size, 07 had the size but not the concurrency.

### Retention scales with the module, and it is not the collapse's fault

Live heap after a forced GC at the end of each point, with the strategies' contexts deliberately still referenced (`P=4`):

```
STRATEGY              COMPS     N   HEAP_KEPT   PER RENDER
S2-ctx-per-render         2    64        2.2M       35.0K
S2-ctx-per-render         9    64        2.9M       45.6K
S2-ctx-per-render        33    48        3.3M       69.8K
S2-ctx-per-render       129    32        3.7M      117.2K
S1-ctx-per-worker         2    64        2.6G       41.9M
S1-ctx-per-worker         9    64        4.5G       71.8M
S1-ctx-per-worker        33    48        8.1G      173.8M
S1-ctx-per-worker       129    32       18.2G      581.8M
SB-base-serialised        2    64      768.6M       12.0M
SB-base-serialised        9    64        1.9G       30.6M
SB-base-serialised       33    48        4.4G       94.1M
SB-base-serialised      129    32       10.9G      348.0M
```

Three things.

**`S1`'s 41.9 MB per render at 2 components independently reproduces experiment 06's 37.5 MB**, on a different harness with a different fixture at the same size. That is a useful cross-check on 06 rather than a new finding.

**The per-render retention grows with the module**, 41.9 MB to 581.8 MB, which is what the extrapolation from 06 and 07 predicted and is now measured rather than argued. `S1` at 129 components held **22 to 23.4 GB resident** through only 32 renders, and never tripped the 24 GB ceiling only because the render count was capped at 32. One more worker's worth of renders and this point would have been a measurement of the ceiling instead.

**`SB` retains too, at 348 MB per render.** Today's path holds one `cue.Context` for the life of the process by construction, so the retention problem is not something the collapse introduces; it is one the collapse is the only measured escape from. `S2` holds 117 KB per render at 129 components, five thousand times less than `S1` at the same size, and its retention is flat in render count.

### Resident memory under concurrency

Peak RSS grows sub-linearly in workers for `S2`: from `P=4` to `P=16`, a 4x increase in workers costs 3.39x to 5.64x more resident memory, and the growth is smallest at the largest module. The operational figures an operator would size against:

| components | P=4 | P=8 | P=16 |
| --- | --- | --- | --- |
| 2 | 285 MB | 595 MB | 1.6 GB |
| 9 | 646 MB | 1.1 GB | 2.2 GB |
| 33 | 1.4 GB | 2.4 GB | 6.7 GB |
| 129 | 4.0 GB | 8.3 GB | 13.6 GB |

Sixteen concurrent renders of a 129-component module need about 14 GB. That is a real constraint, and it is the argument for a worker pool sized by memory rather than by core count. It is also five times less than `S1` needs for the same work.

### Correctness

**Zero wrong values, across 2688 renders at every size and worker count.** Every concurrent render's bytes matched that strategy's own sequential `P=1` render for the same index. The `P=1` references were then compared across strategies and agreed byte-for-byte at all four sizes, including between the single build and today's finalizing path (the fleet fixture writes its environment plainly, so experiment 07's list-order divergence does not arise here).

### Safety: size does not change it either

The race detector run is in [`_out/results-race.txt`](_out/results-race.txt): 33 components, `P=8`, `S2` and `SB`, **zero data race reports**.

That is the answer this half was for. Experiment 06 established `S2` race-clean on a 2-component module and, in the same run, produced 2321 reports from ADR-002's shared held platform. The open question was whether a module large enough to change the evaluation's shape changes that verdict. It does not, for either the strategy under recommendation or the serialised yardstick.

`S1` is deliberately absent from the race run: it holds 9.8 GB at this size without the detector, and the detector multiplies that. 06 already established it race-clean, and its problem is memory rather than safety.

### Six findings

**1. Concurrent scaling is independent of module size**, within 5% across a 64-fold size range. 06's number stands unchanged.

**2. There is no crossover once safety is accounted for.** `S2` beats the serialised baseline 2.48x at 2 components and 5.49x at 129. Experiment 07's sequential crossover at about a dozen components is real but not decision-relevant, because the thing it crosses over cannot be run concurrently.

**3. `S2` retention is flat and negligible at every size**, 35 KB to 117 KB per render. This is the property that makes a long-lived render worker safe, and it does not degrade with the module.

**4. A reused context is worse at scale, in proportion to the module.** `S1` retains 581.8 MB per render at 129 components. 06 disqualified it on a figure fourteen times smaller.

**5. Today's path has the same retention problem, and it is worse than the collapse's.** `SB` holds 348 MB per render. This is worth stating plainly because the retention finding has been read as a cost of the collapse; it is not, it is a cost of holding a `cue.Context`, and the collapse is what makes dropping one per render affordable.

**6. Throughput saturates at physical cores, not threads.** `P=16` adds between nothing and 5% over `P=8` at every size. An operator sizing a render pool should count physical cores and then check the memory table above, because memory is the binding constraint well before threads are.

### Follow-up: is there parallelism to gain INSIDE one render?

Measured after this experiment concluded, on the same harness and tree, because the question came up and the answer changes what an operator should build. Six renders of a 129-component module through one worker, timed three ways:

```
                   CPU%    per render   RSS peak
default            159%       1922 ms      1.2G
GOGC=off           104%       1822 ms      5.6G
GOMAXPROCS=1        99%       2692 ms      1.6G
```

**CUE's evaluation of a single build is single-threaded.** With the collector disabled the process uses 1.04 cores, so the 59% of extra CPU at default settings is the concurrent garbage collector, not parallel evaluation of the (component, transformer) pairs. Forcing everything onto one OS thread costs 40% wall time, which is the collector losing its own thread and competing with the evaluator.

Two consequences.

There is **no within-render parallelism to harvest**. In the collapsed design the pairs live inside one CUE build, so there is no Go-side loop to parallelise, and the evaluator will not do it. In today's path the pairs *are* a Go loop, and parallelising it is exactly the shape experiment 06 measured producing 2321 data races. The parallelism available is across renders, which is what this experiment measured.

And it explains the ceiling. Each render demands about 1.6 cores (one evaluator plus roughly 0.6 of collector), so eight physical cores saturate at about five renders in flight. The measured peak of 4.0x to 4.3x is that number, not a scheduling defect.

### Follow-up: could ONE large render be split across parallel builds?

The obvious next idea is to build the instance once, match, and hand subsets of the matched pairs to separate builds running in parallel. `-timesplit` measures whether there is anything there, by holding the instance fixed and varying only how many components the generated render module asks for. Full output in [`_out/results-timesplit.txt`](_out/results-timesplit.txt); six fixture and style combinations:

| fixture | style | components | transform per component | outputs each | transform per object | serial floor | Amdahl ceiling |
| --- | --- | --- | --- | --- | --- | --- | --- |
| fleet | bp | 129 | 4.32 ms | 3 | 1.44 ms | 70% | 1.43x |
| fleet | raw | 129 | 4.29 ms | 3 | 1.43 ms | 46% | 2.16x |
| fleet | bp | 33 | 3.79 ms | 3 | 1.26 ms | 76% | 1.31x |
| fleet | raw | 33 | 4.42 ms | 3 | 1.47 ms | 55% | 1.82x |
| complex | bp | 32 | 10.77 ms | 5 | 2.15 ms | 69% | 1.45x |
| complex | raw | 32 | 11.73 ms | 5 | 2.35 ms | 52% | 1.91x |

**So how fast is the transformer step?** About **1.3 to 1.5 ms per rendered Kubernetes object** for the shallow fixture and **2.2 to 2.4 ms** for the deep one, which is 3.8 to 4.4 ms per component at three outputs and 10.8 to 11.7 ms at five. On the full 129-component fleet that is 557 ms of an 1860 ms render.

**And no, the transformers are not the slow part. Constructing the components is.** Two independent readings say so.

`FORCE` in the raw output is the time to make `rendered` concrete *after* `BuildInstance` returns: **3.0 ms out of 1831 ms** for 387 objects. CUE has already evaluated every pair by the time the build call returns, which reproduces experiment 04's finding 4 at 64 times the module size. The pairs are not deferred work waiting for a worker.

And rendering a single component out of a 129-component instance still costs 1303 ms of the 1860 ms full render. That floor is the instance and its catalog being built, and every split re-pays it in full.

**The transform cost is identical between blueprint and raw authoring** (4.32 against 4.29 ms per component on the fleet, 10.77 against 11.73 on complex). That pins the entire blueprint tax experiment 07 measured on component *construction* rather than on transformation, which is the mechanism 07 inferred and this measures.

### What that means for splitting

The floor has to be paid, serially, before any transform can start, because transforms consume components. That is an Amdahl bound, and it does not care how the parallel half is implemented:

```
fleet bp 129 comps   K=2 1.18x   K=4 1.29x   K=8 1.35x   ceiling 1.43x
fleet raw 129 comps  K=2 1.53x   K=4 1.81x   K=8 1.97x   ceiling 2.16x
```

Between **1.31x and 2.16x** depending on module shape and authoring style, for K times the working set (about 1 GB each at 129 components) and K cores an operator would otherwise spend on other renders, which parallelise at 4.0x to 4.3x for 1x memory each. The ceiling is highest exactly where the absolute time is already lowest, because raw authoring shrinks the serial floor rather than the parallel part.

**This corrects an estimate in an earlier version of this section**, which projected roughly 4x by applying experiment 07's 14.01 ms-per-component slope to a subset build. That slope conflates about 4.3 ms per component of transform work, which a split could divide, with about 9.3 ms of component construction, which it cannot. Only the smaller half was ever splittable. An earlier revision then over-generalised the fleet-with-blueprints figure to "70%, 1.43x"; the table above is the range.

The practical lever on a large module's render time is not concurrency. Authoring the same 129-component fleet with primitives instead of blueprints takes it from about 1.86 s to about 1.03 s, a 1.8x win at no extra memory and no extra cores, which is at or above what splitting could reach even in the best case.

### Limits

- **One machine, 8 physical cores.** The 4x is the core count, not a property of CUE. What travels is that the ratio does not move with module size.
- **No admission control or backpressure.** The pool hands each index to whichever worker is free. A real operator queue would also have to decide what happens when 16 large renders arrive at once, which the memory table says is the interesting case.
- **Renders per point fall as the module grows** (64, 64, 48, 32), so the largest points have the least statistical weight. Speedup is only ever computed within one size, where the count is constant.
- **The RSS ceiling never fired**, so no point was truncated, but `S1` at 129 components came within 0.6 GB of it. That number is a floor on what that strategy costs, not a measurement of where it stops.
