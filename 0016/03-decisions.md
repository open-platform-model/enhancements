# Design Decisions — Initialize a Module Instance Package from a Published Module

This document records every significant design choice with its reasoning
and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they
are made. **Numbers are permanent** — never reused, never renumbered, because
other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** How that stays true depends on the entry's `status`:

- While the entry is **`draft`**, decisions are living text: a changed choice is an **in-place edit** to the existing `DN`, and the log never contains two conflicting decisions. If the replaced position was backed by real evidence (an experiment outcome, an explicit user decision), fold it into *Alternatives considered* — marked as previously adopted — before overwriting; a mere sketch may be replaced outright. A decision retracted outright keeps its number as a one-line tombstone (`### DN: (retracted, YYYY-MM-DD)`).
- Once **`accepted`**, decision bodies are **protected**. A change lands as a *new* `DN` with `**Amends:**` / `**Supersedes:**` relation fields; existing bodies are edited only through the `enhancement-compaction` skill, which weaves stacked reversals into the decisions they reverse (lower number survives, vacated number keeps a tombstone) — at latest in the mandatory pass immediately before the `implemented` flip.
- **`implemented`** entries are frozen; **`superseded`** entries are stubbed via compaction.

Either way the log stays safe to read linearly: a reader who stops halfway should never come away believing something a later entry already killed.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source. The Source field is specific — `"User decision YYYY-MM-DD"`, a URL, or a file path — so the provenance of a choice never gets lost. A decision revised in place or by a merge keeps its original `Source:` and gains a `Revised: YYYY-MM-DD` line; *Alternatives considered* always survives revision and compaction, because it is what stops a rejected option being re-litigated later.

---

## Decisions

### D1: A new CLI command scaffolds an on-disk instance package from a published module reference

**Decision:** The CLI gains an init command for module instances: the user supplies an OCI module reference and tag (plus instance name and namespace), and the command writes a complete, standalone on-disk instance package — `cue.mod/module.cue`, `instance.cue`, `values.cue` — the same shape `LoadInstancePackage` consumes and `opm instance build`/`apply` accept.

**Alternatives considered:**

