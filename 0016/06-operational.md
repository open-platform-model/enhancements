# Operational Concerns: Initialize a Module Instance Package from a Published Module

OPM's Production Readiness Review (PRR-lite): five fixed prompts, each answered below.

## Observability

**What new signals, metrics, diagnostics, or error types does this
enhancement introduce, and how are they surfaced?**

The command's report (`#InstanceInitReport` in `contracts/contracts.cue`) is the observability surface: resolved module reference and version, the values source used (`initValues` / `debugValues` / `empty`), the target directory, and warnings, including the mandatory review warning whenever the source is `debugValues`. The report also names the selected major and any higher majors skipped as core-incompatible (D5), and ends with the vet command to run next (D8).

Failure modes reuse the CLI's existing error surfaces and exit codes: refusals (2) and registry connectivity (3) from the kernel acquire path. `#config` conformance is not checked at init; it surfaces through `opm instance vet`. No metrics or long-running signals: this is a local, one-shot scaffolding command.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the
backwards-compatibility plan?**

No. The core change is one *optional* field on `#Module`: additive on the v2 line (`opmodel.dev/core@v2`, currently alpha), a `feat:` commit, no existing module invalidated, no consumer forced to read it. The CLI change is a new subcommand: additive, minor on the CLI's own version. Library ships nothing (D7). Enhancement-level `semver`: `minor`. The v1 maintenance lines get nothing (new work lands on `main` only, per the branch model).

Backwards direction: a new CLI running against a module published before the field exists falls back to `debugValues` (D2): that fallback *is* the compatibility plan, and it makes the feature useful against the entire already-published fleet with no republish. Forward direction: `#Module` is closed, so an author who sets `initValues` must first pin the module to the core v2 tag that ships the field (experiment 06); older core tags reject it with "field not allowed". Only the core v2 line is in scope; nothing here reaches v1 or v0.

## Deprecation

**What gets removed and when? What replaces it?**

Nothing is removed. `debugValues` keeps its contract unchanged and additionally serves as init's fallback source; it is not deprecated by `initValues`, because the two answer different questions (test fixture vs onboarding template). No Go API, fixture, or tooling is retired.

## Rollback

**If this lands and proves bad, what's the rollback story?**

Clean in both directions. The CLI command can be removed without touching any deployed state: init writes local files only, and packages already generated remain plain CUE packages that keep working with no dependency on the command that wrote them.

The core field can stop being read at any time. As an optional field it can even be removed on the alpha line if it proves wrong (alpha permits breaking iteration), leaving modules that set it carrying a harmless unknown field until they republish. If removal happens after stabilization instead, the field stays as documented-but-unread surface. No data-plane or cluster state is involved anywhere.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

Sequence: `core` → (`0019` render-path changes in `library` and `cli`) → `cli` → `opmodel.dev` (mechanical CLI-reference regeneration, follows the landing).

- **This entry depends on [0019](../0019/).** The generated package is only useful through `opm instance vet`/`build`, and 0019 redefines what those do:
  - one CUE build per render with a derived render `cue.mod` (D9, D13 in 0019);
  - a platform that embeds its catalog (D5, D6 in 0019);
  - module-versus-platform catalog skew surfaced as a kernel-detected signal that defaults to warn-and-render (D7, D18 in 0019).

  Experiment 03 showed the pre-0019 behavior: a correct package fails outright with "unresolved demands" when the platform's catalog pin differs from the module's. After 0019 that same package renders with a skew warning instead. The `cli` slice of this entry therefore lands after 0019's render-path changes are in the CLI's kernel dependency, so that the vet the report points at behaves as designed. The `core` slice (the `initValues` field) has no such constraint and may land first.

- `core` ships the new optional field (with SPEC.md co-update) and publishes a v2 alpha tag; the artefact downstream consumes is that published tag.
- `cli` ships `opm instance init` against that core tag. The fallback ladder means the CLI does not hard-require modules republished with the new field, only the new core *schema* version so the field is legal to read. No library release is required (D7).
- `modules` is not required to do anything; authors adopt `initValues` module-by-module at their own pace, each adoption moving that module's core pin to the shipping tag first.

Two hand-offs in a straight line plus the 0019 precondition on the `cli` slice; the constraints here suffice, and landings are logged in `delivery.yaml` as they happen.
