# Experiment 06: concurrent-render

Status: Concluded

## Hypothesis

The single-build render path parallelises: with each worker owning its own `cue.Context`, throughput scales close to linearly with worker count up to the core count, and peak memory grows with the number of **workers** rather than with the number of renders, so an operator's throughput ceiling is set by cores rather than by a serialisation point.

Opened by experiment 04's residue. That experiment measured 90 ms per render sequentially and 2.1x the held-platform baseline, which reads as affordable only if renders can actually run at the same time. `library/opm/compile/execute.go` states in its own comment that execution is sequential because `*cue.Context` is not goroutine-safe. If that holds and no other strategy works, both the single build and today's path share a throughput ceiling of roughly eleven renders per second per process regardless of core count, and the 2.1x becomes far less interesting than the ceiling it sits under.

Falsifiable in two specific ways, stated before the harness is written. It is **refuted on scaling** if throughput plateaus below roughly 2x at four or more workers. It is **refuted on memory** if peak resident grows per render rather than per worker, since that is the shape that makes a long-lived operator process untenable no matter how fast it is.

### Why safety and scaling are one experiment

The protocol's one-concept rule pushes back on a hypothesis that names two things. They are one concept here because the safety answer **decides which scaling strategies are legal**: if a shared `cue.Context` is safe, the cheapest strategy is one context for the whole process and the scaling question is asked of that; if it is not, every worker pays its own catalog and the scaling question is asked of a different shape entirely. Measuring them apart would mean guessing the answer to one in order to design the other.

The split trigger is stated in advance: if the shared-context arm turns out to be safe but *contended* (correct under `-race`, yet serialised by an internal lock so throughput is flat), then the lock's location becomes an upstream CUE question rather than an OPM design question, and it leaves this experiment for its own entry.

> The split trigger did not fire. The shared-context arm is both race-clean and parallel, so nothing here was deferred on that ground.

## Setup

A Go harness reusing experiment 04's fixture tree and render path, with the sequential loop replaced by a worker pool. Same fixtures, same five pairs, same assertions, so the sequential numbers from 04 are directly comparable and any difference is attributable to concurrency rather than to a changed fixture. The sequential control reproduced them: 85.6 ms per single-build render against 04's 90.2 ms, and 47.8 ms per baseline render against 04's 42.3 ms.

| Path | Role |
| --- | --- |
| `fixtures/` | copied wholesale from `experiments/04-render-build-cost/fixtures/`, byte for byte |
| `main.go` | flags, the sweep, the sequential reference, the report and the two pre-registered verdicts |
| `strategies.go` | the five strategies, the worker pool, and the memory sampler |
| `arms.go` | copied from experiment 04: `renderOnce`, the baseline fill path, the finalize copy, the five-output assertion |
| `fixtures.go` | copied from experiment 04, plus `-reuse` so one scratch tree serves every process |
| `race_on.go`, `race_off.go` | a build-tagged constant, so a run states whether the detector was compiled in rather than leaving it to be remembered |
| `run.sh` | one process per strategy, the `--race` pass, and the `--mem` pass |

**Copied, never referenced**, including from experiment 04. A later edit to that experiment must not change what this one measured, which is the same reason 04 copied from 01 and 02 rather than importing them. The fixture CUE modules still carry experiment 04's `.../render-build-cost/...` module paths: renaming them would turn "the same fixtures as 04" from a fact into a claim, and every one of those paths is directory-replaced during setup, so none of them is ever resolved from a registry.

Two structural choices are load-bearing rather than tidiness.

**Each strategy runs in its own process.** A shared `cue.Context` was expected to be unsafe, and one of the ways CUE can be unsafe is a fatal runtime throw, which is unrecoverable by design and would have erased the other strategies' numbers along with its own. One process per strategy makes a crash into that strategy's result. It also means the sequential reference is computed once and cached to `_out/ref-<family>.json` rather than four times over.

