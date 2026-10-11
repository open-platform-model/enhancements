# 0025: Self-Describing Modules

A module today describes its workloads and nothing about itself. This entry gives a module one place to say what it is. It ships that extension point and no vocabulary.

## Why

Everything a module says is per component. A fact about the whole module, such as one network policy for all its workloads, has no component to attach to, and no transformer matches a module. Authors copy a trait onto every component, or write an annotation that nothing types, versions or reads. Each entry that meets the gap proposes its own top-level field on the module.

## What Changes

- A module gains a named map of aspects. Each aspect attaches module traits from a catalog and fills a closed spec.
- A catalog publishes module traits and module transformers beside its component ones.
- A module transformer renders an aspect into resources, in the same build, once per matched pair.
- The platform's contract inventory covers aspects, so a demand nobody handles is reported before anything renders.
- No catalog publishes a module trait here.

## What this is not

- Not a way to offer a module as a kind. That is enhancement 0027.
- Not a second build. Nothing post-processes rendered output.
- Not an aspect on a module instance. What an instance does belongs to enhancement 0009.
- Not a vocabulary. Network isolation and a resource budget are examples only.

## Example

```cue
// in a payments module, beside its components
#aspects: isolation: {
	#traits: (networkIsolation.metadata.fqn): networkIsolation // a module trait from some catalog
	spec: networkIsolation: allowedCIDRs: #config.allowedCIDRs
}
```

A module transformer renders one network policy for the instance. A platform that enables no transformer for this trait reports it before any render.

## Capabilities

- **New:** `module-aspects`, `module-traits`, `module-transformers`, `aspect-demand`
- **Modified:** `platform-contract-inventory`

## Impact

- **core** gains three definitions, an optional `#aspects` map on `#Module`, and module transformers on `#Catalog` and `#Platform`.
- **library** gains one matching pass, and the inventory covers module traits.
- Catalogs and modules change nothing. A module with no aspect observes nothing, so the entry is not breaking.

## Open questions

- Blocking: How does a module trait that no transformer handles state its fulfilment? The inventory reads `fulfilment`. The offering declaration of entry 0027 and the lifecycle trait of entry 0009 are read by the CLI, a reconciler and the execution half, never by a transformer. The value `"catalog"` claims the catalog implements the trait, which is false. The value `"provider"` demands exactly one platform transformer, which is worse. The options are a third value that names a non-render consumer, or reusing `"catalog"` with a rule that the inventory skips a trait no module transformer in the same catalog requires. The first is honest and adds a value to a vocabulary that enhancement 0010 fixed. The second reuses what exists and leaves the falsehood in the field. It settles when entries 0027 and 0009 are accepted against one of them.
- Not blocking: Does `#ctx` gain an `aspects` projection beside `components`? A component spec uses `#ctx.components` to read another component's computed names. No fixture trait needs an aspect's name from elsewhere in the module, and `#ctx` is open, so it can be added later without breaking a module body. It settles when a trait needs it.
- Not blocking: Does `#ModuleInstance` get an aspect slot of its own? Suspend, pause or a maintenance window may be an attachment on the instance rather than the module. The candidate answer is no: aspects describe the module, and what an instance does is entry 0009's, attached at the instance's transitions. It settles when entry 0009 is accepted.
