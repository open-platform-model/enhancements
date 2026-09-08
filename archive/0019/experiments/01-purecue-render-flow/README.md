# Experiment 01: purecue-render-flow

Status: Concluded

## Hypothesis

The whole OPM render flow (match, context construction, execute) is expressible as plain CUE unification against **real** artifacts: a real `#Module`, a real `#ModuleInstance`, and the real published `catalogs/opm` transformers. Doing so requires no analogue of the kernel's `FinalizeValue` step, and every definition field on a component (`#names`, `#resources`, `#traits`, `#instance`) plus the third declared input `#moduleInstance` is readable throughout.

This validates D1's premise in `02-design.md`, that pure-CUE unification is a coherent oracle for the render path, rather than a thought experiment that falls apart on real inputs.

## Setup

Real artifacts, copied in per the copy-never-reference rule:

| File | Copied from | Modified |
| --- | --- | --- |
| `web_app/module.cue` | `library/testdata/modules/web_app/module.cue` | no |
| `web_app/components.cue` | `library/testdata/modules/web_app/components.cue` | no |
| `opm_platform/platform.cue` | `library/modules/opm_platform/platform.cue` | no |

Two files are authored here rather than copied, because the kernel has no on-disk equivalent to copy:

- `instance.cue` is the `#ModuleInstance`. It names the module by **import**. The kernel's own flow fixture instead pulls `#components` out of a module value and fills it into a separately compiled skeleton, which severs the reference wiring `#instance`; authoring it the normal way is what makes `#names.dns.fqdn` resolve here. Instance name and namespace match the kernel flow test (`web-app-demo` / `default`) so rendered object names are directly comparable.
- `render.cue` is the glue, at 82 non-comment lines.

**Deviation from the copy-never-reference rule, stated deliberately.** `cue.mod/module.cue` depends on `opmodel.dev/core@v2.0.0-alpha.4` and `opmodel.dev/catalogs/opm@v2.0.0-alpha.3` from the registry rather than vendoring their bytes. Both are exact published versions, so they are immutable and cannot drift, which satisfies the rule's stated rationale (an experiment must not be silently invalidated by an upstream change). Copying roughly 70 catalog members in would also defeat the experiment's purpose, which is to run against what actually ships. The two pins are the same builds `library/testdata/modules/web_app` and `library/modules/opm_platform` use, so this evaluates the same bytes the kernel does.

`_transformers` is a hidden field. Exposing the catalog map publicly makes `cue vet -c` demand concreteness of every unmatched transformer's `optionalTraits` templates, which are schema declarations and legitimately non-concrete. Hiding it keeps the concreteness check meaningful over the rendered output.

### Reading order

`render.cue` is laid out in the kernel's own phases so the two can be read side by side:

| `render.cue` | Kernel equivalent |
| --- | --- |
| `matched` / `pairs` | `library/opm/compile/match.go` |
| `_contextFor` | `library/opm/schema/context.go` |
| `rendered` | `library/opm/compile/execute.go` |
| (nothing) | `library/opm/compile/finalize.go` |

The empty row is the experiment's whole point.

## Run

```bash
export CUE_REGISTRY='opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'

cue eval -e pairs .                    # phase 1: which transformers matched
cue eval -e rendered --out yaml .      # phase 3: the rendered Kubernetes objects
cue eval -e visibleToTransformers .    # the definition fields the kernel strips
cue vet -c ./...                       # everything concrete; exits 0
```

Pinned to `cue v0.17.1`, the same version `library/go.mod` pins for the SDK.

## Outcome

**Hypothesis held.**

`cue vet -c ./...` exits 0. The flow produces the same five pairs the kernel's `TestFlow_WebApp_OnOpmPlatform` produces, and renders real Kubernetes objects through the real published transformers:

```
web    :: deployment-transformer@2.0.0-alpha.3   -> Deployment/web-app-demo-web
web    :: hpa-transformer@2.0.0-alpha.3          -> list[0]
web    :: http-route-transformer@2.0.0-alpha.3   -> HTTPRoute/web-app-demo-web
web    :: service-transformer@2.0.0-alpha.3      -> Service/web-app-demo-web
config :: configmap-transformer@2.0.0-alpha.3    -> list[2] ConfigMap, ConfigMap
```

Every definition field is readable throughout, including the ones no transformer can currently reach:

```
web:    resourceName "web",    fqdn "web.default.svc.cluster.local",
        1 resource, 7 traits,  #instance.namespace "default"
config: resourceName "config", fqdn "config.default.svc.cluster.local",
        1 resource, 0 traits,  #instance.namespace "default"
```

### Four things the experiment settled beyond the hypothesis

**Matching needs definitions, and rendering is given a value that lacks them.** Predicates 2 and 3 read `#resources` and `#traits` off the component. That is the structural reason the kernel keeps two values: it cannot match with the value it renders with. With one value the problem does not exist, which reframes the two-value split as a consequence of the strip rather than an independent design choice.

**Filling `#moduleInstance` works even though no shipped transformer declares it.** `core.#ComponentTransformer` declares the slot, so the field exists in the unified value and a caller can fill it. What a transformer cannot do without re-declaring it is *reference* it, because CUE resolves references lexically against the source they are written in. Filling and referencing are separate concerns, and only the second imposes an authoring rule. This is a sharper statement of the finding in `experiments/00-purecue-definitions/`.

**`#context` is a projection, in full.** `_contextFor` derives every field from the instance and the component. Only `#runtimeName` comes from outside, because nothing in the artifacts can know what is executing them. This is OQ5 demonstrated rather than argued: the Go decoding in `library/opm/schema/context.go` reproduces by hand what 18 lines of CUE derive.

**OQ3 is visible in the file.** In a single build the catalog version is decided by `cue.mod` and CUE's Minimal Version Selection. The platform's `#registry` subscription is inert here, because the import already resolved it. `_versionsAgree` unifies the two and fails the build if they diverge. Under 0010 D14 the platform file *is* the resolution; under single-build evaluation `cue.mod` is. The experiment does not resolve the conflict, it makes it executable.

### Deliberately not done

No diff against the kernel's actual rendered output. That comparison is the parity harness itself, which is slice 1 of this enhancement, and building a one-off version here would prejudge the equality question that the acceptance criteria hold as a gate item. Note also that the kernel's flow fixture hardcodes an instance `uuid` rather than letting core compute it from the fqn, so a naive diff would differ on labels for reasons unrelated to this entry.
