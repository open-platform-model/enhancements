# 05-nonstruct-debugvalues — Initialize a Module Instance Package from a Published Module

Status: Concluded

## Hypothesis

A module whose `#config` is a non-struct (`#config: string`) with `debugValues: "x"` renders `values: "x"` verbatim, and that package still evaluates through `#ModuleInstance`'s `let unifiedModule = #module & {#config: values}` line. Backs D6 (concrete non-struct sources render verbatim, no refusal).

## Setup

Pure CUE. `core/` is a byte copy of `core/src/*.cue` (core commit a11aefc, package `core`; `INDEX.md` not copied) inside a throwaway module `experiment05.local/x@v0` at language `v0.17.0`. `probe.cue` declares `mod: core.#Module` with `#config: string`, `debugValues: "x"`, empty `#components`, and `inst: core.#ModuleInstance` with `#module: mod` and `values: "x"`, the file init would write.

Two modifications to the copy, both outside the schema definitions: core's pin fixture files (`platform_and_match_pins.cue`, `identity_pins.cue`, `identity_package_pins.cue`, which are core's own tests, not schema) are not copied, and one explanatory comment in `module_instance.cue` was reworded. Every definition is byte-identical to core.

## Run

```bash
cue vet ./...
cue eval ./ -e inst.values -e inst.metadata.fqn
cue eval ./ -e 'mod.#config & mod.debugValues'
```

## Outcome

**Hypothesis held.** Run 2026-08-24.

- `cue vet ./...` passes (exit 0).
- `inst.values` evaluates to `"x"` and `inst.metadata.fqn` to `"example.com/modules/probe:probe:default"`, so the instance is fully formed with a non-struct `values`.
- `mod.#config & mod.debugValues` evaluates to `"x"`: nothing in the copied `#ModuleInstance` (`values: _`, the `let unifiedModule` merge, the components comprehension) constrains `values` to a struct.

D6's "render verbatim" therefore needs no narrowing. Evidence linked from D6's `Source:` in `../../03-decisions.md`.