- *Extend `opm module build --name/--namespace` (the synth path) with a `--write` flag.* Rejected: synth answers "does this module render?" and is deliberately fileless and ephemeral; grafting file emission onto it conflates a validation tool with a scaffolding tool, and its output (an overlay inside the module's staged tree) is not the standalone committable package the user needs.
- *Documentation only — publish a canonical instance-package example per module.* Rejected: pushes the boilerplate burden onto every module author, and the copied example still carries stale pins and majors the moment either the module or core moves.

**Rationale:** The instance package is the unit everything downstream consumes (CLI build/apply, operator ModulePackage path, GitOps commits), yet nothing generates it — see `01-problem.md`. Generating it from the acquired artifact makes the boilerplate correct by construction.

**Source:** User decision 2026-08-13.

### D2: `debugValues` is the default template source for the generated `values.cue`

**Decision:** When the module declares no dedicated init field (D3), init populates the generated `values.cue` from the module's `debugValues`. The command output names the source used, so a `debugValues`-scaffolded file is visibly that.

**Alternatives considered:**

- *Always start from an empty `values: {}` scaffold.* Rejected as the default: it discards author knowledge that already exists in every published module today and makes the first `opm instance build` fail out of the box for any module with required config.
- *Render `#config`'s defaults into `values.cue`.* Not chosen as the default: `#config` is a constraint schema (possibly non-concrete), so this produces a partial file at best; it remains a candidate fallback for modules with neither field (OQ3).

**Rationale:** `debugValues` is the only values-shaped, author-written, concrete content guaranteed to exist in already-published modules; using it makes init useful against the entire existing fleet on day one, with no republish required. Its known weakness — debug-only content the author never meant as a starting point — is exactly what D3 exists to fix.

**Source:** User decision 2026-08-13.

### D3: `#Module` gains an optional field carrying the author-intended init template, taking precedence over `debugValues`

**Decision:** `#Module` gains a new optional field (working name `initValues`; final name and shape are OQ1) whose meaning is: the values a freshly initialized instance package starts from. When present, init uses it and never reads `debugValues`. `debugValues` keeps its existing contract (concrete example values for testing and debugging) unchanged.

**Alternatives considered:**

- *Reuse `debugValues` permanently as the init source, no core change.* Rejected: it silently rewrites `debugValues`' contract from "debug fixture" to "public onboarding surface", and punishes authors whose debug values legitimately contain test-only content (throwaway hostnames, debug log levels, dummy credentials) they never want templated into a user's deployment.
- *Ship the init template as a separate file in the OCI artifact rather than a `#Module` field.* Rejected: introduces a second distribution channel with its own packaging/validation rules, invisible to CUE evaluation; a schema field travels with the module, is validated with the module, and is readable by every consumer that already decodes `#Module`.

**Rationale:** Author intent for "what a new deployment starts as" and "what I test with" are different statements; conflating them in one field forces authors to compromise one to serve the other. An optional field with a `debugValues` fallback gives a clean upgrade path: existing modules work today, and authors opt into curated init content at their own pace.

**Source:** User decision 2026-08-13.

---

## Open Questions

Track unresolved questions surfaced during design. Each entry carries a
`Status:` line; close it with `resolved-by-D##`, `deferred-to-NNNN`, or
`answered` when the question resolves.

- **OQ1: Name and shape of the new `#Module` field.** Status: open. Working name is `initValues?: _`, mirroring `debugValues`. To settle: the name (`initValues` vs `instanceValues` vs `exampleValues` vs a structured `init: {values: ...}` block that could later grow siblings such as author notes); whether the schema asserts it satisfies `#config` (a `let` unification like `#ModuleInstance`'s `values` check, at the cost of evaluating `#config` on every module load) or leaves conformance to init-time reporting (OQ5); and whether it must be concrete or may carry defaults/optional parts that render as partially-filled scaffolding.
- **OQ2: Command surface and reference syntax.** Status: open. Working shape is `opm instance init <module-ref> [--version <tag>] --name <n> --namespace <ns> [--dir <dir>]`. To settle: whether `<module-ref>` is the CUE module path with major (`opmodel.dev/modules/jellyfin@v3`, resolved through `CUE_REGISTRY` routing like every existing command) or also accepts an explicit OCI URL; how a missing `--version` resolves (refuse, or resolve the highest release of the referenced major, and via which existing library primitive); and whether name/namespace are flags, positionals, or interactively prompted when omitted.
- **OQ3: Behavior when the module has neither `initValues` nor usable `debugValues`.** Status: open. `debugValues: _` is a regular field, so "absent" really means "unset/non-concrete top". Options: emit `values: {}` with a warning; render a best-effort skeleton from `#config` (field names and defaults where concrete); or refuse without an explicit `--empty` flag. Also to settle here: whether a *non-struct* concrete `debugValues` is rendered verbatim or refused.
- **OQ4: Where the package renderer lives.** Status: open. `synth.Instance` already renders an `instance.cue` (and `values.cue`) for its in-memory overlay (`library/opm/helper/synth/instance.go`); init needs the same logical files plus a generated `cue.mod/module.cue` with registry deps instead of the staged-tree trick. Options: generalize and export the synth renderer in `library` so both frontends share one generator (keeps the two file shapes from drifting; adds public API surface to library), or render CLI-side next to the existing `opm module init` template machinery (keeps library untouched; duplicates the instance-file shape in two repos). The answer determines whether `library` appears in `affects`.
- **OQ5: Validation at init time.** Status: open. Should init run the equivalent of `opm instance vet` on the generated package before reporting success — and if the template source does not satisfy `#config` (a real possibility for stale `debugValues`), does init fail, write the files with a prominent warning, or gate on a `--no-verify` escape hatch? Related: is `initValues` failing `#config` a publish-time error once 0011's publish gates exist?
- **OQ6: Version pinning and dep hygiene in the generated `cue.mod/module.cue`.** Status: open. The generated module file must pin the module dependency to the resolved tag and carry core at the module's own major (the same derivation synth performs from the acquired module's tidied `cue.mod/module.cue`). To settle: whether init copies the module's resolved dep closure verbatim, runs the equivalent of `cue mod tidy` after writing, or writes minimal deps and instructs the user; and what the generated package's own `module:` path is (a placeholder local path vs user-supplied).
