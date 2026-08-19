# Design — Kernel render path parity with pure CUE

## Design Goals

- **Parity is the contract.** For any (instance, component, transformer) triple, the kernel's rendered output equals what plain CUE unification of the same three inputs produces. Where they differ, the kernel is wrong.
- **Parity is checkable.** The equality above is a test that runs in CI, not a principle in a document.
- **The kernel gets smaller.** Every divergence is closed by removing kernel behaviour, never by adding kernel behaviour that reproduces CUE more faithfully.
- **The declared contract is honoured in full.** All three inputs `core` declares on `#transform` are supplied concretely.

## Non-Goals

- Changing what a transformer is, or how components pair with transformers. Matching is untouched.
- Changing the unit of execution. One `#component` per `#transform` evaluation stays (D2).
- Removing `#moduleInstance` from the schema. It is intended, and the fix is to fill it (D3).
- Resolving the render path's build topology. Whether the pipeline collapses to a single CUE build is a real question raised by this work and deliberately left open (OQ1, OQ2, OQ3).

## High-Level Approach

The render path currently forks one component value into two and hands the transformer the lossy branch. The target keeps one value.

```
  TODAY                                    TARGET

  components                               components
      |                                        |
      +-- schemaComponents --> Match           +--> Match
      |                    --> #context        +--> #context
      |                                        +--> #component
      +-- dataComponents   --> #component      +--> #moduleInstance
          (definitions gone)                       (nothing removed)
```

Three properties follow, and each is measured rather than assumed:

**Nothing breaks.** Filling `#component` from the unstripped value leaves the full library suite green across 14 packages, including `composed_open_test.go`'s closed-platform corruption guard, `materialize_test.go`'s seam guard, and the `cueregression` canary pair that pins the unfixed upstream CUE closedness regression in both directions.

**The hazard does not reproduce.** A transformer with a hidden field declared lexically inside `output`, referencing a `#transform`-scope hidden field and consumed in-expression, the exact shape that ADR-003 exists to route around, marshals concretely with the sidecar intact. The corruption ADR-003 documents is a cross-build closed-fill artifact, and the fill site this enhancement changes is not that composition.

Validated end-to-end against real artifacts by `experiments/01-purecue-render-flow/`, which runs the whole flow (match, context, execute) as CUE against the published `catalogs/opm` transformers and renders a Deployment, a Service, an HTTPRoute and two ConfigMaps with `cue vet -c` clean.

**Defaults survive.** `cue.Final()` also sets `TakeDefaults`, so dropping it raises the question of whether defaulted disjunctions still resolve. A component field `port: *8080 | int` renders `8080` without it, and an unset optional stays absent from the output.

## The parity oracle

The design's load-bearing artifact is not a code change, it is a test shape:

```
  for each (instance, platform, component, transformer) fixture:

      kernel render    ----+
                           +---> assert equal
      pure CUE unify   ----+

  where "pure CUE unify" is literally:
      tf.#transform & {#moduleInstance: inst, #component: inst.components.<id>, #context: <projection>}
```

This differential harness is what turns D1 from an intention into an invariant. It fails on the definition strip the day it is written, which is the point: the first failure is the evidence, and every later removal is checked against an oracle rather than against "the suite still passes".

It also has a property worth naming: it makes the *absence* of divergence visible. A future contributor who adds a Go-side transformation of a component value, for a good local reason, gets a failing parity test rather than a green suite and a slow drift.

## Schema and API Surface

### `core`

`#transform`'s three declared inputs are unchanged in shape. What changes is that all three are filled.

A second, larger reduction is available and is held as an open question rather than a decision. `#TransformerContext` is almost entirely derivable from the other two inputs:

| `#context` field | derivable from |
| --- | --- |
| `#moduleInstanceMetadata.{name,namespace,fqn,uuid,labels,annotations}` | `#moduleInstance.metadata.*` |
| `#moduleInstanceMetadata.version` | `#moduleInstance.#moduleMetadata.version` |
| `#componentMetadata.{name,labels,annotations}` | `#component.metadata.*` |
| `moduleLabels`, `componentLabels`, `controllerLabels` | already CUE-computed folds over the above |
| `#runtimeName` | nothing; it is the runtime's own identity |

