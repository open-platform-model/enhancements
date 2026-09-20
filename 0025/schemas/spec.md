# Specification changes: Self-Describing Modules

<!--
This document pre-drafts the core/SPEC.md co-update that the core slice
will need at implementation time (the `core-schema-edit` skill gates that
co-update via pre-commit hook + CI). It is required, with examples.cue,
from the draft → accepted gate.

-->

## #Aspect (NEW)

### Definition

A named, module-scoped bundle of module traits: `#Component` transposed to the module. Where a component says what a workload is, an aspect says something about the module as a whole: that it is network-isolated, that it has a budget, that it is offered as a kind. It lives in `#Module.#aspects`, keyed the way `#components` is keyed, and it is what a `#ModuleTransformer` matches and renders.

### Shape

```
#Aspect: {
    kind: "Aspect"
    metadata: {name!, resourceName, labels?, annotations?}
    #traits:     [#ContractFQNType]: #ModuleTrait   // at least one
    matchLabels: <derived from #traits>
    #instance:   #InstanceIdentity                  // injected by #Module
    #names:      {resourceName}                     // no DNS variants
    spec:        close({<the attached traits' specs>})
}

#Module: #aspects?: [Id=#NameType]: #Aspect & {
    metadata: {name: string | *Id, labels: "aspect.opmodel.dev/name": name}
    #instance: #ctx.instance
}
```

### Constraints

- An aspect MUST attach at least one module trait; an aspect with none is refused.
- `matchLabels` MUST be exactly the wholesale unification of the attached traits' `matchLabels`; an aspect that contributes a key of its own is refused, the rule `#Component` already holds.
- `spec` MUST be closed over the attached traits' specs, and the module author MUST make it concrete; a key no attached trait declares is refused.
- `metadata.resourceName` MUST default to the instance-qualified name and, when authored, MUST be a DNS subdomain; `#names` carries `resourceName` and nothing else.
- An aspect MUST NOT carry resources, blueprints or a name constraint; those are workload concepts.
- `#instance` MUST be injected by `#Module` from `#ctx.instance` and MUST NOT be authored.

### Rationale

- **Why a named map and not a flat field.** Two aspects of one kind with different specs (an edge and an internal isolation policy) each need a name and render their own object; a flat trait map on the module cannot hold both.
- **Why not a trait-only component.** It would satisfy the component transformer contract while lying about scope; an aspect is honest that its transformer sees the module.
- **Why no resources.** A resource is a workload demand the platform must satisfy (0010 D28); an aspect describes, it does not demand a workload.
- **Why the spec is authored inside the module.** It then sees `#config` and `#ctx.components` lexically, which is what lets a module-scoped policy read values and every component's computed names.

## #ModuleTrait (NEW)

### Definition

A catalog-published trait a module attaches to itself through an aspect. It is `#Trait`'s sibling, not a mode of it: the identity block, `matchLabels`, `fulfilment`, `optional` and `spec` are the same, so the catalog gates that hold traits hold module traits unchanged, and the two things a component trait has that a module has no use for are absent.

### Shape

```
#ModuleTrait: {
    kind: "ModuleTrait"
    metadata: {name!, modulePath!, apiVersion!, catalogVersion!, fqn!, description?, labels?, annotations?}
    matchLabels?: #LabelsAnnotationsType
    fulfilment:   *"catalog" | "provider"    // OQ13 for declaration-only traits
    optional:     bool                       // stated by the catalog as a default, never pinned
    spec!:        (<camelCase of name>): _
}
```

### Constraints

- A module trait MUST carry the same identity block as `#Trait` and MUST pass `#CatalogMemberFQNGate` and `#TraitOptionalGate` at publish.
- A module trait MUST NOT carry `appliesTo` or a name constraint.
- The declaring catalog MUST state `optional` as a default; an attachment site MAY narrow it; a pinned value is refused.
- `matchLabels` MUST NOT be rendered; it reaches the aspect's `matchLabels` and nothing else.

### Rationale

- **Why a sibling and not a `scope` field on `#Trait`.** `appliesTo!` and `#nameConstraint` would become conditional on a mode flag, and every consumer of `#Trait` would have to check it. Two definitions with one shared block is the same choice `#ComponentTransformer` made.
- **Why catalog-published.** Vocabulary belongs in catalogs and shapes in core (0010); a module trait is versioned, keyed by its own API version and under the additive promise, which an annotation never is.

## #ModuleTransformer (NEW)

### Definition

What renders an aspect: `#ComponentTransformer` transposed. It matches on an aspect's `matchLabels` and its attached module traits, takes the concrete module instance and one aspect, and produces rendered resources. Whole-module facts reach it through the instance's module; it has no view of rendered component output.

### Shape

```
#ModuleTransformer: {
    kind: "ModuleTransformer"
    metadata: {modulePath!, name!, catalogVersion!, fqn!: #ImplFQNType, description!, labels?, annotations?}
    requiredLabels?, optionalLabels?: #LabelsAnnotationsType
    requiredTraits?, optionalTraits?: [#ContractFQNType]: #ModuleTrait
    producesKinds?: [...string]
    #transform: {
        #moduleInstance: _
        #aspect:         _
        #context: {#moduleInstanceMetadata, #aspectMetadata, labels}
        output: {...} | [...{...}]
    }
}
```

### Constraints

- A module transformer MUST match on labels and module traits only; it has no resource buckets.
- `#transform` MUST take the module instance and one aspect, and MUST execute once per matched (aspect, transformer) pair, the `#ComponentTransformer` rule transposed (0019 D2).
- `output` MUST be rendered resources; a module transformer MUST NOT produce a plan or any non-resource output.
- A module transformer MUST NOT read rendered component output; the render is one build (0019 D9), and aspects join it rather than post-process it.
- `#context` MUST carry the instance identity and the aspect's identity, and MUST NOT carry a component's.

### Rationale

- **Why symmetric with the component transformer.** One matching discipline, one contract inventory, one parity oracle; a second shape would need every 0019 guarantee restated.
- **Why resources only.** The one other interpreter of a `#Module`, the execution half 0009 designs, reads the same aspects for lifecycle and workflows; giving the render-side transformer a second output type would make it a third interpreter.

## #Module (CHANGED: `#aspects`)

`#Module` gains one optional map, `#aspects`, with the pattern constraint shown under `#Aspect`. Nothing else on `#Module` changes: `#components`, `#config`, `debugValues` and the label stamps are as before. `#ctx` is open and MAY later project aspects beside components (OQ14). The addition is additive: a module that declares no aspect observes nothing.

## #Catalog, #Platform (CHANGED: module transformers)

`#Catalog` carries `#moduleTransformers` beside `#transformers`, stamped the same way. `#Platform` folds enabled catalogs' module transformers as it folds component transformers, and its contract inventory covers module traits and the module transformers that require them, so an unhandled aspect demand is reported or refused by `optional` and `fulfilment` exactly as an unhandled component demand is (0015 D18). A catalog that publishes no module transformer observes nothing.

## #ModuleInstance (UNCHANGED)

`#ModuleInstance` is unchanged. Its `#ctx.instance` wiring already reaches every aspect through `#Module`, which is what gives an aspect's `resourceName` its instance qualification.
