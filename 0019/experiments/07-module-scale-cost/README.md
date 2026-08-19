# Experiment 07: module-scale-cost

Status: Concluded

## Hypothesis

The cost the single-build render pipeline adds over today's path scales with the **definitional payload** a module carries into the build, and experiment 04's 2.1x is therefore a floor measured on the smallest possible module rather than a general figure.

The mechanism the hypothesis names is specific. Today's path finalizes a component before filling it into a transformer (`library/opm/compile/finalize.go`, `cue.Final()`), which strips `#resources`, `#traits`, `#blueprints` and `#names` away. The collapse this enhancement proposes does not: it unifies the whole component value, definition fields included, into `#transform`. So everything definitional a component carries is work the single build pays for and the baseline does not, and both of the things that make a module "big" add to it:

- **more components** (a fleet), each carrying its own attached primitives;
- **blueprint authoring**, where one attachment drags in a `#blueprints` entry holding the whole blueprint definition, its `composedResources` and `composedTraits` lists, a second copy of every value under `spec.<blueprintName>`, and the guards that propagate that copy onto the primitive fields.

Two falsifiable claims, both stated before the harness ran and both encoded as thresholds in `main.go`'s verdict section:

1. **Bounded ratio.** Per-render cost grows with module size in both arms, but the single-build / baseline *ratio* stays bounded. Refuted if the ratio at the largest size exceeds twice the ratio at the smallest.
2. **The payload is what costs.** Blueprint-authored components cost measurably more than raw components rendering identical output, and **the gap is wider in the single build than in the baseline**, because the baseline strips the payload before it fills. Refuted if bp and raw land within 10% of each other everywhere, or if the single-build gap is not the wider one.

This is the follow-up experiment 04 asked for in its own outcome: *"the 2.1x is measured on a two-component module with five pairs, and the per-render term grows with module size while the baseline's held-platform term does not, so a large module should be measured before the ratio is quoted as general."*

### Why this is one experiment and not two

Size and authoring style look like two claims. They are two ways of growing the same quantity: what a component carries into `#transform`. A fleet grows it by having more components; a blueprint grows it per component. The experiment measures one thing (per-render cost as a function of the payload) along two axes, and a result on either axis is uninterpretable without the other: a blueprint tax measured on a two-component module says nothing about a fleet, and a fleet measured in one authoring style cannot say whether the slope belongs to the components or to how they were written.

## Setup

A Go harness plus a CUE fixture tree, self-contained in this directory.

| Path | Role |
| --- | --- |
| `main.go` | flags, the sweep, the report, and the three pre-registered verdicts |
| `gen.go` | the point definition, and every generated CUE file (instances, render glue) |
| `fixtures.go` | materializes the scratch tree |
| `arms.go` | the two arms, the digests, and copies of `FinalizeValue` and the `schema.paths` constants |
| `fixtures/platform/` | the **D5** platform, copied from `experiments/04-render-build-cost/fixtures/platform/` with the module path renamed |
| `fixtures/render/` | the render module's `cue.mod` and the baseline's platform-only package, copied from 04 |
| `fixtures/mods/fleet_bp`, `fleet_raw` | the breadth fixture, authored two ways |
| `fixtures/mods/complex_bp`, `complex_raw` | the depth fixture, authored two ways |

**Copied, never referenced.** The platform, the render module's `cue.mod`, the baseline package, `FinalizeValue` and the `#component` / `#context` path constants come in as bytes from experiment 04 and from `library/opm/compile/` rather than by import, so a later edit to either cannot silently change what this measured.

**One deliberate deviation from the copy rule**, on the grounds experiments 01, 02 and 04 all recorded: `opmodel.dev/core@v2.0.0-alpha.4` and `opmodel.dev/catalogs/opm@v2.0.0-alpha.3` resolve from GHCR at exact published versions rather than being vendored. They are immutable artifacts, and an experiment measuring load and evaluation cost cannot vendor away the thing it exists to measure.

