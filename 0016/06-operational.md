# Operational Concerns — Initialize a Module Instance Package from a Published Module

This document is the OPM Production Readiness Review (PRR-lite). Five
fixed prompts — answer every one, even briefly.

## Observability

**What new signals, metrics, diagnostics, or error types does this
enhancement introduce, and how are they surfaced?**

The command's report (`#InstanceInitReport` in `contracts/contracts.cue`) is the observability surface: resolved module reference and version, the values source used (`initValues` / `debugValues` / `empty`), the target directory, and warnings — including the mandatory review warning whenever the source is `debugValues`. Failure modes reuse the CLI's existing error surfaces: registry acquisition errors from the kernel acquire path, and (per OQ5) `#config`-conformance diagnostics from the same validation machinery `opm instance vet` uses. No metrics or long-running signals — this is a local, one-shot scaffolding command.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the
backwards-compatibility plan?**

No. The core change is one *optional* field on `#Module` — additive on the v2 line (`opmodel.dev/core@v2`, currently alpha), a `feat:` commit, no existing module invalidated, no consumer forced to read it. The CLI change is a new subcommand — additive, minor on the CLI's own version. Library impact depends on OQ4 but is additive API at most. Enhancement-level `semver`: `minor`. The v1 maintenance lines get nothing (new work lands on `main` only, per the branch model).

Backwards direction: a new CLI running against a module published before the field exists falls back to `debugValues` (D2) — that fallback *is* the compatibility plan, and it makes the feature useful against the entire already-published fleet with no republish.

## Deprecation

**What gets removed and when? What replaces it?**

Nothing is removed. `debugValues` keeps its contract unchanged and additionally serves as init's fallback source; it is not deprecated by `initValues`, because the two answer different questions (test fixture vs onboarding template). No Go API, fixture, or tooling is retired.

## Rollback

**If this lands and proves bad, what's the rollback story?**

Clean in both directions. The CLI command can be removed without touching any deployed state — init writes local files only; packages already generated remain plain CUE packages that keep working with no dependency on the command that wrote them. The core field can stop being read at any time; as an optional field it can even be removed on the alpha line if it proves wrong (alpha permits breaking iteration), leaving modules that set it carrying a harmless unknown field until they republish — and if removal happens after stabilization, the field stays as documented-but-unread surface. No data-plane or cluster state is involved anywhere.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

Sequence: `core` → (`library`, if OQ4 chooses the shared renderer) → `cli` → `opmodel.dev` (mechanical CLI-reference regeneration, follows the landing).

- `core` ships the new optional field (with SPEC.md co-update) and publishes a v2 alpha tag; the artefact downstream consumes is that published tag.
- `library` (conditional on OQ4): exports the instance-package renderer and exposes the new field on the module decode surface; artefact: a tagged library release the CLI's `go.mod` picks up.
- `cli` ships `opm instance init` consuming both. The fallback ladder means the CLI does not hard-require modules republished with the new field — only the new core *schema* version so the field is legal to read.
- `modules` is not required to do anything; authors adopt `initValues` module-by-module at their own pace.

Two to three hand-offs in a straight line; the constraints here suffice. OQ4 fixes whether `library` is in the chain, and landings are logged in `delivery.yaml` as they happen.
