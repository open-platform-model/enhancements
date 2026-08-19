# Problem Statement — Kernel render path parity with pure CUE

This document answers the question: "Why does this enhancement need to exist?"

## Current State

OPM's rendering contract is stated in `core/src/transformer.cue`. A transformer declares a `#transform` block with three inputs, and the comment above them states who fills them:

```
// Transform function. The runtime supplies all three inputs concretely (D18).
#transform: {
    #moduleInstance: _
    #component:      _
    #context:        #TransformerContext

    output: {...} | [...{...}]
}
```

The kernel executes this contract in Go. `compileModuleInstance` (`library/opm/kernel/compile.go`) takes the instance's components and produces **two** values from them: `schemaComponents`, which is the evaluated value untouched, and `dataComponents`, which is the result of `compile.FinalizeValue`. Match consumes the first. `executePair` (`library/opm/compile/execute.go`) consumes both, filling `#component` from the finalized value and building `#context` in Go from the unfinalized one.

```
    inst.MatchComponents()
             |
      +------+---------------------------+
      |                                  |
      | (untouched)              FinalizeValue()
      |                          Syntax(cue.Final()) -> BuildExpr
      v                                  v
  schemaComponents                  dataComponents
      |                                  |
      +--> Match          reads #resources, #traits
      +--> #context       decoded in Go, re-encoded
                                         |
                                         +--> #component   <-- what a transformer sees
```

`FinalizeValue` reaches for `cue.Final()`, which is not one switch but four: it resolves defaults, drops unset optional fields, drops hidden fields, and **drops every definition field**. The fourth is why `#component.#names`, `#component.#resources`, `#component.#traits` and `#component.#instance` do not exist inside any `#transform`.

`#moduleInstance` is not filled at all. It has no path constant in `library/opm/schema/paths.go`, no fill site, and no test in either direction.

## Gap / Pain

**The kernel does not behave like CUE.** A plain CUE wrapper that unified the same three values would hand the transformer everything. The kernel hands it a subset, and the subset is not documented as a contract anywhere; it is a side effect of a tool chosen to do something else.

The consequences are already being paid, in three places:

**Core computes an identity nothing can read.** `#Component.#names` is documented in `core/SPEC.md` as "the single source of truth for this component's identity", and the render path structurally cannot see it. All 35 transformers in `catalog_opm` rebuild the object name by hand from `#context`, in six different formulas, tracked as open-platform-model/core#49 and open-platform-model/catalog_opm#44. Those two issues work around this one by moving a computed value into a regular field, which fixes one value and leaves the next projection to hit the same wall.

**A declared slot is a trap.** A transformer that reads `#moduleInstance` passes `cue vet` at authoring time, publishes clean, and fails at render with `#transform.output: 2 errors in empty disjunction`, a message that names neither the slot nor the reason. Tracked as open-platform-model/library#65.

**The divergence is unmeasurable.** Nothing in the repository compares kernel output against what CUE would produce, so the gap can only be found by someone noticing it. It was found this way: the strip has been in place since the code arrived in `library` in May 2026, carried across from a `cli` experiment, and its justifying comment was never re-tested until August.

## Concrete Example

A pure-CUE harness (`library/docs/design/repro-purecue-definitions/`) builds a real `#Module`, a real `#ModuleInstance`, and a real `#ComponentTransformer` in a separate package reached by import. The render step is written as one unification, which is exactly what a wrapper around CUE would do:

```
applied: cat.#TestTransformer.#transform & {
	#moduleInstance: _inst
	#component:      _inst.components.web
	#context: { ... }
}
result: applied.output
```

Pinned to `cue v0.17.1`, the same version `library/go.mod` pins for the SDK. It evaluates to:

```
kind:  "Deployment"
image: "nginx"                                            # regular field
rName: "web"                                              # #component.#names.resourceName
fqdn:  "web.prod.svc.cluster.local"                       # #component.#names.dns.fqdn
resources: ["scratch.example/cat/resources/container@v1"] # #component.#resources
ns:       "prod"                                          # #component.#instance.namespace
instName: "web-inst"                                      # #moduleInstance.metadata.name
instFQN:  "scratch.example/modules/web_app:web-inst:prod" # #moduleInstance.metadata.fqn
```

`cue vet -c ./...` exits 0. Every field the kernel removes is present, concrete and correct. The same transformer, run through the kernel, cannot see six of those eight fields.

## The premise that justified the strip does not hold

The behaviour originates in a `cli` experiment from March 2026 whose design document records the reason in a table row:

> Execute uses DataComponents, because `FillPath` on `#component` fails with schema constraints present.

The component in the control **does** carry those constraints. Its `spec` is genuinely closed, verified by unifying an unknown field into the value the transformer receives:

```
_probe.spec.bogus: field not allowed
```

It renders anyway, fully concrete. Whatever that sentence described in March was a property of how the Go API was being driven at the time, not a property of the CUE language. The function's own doc comment states the intent plainly (it exists to remove "matchN validators, close() enforcement"), and definition-stripping rode along in the same bundle.

Three later changes removed the conditions that motivated it, and none of them prompted a re-examination: materialize federation (ADR-003) removed the closed-value fill that was corrupting transformers, single-build synth removed the closed-into-closed composition on the instance side, and core settled `#component: _` as explicitly unconstrained.

## User Stories

- As a **catalog author**, I want to render an object name from the component's own computed identity so that a rename propagates from one place. Today: `#component.#names` does not exist inside `#transform`, so I interpolate the name by hand and my formula silently disagrees with the five other transformers that did the same.
- As a **catalog author**, I want to read instance data from the slot the schema declares for it. Today: the slot exists, my catalog vets and publishes, and the render fails on a consumer's cluster with an error about a disjunction.
- As a **kernel contributor**, I want a mechanical answer to "does the kernel still behave like CUE". Today: there is no oracle, so the question is answered by reading the render path and reasoning about `cue.Final()`.

## Why Existing Workarounds Fail

The workarounds in flight are correct locally and do not address the class.

`core#49` moves the resolved name onto the component as a regular field, specifically because regular fields survive finalization, and states "No `library` change is required". That is true and it fixes the name. It does not make the next schema-computed projection readable, and it encodes the strip as a constraint that core has to design around rather than a defect the kernel should stop causing.

`catalog_opm#44` sweeps 35 transformers onto that single field. Also correct, also silent about why the field had to be a regular one.

The general form of the workaround is: for every value the schema computes and the render path needs, add a parallel regular field. That is a permanent tax proportional to how much OPM computes in CUE, which is the thing OPM is built to do.
