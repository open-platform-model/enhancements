# 01-attribute-propagation — Attribute-Declared Secret Fields

Status: Concluded

## Hypothesis

A CUE field attribute written on a `#config` field survives every construct the OPM artifact shape puts it through, is reachable from the schema side of a `#ModuleInstance`, and can be found and parsed by an ordinary Go walk — so `@opm(secret, …)` is a viable replacement for the `#Secret` contract type.

This is the mechanism claim underneath **D2** and **D3** (and, when it was run, the superseded **D1**). If it fails, the enhancement has no basis.

The corollary tested at the same time is the *negative* half that shapes D3 and forces the kernel-side rewrite in D11: the mark is reachable on the **schema** side and **not** on the values side or through a reference.

## Setup

Two halves, in one Go module.

**Part A — `main.go`.** A matrix of synthetic cases built with `ctx.CompileString`, probing attribute survival across: definition-to-value unification in both orders and via Go `Unify`; the `#Module` skeleton, the required `#module!` field, and the `let unified = #module & {#config: values}` shape; 12 levels of nesting; list elements; `[string]:` pattern constraints; optional fields; disjunction resolution; multiple conjuncts carrying attributes; the argument-parsing surface including `@opm` namespace sharing with `identity`; and export round-trips. Nothing is copied in — these cases are written from scratch to isolate CUE behaviour.

**Part B — `real.go` + `module/` + `cue-deps/`.** The same questions against the real schema.

- `cue-deps/core/` is a **frozen copy** of `core/src/*.cue` and `core/src/cue.mod/module.cue`, taken at commit `7500c5d` (the commit that removed the `opm-secrets` synthesis). Copied, not referenced, per the experiments protocol — an upstream change must not silently alter this experiment's result.
- `cue-deps/frag/` is a small second CUE module (`example.com/frag@v1`) shipping a pre-marked `#BasicAuth` fragment. It exists to test one thing: whether a mark declared in a *dependency* survives into a consuming module, which is what would let a catalog ship pre-marked schema.
- `module/` is a module and instance carrying marked fields typed `string` (see the scope note under Outcome). Its `cue.mod/local-module.cue` points both deps at the copies inside this directory, so nothing outside the experiment is read.

`discover()` in `main.go` is the experiment's stand-in for the kernel's discovery pass — the walk that replaces the ~240 lines of hand-unrolled comprehension in `core/src/schemas.cue`.

## Run

```bash
go run .
```

Requires network access on first run to fetch `cuelang.org/go v0.17.1`. No registry access is needed — both CUE deps resolve to the local copies.

## Outcome

**Hypothesis held.** Every case passed. The findings that drive decisions:

| Question | Result |
| --- | --- |
| Survives definition → concrete unification? | Yes — both orders, and via Go `Unify()` |
| Survives the full `#Module` / `#ModuleInstance` shape? | Yes — all seven shape variants, including `let unified = #module & {#config: values}` with `#components` wiring the field |
| Depth limit? | None — 12 levels passed; the walk is Go recursion |
| Lists? | Yes — found inside a list element |
| `[string]:` pattern constraints? | Yes — the mark is **inherited** by every key the user adds |
| Optional fields? | Yes, both filled and unfilled |
| After disjunction resolution? | Yes |
| Cross-CUE-module import? | Yes — `#BasicAuth` declared in `example.com/frag@v1` arrived marked |
| Discoverable with no values? | Yes — 5 declarations from the bare module |
| Export round-trip? | `Syntax()` preserves under every option set; `MarshalJSON` drops them, correctly |

**The negative results are the load-bearing ones.** Probing every path of a built instance (`E3`):

- `i.#module.#config.password` — carries the mark, but **not** the value.
- `i.values.password` — carries the value, but **not** the mark. The `values` vertex holds only its own conjunct.
- `i.components.web.pw` (a reference to the marked field) — carries **neither**.

That is what forces D3 (discovery reads `#config`) and D11 (a reference cannot carry the mark, so the kernel must rewrite the value into something a transformer can act on). It also showed the unified config is not addressable from a `#ModuleInstance` at all, since `let unifiedModule` is a let binding.

Two secondary findings worth recording:

- **`E5`** — when two conjuncts carry *different* attribute text, CUE returns **both**; identical text is deduped. A kernel must therefore treat more than one `@opm(secret)` marker on one field as an error rather than silently picking one. Implemented in experiment 02's `parseField`.
- **`E6` / `f7`** — `@opm(secrit, group=g)` parses cleanly and is silently not a secret. This is the mistyped-marker risk recorded in `05-risks.md`; the experiment demonstrates it rather than merely predicting it.

**One methodology note.** An early run appeared to refute the hypothesis for the full OPM shape. The cause was in the test, not in CUE: writing `i: #Inst & {#module: #module}` makes `#module` a self-reference to the field being declared, so the module never arrived and the mark was legitimately absent. The corrected case passes. That case is retained in `main.go` as an explicit negative control, because "the attribute is missing" is a symptom a CUE scoping bug produces just as readily as a real limitation.

**Scope note after D10.** This experiment marks fields typed `string`, because it was run before D10 restored `#Secret` as the fulfilment slot. That does not weaken it: the claims here are about the *attribute* — whether a mark survives, and whether a Go walk can find and parse it — and those are independent of the marked field's type. The `#Secret`-typed case is exercised end to end in `../02-resolve-in-place`, against a module whose every marked field is `c.#Secret @opm(secret, …)`. E4's disjunction case is the bridge: an attribute survives disjunction resolution.

Feeds: `03-decisions.md` D2, D3, and the negative result that forced D11; `05-risks.md` (mistyped marker, export round-trip).
