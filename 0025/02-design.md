# Design: Self-Describing Modules

A module gains one named attachment point for what it is as a whole: aspects, bundles of catalog-published module traits that module transformers render through the existing matching path. An aspect is a sibling of a component, not a special case of one, and everything true of a component's matching is true of an aspect's.

## Design Goals

- **A module may state facts about itself as a whole.** `#Module` gains one named attachment map for module-scoped, catalog-published traits, so the next such need is a word in a catalog rather than a field in core.
- **Module-scoped concerns render through the machinery components use.** An aspect is matched and rendered by the same discipline as a component: derived matching labels, a catalog-published transformer, the platform's contract inventory. Nothing about the render learns a new concept; it learns a second unit.
- **The vocabulary is the catalog's, not core's.** Core defines what a module trait is; which module traits exist, and what they mean, is a catalog's decision under its own API versions.
- **An unhandled demand is never silent.** What a module asks for is visible to the platform's contract inventory before anything renders, exactly as a component's demand is.

## Non-Goals

- **A third interpreter of a module.** The render half renders aspects; the execution half 0009 designs reads them for operational intent. Neither this entry nor a successor adds a third.
- **A vocabulary.** This entry publishes no module trait and no module transformer in any catalog (D15). The traits it shows are examples and fixtures.
- **Binding a module as something consumers instantiate.** Offering a module as a kind is entry 0027, which rests on this one.
- **Aspects on a `#ModuleInstance`.** What an instance does is entry 0009's, attached at the instance's transitions (OQ15).
- **A second build.** An aspect joins the one render build; nothing post-processes rendered output (0019:D9).

## High-Level Approach

One layer, on the module. An aspect is a named bundle of module traits, matched and rendered by the discipline components already use.

```
  a module                              a catalog (any catalog, none ships here)

  module payments                         module traits:       network-isolation, resource-budget
    #components: {api, worker, backup}    module transformers: network-policy, resource-quota
    #aspects:
      isolation: network-isolation  --------> matched, rendered: one NetworkPolicy for the module
      budget:    resource-budget    --------> matched, rendered: one ResourceQuota for the module
      owner:     ownership          ----> no transformer matches it: a statement other tools read
```

**Aspects (D11 to D15).** A module carries named aspects beside its components. Each attaches one or more module traits published by a catalog, derives its matching labels from them, and exposes a closed spec the author fills, reading `#config` and the components' computed names as any component spec does. A module transformer matches an aspect the way a component transformer matches a component and renders resources into the same output; the platform's contract inventory covers both, so an aspect nobody handles is reported, never silently dropped. An aspect that no transformer renders is legitimate: it is a statement other tools read, and entry 0027's offering declaration is the first of those.

## Schema / API Surface

Full shapes in [`schemas/target.cue`](schemas/target.cue).

- **`#Aspect`**: a named bundle of module traits on `#Module.#aspects`: `resourceName` cascade, derived `matchLabels`, injected instance identity, closed `spec`. At least one trait; no resources, no DNS names.
- **`#ModuleTrait`**: `#Trait`'s sibling: same identity block, `matchLabels`, `fulfilment`, `optional`, `spec`; no `appliesTo`, no name constraint. How a trait consumed outside the render path states its `fulfilment` is OQ13.
- **`#ModuleTransformer`**: `#ComponentTransformer`'s sibling: label and module-trait matching buckets, a transform over the module instance and one aspect, resources out.
- **`#Module`**: gains `#aspects`; `#ctx` may later project them (OQ14). **`#Catalog`** gains module transformers beside component transformers; **`#Platform`** folds both. **`#ModuleInstance`**: unchanged.

## Affected Surfaces

**core.** Three new definitions: `#Aspect`, `#ModuleTrait` and `#ModuleTransformer`. `#Module` gains `#aspects`; `#Catalog` and `#Platform` carry and fold module transformers; `#ModuleInstance` does not change. SPEC.md gains the constructs; a `core-schema-edit` co-update.

**library.** The kernel gains one matching pass keyed on aspects and executes module transformers per matched pair into the same output set, under the single-build rule (0019:D9) and once-per-pair execution (0019:D2) that component matching already keeps. The contract inventory covers module traits, so an unhandled aspect demand is reported the way an unhandled component demand is (0015:D18). Kernel neutrality holds: the pass is matching and execution over CUE, with no new runtime surface.

**catalogs and modules.** Nothing, under this entry. No catalog publishes a module trait or a module transformer here (D15), and no module attaches an aspect until one exists to attach.

## Before / After

**Isolating a module.** Before: a NetworkPolicy trait on each of the module's components, or none, because the concern belongs to no single workload. After: one `isolation` aspect on the module, its allowed CIDRs read from `#config`, rendered as one NetworkPolicy selecting every workload of the instance.

**Budgeting a module.** Before: no field, no component, nowhere. The figure lives in a wiki page or in the platform team's head. After: one `budget` aspect on the module, its figure read from `#config`, rendered as one ResourceQuota for the instance.

**A capability nobody implements.** Before: silence. A module either ships the per-component copies or ships nothing, and no tool can tell the difference. After: the aspect carries a required module trait, and a platform whose enabled transformers do not handle it reports the demand before any render.

**Adding the next module-wide concern.** Before: a new top-level field on `#Module`, one per entry that needs one. After: a word published in a catalog under its own API version, attached on an aspect, with no core change at all.
