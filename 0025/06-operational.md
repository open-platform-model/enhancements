# Operational Concerns: Self-Service Kinds from Published Modules

This document is the OPM Production Readiness Review (PRR-lite). Five fixed prompts, each answered.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

- **Definition status.** Conditions for accepted versus refused (with the refusal reason: module not found, bound release outside the bound major, `#config` not structural, kind already served by another definition), for the served CRD being established, and for the bound release in effect. A rebind that is pending under a manual update policy is visible as a condition, never inferred.
- **Instance status.** A served-kind instance mirrors the projected `ModuleInstance`'s readiness and its render diagnostics, so a consumer reads failures on the object they created. The exact status shape is OQ5.
- **Dependents.** A definition reports how many instances bind to it; deletion refused while that count is non-zero names it.
- **Guardrail refusals.** An admission refusal of a direct module reference under a tenant identity is an API-server error naming the definition path the tenant should use.
- **Pre-flight.** The CLI reports, for a definition before it is applied, whether the bound release resolves, whether the module's `#config` is a valid kind schema, and whether the group and kind collide with an existing definition.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

Additive throughout. Core gains three definitions and changes neither `#Module` nor `#ModuleInstance`. The operator gains a CRD, an optional field on `ModuleInstance`, and served kinds that exist only where a definition asks for them. Catalog_opm gains a resource contract and a transformer. The CLI gains commands. A module that is never bound as an offering observes nothing. The one new refusal, a non-structural `#config` as a definition target, applies to a module only at the moment someone binds it. `semver` is set at promotion; the expected value is `minor`.

## Deprecation

**What gets removed and when? What replaces it?**

Nothing is removed. Hand-authored `ModuleInstance` objects stay first-class; the definition reference is an alternative to the module reference, not a replacement.

## Rollback

**If this lands and proves bad, what's the rollback story?**

- **Binding layer.** Delete the definitions. Instances referencing one lose their binding and stop reconciling with a diagnostic naming the missing definition; rewriting each to name its module directly restores it, which is the state before this entry. No rendered resource changes on rollback alone.
- **Kind layer.** A definition cannot be deleted while instances exist, so rollback is: delete the served-kind instances (or convert them to hand-authored `ModuleInstance` objects, which the projection makes mechanical), then the definition, then the CRD goes with it. Whether the projected `ModuleInstance` is a real object that can outlive its served-kind parent is OQ7 and decides whether the conversion step is a rename or a re-create.
- **Core.** Additive definitions; a consumer that never references them is unaffected by their presence or removal.

## Cross-Repo Coordination

**Which repos must coordinate, and what constrains the order?**

Constraints only; landings are logged in this entry's `delivery.yaml`.

- **Core before everything.** The definition shape, the served-instance shape and the projection are core definitions every other repo reads. The kernel cannot read a projection core does not define.
- **Library before the operator and the CLI.** The kernel's projection read and its "is this `#config` structural" answer are the single implementation both frontends share; each frontend implementing its own would be the drift D6 exists to prevent.
- **Catalog_opm's definition pair before rendered definitions.** A platform product module can attach the definition resource contract only once catalog_opm publishes it and the transformer that renders it. Hand-authored definitions do not wait for this.
- **The kind layer depends on the encoder.** CRD generation from `#config` uses the structural encoder 0008 chose. If 0008 has not landed the operator vendors the same encoder; either way the encoder's behaviour is one thing, not two.
- **The offered module's `#config` must be structural.** A platform team wanting to offer a module whose `#config` uses templating must first change that module. That is a constraint on module authors, and the CLI pre-flight is how they learn it before binding.
