# 10-service-name-source — Kernel render path parity with pure CUE

Status: Concluded

## Hypothesis

The Service name can be carried by a single always-read field,
`#ExposeSchema.name`, that **defaults to the component's `#names.dns.short`**
(so the default Service, workload and DNS projection agree) while an author
may override it to an unrelated exact name; and, as the alternative under
review ("Path C"), that the same field could instead act as a **constraint**
the trait feeds into `metadata.resourceName` through its `#nameConstraint`,
so a Service override would rename the workload too and the DNS projection
could never diverge.

Three questions, answered separately: (1) where can the default be
expressed, given `#ExposeSchema` has no lexical path to the owning
component; (2) what does `#names.dns.*` say when `expose.name` is overridden;
(3) is the author's `expose.name` concrete on the `#traits` entry, which is
the only place a trait-owned `#nameConstraint` can read it.

## Setup

Self-contained CUE module (`experiments.opmodel.dev/e0019x10@v0`), cue
v0.17.1. Copied (never referenced):

- `types.cue` — byte-identical to experiment 09's (`#NameType` from
  `core/src/types.cue:10`; D20's `#ObjectNameType`, `#ServiceNameType`).
- `component.cue` — experiment 09's `#Component` (D20 ceiling, D21
  propagation) plus ONE addition: `spec` is the union of attached trait
  specs, the way `core/src/component.cue` `_allFields` builds it. Needed to
  model a trait that carries a spec at all.
- `expose.cue` — the naming surface of
  `catalog_opm/opm/traits/v1beta1/expose.cue`: `#ExposeSchema` with `name`
  typed `#ServiceNameType` (D20), `#ExposeTrait` with D21's constraint, and
  the `#Expose` wrapper carrying the default. A stand-in
  `#ServiceTransformer` reads only `spec.expose.name`, as the proposal
  requires. `#ExposeTraitC`/`#ExposeC` model Path C (constraint computed from
  the trait's own filled spec); `#ExposeC2` additionally feeds the
  component-level value back onto the trait entry.
- `cases.cue` — three pass cases for the proposal (default, `expose.name`
  override, `resourceName` override), the Path C probe pinned as a hidden
  assertion, and two recorded refusals (C2, must-fail F).

## Run

```bash
cd enhancements/0019/experiments/10-service-name-source
cue vet -c ./...
cue eval ./... -e a1.spec.expose.name -e a2.spec.expose.name -e 'a2.#names.dns.fqdn' \
  -e a3.spec.expose.name -e 'c1.#traits.expose.#nameConstraint' -e 'c1.#names.resourceName'
```

To reproduce a refusal, paste the commented `c2` or `failF` block from
`cases.cue` into a scratch file in the package and re-run `cue vet -c ./...`.

## Outcome

**Hypothesis held for the always-read field with a wrapper-hosted default;
refuted for Path C in both spellings.**

1. **Where the default lives (measured).** `#ExposeSchema` cannot reference
   the component, and neither can the `#Expose` wrapper *by default*: the
   first spelling failed with `reference "#names" not found` at
   `expose.cue:26`. `#names` reaches the wrapper only by unification with
   `#Component`, not lexically — the same rule 0019 records for `#transform`
   slots. The wrapper must re-declare `#names: _` (and `spec: _` when it
   references `spec`) to reference it; unification with `#Component`'s own
   `#names` makes it the same value. With that, the default is expressible
   on the wrapper and nowhere else in the catalog: `#ExposeSchema` never
   sees the component, so a raw `#ExposeTrait` attachment without the
   wrapper has no default (the fleet attaches through the wrapper in all 17
   files; the production landing should make `name!` required so a raw
   attachment refuses rather than renders an unnamed Service).

2. **Default case (`a1`).** `spec.expose.name` resolves `prod-web`, the
   stand-in transformer emits `prod-web`, `#names.dns.fqdn` is
   `prod-web.media.svc.cluster.local`. All three agree.

3. **`expose.name` override (`a2`, istiod).** Service `istiod`; workload
   `istio-istiod`; `#names.dns.fqdn` = `istio-istiod.istio-system.svc.cluster.local`.
   **The DNS projection follows the workload, not the Service**, so for an
   overridden `expose.name` the projection names a Service that does not
   exist. Pinned as `_a2DnsDiverges`. This is the price of a free override
   and is now measured rather than argued; the seven fleet modules that set
   `expose.name` today (`istio_ambient` plus six `serviceName` knobs) are
   exactly the cases where `#ctx.components.<id>.dns.*` would mislead.

4. **`resourceName` override (`a3`, istiod).** Expose's D21 constraint
   admits `istiod` (DNS-1035), `expose.name` defaults to it, Service,
   workload and FQDN all read `istiod.istio-system.svc.cluster.local`. The
   author has a spelling that keeps the projection true when the exact name
   is safe for the workload too.

5. **Path C, trait-owned constraint (`c1`): refuted.** On the `#traits`
   entry, `spec.expose.name` is the TYPE (`#ServiceNameType`), never the
   author's value — that lands on the component's `spec` only. The entry's
   `#nameConstraint` therefore degrades to the type, and the override never
   reaches `resourceName` (`istio-istiod`). Path C is Path A with a
   different field name.

6. **Path C2, wrapper feeding the value back (`c2`): refuted.** The cycle
   entry.spec → component.spec → entry.spec passes through the component's
   `if t.spec != _|_` comprehension guard, which then contributes nothing,
   and the author's own `spec: expose: ...` is refused as
   `field not allowed`. Not a spelling problem to iterate on: the trait
   entry is a schema, and making it carry the instance's value inverts the
   direction core's `_allFields` builds `spec` in.

7. **Must-fail F.** A dotted `expose.name` (`svc.internal`) is refused by the
   field's own `#ServiceNameType`, error naming the DNS-1035 regex.

**Consequence for the design.** The always-read `expose.name` with a
wrapper-hosted default is viable and matches the author's intent; what it
cannot deliver is a `#names.dns.*` that stays true under an override. Two
honest options follow, neither measured here: make the `dns` block derive
from a primitive-declared network identity rather than from `resourceName`
(the "conditional dns" claim experiment 09 explicitly left open), or
document `#names.dns.*` as the workload-derived name and steer authors who
override `expose.name` away from the projection. Path C is off the table.
