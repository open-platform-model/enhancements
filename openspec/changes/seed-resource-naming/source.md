# Source note: seed-resource-naming

This is a seed. It records behaviour the repos ship today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `resource-naming`. Full seed (13 requirements, 37 scenarios). Written 2026-10-11 from `core` at commit `f3b7ecd` and `catalog_opm` at commit `816baef`. The map row (`explore/T4.1b.md` row 18) counted 6 requirements, one per requirement of the two `core` specs. The count here is higher because the catalog side has no spec and the 500-character limit splits two long ones.

## Sources

All read at the commits named. The requirement text is rewritten at intent level: no file path, no Go symbol, no CUE field path. It names published CUE definitions (`#NameType`, `#ObjectNameType`, `#ServiceNameType`, and the slot `#nameConstraint` that catalog authors write) and Kubernetes kinds.

| Requirement here | Source requirement | Code read |
| --- | --- | --- |
| A resource name defaults to the instance-qualified name | `core` `openspec/specs/component-names`, "The resource name defaults to the instance-qualified name" (default, authored wins, equal to default) | `core` `src/component.cue:29` (the default arm) |
| An authored resource name is a DNS subdomain | same requirement (dotted name, invalid name, one message, no default arm shown) | `core` `src/component.cue:29` (`#ObjectNameType` arm and the `error()` arm); `src/pins/component_names_pins.cue`, the must-fail cases `_failNameBad` and `_failNameOverlongOverride` |
| DNS variants follow the resource name | same spec, "DNS variants follow the resource name" | `core` `src/component.cue:200-206` |
| A module context carries each component's names | the Purpose of `component-names` ("`#Module.#ctx.components` is a projection of it"); no requirement states it | `core` `src/module_context.cue:25-36`, `src/module.cue:142`; pin `_pinNameProjection` |
| The default cannot overflow the ceiling | same spec, "The default cannot overflow the ceiling" | `core` `src/component.cue:29`; pins `_pinNameLongDefault`, `_pinNameMaxDefault` |
| Three name types mirror the server's validators | `core` `openspec/specs/name-constraints`, "Three name types mirror the server's validators" | `core` `src/types.cue:13, 28, 37`; `src/INDEX.md:72-74` |
| A primitive declares its name constraint | same spec, "A primitive declares its name constraint on a hidden slot" | `core` `src/resource.cue:126`, `src/trait.cue:78`, `src/blueprint.cue:95`; `src/component.cue:160-170` (the collection has no existence guard) |
| A component's resolved name meets every attached constraint | same spec, "The component asserts the resolved name against every attached constraint" | `core` `src/component.cue:160-186` (`_nameConstraints`, `_nameFits`); the pins file, the must-fail cases and `_pinNameComposed` |
| A computed constraint binds on every path | none in a spec. 0019 D24 is in an archived entry; the catalog note "A computed constraint must resolve on every attachment path" states the rule and the measurement | `catalog_opm` `docs/name-constraints.md`; `src/resources/v1beta1/container.cue:38-72` (the wrapper computes it from the component's derived matching labels), `src/blueprints/v1beta1/stateful_workload.cue:45` |
| The primitive that owns the reason declares it | none in a spec. `catalog_opm/docs/name-constraints.md`, "The rule: the primitive that owns the reason declares the constraint" (table of five rows) | `catalog_opm` `src/traits/v1beta1/expose.cue:34`, `stateful_workload.cue:45`, `container.cue:66`, `src/resources/v1alpha1/namespace.cue:30` and the wrapper assertion at `:53`; the objects resource declares none (`git grep nameConstraint` finds no hit in it) |
| The Service name defaults to the short name | none in a spec. The same note and 0019 D22 | `catalog_opm` `src/traits/v1beta1/expose.cue:43-53, 57-91` (the wrapper default and `name!: c.#ServiceNameType`) |
| A primary object carries the resource name | none in a spec. The same note, "Transformers read names, never derive them" (0019 D15) | `catalog_opm` `src/transformers/deployment_transformer.cue:147` and eleven more transformers read `#component.#names.resourceName`; the `exact` comments (a dash and the contract named) in `namespace_transformer.cue:51`, `crd_transformer.cue:58`, `sa_helpers.cue:27`, `objects_transformer.cue:10` |
| A Service reference follows the Service name | none in a spec. The same note, carve-out 3 | `catalog_opm` `src/transformers/name_helpers.cue` (`#ServiceName`), `statefulset_transformer.cue:153-156`, `http_route_transformer.cue:36-48` and the three other route transformers |

## Where the code and the sources differ

- The matching key of the workload type is spelled `workload-type` in the catalog note and `opm.opmodel.dev/workload-type` in the core pins. The catalog code says `core.opmodel.dev/workload-type` (`container.cue:66-67`, `stateful_workload.cue:37`). The code wins. The requirement text names no key spelling; it says "workload-type key".
- The core spec's second requirement of `name-constraints` says the check is on "a hidden field". The code names it `_nameFits`. The text says "SHALL check", not where.
- Scenarios with no sentence in a repo spec or in the catalog note, written from the code only. The sample should look at them: "A name over 253 runes is refused" (the `error()` arm in `component.cue:29`; the pins record the message), "A blueprint answers the key" (the blueprint declares `#NameType` itself, `stateful_workload.cue:45`), "A namespace name" (`namespace.cue`, assertion `_namespaceNamesFit`), "A raw object resource", "The trait without the wrapper" (`name!` is required; a stand-alone CUE probe with `cue vet` v0.17.1 refuses a missing required field), "A governing service", "A route to a renamed Service".
- "The trait without the wrapper": the code comment in `expose.cue:72-73` says the Service "can never render unnamed". I checked the `name!` required field with a probe, not the catalog fixtures.

## Left out

- Behaviour a live entry owns: none found. Entries 0024, 0025, 0013, 0017 and 0027 name no resource-naming rule in their converted text (a search of their branches for `resourceName`, `nameConstraint`, `#names` and the name types gives no hit outside `evidence/`). 0025 states that a module trait carries no name constraint; that is its own rule for a new kind and stays with it.
- Render-side rules. `seed-single-build-render` holds the render path. This seed states what a transformer reads and what name an object carries, not how the render finds or refuses a transformer. The requirement "A Service reference follows the Service name" says a route transformer requires the expose trait; the render's refusal of an unmatched demand stays in the render seed.
- The label-value rule of 0019 D19 (no transformer copies the resource name into a label value). The note says it is "enforced in review, not by the evaluator"; no code or spec states it.
- The legacy-shape fallback of `#ServiceName` for components built against an older catalog. It is the compatibility rule of 0010 D27, not naming.
- The deleted `#ResourceNameTrait` and `#WorkloadName` (0019 D15): removed behaviour.
- Secondary and multi-object names (ConfigMap and Secret content-hashed names, per-volume claims): the note says they "stay derived". They are carved out in the text as "objects rendered several to a component" and not stated one by one.
- The per-component cost of the constraint walk (0.15 to 0.22 ms): a measurement, not behaviour.
- Fixtures for a wrapper default (`#instance` set by hand, the interpolation guard): a test method.
- Library-internal placement rules: none touch this capability.

## Overlap with other seeds

I read the specs of every seed on a branch `refactoring-enhancements/p4-seed-*` that has a `spec.md`. None states a naming rule. `single-build-render` mentions that returned objects name their instance, component and transformer (provenance); that is not an object name. `component-matching` holds the matching labels this seed reads (the workload-type key) and `contract-fulfilment` the trait optionality that the expose trait sets; this seed names neither rule. `instance-identity` holds the instance name and FQN; this seed uses the instance name as an input only.
