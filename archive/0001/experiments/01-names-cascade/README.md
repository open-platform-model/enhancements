# 01-names-cascade — #Platform Redesign Umbrella

Status: Concluded

Pins: D2, D3, OQ19, OQ20

## Hypothesis

A two-component `#Module` with `#release` wired via the `#components` pattern constraint evaluates `#components.<id>.#names.dns.fqdn` and `#ctx.components.<id>.dns.fqdn` to byte-identical strings; `metadata.resourceName: *name | #NameType` override wins when set, falls back to `metadata.name`, which itself defaults to the `#components` map key.

## Setup

`./target.cue` — copy of `enhancements/0001/schemas/target.cue` (skill rule: copy, never reference).
`./example_instance.cue` — three-component cascade probe in the same `schema` package as `target.cue`:

1. `default-name` — neither `metadata.name` nor `metadata.resourceName` set; expects map key `"default-name"` to flow through the `metadata: name: string | *Id` pattern + cascade.
2. `explicit-name` — `metadata.name: "explicit-svc"`; `metadata.resourceName` absent; expects `resourceName == "explicit-svc"` via default-disjunction.
3. `explicit-override` — `metadata.name: "internal"`, `metadata.resourceName: "public"`; expects override `"public"` to win.

Top-level `results` struct surfaces each component's `resourceName` + `dns.fqdn` (hidden `#`-prefixed fields don't render in `cue eval` output). Top-level `identity_checks` unifies `#ctx.components.<id>` against `#components.<id>.#names` to prove byte-identity, plus explicit-value assertions per branch.

`./cue.mod/module.cue` — `module: "enhancements.opmodel.dev/0001/experiments/01-names-cascade@v0"`.

## Run

```bash
cue eval -c ./...
```

Expected: three concrete `resourceName` strings (`default-name`, `explicit-svc`, `public`); three resolved FQDN strings of the form `<resourceName>.cascade-prod.svc.cluster.local`; `identity_checks.*_match` blocks materialize identical `#ComponentNames` shapes from both sides; `identity_checks.*_expected` strings carry the expected concrete values.

## Outcome

Observed on 2026-05-23 with cue v0.16.1:

- `results.default_resource == "default-name"` — map-key fallback through `metadata.name = *Id` and `resourceName = *name`.
- `results.explicit_resource == "explicit-svc"` — `metadata.name` flows into `resourceName` via the default-disjunction.
- `results.override_resource == "public"` — explicit `metadata.resourceName` override wins.
- `results.{default,explicit,override}_fqdn` all materialize as `<resourceName>.cascade-prod.svc.cluster.local` (cluster domain defaulted).
- `identity_checks.{default,explicit,override}_match` evaluate to identical `#ComponentNames` shapes — byte-identity between `#components.<id>.#names` and `#ctx.components.<id>` confirmed.

**Hypothesis held.** Evidence wired back into D2 and D3 Source lines (`03-decisions.md`).
