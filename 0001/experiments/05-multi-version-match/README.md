# 05-multi-version-match — #Platform Redesign Umbrella

Status: Concluded

Pins: OQ1 / OQ4 / OQ7 (supported, not strictly resolved — kernel-side absent); OQ15 → informed-by-exp-05 (`MissingFQN` shape sketched)

## Hypothesis

A synthetic `#composedTransformers` map carrying three SemVer-keyed variants of the same primitive — `container@1.0.4`, `container@1.1.0`, `container@1.4.0` — resolves App A's `container@1.0.4` declaration against the 1.0.4 entry, App B's `container@1.4.0` against the 1.4.0 entry, and emits one `MissingFQN`-shaped diagnostic for App C that pins `container@2.0.0`, naming the adjacent in-range SemVers (`1.4.0`) as alternatives. Headline claim of the umbrella, expressed in pure CUE without any Go-side kernel.

## Setup

Single package `match`. Minimal schema slice in `./schema.cue` from `enhancements/0001/schemas/target.cue`: `#NameType`, `#ModulePathType`, `#VersionType`, `#FQNType`, `#PrimitiveMetadata`, `#ComponentTransformer`, `#TransformerMap`. Plus an inline `#MissingFQN: { release!, component!, fqn!, alternatives: [...#FQNType] }` diagnostic shape (sketch — OQ15 territory).

Three fixtures:

- `./composed.cue` — `composed: #TransformerMap` with four entries: `container@1.0.4`, `container@1.1.0`, `container@1.4.0`, `expose-trait@1.0.0` (the trait demonstrates multi-primitive coexistence on the same materialized platform).
- `./releases.cue` — three releases (`app-a`, `app-b`, `app-c`); each has one `api` component with `requires: [...]` listing one container FQN.
- `./match.cue` — pure-CUE matcher: comprehension produces `matched: { (relId): { (compId): [matched-fqns] } }`; missing emission produces `missing: [...#MissingFQN]` with alternatives computed by `strings.HasPrefix(k, modulePath+"/"+name+"@")` against `composed` keys.

`./cue.mod/module.cue` — `module: "enhancements.opmodel.dev/0001/experiments/05-multi-version-match@v0"`.

## Run

```bash
cue eval -c ./...
```

## Outcome

Observed on 2026-05-23 with cue v0.16.1:

```
matched: {
    "app-a": { api: ["opmodel.dev/modules/opm/container@1.0.4"] }
    "app-b": { api: ["opmodel.dev/modules/opm/container@1.4.0"] }
    "app-c": { api: [] }
}
missing: [{
    release:   "app-c"
    component: "api"
    fqn:       "opmodel.dev/modules/opm/container@2.0.0"
    alternatives: ["opmodel.dev/modules/opm/container@1.0.4",
                   "opmodel.dev/modules/opm/container@1.1.0",
                   "opmodel.dev/modules/opm/container@1.4.0"]
}]
```

**Hypothesis held.** App A and App B pair against their pinned SemVer; App C's out-of-range pin surfaces as a structured `MissingFQN` with all adjacent in-range versions listed as alternatives. This is the headline umbrella claim — one materialized platform pairing two consumer modules against two different versions of the same primitive — proven in pure CUE without any Go kernel. `MissingFQN` shape `{release, component, fqn, alternatives}` informed OQ15 + the `06-operational.md` diagnostic spec. OQ1 / OQ4 / OQ7 remain formally open pending the kernel-side Materialize implementation (the experiment proves the pattern but not the Go integration); status flipped to `supported-by-exp-05` in `03-decisions.md` for traceability.