**Retention is read with the workers' contexts deliberately still alive.** `runtime.KeepAlive` around the post-GC heap reading is what makes the memory column mean anything: without it Go frees the contexts before the GC runs, every strategy reports the same near-zero number, and the per-render growth that finding 3 rests on is invisible. This is why experiment 04 read 9.5 MB retained for a shared context that this harness reads at 2.9 GB. The two numbers are not in conflict; 04 measured after its context had already become collectible.

### The strategies

Each is run across a worker sweep of 1, 2, 4, 8 and 16 (the machine's thread count), rendering a fixed total of N instances so throughput is comparable across the sweep.

| Strategy | What each worker gets | What it answers |
| --- | --- | --- |
| `S1-ctx-per-worker` | one `cue.Context` per worker, reused across that worker's renders | the strategy the hypothesis rests on: legal if a context is not shareable, and the natural shape for a worker pool |
| `S2-ctx-per-render` | a fresh `cue.Context` per render | whether holding a context per worker is worth anything under load, and the safest possible shape |
| `S3-ctx-shared` | one `cue.Context` for every worker | the direct test of the `execute.go` comment. Expected to fail; the value is in HOW it fails (data race, panic, wrong output, or silently fine) |
| `S4-baseline` | one prebuilt platform value shared read-only, per-worker contexts for the instance builds | ADR-002's claim, which is that exactly this is safe today. It is the yardstick and it is also an independent check on the ADR |
| `S5-base-prewalked` | S4, with the held platform walked to completion before any worker touches it | **added mid-experiment**, after S4 raced. Separates "sharing a lazily-evaluated value" from "sharing a value at all" |

S5 was not in the plan. It exists because S4 produced the result the experiment was least expecting, and the first question that result raises is whether the fault is the sharing or the laziness. Recording it as an addition rather than folding it into the original table is the honest way to carry that.

### The metrics

- **Throughput**: renders per second at each worker count, and the speedup curve against that run's P=1 case. This is the headline.
- **Latency**: per-render median and p90 at each worker count. A flat throughput curve with rising latency is contention; a flat curve with flat latency is a serialisation point.
- **Peak resident and peak heap** sampled every 20 ms *during* the run, through `/proc/self/statm` and `runtime/metrics` rather than `ReadMemStats`, because the instrument must not stop the world when the thing being measured is throughput.
- **Kept heap**: live heap after a forced GC at the end of each point, with the contexts still referenced. The difference between churn and retention, and the reading the memory verdict turns on.
- **`-race` verdict** per strategy, which is the only honest way to answer S3.
- **Correctness under load**: every render still asserts its five outputs, and every render's exported JSON is hashed and compared against a sequential reference render of the same instance. A concurrency bug that produces a *wrong* value rather than a crash is the failure mode that matters most and the one a throughput number would hide.

### What this deliberately does not model

- **Cost per render in isolation.** That is experiment 04, and re-deriving it here would invite reading two different numbers for the same thing.
- **Matching.** The glue stays execute-only, as in 04, so the comparison holds.
- **Several platforms.** One platform, N instances. A fleet with several platforms multiplies the memory term per worker, and the harness prints per-point memory so that multiplication can be done on paper.
- **The operator's actual scheduler.** Whether `opm-operator` should run a worker pool at all, and how it would bound one, is a design question this only supplies inputs for.

## Run

```bash
export CUE_REGISTRY='opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'

./run.sh                              # every strategy across the worker sweep
./run.sh -n 200 -workers 1,4,16       # a narrower sweep with more samples
./run.sh --strategy S3 --race         # the safety question on its own, under the race detector
./run.sh --mem                        # fixed P, rising N: is memory per worker or per render
```

`run.sh` materializes one scratch tree, then gives each strategy its own `go run`. Flags it does not recognise are passed through to the harness (`-n`, `-workers`, `-strategy`, `-skip-ref`). The tree is built under `_out/run` and removed on exit unless `--keep` is passed.

Pinned to `cue v0.17.1`, matching `library/go.mod`. Measured on Go 1.26.5.

## Outcome

**Hypothesis held on scaling, refuted on memory, and the safety half came out inverted.** Renders do run at the same time: the feared ceiling of eleven per second per process is not there, and the single build reaches 42 to 45 renders per second on this machine. But peak and kept memory grow per **render**, not per worker, for every strategy that holds a `cue.Context` across renders, which is the shape the hypothesis pre-registered as a refutation. And the strategy expected to fail on safety is clean, while the one the library's own ADR-002 declares safe is the one the race detector fires on.

Measured on an AMD Ryzen AI 7 350 (8 cores, 16 threads), Go 1.26.5, `cue v0.17.1`, warm module cache, `n=80` per point. Full output in [`_out/results.txt`](_out/results.txt), [`_out/results-mem.txt`](_out/results-mem.txt) and [`_out/results-race.txt`](_out/results-race.txt).

```
RENDERS PER SECOND
  STRATEGY              P=1    P=2    P=4    P=8   P=16   peak   kept heap   races
  S1-ctx-per-worker    10.5   15.5   26.2   36.2   44.2  4.22x       2.9G       0
  S2-ctx-per-render     7.8   14.9   28.0   42.0   44.7  5.74x       2.3M       0
  S3-ctx-shared         8.7   15.5   26.2   38.1   41.9  4.84x       2.9G       0
  S4-baseline          19.3   35.5   58.6   85.5   97.4  5.05x     739.9M    2321
  S5-base-prewalked    19.8   35.3   58.3   87.3   89.5  4.52x     740.0M    1540

LATENCY p50, S1 (ms)   90.3  115.1  124.9  209.3  355.2
KEPT HEAP AT P=4, rising N (renders per point)
  N                      20     40     80    160
  S1-ctx-per-worker  752.6M   1.5G   2.9G   5.9G      37.5 MB per render
  S2-ctx-per-render    1.6M   1.7M   2.0M   1.9M      flat
  S4-baseline        209.5M 386.0M 738.9M   1.4G       9.2 MB per render
```

P=1 carries run-to-run variance of roughly 20% (S2's P=1 read 10.1 renders per second in one full run and 7.8 in another), so the speedup column is a within-run ratio and the absolute throughput is the number to quote. Across runs the sequential single build is consistently 10.5 to 11 renders per second and the P=16 figure is consistently 42 to 45.

### Findings

**1. Renders run at the same time, and the ceiling the hypothesis feared is not there.** Every strategy clears the 2x threshold at four or more workers by a wide margin. The single build goes from about 11 renders per second to about 44, so experiment 04's 90 ms per render is a per-render cost and not a per-process one. `execute.go`'s sequential loop is not a property of CUE that the design has to live with.

**2. Scaling is real but sub-linear, and saturates near the physical core count.** About 4x on 16 threads (8 physical cores), with the curve bending after P=8: throughput rises 36.2 to 44.2 from P=8 to P=16 while p50 latency rises 209 ms to 355 ms, which is queueing rather than throughput. That is the same shape ADR-002's spike reported in a different harness, "saturating around four cores, allocator-bound", and it means an operator sizing a worker pool should size it to cores and not to pending `ModuleRelease`s.

**3. Memory is retained per render, for as long as the context that produced it lives.** This is the refutation, and it is the finding with the longest reach. A `cue.Context` reused across renders keeps about **37.5 MB per single-build render** and about **9.2 MB per baseline render**, and releases none of it until the context itself is dropped: kept heap is flat in P and exactly linear in N (752 MB, 1.5 GB, 2.9 GB, 5.9 GB for 20, 40, 80 and 160 renders at P=4). Dropping the context per render is the whole fix. S2 keeps under 2.5 MB at every N and every worker count, and it costs nothing measurable in throughput; at P=16 it is the *fastest* strategy in the table. So the hypothesis is refuted as stated, and the design consequence is small and specific: a long-lived render worker must not hold a `cue.Context`, and this is a property of the current path too, not something the collapse introduces.

**4. The shared `cue.Context` is race-clean here, contra `execute.go`'s comment.** S3 ran every worker through one context across the full sweep and under the race detector: zero data races, zero failed renders, zero digest mismatches, and a scaling curve indistinguishable from the per-worker strategies. Whatever the comment was true of, it is not true of this operation set (`load.Instances`, `BuildInstance`, `Validate`, `MarshalJSON` on disjoint packages) on `cue v0.17.1`. Two limits on that: the detector reports only the races that actually occur in the schedules it observed, and S3 is no better than S1 on either throughput or memory, so nothing recommends it.

**5. ADR-002's shared held platform is the one that races, and pre-walking does not fix it.** S4 produced **2321 data-race reports** under `-race`. They all have the same shape: two workers in `adt.(*scheduler).signal` through `Vertex.lookup` and `FieldReference.resolve`, reached from `Value.FillPath` on the shared platform value. S5 forced the whole held value graph to evaluate first, which cost 176 ms once, and still produced **1540**. So the fault is not laziness that a pre-pass can discharge: filling a value owned by another goroutine's build is a *write* to that value's evaluation state, and unification is not a read. ADR-002's own wording anticipated the risk ("the verified v0.17 guarantee is reads-only ... the OPM render path is construction-heavy") and then measured a raw-CUE keystone that did not reproduce it; against the real catalog it reproduces on every run.

Worth stating precisely, because it is the difference between a bug report and a scare: **no wrong value was ever observed.** Across every strategy, every worker count and both instruments, 2000 concurrent renders matched their sequential reference digest exactly. A data race is undefined behaviour and is enough to invalidate a safety claim, but nothing here demonstrates corruption, and the failure this experiment was most afraid of did not occur.

**6. The 2.1x cost of the collapse survives concurrency.** At peak the baseline runs 97.4 renders per second against the single build's 44.7, a ratio of 2.18x, essentially identical to experiment 04's sequential 2.1x. Both paths parallelise about equally well, so the multiplier is a constant rather than something that widens under load. The comparison at *equal safety* is less favourable to the baseline than that: S2 reaches 44.7 renders per second race-clean with flat memory, and the held-platform baseline has no demonstrated race-free concurrent form at all.

### What this means for OQ8

Experiment 04 answered OQ8's feasibility question sequentially and left the throughput ceiling as the open residue. That residue is now closed in the affirmative, so the affordability verdict stands: a per-render single build costs 2.1x and parallelises to roughly 4x on eight cores, and reuse remains an optimisation rather than a precondition.

It also narrows what a reuse strategy is allowed to look like. Finding 5 removes "hold one materialized platform and render against it concurrently" from the table on safety grounds, which is the strategy ADR-002 adopted and `opm-operator`'s `store.go` is built around. Finding 3 removes "hold a context per worker" on memory grounds. What is left standing is the shape that shares nothing: a fresh context per render, which is also the cheapest to reason about and, at P=16, the fastest thing measured.

### Limits

- One module, two components, five pairs. The per-render memory and cost terms both grow with module size; the ratios should be re-measured on a large module before being quoted as general.
- One machine, one CUE version. The scaling curve is allocator-sensitive and the safety findings are `v0.17.1` findings.
- S4 and S5 test cross-context sharing (per-worker contexts filling into a platform owned by another). A same-context variant, where the workers also use the platform's own context, was not run; nothing suggests it would be safer, but it is untested rather than ruled out.
- The race detector observes schedules, not proofs. S1, S2 and S3's clean verdicts are evidence of absence, not proof of it.

Hypothesis held on scaling and refuted on memory. The single-build render path parallelises to about 4x on eight cores and its cost multiplier survives concurrency, but memory is retained per render rather than per worker, and the safety result is the reverse of what both `execute.go` and ADR-002 assert: sharing a context is clean, and sharing a built platform value is not.
