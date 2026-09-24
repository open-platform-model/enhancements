# Problem Statement: Self-Describing Modules

A module today describes its workloads and nothing about itself. It is limiting, not allowing a module to describe something else. For example, instead of the module being installed, it could declare an input schema and a way to transform that input into a new output (Abstraction). This entry gives a module one place to say what it is.

## Current State

**Everything a module says is per component.** `#Module` carries `#components`, `#config` and metadata. A component attaches resources and traits, and a transformer renders each component on its own. There is no place for a fact about the module as a whole. Labels and annotations on `#Module.metadata` SHOULD be treated as an escape hatch, and nothing types, versions or consumes them.

**A component is the only thing a transformer sees.** A component transformer matches a component's labels and attached traits, takes one component context, and runs once per matched pair. Nothing matches a module, so nothing can render one object for the whole of it.

**A catalog can publish words about workloads only.** A `#Trait` declares `appliesTo`, naming the resource kinds it may attach to, and the platform's contract inventory covers what component transformers require. A catalog has no way to publish a word that means something about a module rather than a workload, and therefore no way to be told that nobody implements one.

**Each entry that meets this gap proposes its own field.** Lifecycle placement in entry 0009 and seed values in entry 0016 both reached for a new top-level field on `#Module`. That is how a schema grows a field per feature, each with its own consumer and no matching.

## Gap / Pain

**Gap 1: a module cannot describe itself.** A module author who wants to say "I am not something you deploy, I am something other teams ask for" has nowhere to say it that any tool reads. A module author who wants one default-deny network policy across the module either writes it per component, where it is a workload concern it is not, or ships none.

**Gap 2: a module-scoped concern has no renderer.** Even with somewhere to write the fact, nothing would render it. The render path walks components and runs component transformers; a module-wide object has no matched pair to be produced from, so the fact would be documentation rather than a resource.

**Gap 3: what a module says cannot be a contract.** A fact parked in an annotation cannot be required, cannot be versioned, and cannot be reported as unhandled. A platform that cannot do what a module asks for has no way to say so, and a module whose request went unanswered looks exactly like a module that never asked.

## Concrete Example

A team writes a module for a Postgres cluster: three components, and a configuration schema taking a size, a version and a replica count. OPM can do exactly one thing with that module. Somebody writes an instance of it, and the components become an application running in a namespace.

The team wants something else. They want the module to be the definition of a thing other teams can ask for. Its configuration schema is the API those teams fill in, its components are what gets built each time one of them asks, and no copy of it runs until somebody does. The module is not an application. It is the description of one.

Nothing in the module can say so. It carries components, a configuration schema and metadata, and every one of those describes the workloads. There is no typed place for a fact about the module as a whole, so there is nowhere to write "I am not something you deploy, I am something you offer". The runtime therefore treats every module the same way, because being deployed is the only thing a module has ever meant.

```
  today                                  wanted

  module: a Postgres cluster             module: a Postgres cluster
    components: 3                          components: 3
    config schema: size, version           config schema: size, version

    the only thing it can be:              a fact about the module itself:
      deployed, once, as an app              "I am something teams ask for,
                                              not something you deploy"

  the team's actual intent:              the runtime reads the fact and
    lives in a README                      serves the config schema as an API
                                           builds the components per request
```

Three failures on the left. The intent has nowhere to live, so it lives in a README or in the head of whoever wrote the module. The runtime cannot be told, so it cannot act on it, and the team's only way forward is to build a bespoke controller beside the module and hand-write an API that drifts from the configuration schema it is supposed to mirror. And a platform that cannot do what the module asks for has no way to say so: the module looks exactly like any other module, so it is deployed as an application, which is not a missing feature but a wrong answer.

The same module has a second kind of fact with the same problem, and it is the kind that must become an object rather than be read: every workload in the module should share one network policy, and the module has one memory budget for the set. Neither is a property of any single workload, so neither has a component to attach it to.

## User Stories

- As a **module author**, I want to declare facts about the module as a whole, such as "this is something other teams ask for, not something you deploy" and "isolate every workload in this module", so that they are typed, versioned, and read or rendered by whatever consumes them. Today: a README, an annotation nothing reads, or a trait copied onto every component.
- As a **catalog author**, I want to publish a word that means something about a module rather than a workload, under my own API version and the additive promise, so that a module-wide concern is vocabulary like any other. Today: `#Trait` requires `appliesTo`, so every word I publish is about a workload.
- As a **platform operator**, I want to be told that a module asks for something no transformer I enable implements, before anything renders, so that a missing capability is a diagnostic rather than a quietly absent object. Today: there is no demand to report, because the module could not state one.
- As a **designer of another entry**, I want one place to attach what a module says about itself, so that the next such need does not add a fourth top-level field to `#Module`. Today: lifecycle placement and seed values each proposed their own.

## Why Existing Workarounds Fail

**Build a bespoke controller beside the module.** The way a team gets a module treated as anything other than an application today. It works, and it costs a controller to write and operate, plus an API written by hand that drifts from the module's configuration schema the first time either changes. The module still says nothing about itself; the knowledge lives in a second codebase.

**Copy the trait onto every component.** The closest thing to working, and what authors do today. It drifts the first time one copy is edited, it scales with the component count, and it renders N objects where the concern is one. It also states the wrong scope: nothing in the output says the fact belongs to the module.

**Annotations on the module.** `#Module.metadata.annotations` can carry "offer me, do not deploy me" or "isolate me". Nothing types the value, nothing versions the key, and no transformer or reconciler consumes it, so it is documentation with a colon in it.

**A component with only traits.** A component that attaches a trait and no resource could carry a module-wide concern. It would pass the component transformer contract (one workload, one component context) while lying about scope, and every transformer author would have to know it might be looking at one.

**Author the objects beside the module.** The platform team writes the NetworkPolicy and the ResourceQuota by hand, or an external policy engine attaches them by label. The fact then does not travel with the module artifact, is not versioned with it, and cannot read `#config`, so the two drift the first time the module changes shape.

**A module-level pass over the rendered output.** Render the components, then append to or mutate the result. That is a second build after the first, which is what the single build and its parity oracle exist to prevent (0019:D9).

**A new top-level field on `#Module` per concern.** What the entries meeting this gap have each proposed. Every field arrives with its own consumer, its own versioning story and no matching, so nothing can report a field nobody implements.
