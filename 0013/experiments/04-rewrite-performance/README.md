# 04-rewrite-performance — Attribute-Declared Secret Fields

Status: Concluded

## Hypothesis

Of the two candidate mechanisms for producing the resolved values (D16 left the choice to implementation), **prune-graft** (`FillPath` untouched subtrees wholesale onto an empty struct, touching only branches containing marked paths) scales with the number of *marked paths*, while **decode-encode** (experiment 02's `Decode` → splice in Go → `Encode`) scales with *total tree size* — so graft should win on large configs with few secrets.

## Setup

Fully offline and self-contained: the rewrite operates on concrete data, so no schema, no registry, no kernel — only `cuelang.org/go v0.17.1` (the library's pinned CUE version).

- **`main.go`** implements both mechanisms (`decodeEncode`, `pruneGraft`), five synthetic value-tree shapes (wide small/medium/large, large-sparse with one secret in 2000 fields, and a 12-level deep nest), a correctness gate, and a wall-clock harness (≥250ms / ≥10 iterations per cell, warmup first).
- **Correctness gate before any timing:** on every shape, both mechanisms must produce JSON-identical output, and no plaintext (`sec-*`) may survive into either output. Timing a wrong mechanism would be meaningless.
- **Rider:** bake-style delivery needs the resolved value as CUE source bytes (fill-style needs nothing), so `Syntax(cue.Final()) → format.Node` is timed separately per shape to price the seam choice.
- Schema-side validation cost is out of scope: `ValidateConfig` runs identically regardless of which mechanism produced the value.

## Run

```bash
go run .
```

No network beyond the first `go mod` fetch of `cuelang.org/go`.

## Outcome

**Hypothesis refuted** (2026-08-14, CUE v0.17.1, Linux):

```
shape               fields  sec    A decode µs   B graft µs     B/A   serialize µs
small-20f-2s            20    2           51.6        712.6  13.81x           98.9
medium-200f-5s         200    5          435.1       5404.7  12.42x          646.6
large-2000f-10s       2000   10         3998.0     105033.8  26.27x         5006.6
large-2000f-1s        2000    1         3833.3      46241.4  12.06x         4960.0
deep-12lvl              37    1           77.9       3026.7  38.86x          281.4
```

- **Decode-encode wins every shape by 12–39×**, including `large-2000f-1s` — the case constructed to favor the graft. The graft's per-`FillPath` overhead (each call constructs a new value and re-unifies) dominates its savings from not decoding untouched data; it even scales *worse* as secret count grows (26× at 10 secrets vs 12× at 1 on the same tree). Deep paths are its worst case (39×).
- **Absolute cost is negligible either way:** the winning mechanism resolves a 2000-field config in ~4ms — noise next to registry pulls and module evaluation. Performance does not constrain the design; it just settles the implementation choice.
- **Serialization rider:** exporting the resolved value to CUE bytes costs about the same as one decode-encode pass (~5ms on large). So bake-style delivery ≈ 2× fill-style on the rewrite step — still negligible, but fill-style is strictly cheaper when the seam permits it.
- Correctness gate held on every shape: both mechanisms JSON-identical, no plaintext in any output.

**Consequence:** the production `library/opm/secret` Resolve should use experiment 02's decode → splice → encode mechanism — the simple prototype approach is also the fastest measured. Recorded as **D17** in `../../03-decisions.md`.
