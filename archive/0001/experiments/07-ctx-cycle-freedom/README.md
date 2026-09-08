# 07-ctx-cycle-freedom — #Platform Redesign Umbrella

Status: Concluded

Pins: D2 cycle-freedom claim ("With CUE comprehensions the projection is structurally guaranteed identical"); replaced the now-stale `#ContextBuilder` circularity risk in `05-risks.md`

## Hypothesis

A `#Module` with N components — where each component body references both `#names.dns.fqdn` (self) and `#ctx.components.<other-id>.dns.fqdn` (cross-component) — evaluates to a fully concrete value without a CUE cycle error, because `#names` depends only on `metadata + #release` (not on `#ctx.components`) and `#ctx.components` is a downstream projection. A control case that flips `#names` to depend on `#ctx.components` errors with a cycle. Cheapest insurance against the bug `05-risks.md` was worried about.

## Setup

`./schema/target.cue` — copy of `enhancements/0001/schemas/target.cue` (skill rule: copy, never reference).

Two sibling packages:

### `./main/instance.cue` (package `main`)

Three components in one `main_module: schema.#Module`:

- `api` — `spec.url` references `#ctx.components.worker.dns.fqdn` (cross-component).
- `worker` — `spec.url` references `#ctx.components.api.dns.fqdn` (mutual cross-component).
- `db` — `spec.selfUrl` references `#ctx.components.db.dns.fqdn` (the projection equivalent of `#names.dns.fqdn`; `#names` is not in lexical scope from inside a component instance's spec field because CUE references resolve pre-unification and `#names` lives only in `#Component`'s definition body — `#ctx` is a sibling of `#components` at the `#Module` level and IS in scope).

Top-level `results` struct surfaces five concrete strings (3 spec URLs + 2 projection FQDNs) so they render in `cue eval` output despite hidden field prefixes.

### `./control/instance.cue` (package `control`)

One component (`cyclic`) whose `metadata.resourceName` is set to its own `#ctx.components.cyclic.dns.fqdn` — `dns.fqdn` derives from `resourceName` via `#names`, so this creates the cycle the comprehension architecture is supposed to prevent. Top-level `cycle_probe: control_module.#components.cyclic.#names.dns.fqdn` forces materialization (hidden fields don't render otherwise; the cycle won't surface).

`./cue.mod/module.cue` — `module: "enhancements.opmodel.dev/0001/experiments/07-ctx-cycle-freedom@v0"`.

## Run

```bash
cue eval -c ./main/...                              # MUST succeed; concrete spec.url strings
cue eval -c ./control/...                           # MUST error on cycle_probe
```

## Outcome

Observed on 2026-05-23 with cue v0.16.1:

- Main case `results` block resolves to fully concrete strings:
  ```
  api_url:    "http://worker.ctx-cycle-prod.svc.cluster.local"
  worker_url: "http://api.ctx-cycle-prod.svc.cluster.local"
  db_url:     "http://db.ctx-cycle-prod.svc.cluster.local"
  api_fqdn:   "api.ctx-cycle-prod.svc.cluster.local"
  db_fqdn:    "db.ctx-cycle-prod.svc.cluster.local"
  ```
  Mutual `api↔worker` cross-component refs evaluate without a cycle because `#names` depends only on `metadata + #release`, not on `#ctx.components`. Self-ref on `db` resolves identically via the projection.
- Control case errors with:
  ```
  control_module.#components.cyclic.metadata.resourceName: invalid interpolation: 3 errors in empty disjunction
      ./schema/target.cue:234:11
      ./schema/target.cue:234:14
  ```
  The cycle manifests downstream of `#names.dns.fqdn` (target.cue:234) — CUE's disjunction resolver can't satisfy `resourceName = *name | #NameType` when `resourceName` is forced to depend on `dns.fqdn` (which depends on `resourceName`).

**Hypothesis held.** The cycle-freedom claim in D2 is empirically structural, not luck: the projection's input (`#names`) cannot read its output (`#ctx.components`) without producing a hard CUE error. The `#ContextBuilder` circularity risk in `05-risks.md` is replaced with the residual finding: author-introduced cycles surface as `invalid interpolation: empty disjunction` (not "cycle detected") because the `*name | #NameType` cascade fails first. Authoring caveat for `#names` lexical scope from inside `spec` (must use `#ctx.components.<self-id>` projection rather than `#names` direct) added to `02-design.md`. D2 Source line updated.