If those become projections in `core`, `library` stops decoding metadata into Go structs and re-encoding it, and `opm/schema/context.go` collapses to filling one string. That deletes a hand-maintained mirror of the schema, which is a drift surface by construction. It is OQ5 rather than a decision because it changes `core` shapes and wants its own evidence.

### `library`

- `opm/schema/paths.go` gains a `ModuleInstance` path constant, built with `cue.MakePath(cue.Def(...))` per that file's own note about definition paths on closed structs.
- `opm/compile/execute.go` fills `#component` from the schema-side component value, and fills `#moduleInstance`.
- `opm/compile/finalize.go`'s `FinalizeValue` leaves the render path. It is also exposed as a public kernel method (`opm/kernel/phases.go`), so its removal is a Go API break and carries a `MIGRATIONS.md` entry.
- `opm/kernel/flow_integration_test.go` stops constructing its instance by `LookupPath` plus `FillPath` (see below).

## The fixture that has to move first

`TestFlow_WebApp_OnOpmPlatform` builds its instance by pulling `#components` out of a module value and filling it into a separately-compiled skeleton. That is the shape the workspace's own `module-construction` experiment measured in February 2026 and found to sever references: a sub-value's internal references resolve against the scope it was defined in, and moving it to a new parent does not rebind them.

The visible symptom is that `#instance` is never wired, so `#names.dns.fqdn` fails with `required field missing: namespace` **in place**, before any fill and independent of anything this enhancement changes. On the real `synth.Instance` path the same expression resolves to `web.prod.svc.cluster.local`.

This matters for ordering, not for correctness of the change. While definitions are stripped, that fixture ships *no* value. Once they are exposed, it ships a *broken* one. The fixture is therefore a prerequisite of the slice that exposes definitions, not follow-up work.

## The single-build question

ADR-003 chose federation over single-build evaluation for one stated reason: a platform may subscribe to multiple versions of the same catalog `path@major` simultaneously, and CUE's Minimal Version Selection admits exactly one version per `path@major` per build.

Enhancement 0010 D14 subsequently deleted that requirement. A subscription carries one scalar `version`, the registry key is major-qualified by type, CUE map semantics enforce one subscription per key, and the decision states the rule as permanent: "A platform that wants two builds of one catalog cannot express it; it makes two platforms."

```
   ADR-003 (June 2026)                    0010 D14 (August 2026)
   platform may hold                      one subscription per path,
   catalog 0.5.0 AND 0.5.1     versus     scalar version, two builds
   simultaneously                         = two platforms, permanent
            |                                        |
            +--------------------+-------------------+
                                 |
              which is exactly MVS's own constraint.
              The premise for federation no longer holds.
```

If that reading survives scrutiny, the render pipeline could collapse to a single evaluation, and with it go `FinalizeValue`, the cross-build `FillPath` sequence, the federation machinery, and the class of bug ADR-003 exists to contain, because that bug is a cross-build artifact.

This enhancement does not decide it. Three questions gate it (OQ1, OQ2, OQ3), and the third is a genuine design fork rather than a verification task: in one build, MVS would resolve a module's catalog pin against the platform's subscription by picking the higher, which can override the version the platform names and contradict 0010 D14's "the platform file *is* the resolution".

## Integration Points

| Repo | Surface | Nature |
| --- | --- | --- |
| `library` | `opm/compile/execute.go`, `opm/schema/paths.go` | the fills |
| `library` | `opm/compile/finalize.go`, `opm/kernel/phases.go` | removal, Go API break |
| `library` | `opm/kernel/flow_integration_test.go` | fixture construction |
| `library` | new parity harness | the enforcement mechanism |
| `core` | `src/transformer.cue`, `SPEC.md` | only if OQ5 resolves toward projection |
| `catalog_opm` | transformer authoring docs | the lexical-declaration rule (downstream, no slice here) |

## Open Questions

The full list with status lines lives in [`03-decisions.md`](03-decisions.md). In summary: three concern the single-build question (OQ1, OQ2, OQ3), one concerns whether sibling-component access through `#moduleInstance` should be constrained (OQ4), and one concerns collapsing `#TransformerContext` to a projection (OQ5).
