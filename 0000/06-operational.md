# Operational Concerns — {Enhancement Title}

This document is the OPM Production Readiness Review (PRR-lite). Five
fixed prompts — answer every one, even briefly. The answers tell future
operators, contributors, and on-call responders what to expect when the
enhancement lands. Leave a prompt blank only if it is genuinely N/A; say
so explicitly when it is.

## Observability

**What new signals, metrics, diagnostics, or error types does this
enhancement introduce, and how are they surfaced?**

{Name new error kinds, structured diagnostic fields, log lines, metrics,
or trace spans. Point readers to the file paths where each is emitted.
If the enhancement is observability-neutral, say so.}

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the
backwards-compatibility plan?**

{State the impact on `opmodel.dev/core` (`@v0` → `@v1`?) and on every
downstream consumer (library, catalog, opm-operator, …). Name the
shipping sequence; identify which consumers must update before which
others.}

## Deprecation

**What gets removed and when? What replaces it?**

{List deprecated CUE definitions, Go functions, fields, regexes, fixtures,
and tooling. Name the replacement for each. State the removal timeline —
typically the same release as the enhancement, unless a transition window
is required.}

## Rollback

**If this lands and proves bad, what's the rollback story?**

{Describe how to revert. Are previous artifacts still consumable? Does
the library still work against the previous `core` major? Are there
data-plane state changes that survive a code rollback?}

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

{Sequence the repo landings (core → library → catalog → …). For each
hand-off, name the artefact the upstream produces that the downstream
consumes (a published OCI tag, a regenerated fixture, a new task target).}
