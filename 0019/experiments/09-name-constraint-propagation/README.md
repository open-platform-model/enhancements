# 09-name-constraint-propagation — Kernel render path parity with pure CUE

Status: Concluded

## Hypothesis

`metadata.resourceName`'s ceiling can widen to a DNS-1123 **subdomain** type
(dots allowed, 253 runes — what the API server actually admits for
Deployment/DaemonSet/ConfigMap/CSIDriver `metadata.name`) while the three
dot-hostile kinds (Service, StatefulSet, Namespace) stay protected **by the
primitive that introduces the hazard**: a `#nameConstraint` slot on
`#Resource`/`#Trait`/`#Blueprint`, unified into `resourceName` by `#Component`
comprehensions — the `matchLabels` wholesale-unification pattern applied to a
scalar — with no per-kind knowledge in core and no precedence rule anywhere.

Motivating matrix, measured against a live k8s v1.33.0 API server
(server-side dry-run, 2026-08-24): dots accepted on Deployment, DaemonSet,
ConfigMap, StorageClass, CSIDriver (`zfs.csi.openebs.io`); refused on Service
(DNS-1035: "must start with an alphabetic character"), StatefulSet and
Namespace (bespoke "must not contain dots"). The rule is exactly: a name is
dot-restricted iff it becomes a DNS label.

## Setup

Self-contained CUE module (`experiments.opmodel.dev/e0019x09@v0`), cue
v0.17.1. Copied (never referenced), then cut to the naming surface:

- `types.cue` — `#NameType` copied byte-identical from `core/src/types.cue:10`.
  NEW: `#ObjectNameType` (DNS-1123 subdomain, ≤253) and `#ServiceNameType`
  (DNS-1035 label) — these two ARE the D20 proposal.
- `component.cue` — `#Component` cut down from `core/src/component.cue`
  (kept: `metadata.{name,resourceName}`, `#instance`, `#names`, the three
  attachment maps; dropped: matchLabels machinery, `_allFields`/`spec`).
  CHANGED: the resourceName ceiling (D16's qualified default kept, unified
  against `#ObjectNameType` instead of `#NameType`) and the NEW propagation
  comprehensions. Stand-in `#Resource`/`#Trait`/`#Blueprint` carry the NEW
  `#nameConstraint` slot.
- `primitives.cue` — naming surfaces of `#ExposeTrait`
  (`catalog_opm/opm/traits/v1beta1/expose.cue`), `#StatefulWorkloadBlueprint`
  (`catalog_opm/opm/blueprints/v1beta1/stateful_workload.cue`), a Namespace
  resource, plus a constraint-free `#ContainerResource` as the neutral
  baseline.
- `cases.cue` — four pass cases pinned by hidden assertions
  (`_matchLabelsAreDerived` style) and four must-fail cases, commented out
  with observed error text.

## Run

```bash
cd enhancements/0019/experiments/09-name-constraint-propagation
cue vet -c ./...          # passes; hidden assertions pin all derived names
cue eval ./... -e 'case4.#names.resourceName'   # "prod-db"
```

To reproduce a refusal, paste any commented `caseFailX` block from
`cases.cue` into a scratch file in the package and re-run `cue vet -c ./...`.

## Outcome

**Hypothesis held — after one refutation that changed the mechanism's shape.**

The first spelling — `#nameConstraint?: string` guarded by
`if t.#nameConstraint != _|_` — **silently never propagated**: on cue
v0.17.1, `!= _|_` evaluates to `false` for a **non-concrete** value (probe:
`#ExposeTrait.#nameConstraint != _|_` → `false`), so every guard skipped and
all three must-fail cases passed vet clean. The `!= _|_` idiom is safe for
concrete *data*; this slot carries a *type*. This failure mode is invisible
in review — the code reads correctly and does nothing.

The corrected spelling drops optionality and the guard entirely:
`#nameConstraint: _` (top) on every primitive, unified **unconditionally** by
the component. Unifying top is the identity, so an indifferent primitive
costs nothing; declaring a constraint is just narrowing the field. With that:

- **Pass:** dot-neutral default (`prod-web` + correct FQDN); dotted override
  with no dot-hostile primitive (`metrics.internal.example`); Expose attached
  with default name (`prod-web2` — a valid DNS-1035 label, so tightening
  costs a well-named component nothing); Expose + StatefulWorkload composed
  (intersection DNS-1035 governs, no precedence rule written).
- **Fail (all refused at `cue vet -c`):** dotted override + Expose (error
  names the DNS-1035 regex and traces through the trait comprehension);
  leading-digit instance + Expose — the latent hole in today's core, since
  `#NameType` admits `1prod` but Service refuses `1prod-web` at apply, now
  caught at vet; dotted override + StatefulWorkload; a 254-rune override
  (the `#ObjectNameType` ceiling holds with no primitive attached).

Two legibility caveats for the production landing, both extensions of D16's
recorded caveat: the leading-digit case refuses as a bare
`incomplete value <constraint conjunction>` with the offending string
nowhere in the message, and the other refusals bury the decisive
`out of bound` line under `#names` interpolation re-reports. The D16-style
hidden assertion should cover constraint-tightened defaults too.

Also confirmed by construction: the D16 qualified default
(`<instance>-<component>`) is intrinsically dotless — both halves are
`#NameType` labels — so only an *explicit* override can ever meet a dot
constraint. The default path is structurally safe; validation cost lands
solely on deliberate overrides.

Evidence for D19–D21 in `03-decisions.md`.
