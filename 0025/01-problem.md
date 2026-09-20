# Problem Statement: Self-Describing Modules

A module can say what each of its workloads is, and nothing about itself as a whole. That every workload in it should be network-isolated, that the set has one budget, that it is meant to be offered to other teams: each is a fact about the module, and none has a place to live. This entry gives a module one named attachment point for what it is.

## Current State

**Everything a module says is per component.** `#Module` carries `#components`, `#config` and metadata. A component attaches resources and traits, and a transformer renders each component on its own. There is no place for a fact about the module as a whole. Labels and annotations on `#Module.metadata` are the only escape hatch, and nothing types, versions or consumes them.

**A component is the only thing a transformer sees.** A component transformer matches a component's labels and attached traits, takes one component context, and runs once per matched pair. Nothing matches a module, so nothing can render one object for the whole of it.

**A catalog can publish words about workloads only.** A `#Trait` declares `appliesTo`, naming the resource kinds it may attach to, and the platform's contract inventory covers what component transformers require. A catalog has no way to publish a word that means something about a module rather than a workload, and therefore no way to be told that nobody implements one.

**Each entry that meets this gap proposes its own field.** Lifecycle placement in entry 0009 and seed values in entry 0016 both reached for a new top-level field on `#Module`. That is how a schema grows a field per feature, each with its own consumer and no matching.

## Gap / Pain

**Gap 1: a module cannot describe itself.** A module author who wants one default-deny NetworkPolicy across the module either writes it per component, where it is a workload concern it is not, or ships none. A module author who wants to say "this is a database offering, here is its kind" has nowhere to say it that a tool reads.

**Gap 2: a module-scoped concern has no renderer.** Even with somewhere to write the fact, nothing would render it. The render path walks components and runs component transformers; a module-wide object has no matched pair to be produced from, so the fact would be documentation rather than a resource.

**Gap 3: what a module says cannot be a contract.** A fact parked in an annotation cannot be required, cannot be versioned, and cannot be reported as unhandled. A platform that does not implement isolation has no way to say so, and a module that wanted isolation and got nothing looks exactly like a module that never asked.

## Concrete Example

A module called `payments` ships three workloads: an API, a queue worker and a nightly backup job. Two facts about the module as a whole have nowhere to live.

The first is that every workload in it talks only to the other two and to one allowed network range. The author can attach a network-policy trait to each of the three components. That is three copies of one decision, and four the day a fourth workload lands. Each copy also says the wrong thing: it says "this workload is isolated", and none of them says "this module is isolated".

The second fact cannot be written even three times. The module has one memory budget for the set, and no workload owns it. There is no component to attach it to, because it is not a property of any workload.

```
  today                                    wanted

  module payments                          module payments
    #components:                             #components:
      api:    [network-policy]  ┐              api, worker, backup
      worker: [network-policy]  ├ copies
      backup: [network-policy]  ┘            #aspects:
                                               isolation: network-isolation
    the module's memory budget:                  allowed ranges read from #config
      nowhere                                  budget:    resource-budget
                                                 one figure for the whole module
    a catalog can publish:
      words about workloads only             rendered: one NetworkPolicy
                                                       one ResourceQuota
```

Three failures on the left. The isolation decision is copied per workload and drifts the first time one copy is edited. The budget cannot be stated at all. And a platform that does not implement isolation cannot say so, because nothing in the module declares a demand for it: the copies are ordinary component traits, and a module that ships none looks exactly like a module that wanted isolation and got nothing.

## User Stories

- As a **module author**, I want to declare module-wide facts once, such as "isolate every workload in this module" and "this module has one memory budget", so that they are typed, versioned and rendered, instead of copied per component or parked in an annotation nothing reads. Today: per-component traits or nothing.
- As a **catalog author**, I want to publish a word that means something about a module rather than a workload, under my own API version and the additive promise, so that a module-wide concern is vocabulary like any other. Today: `#Trait` requires `appliesTo`, so every word I publish is about a workload.
- As a **platform operator**, I want to be told that a module asks for something no transformer I enable implements, before anything renders, so that a missing capability is a diagnostic rather than a quietly absent object. Today: there is no demand to report, because the module could not state one.
- As a **designer of another entry**, I want one place to attach what a module says about itself, so that the next such need does not add a fourth top-level field to `#Module`. Today: lifecycle placement and seed values each proposed their own.

## Why Existing Workarounds Fail

**Copy the trait onto every component.** The closest thing to working, and what authors do today. It drifts the first time one copy is edited, it scales with the component count, and it renders N objects where the concern is one. It also states the wrong scope: nothing in the output says the fact belongs to the module.

**Annotations on the module.** `#Module.metadata.annotations` can carry "isolate me". Nothing types the value, nothing versions the key, and no transformer or reconciler consumes it, so it is documentation with a colon in it.

**A component with only traits.** A component that attaches a trait and no resource could carry a module-wide concern. It would pass the component transformer contract (one workload, one component context) while lying about scope, and every transformer author would have to know it might be looking at one.

**Author the objects beside the module.** The platform team writes the NetworkPolicy and the ResourceQuota by hand, or an external policy engine attaches them by label. The fact then does not travel with the module artifact, is not versioned with it, and cannot read `#config`, so the two drift the first time the module changes shape.

**A module-level pass over the rendered output.** Render the components, then append to or mutate the result. That is a second build after the first, which is what the single build and its parity oracle exist to prevent (0019:D9).

**A new top-level field on `#Module` per concern.** What the entries meeting this gap have each proposed. Every field arrives with its own consumer, its own versioning story and no matching, so nothing can report a field nobody implements.
