# Experiment 00: purecue-definitions

Status: Concluded

The pure-CUE control this entry opened on. Relocated 2026-08-20 from `library/docs/design/repro-purecue-definitions/` (its citations in `config.yaml.history` name the old path, which was true when written); content unchanged apart from this header and section names.

## Hypothesis

**Question.** OPM is meant to stay backwards compatible with CUE: rendering a component with a
transformer should behave the way a plain CUE wrapper around CUE behaves. Does it?

**Answer: no.** In pure CUE, unifying a `#ModuleInstance`'s component into a transformer's
`#transform` preserves **every** field, definitions included, and evaluates fully concrete. The Go
kernel removes the definition fields before the transformer sees them. The divergence is entirely
the kernel's; CUE does exactly what OPM wants.

This harness is the control that establishes CUE's own behaviour as the reference the render path
should match. Its library-side companions were `repro-hidden-field/` (which proved the earlier
corruption was in Go, not CUE) and `repro-cue-closedness/` (the upstream evaluator reproducer,
surviving as `library/opm/internal/cueregression/`).

## Setup

| File | Role |
| --- | --- |
| `artifacts.cue` | A real `#Module` and a real `#ModuleInstance` built on `opmodel.dev/core@v2`. |
| `cat/transformer.cue` | A `#ComponentTransformer` in a **separate package**, reached by import, mirroring how a catalog transformer actually arrives. Its `output` reads definition fields. |
| `glue.cue` | The whole render step, in CUE: one unification. No Go, no finalization, no kernel. |

The glue is the entire point. It is what a plain CUE wrapper writes:

```cue
applied: cat.#TestTransformer.#transform & {
	#moduleInstance: _inst
	#component:      _inst.components.web
	#context: { ... }
}
result: applied.output
```

## Run

```bash
export CUE_REGISTRY='opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'
cue eval -e result .   # renders
cue vet -c ./...       # fully concrete, exit 0
```

Pinned to `cue v0.17.1`, the same version `library/go.mod` pins for the SDK, so the toolchain is
controlled for.

## Outcome

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

`cue vet -c ./...` exits 0. Every definition field the kernel strips is readable, concrete, and
correct here.

### Three findings this control establishes

#### 1. The March 2026 premise does not hold in CUE

The render path finalizes components before filling them because of a claim recorded in the
`experiments/factory` design doc that became this kernel:

> Execute uses DataComponents, because `FillPath` on `#component` fails with schema constraints
> present.

The component this control hands the transformer **does** carry those constraints. Its `spec` is
genuinely closed, verified by unifying a bogus field into the received value:

```
_probe.spec.bogus: field not allowed
```

It renders anyway, fully concrete. Whatever that claim described in March, it is not a property of
the CUE language. `cue.Final()` was reached for to strip constraints; `omitDefinitions` is one of
the four switches it flips, and dropping definitions was collateral rather than intent.

#### 2. A transformer must DECLARE a slot to reference it

The first run of this harness failed:

```
#TestTransformer.#transform.output.instName: reference "#moduleInstance" not found
```

even though `core.#ComponentTransformer` declares `#moduleInstance` and the transformer unifies
with it. CUE resolves references **lexically**, against the source where the reference is written,
not against the unified result. A field that arrives only by unification with an imported
definition is not in lexical scope.

This is why every real catalog transformer re-declares `#component: _` in its own `#transform`
block. That is not redundancy; it is the only way the body can reference it. Any slot the kernel
starts filling has to be declared the same way by transformers that want to read it, and that is an
authoring rule worth stating rather than leaving to be rediscovered.

#### 3. `#moduleInstance` works, and is only missing a filler

`core/src/transformer.cue` declares `#moduleInstance: _` and the comment above `#transform` states
that the runtime supplies all three inputs concretely. This control fills all three by hand and the
transformer reads the instance without trouble, including the self-referential case: the instance
that is filled in **contains** the component being rendered, and this produces no cycle and no
error. Nothing about the slot is unsound. The kernel simply never fills it.

## What the render path should do instead

Match CUE. Hand `#transform` the component as it exists on the instance, with its definitions
intact, and fill all three declared inputs. The kernel's own `#context` construction already reads
the unstripped value, so both values are already in scope at the fill site.

Tracked in open-platform-model/library#64.
