# Operational Concerns — Layered Defaults

This document is the OPM Production Readiness Review (PRR-lite).

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

- **Config-boundary ambiguity errors** (library): a config field whose defaults annihilate (e.g. two value layers each marking `*`) fails at finalize time with a config-shaped error naming the field, instead of surfacing later as an `unresolved disjunction` deep inside a component. Emitted from the kernel finalize step (`opm/kernel/validate.go` area).
- **Default-as-commitment conflicts** (library): a config default violating a downstream constraint now errors with CUE's own conflict message naming both positions; previously a silently substituted value with no signal at all.
- **Vet-time kind errors** (catalog): kind-invalid trait values fail `cue vet` with a conflict pointing at the blueprint's narrowing line; previously an apply-time API-server rejection.
- **Unstated-posture errors** (core): a trait without a stated `optional` posture fails at every consumer with an incomplete-bool error at the projection; previously silent.
- No metrics or trace changes; all signals are evaluation errors.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

- **core**: `feat!` on the v2 alpha line (`opmodel.dev/core@v2`, advances `v2.0.0-alpha.N`; no major crossing). Behavior change: optional-trait fields become absent-by-default; unstated posture becomes an error. The v1 branch is untouched.
- **catalog**: `feat!` on the v2 alpha line — narrowing tightens published acceptance (kind-invalid values now rejected); blueprint defaults change rendered output for silent authors. The v1 branches are untouched.
- **library**: kernel behavior change (finalize-before-fill); Go API surface unchanged. Consumers of the library (`cli`, `opm-operator`) pick it up by dependency bump.
- **modules / cli templates**: consumers of the above; their changes are cleanups, not breaks.
- Enhancement `semver: major` overall — the projection and narrowing changes alter what published schemas accept and produce.

## Deprecation

**What gets removed and when? What replaces it?**

- `#*Defaults` definitions (twelve, catalog_opm): already removed (eab9b12, ships with the next catalog release). Replaced by blueprint field-level defaults (D3) and transformer fallbacks (now reachable via D5).
- SPEC §6 **L5 as an author obligation**: replaced by the kernel guarantee wording once D4 lands (`docs(spec)` co-update in the core slice).
- Hand-set strategy/restartPolicy lines in cli templates and the v2 module fleet: deleted once blueprint defaults land; nothing replaces them — that is the point.

## Rollback

**If this lands and proves bad, what's the rollback story?**

- Per-repo and independent: core alpha releases are pinned by consumers, so a bad projection release is rolled back by re-pinning the previous alpha via `task deps:update`-managed bumps; the catalog similarly. The library finalize step is a single commit revert with no persisted-state consequences.
- Cross-version compatibility during rollback windows: a new catalog against an old core (or vice versa) stays evaluable — narrowing and defaults are plain unification against shapes both majors share; the only coupling is behavioral (which fields render), not structural.
- No data-plane state changes anywhere; rendered manifests are regenerated from source on every build.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

Pending OQ4, the default sequence minimizes observable output shifts:

1. **core** — D5 projection + SPEC co-updates → `v2.0.0-alpha.N` release. Produces: the published core the catalog builds against.
2. **catalog** — deps bump to the new core; blueprint narrowing + defaults (per OQ1); blueprint-path transformer fixtures → catalog alpha release. Produces: the published catalog templates and modules consume.
3. **library** — finalize-before-fill (independent of 1–2; can land in parallel, gated by the full-fleet render pass). Produces: the kernel `cli`/`opm-operator` embed.
4. **cli** — deps/library bump; template cleanup; template render smoke test in CI. Produces: templates that render out of the box.
5. **modules** (`main`) — deps bump; boilerplate deletion; render-diff verification.

The catalog-first variant (unblocks templates without waiting for a core release, at the cost of a second output shift) is OQ4's open alternative. A `plan.yaml` is scaffolded at the draft→accepted gate per the slicing skill; this section then records *why* the order holds and the plan records the order itself.
