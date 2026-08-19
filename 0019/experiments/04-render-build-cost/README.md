# Experiment 04: render-build-cost

Status: Concluded

## Hypothesis

A per-render single CUE build is affordable: with the module cache warm and one `cue.Context` shared across renders, the marginal cost of rendering one more `#ModuleInstance` stays within the same order of magnitude as today's fill-into-a-shared-materialized-platform path, so ADR-002's materialize-once model is an optimisation rather than a precondition for the single-build render pipeline.

This is the executable form of **OQ8** (`03-decisions.md`), which `02-design.md` names as the most likely feasibility blocker for the collapse. Every other question in the entry is about whether a single build is *correct*; this one is the only question about whether it is *usable*. Experiment 03 already killed the cheapest escape route (sealing a platform into catalog-independent CUE does not round-trip), so the remaining candidates are all "pay it, amortise it, or batch it", and none of them can be chosen without a number.

The hypothesis is falsifiable in a specific way, stated before the harness was written: it is **refuted** if per-render wall clock at steady state, with everything warm that can legitimately be warmed, exceeds roughly 10x the shared-platform baseline, or if resident memory grows per render in a way that makes an operator rendering many releases concurrently untenable.

## Setup

A Go harness plus a CUE fixture tree, self-contained in this directory.

| Path | Role |
| --- | --- |
| `main.go` | flags, orchestration, and the report |
| `fixtures.go` | materializes the scratch tree: one platform, N instance modules, N render modules |
| `arms.go` | the four arms, plus a copy of the kernel's `FinalizeValue` and the `schema.paths` constants arm D needs |
| `fixtures/platform/` | the platform under the **D5** shape, copied from `experiments/02-platform-authority-mvs/platform/` with the module path renamed |
| `fixtures/instance/` | the instance and `web_app` module, copied from `experiments/01-purecue-render-flow/`, with `metadata.name` made a substitutable placeholder |
| `fixtures/render/render.cue` | the glue: experiment 01's render flow with the match phase removed and the platform interposed |
| `fixtures/render/baseline/` | the platform without any instance, which is arm D's one-time build |

**Copied, never referenced.** The platform shape, the instance, the module and the render glue come in as bytes from experiments 01 and 02 rather than by import, so a later edit to either cannot silently change what this measured. `FinalizeValue` and the `#component` / `#context` path constants are likewise copied from `library/opm/compile/finalize.go` and `library/opm/schema/paths.go` rather than imported.

**One deliberate deviation from the copy rule**, on the same grounds experiments 01 and 02 recorded: `opmodel.dev/core@v2.0.0-alpha.4` and `opmodel.dev/catalogs/opm@v2.0.0-alpha.3` resolve from GHCR at exact published versions rather than being vendored. They are immutable artifacts, and an experiment measuring load and resolution cost cannot vendor away the loader it exists to measure.

### What varies, and what does not

The platform is byte-identical for every render in every arm: all N render modules directory-replace the *same* platform directory. The N instance modules differ in exactly one thing, `metadata.name`, which reaches every rendered resource's name and labels, so no render can be answered out of another render's evaluation state. Every arm therefore does the same work on the same inputs, and the only difference between arms is what is reused.

### The arms

| Arm | What it does | What it isolates |
| --- | --- | --- |
| `A-cold` | fresh `cue.Context`, fresh `CUE_CACHE_DIR` per sample, full load and build | what a cold pod pays before its first render |
| `B-warm` | fresh `cue.Context` per render, shared module cache | parse and evaluate without the fetch |
| `C-shared` | one `cue.Context` for the whole run, shared module cache | whether CUE amortises a shared platform across builds in one process |
| `D-base` | platform and catalog built once and held; each instance built in its own build, its components finalized, and the finalized value filled across the build boundary | today's path (`library/opm/compile/execute.go`), as the yardstick |

Arm D is deliberately **not** parity-correct: finalization is the strip this enhancement exists to remove, and its `#context` is constructed in Go precisely because the definition fields a CUE projection would read are gone by then. It is a cost yardstick and nothing else.

Arm A takes few samples by design. A cold cache is a per-process event, not a per-render one, and each sample refetches the entire dependency set over the network.

### Guards

Every sample asserts that the render produced **five** outputs, the same five pairs experiment 01 produced. Without that assertion an arm that silently rendered nothing would report as the fastest one. The pairs are located by transformer short name on both the CUE and the Go side, so no version is restated as data and a catalog bump fails loudly rather than quietly changing which bodies execute.

### What this does not measure

- **Concurrency.** The arms are sequential. Whether a shared `cue.Context` is safe under the parallel render ADR-002 assumes is a correctness question, not a cost question.
- **Matching.** The glue is execute-only, so the numbers below are a floor that experiment 05's cost adds to.
- **Render-module generation.** Writing the render module's `cue.mod` and `local-module.cue` is real per-render kernel work (OQ6), but the harness does it by copying a tree and spawning `cue mod edit`, which a kernel would not. The run prints it separately, labelled, rather than folding it into any arm.
- **A realistic fleet.** One platform, one module, two components, five pairs. A bigger module scales the per-render term; several platforms multiply the catalog term.

## Run

```bash
./run.sh                       # all four arms, n=50
./run.sh -n 100 -arm B,C,D     # skip the network-bound cold arm
./run.sh -arm C -profile cpu.out
./run.sh -n 10 -keep           # leave the scratch tree under _out/run for inspection
```

