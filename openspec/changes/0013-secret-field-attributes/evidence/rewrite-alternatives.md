# Why the kernel rewrites each secret to a reference

Condensed from D11, D16 and OQ2 of `0013/03-decisions.md` and `0013/07-questions.md`. Mockup note.

## The problem with the simple approach

Under the closed `#Secret` type, `{value: …} & {ref: …, key: …}` is an error. So the kernel cannot add the reference beside the literal. It must build the render without the deployer's original value.

## What was measured

- `experiments/02-resolve-in-place` did the rewrite as decode, change, encode. It works.
- `experiments/03-kernel-omission` ran the published kernel (2026-08-14). Leaving the original value out of the build works on both candidate paths. One build is enough. Overriding the value in place fails.

## The two rejected designs that will come up again

**A kernel-filled side table (`#ctx.secrets`).** Rejected on three grounds:

1. Authors would write `#ctx.secrets.db.password` where `#config.db.password` is the natural reference.
2. Attributes take no part in evaluation, so the table cannot be computed in CUE. A module would not check without the kernel.
3. The plaintext stays live at the `#config` path.

**A shared base type, so both forms unify (`#SecretBase`).** It makes the rewrite a plain fill and keeps the author's wiring. Rejected because the plaintext then stays in the component graph: a transformer that reads `.value`, an interpolation, or an error message would leak it silently. It was the strongest measured fallback if leaving the value out had not worked. It was not needed.