**The fixtures are new.** They are written for this experiment rather than copied, because no existing fixture is large. They take their shape from a real 2200-line OPM v0 module (a Minecraft server fleet: a map of servers, one workload and Service and ConfigMap per entry, one router whose arguments fold over the whole map) but share no bytes with it — that module is written against OPM v0 and a retired catalog.

### The two fixtures

| Fixture | Grows | Per component | Components at size K | Outputs |
| --- | --- | --- | --- | --- |
| `fleet` | **breadth** | modest: container, one volume, expose, one ConfigMap folded from a settings map | K servers + 1 router | 3K + 3 |
| `complex` | **depth** | heavy: a five-arm runtime disjunction driving command and probes, ~25 environment variables unified from four sources, up to four volumes of four different source kinds, an init container, up to two guarded sidecars, three probes, autoscaling, a disruption budget, pod metadata, and a ConfigMap whose data is both folded from a settings map and JSON-marshalled, plus a second ConfigMap under a feature guard | K services | 5K |

Splitting the two knobs is what makes either number interpretable. A single "big module" fixture growing both at once would report a cost with no way to attribute it; here the fleet's slope is component count and the difference between the fixtures at equal component count is per-component complexity.

The fleet's router is deliberately an **aggregating** component: its arguments are a comprehension over every server in the map, so the K components are not K independent evaluations.

### The two authoring styles

Both styles of a fixture are required to render **byte-identical output**. The harness digests every render and reports any divergence; without that, a cost difference between them would be uninterpretable.

- `fleet_bp` attaches `bp.#StatefulWorkload` / `bp.#StatelessWorkload`. `fleet_raw` attaches the primitives the module actually uses. The blueprint also composes `SidecarContainers` and `InitContainers`, which this fixture does not use, so the fleet's style delta includes **traits a blueprint drags in unused**.
- `complex_bp` attaches `bp.#StatefulWorkload`. `complex_raw` attaches **exactly** the set that blueprint composes, because this fixture uses all of it. So the complex delta isolates the **blueprint wrapper alone**: the `#blueprints` entry, the duplicated `spec.statefulWorkload`, and the six propagation guards.

One thing the raw variants had to discover: **`matchLabels` cannot be written on a component.** `res.#ContainerResource` declares `core.opmodel.dev/workload-type` as a required matching key with a disjunction for a value (0010 D36), and core derives `matchLabels` from the attached primitives with `_matchLabelsAreDerived` refusing any key the component adds itself. The only spelling that works is narrowing the resource at the attachment site. Answering that key is, precisely, one of the things a workload blueprint exists to do.

### The two arms

| Arm | What it does | What it is |
| --- | --- | --- |
| `single` | one CUE build per render: load the generated render module, build, force `rendered` concrete, export | the collapse, nothing stripped |
| `base` | platform and catalog built once and held; each instance built in its own build, its components finalized, `#context` constructed in Go, the finalized value filled across the build boundary | today's path (`library/opm/compile/execute.go`), as the yardstick |

The `base` arm is deliberately **not** parity-correct: finalization is the strip this enhancement exists to remove. It is a cost yardstick.

The single-build arm takes a **fresh `cue.Context` per render** by default, which is experiment 06's S2 — the strategy that experiments 04 and 06 together leave standing (race-free, flat in memory, and the fastest safe option under concurrency). `-ctx shared` reproduces experiment 04's arm C instead.

### Guards

- **Output count.** Every render must produce exactly the point's expected pair count. An empty `rendered` evaluates instantly, so without this a point that silently rendered nothing would report as the cheapest.
- **bp/raw identity.** The two authoring styles of a fixture must render identical bytes at every size, in both arms.
- **Render distinctness.** Consecutive renders in a point must render *different* bytes. They differ only in `metadata.name`, which reaches every rendered resource, so equal digests would mean one render was answered out of another's evaluation state and every number in the point was a cache reading.
- **Cross-arm identity.** Reported, not asserted, since the baseline is not parity-correct. Two digests are taken per render: a strict one (object keys sorted, array order preserved) and a list-order-insensitive one, so the report can distinguish "different objects" from "the same objects in a different order".

