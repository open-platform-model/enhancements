# 08-moduleish-refusal — Initialize a Module Instance Package from a Published Module

Status: Concluded

## Hypothesis

The directory-occupancy test `opm module init` applies (a `cue.mod/` directory, an identity package, or any root `.cue` file) also recognizes a directory holding a generated instance package, so D5's `--dir` refusal needs no new rule.

## Setup

Shell only. `moduleish.sh` copies the three checks of `moduleish` in `cli/internal/cmd/module/init.go` (cli commit 2370bd6) into a shell function and applies it to five temp directories: empty, a module tree (`cue.mod/` plus `identity/identity.cue`), a generated instance package (`cue.mod/` plus `instance.cue` and `values.cue`), a half-written package holding only `values.cue`, and a bare `cue.mod/`.

## Run

```bash
bash moduleish.sh
```

## Outcome

**Hypothesis held.** Run 2026-08-24.

| Directory | Verdict |
| --- | --- |
| empty | no |
| module tree | yes (`cue.mod/`) |
| generated instance package | yes (`cue.mod/`) |
| half-written (only `values.cue`) | yes (root `.cue` file) |
| bare `cue.mod/` | yes (`cue.mod/`) |

- The existing predicate refuses a generated instance package with no new rule.
- The half-written case is the finding: an init interrupted after writing one file leaves a directory the retry refuses. D5 was revised on 2026-08-24 to state that a failed init leaves no partial directory behind (write everything or nothing), so a retry is always possible.

Evidence linked from D5's `Source:`.
