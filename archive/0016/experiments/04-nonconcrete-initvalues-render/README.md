# 04-nonconcrete-initvalues-render — Initialize a Module Instance Package from a Published Module

Status: Concluded

## Hypothesis

An `initValues` carrying a default (`*1 | int`), a disjunction (`"info" | "debug"`), and an optional field, serialized through `Value.Syntax(cue.Final(), cue.Concrete(false))` and `format.Node` (the path synth's `renderValuesFile` uses), produces a `values.cue` that re-parses and, unified with `#config`, reproduces the original constraint rather than collapsing to the defaults or dropping the disjunction. Backs D4 (non-concrete `initValues` renders as partially filled scaffolding).

## Setup

A Go module (`cuelang.org/go v0.17.1`) with one `main.go`. The two render lines (`Syntax(cue.Final(), cue.Concrete(false))` then `format.Node`) are copied from `renderValuesFile` in `library/opm/helper/synth/render.go` (library commit 11da9b0). Four inline cases, each declaring a `#config` and an `initValues`: `default`, `disjunction`, `optional`, and `mixed`. For each the program writes `out/values-<case>.cue`, re-parses it, unifies it with `#config`, and reports subsumption in both directions plus whether the rendered value is concrete.

## Run

```bash
go run . default
go run . disjunction
go run . optional
go run . mixed
cat out/values-*.cue
```

## Outcome

**Hypothesis refuted in part.** Run 2026-08-24. The rendered text, verbatim:

| Case | `initValues` | Rendered `values:` | Round-trips? |
| --- | --- | --- | --- |
| default | `{replicas: *1 \| int, logLevel: *"info" \| string}` | `{replicas: 1, logLevel: "info"}` | default **resolved** to its concrete value |
| disjunction | `{logLevel: "info" \| "debug"}` | `{logLevel: "info" \| "debug"}` | **preserved**, non-concrete |
| optional | `{host: "example.internal", port?: int}` | `{host: "example.internal"}` | optional field **dropped** |
| mixed | all three | `{replicas: 2, logLevel: "info" \| "debug"}` | as above |

Every rendered file re-parses and validates against its `#config`; the rendered value is always subsumed by the original. What changes is the shape of the scaffold:

- `cue.Final()` resolves defaults, so a `*x | T` renders as `x`. For a scaffold this is the useful behavior (the user sees a value, not a choice), but it means `initValues` cannot carry a "here is the default, change it if you like" marker: the default *is* what lands in the file.
- Disjunctions without a default survive as disjunctions, so `values.cue` is non-concrete and the user's first vet fails until they pick. That is the "partially filled scaffolding" D4 promised, and it works for exactly this construct.
- Optional fields (`port?: int`) are omitted entirely: the file gives no hint the field exists.

D4 was revised on 2026-08-24 to state this precisely: defaults render resolved, undefaulted disjunctions render as choices, optional fields are omitted. An author who wants a field to appear as a prompt writes it as an undefaulted disjunction or a bare type (`port: int`), not as optional.

Evidence linked from D4's `Source:` in `../../03-decisions.md`.