### What this does not measure

- **Matching.** The glue is execute-only, copied from 04. Experiment 05 owns what matching costs.
- **Concurrency.** Sequential by construction; experiment 06 owns it.
- **Retention.** Allocation per render is reported as churn. Experiment 06 measured retention and found it a property of the `cue.Context`'s lifetime, not of the render.
- **Render-module generation.** Writing the render module's `cue.mod` and `local-module.cue` is real per-render kernel work (OQ6). The harness does it once for the whole tree during setup, outside every measurement, because it shells out to `cue mod edit` where a kernel would write two files in-process.

## Run

```bash
./run.sh                                   # the full sweep, both fixtures, both styles
                                           # (the defaults are the run recorded in _out/results.txt)
./run.sh --fresh                           # rebuild the scratch tree first
./run.sh -fixture fleet -fleet-sizes 1,64  # one fixture, two sizes
./run.sh -ctx shared                       # experiment 04's arm C instead of 06's S2
./run.sh -fixture complex -n 3 -dump _out/dump   # write every first render's outputs for inspection
```

`run.sh` sets `CUE_REGISTRY` to the workspace mapping if it is unset, materializes the tree once with `-setup-only`, then measures with `-reuse`. The tree is one generated CUE package per render and is not cheap to build, so it is kept under `_out/run` between runs; `--fresh` removes it. **Delete `_out/run` (or pass `--fresh`) after editing `gen.go`** — the reuse check is structural and will not notice that the generator changed.

Requires the `cue` CLI on `PATH` (setup only) and network access on the first run.

## Outcome

**Hypothesis held on claim 1 and refuted on claim 2, and both results point the same way: the collapse's cost is a FIXED cost per render, not a payload cost per component.**

Measured on an AMD Ryzen AI 7 350 (16 threads), Go 1.26.5, `cue v0.17.1`, `n=8` renders per point, 28 points, 448 renders, zero failed renders. Full output in [`_out/results.txt`](_out/results.txt), produced by:

```bash
./run.sh --fresh -fleet-sizes 1,2,4,8,16,32,64,128 -complex-sizes 1,2,4,8,16,32 -n 8 -max-seconds 120
```

Those sizes are now the flag defaults, so a bare `./run.sh` repeats it.

### The headline: the ratio inverts

| | k=1 | k=2 | k=4 | k=8 | k=16 | k=32 | k=64 | k=128 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fleet bp | 1.74x | 1.48x | 1.25x | 1.03x | 0.92x | 0.83x | 0.76x | 0.75x |
| fleet raw | 2.46x | 2.05x | 1.54x | 1.19x | 0.92x | 0.77x | 0.72x | 0.68x |
| complex bp | 1.59x | 1.25x | 1.07x | 0.88x | 0.82x | 0.77x | | |
| complex raw | 2.01x | 1.52x | 1.15x | 0.91x | 0.80x | 0.75x | | |

Experiment 04's 2.1x reproduces at the size experiment 04 measured (2.46x for the closest comparable point, a two-component fleet authored raw). It does not survive many more components. **Past the crossover the single build is CHEAPER than today's held-platform path**, and by k=128 it renders a 129-component module in 1.08 s where today's path takes 1.59 s.

### The cost model, and it is almost exactly linear

Fitting `total = fixed + slope x components` over each sweep gives R^2 above 0.9996 in all eight cases, with the worst single residual under 9%:

```
FIXTURE   STYLE  ARM       ms/component   fixed ms      R^2
fleet     bp     single           14.01       89.1   0.99996
fleet     bp     base             19.31       32.5   0.99991
fleet     raw    single            7.71       83.9   0.99993
fleet     raw    base             12.17       20.7   0.99993
complex   bp     single           34.13       81.5   0.99991
complex   bp     base             46.83       22.9   0.99995
complex   raw    single           22.79       83.7   0.99968
complex   raw    base             33.35       20.1   0.99997
```

Two numbers carry the whole experiment.

**The single build's fixed cost is 81.5 to 89.1 ms, and it does not move.** Across two fixtures and two authoring styles it lands in an 8 ms band. That is the catalog: resolved and parsed (the `LOAD` column is flat at 31 to 42 ms for every point in the sweep, from a 2-component module to a 129-component one) and then evaluated inside `BuildInstance`. It is the cost of not holding a platform, and it is a constant per render.

**The single build's marginal cost per component is LOWER than the baseline's, in every case.** 7.71 against 12.17, 14.01 against 19.31, 22.79 against 33.35, 34.13 against 46.83. The baseline buys its cheap fixed cost by paying per component forever: finalize the component (`Syntax(cue.Final())` plus a rebuild), construct `#context` in Go, and `FillPath` once per pair. Its `EVAL` column is where this lives and it is enormous at scale, 1116.7 ms of a 1587.9 ms render at fleet raw k=128.

Break-even, from the fits: **10.7 components** (fleet bp), **14.2** (fleet raw), **4.6** (complex bp), **6.0** (complex raw). A heavier component crosses sooner, because the fixed catalog term is amortised faster.

### Six findings

**1. Claim 1 held, and understated the result.** The pre-registered refutation was "the ratio at the largest size exceeds twice the ratio at the smallest". It fell by a factor of 2.3 to 3.6 instead. The collapse does not become more expensive as modules grow; it becomes cheaper, and the crossover sits at a module size that is ordinary rather than exotic: five components for the deep fixture, eleven to fourteen for the shallow one.

**2. Claim 2 refuted, on its second condition and on its mechanism.** The single-build blueprint gap is the wider one in only 5 of 14 sizes. The structure is the giveaway: the baseline's bp/raw gap is FLAT across the whole sweep (56 to 65% on fleet, 34 to 40% on complex) while the single build's gap GROWS (17% to 76% on fleet, 8% to 44% on complex) and crosses the baseline's at about sixteen components. That is not the payload being amplified; it is a per-component tax emerging from underneath a fixed cost that hides it at small sizes.

Per component, from the fitted slopes, the blueprint tax is **larger in the baseline**:

```
fleet     single  +6.30 ms/comp (+82% on the marginal term)     base  +7.14 ms/comp (+59%)
complex   single +11.35 ms/comp (+50%)                          base +13.48 ms/comp (+40%)
```

**3. The definitional payload the collapse carries costs nothing, because nothing reads it.** This is the mechanism that replaces the hypothesis's. No transformer in `catalogs/opm` reads a definition field off `#component` (`grep -rn '#component\.#' transformers/` returns nothing), and CUE is lazy, so `#resources`, `#traits`, `#blueprints` and `#names` ride into `#transform` and are never evaluated. The baseline, by contrast, must **export the entire component value** to finalize it, duplicated `spec.statefulWorkload` and all, whether or not a transformer wanted any of it. The strip costs more than the thing it strips.

**4. Blueprint authoring is expensive in both arms, and that is a catalog question rather than this enhancement's.** A blueprint-authored component costs 40 to 82% more per component than the raw component rendering byte-identical output. Some of that is the wrapper (the `#blueprints` entry carrying the whole blueprint definition with its `composedResources` and `composedTraits` lists, the second copy of every value under `spec.<name>`, the six propagation guards), and some is traits the blueprint attaches that the module never uses. The two fixtures separate them only partly: the fleet, whose blueprint drags in `SidecarContainers` and `InitContainers` unused, shows the wider gap (82% against 50% marginal), but its components are also lighter, so a fixed wrapper cost is a larger fraction of them. Both effects are present and this experiment does not fully separate them.

