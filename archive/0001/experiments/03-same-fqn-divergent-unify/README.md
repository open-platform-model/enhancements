# 03-same-fqn-divergent-unify — #Platform Redesign Umbrella

Status: Concluded

Pins: 02-design integrity claim ("same-SemVer rebuilds with identical content collapse via unification; divergent content fails CUE evaluation at the materialize step"), OQ14 → resolved-by-D6

## Hypothesis

Two synthetic `#ComponentTransformer` values stamped at identical FQN `…@1.0.0` with **identical bodies** collapse to one entry under CUE unification when both are placed into the same `#composedTransformers`-shaped map. With **divergent bodies** the same unification fails with a CUE error that names the diverging field. The matcher never has to detect divergence — CUE does.

## Setup

`./schema/schema.cue` — minimal slice copied from `enhancements/0001/schemas/target.cue`: `#NameType`, `#ModulePathType`, `#VersionType`, `#FQNType`, `#PrimitiveMetadata`, `#ComponentTransformer`, `#TransformerMap`.

Two sibling packages, each with three CUE files demonstrating one side of the claim:

- `./matching/{transformer_a,transformer_b,merge}.cue` (package `matching`) — both files declare `widget_transformer` at FQN `opmodel.dev/test/widget@1.0.0` with **byte-identical body** (description + producesKinds). `merge.cue` indexes the value into a `#TransformerMap` keyed on its FQN.
- `./divergent/{transformer_a,transformer_b,merge.cue}` (package `divergent`) — same FQN, but `transformer_a` carries `description: "...A: emits widget Deployments."` + `producesKinds: ["Deployment"]` while `transformer_b` carries `description: "...B: emits widget StatefulSets."` + `producesKinds: ["StatefulSet"]`.

`./cue.mod/module.cue` — `module: "enhancements.opmodel.dev/0001/experiments/03-same-fqn-divergent-unify@v0"`.

## Run

```bash
cue eval -c ./matching/...                       # MUST succeed; one collapsed entry
cue eval -c ./divergent/... 2>&1                 # MUST error with diverging field named
```

## Outcome

Observed on 2026-05-23 with cue v0.16.1:

- `matching` evaluates to a single `composed["opmodel.dev/test/widget@1.0.0"]` entry holding the merged-equal transformer body.
- `divergent` errors with four `conflicting values` diagnostics — two on `metadata.description`, two on `producesKinds.0` — each citing both source files with line numbers. Example verbatim:

  ```
  composed."opmodel.dev/test/widget@1.0.0".metadata.description: conflicting values
    "DIVERGENT — B: emits widget StatefulSets." and "DIVERGENT — A: emits widget Deployments.":
      ./divergent/merge.cue:6:37
      ./divergent/transformer_a.cue:14:16
      ./divergent/transformer_b.cue:12:16
  ```

**Hypothesis held.** CUE unification catches divergence and names the field — the kernel never needs to implement a "same-SemVer divergent body" detector; the index build step gets it for free. Cited verbatim in `02-design.md` High-Level Approach section 2; OQ14 closed via D6 (`03-decisions.md`).