`run.sh` sets `CUE_REGISTRY` to the workspace mapping if it is unset and forwards every flag to `go run .`. The scratch tree is recreated per run under `_out/run` and removed afterwards unless `-keep` is passed. Nothing outside this directory is mutated.

Requires the `cue` CLI on `PATH` (setup only) and network access on the first run.

## Outcome

**Hypothesis held on its headline claim, and refuted on its stated mechanism.** A per-render single build costs about **2.1x** the baseline, far inside the 10x threshold, and memory is flat. But it is not a shared `cue.Context` that makes it affordable: sharing one recovers only about 14%. It is affordable because the absolute number is small.

Measured on an AMD Ryzen AI 7 350 (16 threads), Go 1.26.5, `cue v0.17.1`, `n=50`, full output in [`_out/results.txt`](_out/results.txt):

```
ARM            N      LOAD     BUILD      EVAL    EXPORT     TOTAL TOTAL_p90    ERRS ALLOC/rnd
----------------------------------------------------------------------------------------------
A-cold         3    1676.4      86.3       0.0       0.7    1763.3    1763.3       0     63.7M
B-warm        50      38.9      63.4       0.0       0.5     104.8     113.1       0     57.3M
C-shared      50      32.0      55.8       0.0       0.4      90.2     107.2       0     56.3M
D-base        50      10.0      17.2      11.9       0.4      42.3      50.9       0     28.9M

DRIFT (median of first fifth vs last fifth)
  B-warm     first 105.1 ms -> last 102.4 ms  (-2.6%)  heap retained 6.6M
  C-shared   first  92.3 ms -> last  88.6 ms  (-4.0%)  heap retained 9.5M
  D-base     first  42.3 ms -> last  40.8 ms  (-3.4%)  heap retained 9.9M

SINGLE BUILD vs BASELINE: C-shared is 2.1x D-base (90.2 ms vs 42.3 ms per render)
```

Stable across repetitions: an independent `n=100` run gave 101.8 / 86.3 / 38.1 ms and a ratio of 2.3x.

### Five findings

**1. The single build costs about 2.1x the baseline, not an order of magnitude.** 90 ms against 42 ms per render, warm. Against the threshold set before the harness was written, that is a hold with a wide margin. It also means the cost of the collapse is roughly one Go-side instance build per render: arm D still pays 10 ms of load and 17 ms of build for the instance module, because the instance imports the catalog too. What the single build adds on top is the platform's catalog being loaded and evaluated again rather than held.

**2. A shared `cue.Context` recovers about 14%, not the catalog term.** This is the finding that changes the design conversation, and it refutes the mechanism the hypothesis named. Every render in arm C resolves and evaluates the *same* platform bytes through the *same* context, and it still pays 32 ms of load and 56 ms of build. CUE does not amortise a package across separate `load.Instances` plus `BuildInstance` calls to the degree the hypothesis assumed. So "share the context and the catalog becomes free" is not available, and OQ8's remaining candidates are the ones that avoid re-loading rather than the ones that hope evaluation is cached.

**3. Memory is flat and retention is small.** About 57 MB allocated per render in the single-build arms, but 6 to 10 MB retained after a forced GC at the end of an arm, and drift is negative in every arm (later renders are slightly *faster* than earlier ones, which is warm-up rather than accumulation). Nothing here suggests a process that renders thousands of instances will grow without bound. The memory half of the refutation condition is not met.

**4. The evaluation happens inside `BuildInstance`, not in a separate eval step.** The `EVAL` column reads 0.0 ms for arms A through C because the value is already computed by the time it is looked up. This was verified rather than assumed: removing the `Validate(cue.Concrete(true))` call entirely leaves `BUILD` at 59 ms and `EXPORT` at 0.5 ms, and the five-output assertion still passes. The meaningful split is therefore `LOAD` (resolution and parse) against `BUILD` (compile and evaluate), roughly 35/65 in the single-build arms. Arm D shows a real 12 ms `EVAL` because there the fills and the output evaluation are explicit Go-side steps after its build.

**5. A cold cache costs 1.76 s, and it is all `LOAD`.** Arm A's build time is indistinguishable from the warm arms; the entire difference is fetching and extracting the dependency set. That is a per-process startup cost for an operator, not a per-render one, and it is the one number here that is network-bound and therefore environment-specific.

### What this means for OQ8

ADR-002's materialize-once model is an **optimisation, not a precondition**. The single-build render pipeline is viable on cost at this fixture size, and the decision about reuse can be made on operational grounds rather than on feasibility.

Two things it does not settle. The 2.1x is measured on a two-component module with five pairs, and the per-render term grows with module size while the baseline's held-platform term does not, so a large module should be measured before the ratio is quoted as general. And finding 2 removes the cheapest reuse strategy from the table: if the per-render cost does need to come down, the candidates left are the ones OQ8 already names (vendoring the catalog's bytes into the platform artifact, or batching instances into one build with the cross-instance coupling that implies), and neither is tested.

Concurrency remains untested and is now the sharper follow-up, because a 90 ms sequential render that cannot be parallelised behaves very differently from one that can.

Hypothesis held: a per-render single build is affordable, and ADR-002's reuse model is not a precondition for the collapse. The mechanism the hypothesis credited for that affordability is wrong, and finding 2 replaces it.