**5. Allocation inverts at the same place the time does.** The single build allocates less than the baseline from k=4 upward, and by fleet bp k=128 it is 913 MB against 1.9 GB per render. Churn, not retention; experiment 06 owns retention.

**6. Finalization reorders map-derived lists, and it shows up in rendered bytes.** The cross-arm digest comparison came out 16 byte-identical, 12 identical modulo list order, 0 genuinely different. The 12 are exactly the `complex` points. Their container environment is assembled from four sources through guards and comprehensions, and `Syntax(cue.Final())` re-emits comprehension-produced fields ahead of plainly-declared ones; the catalog then converts the env MAP to a Kubernetes LIST, so the order difference reaches the object. The `fleet` fixture, whose environment is written out plainly, renders byte-identical in both arms. This is not a cost finding, but it is a live consequence: today's path emits a different `env` ordering than the collapse would, and env is a list under server-side apply.

### Guards

All green. 28 of 28 bp/raw pairs rendered byte-identical output in both arms, which is what makes every style comparison above attributable to authoring rather than to what was rendered. No point produced identical bytes on consecutive renders, so nothing was answered out of another render's evaluation state. Zero failed renders across 448 renders.

### Confirmation: a shared `cue.Context`, and reproducibility

A second sweep with `-ctx shared` (experiment 04's arm C, one `cue.Context` for the whole point instead of a fresh one per render) is in [`_out/results-shared.txt`](_out/results-shared.txt). It does two jobs.

It reproduces the main result independently: 2.33x at fleet raw k=1 against 2.46x, and 0.76x at k=32 against 0.77x, with the same inversion at the same place.

And it puts a number on what sharing recovers, at each end of the sweep:

```
fleet raw   k=1    92.2 ms shared  vs  101.8 ms fresh    -9.4%
fleet raw   k=2    98.2            vs  109.9             -10.6%
fleet raw   k=8   148.3            vs  153.7             -3.5%
fleet raw   k=32  329.0            vs  332.3             -1.0%
```

Experiment 04 measured that recovery at about 14% on a two-component module and concluded it was too small to be the mechanism. This is the same finding with its shape explained: sharing a context shaves a fraction off the FIXED term and nothing off the per-component term, so it fades to noise as the module grows. It also costs what experiment 06 measured it to cost, 37.5 MB retained per render for the context's lifetime, which is why the default here is a fresh context per render.

### Limits

- **One machine, one catalog build, one `cue` release.** The absolute numbers are `v0.17.1` against `catalogs/opm@2.0.0-alpha.3` on a warm module cache; the shape of the model is what travels, not the constants.
- **Matching is still absent.** Copied from 04 on purpose. Experiment 05 owns what matching costs, and it would add to the single build's per-render term, plausibly to the fixed part rather than the per-component part.
- **The blueprint gap conflates two effects** (finding 4).
- **The fixed cost is measured warm.** A cold module cache adds experiment 04's 1.76 s once per cache, which is a much larger constant than the 85 ms measured here.

### What this means for OQ8

The reuse question changes shape. It was "the collapse costs 2.1x, so what do we reuse to claw that back". The answer is that there is nothing to claw back above about a dozen components, and below it what is owed is a flat 85 ms of catalog resolution and evaluation per render, which is exactly the term a reuse strategy would target. So the reuse candidates are unchanged in kind but much narrower in scope: they only pay off for small modules, and they buy at most 85 ms.

It also removes the size caveat 04 attached to its own verdict. Experiment 04 said the 2.1x should not be quoted as general until a large module was measured. A large module was measured, and the number is 0.7x.

**Hypothesis held on the bounded ratio, and refuted on the payload mechanism.** The single build's penalty is a fixed per-render catalog cost of about 85 ms that inverts into an advantage past roughly a dozen components; the definitional payload it stops stripping turns out to be free, because CUE never evaluates what no transformer reads, while finalizing it is not.
