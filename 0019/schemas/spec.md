# Specification changes: Kernel render path parity with pure CUE

This document pre-drafts the `core/SPEC.md` co-update the three core slices of enhancement 0019 will need (`core-registry-import` for D5, `core-context-projection` for D12, `core-resourcename-default` for D16). Each slice lands its own section under the `core-schema-edit` protocol; the CUE they land against is [`target.cue`](target.cue), exercised by [`examples.cue`](examples.cue).

The rest of the enhancement changes kernel behaviour rather than core shapes, and is stated in [`../contracts/contracts.cue`](../contracts/contracts.cue).

## `#CatalogEntry` (NEW, replacing `#Subscription` in SPEC.md §3.4)

### Definition

A `#CatalogEntry` declares that a `#Platform` admits a catalog, by **carrying that catalog's value** rather than by naming a coordinate. The platform module imports the catalog the way any CUE module imports a dependency, and the entry embeds the imported value whole; the build the platform executes is therefore chosen by the platform module's own `cue.mod`, resolved by the same mechanism that resolves every other dependency.

It replaces `#Subscription` outright. A subscription named a build with a version string, which nothing in a CUE build resolves: the kernel pulled the artifact over OCI and indexed it in Go. An entry carries the bytes, which is what lets one render evaluate the instance, the platform and the catalog in a single build (0019 D9).

`#Subscription` is removed rather than extended. It is closed around `enable` and `version!`, so the entry shape is inexpressible as a unification onto it; the removal is a major-version change to `core`.

### Shape

```cue
#CatalogEntry: {
    enable: bool | *true

    // The imported catalog, embedded whole.
    #catalog: #Catalog

    // Derived readouts. Neither is authored.
    version:       #catalog.metadata.version
    #transformers: #TransformerMap & #catalog.#transformers
}
```

`enable` is unchanged from `#Subscription`. `version!` is gone as an authored field and returns as a derived one. `#transformers` is new.

### Constraints

- A registry entry MUST carry `#catalog`, and that value MUST be a `#Catalog` obtained by import. It MUST NOT be assembled inline in the platform file.
- `version` MUST equal `#catalog.metadata.version`. A caller MAY additionally write an expected `version` on the entry (the operator does this at platform-generation time); the written value unifies with the derived readout, so a value that disagrees with the imported bytes MUST fail the build at a path naming the entry.
- `#transformers` MUST equal the embedded catalog's `#transformers` map, whole. Per-transformer selection MUST NOT be expressible on an entry; that concern belongs to enhancement 0015.
- `enable: false` MUST exclude the entry from every derived fold on `#Platform`. The entry stays present in the file.
- An unstamped catalog (no `metadata.version`) MUST refuse as an incomplete value naming that field. `#Catalog.metadata.version!` carries no development default, so this holds without an added check.
- `#Subscription` MUST be removed, together with SPEC.md §3.4's constraints on `#Subscription.version` and on the removed subscription filter.

### Rationale

- **Why an import instead of a version string.** A version string is inert data that nothing resolves, so the kernel had to resolve it out of band and hand the result back in. An import is resolved by `cue/load` from the main module's own dependency list, which is what makes a single-build render have an answer at all. Enhancement 0010 D14's property is preserved rather than weakened: catalog selection stays a pure function of committed source, because `cue.mod` is committed source. The sentence changes from "the platform file is the resolution" to "the platform module is the resolution".
- **Why the version is derived and not authored.** Two answers to one question, with no way for a reader or the kernel to tell which is load-bearing, is the failure mode `#Subscription` plus an import would have. Experiment 02 measured that the import is the one that decides. A derived readout cannot disagree with the bytes it is read from, and it keeps the stamped identity available to skew diagnostics (D7) and to the Platform CR's status, which the coordinate-only shape discarded.
- **Why the optional stamp is not a second answer.** It is an assertion unified against the readout, so its only reachable outcomes are "agrees" (a no-op) and "build conflict naming the entry". That makes it defense in depth for the render module's promoted dependency list (D13) rather than an independent selection mechanism.
- **Why the whole transformer map.** A subset is a second selection mechanism competing with enhancement 0015's provider classes and `TransformerRegistration`, at a granularity nothing needs today. Experiment 07 measured the cost of carrying the rest as zero: unevaluated definition payloads are never evaluated.

## `#Platform` (CHANGED vs SPEC.md §3.4)

### Definition

The change to §3.4's Definition is what a `#Platform` value *is*. It stops being "a spec plus a place for the kernel to write its materialization output" and becomes a complete value: the registry carries the catalogs, and the one materialization slot that survives is a fold over that registry computed by CUE. There is no materialized twin, no `Materialize` step to produce one, and no reverse index.

The sentence "the platform file **is** the resolution" is unchanged in force and stronger in mechanism: the resolution now includes the bytes.

### Shape

```cue
#Platform: {
    // ... kind, metadata, type unchanged ...

    // CHANGED: entry type, plus a pattern constraint that binds the key.
    #registry: [Path=#ModulePathType]: #CatalogEntry & {#catalog: metadata: modulePath: Path}

    // CHANGED: derived, no longer optional, no longer kernel-filled.
    #composedTransformers: {
        for _, entry in #registry if entry.enable {
            for fqn, tf in entry.#transformers {(fqn): tf}
        }
    }

    // REMOVED (D17): the render build's matching glue owns the reverse index.
}
```

### Constraints

- **Added.** The `#registry` pattern constraint MUST bind the map key into the entry's embedded catalog: an entry keyed at a path whose catalog declares a different `metadata.modulePath` MUST fail the build at a path naming that entry.
- **Changed.** `#composedTransformers` MUST be the fold of every enabled entry's `#transformers`. It MUST NOT be optional, and no runtime MUST fill it.
- **Changed.** The fold MUST copy entries member by member (a comprehension). It MUST NOT unify one entry's transformer map into another's: a catalog's provenance stamp (enhancement 0010 D25) refuses a foreign member, so unification across catalogs fails on healthy input.
- **Removed.** `#matchers`. A `#Platform` MUST NOT carry a reverse index. A platform value declaring one MUST be rejected as a field not allowed.
- **Unchanged.** Exactly one entry per catalog path, by CUE map semantics. Two builds of one catalog remain two platforms (enhancement 0010 D13/D14).
- **Removed.** Every constraint phrased in terms of the kernel's `Materialize` step, of a materialized twin, or of `#Subscription`.

### Rationale

- **Why the key binding is structural rather than a check.** Key-and-import drift is the one new failure mode embedding the catalog introduces, and a pattern constraint makes it inexpressible instead of detectable. The conflict names the entry, so the report points at the line the author wrote.
- **Why `#composedTransformers` stops being kernel-filled.** With the maps present in the registry the fold is four lines of CUE, and `library/opm/materialize/index.go` loses its reason to exist. This is enhancement 0019 D1's direction applied to a schema slot: the divergence between what CUE can compute and what the kernel computes is closed by removing the kernel's copy.
- **Why the fold copies rather than unifies.** Measured in experiment 05: the catalog's D25 provenance stamp refuses a transformer from another catalog unified into its member map, so unification would fail on exactly the multi-catalog platform this shape exists to support.
- **Why `#matchers` is removed rather than derived (0019 D17).** The slot existed because a Go step filled it, and both halves of that sentence are being deleted: `Materialize` by this change, and the Go matcher that read it by 0019 D10. Measured 2026-08-20, `library/opm/compile/match.go` is its only reader; nothing in `opm-operator` or `cli` reads it. The in-build glue does not read it either: experiment 05's matcher takes the composed map and the components and builds its own buckets, keyed contract FQN to a *set* of transformer FQNs rather than to a list of transformer values. A derived `#matchers` would therefore be a second index, in a shape nothing consumes, beside the one the render uses. A consumer that wants the index folds it over `#composedTransformers`.

## `#ComponentTransformer.#transform` and `#TransformerContext` (CHANGED vs SPEC.md §4.1)

### Definition

`#TransformerContext` stops being a value the runtime assembles and becomes a projection of the other two `#transform` inputs. Every field except `#runtimeName` is computed from `#moduleInstance` and `#component` at the point where both are already in scope; the runtime's obligation narrows to the one string nothing in the artifacts can know.

Field names and values are unchanged. What changes is where they come from, which is why the migration is stageable: for one release the runtime may keep filling values identical to what the projection computes, and unification agrees.

### Shape

```cue
#transform: {
    #moduleInstance: _
    #component:      _

    // CHANGED: computed, not filled.
    #context: #TransformerContext & {
        #moduleInstanceMetadata: {
            name:      #moduleInstance.metadata.name
            namespace: #moduleInstance.metadata.namespace
            fqn:       #moduleInstance.metadata.fqn
            uuid:      #moduleInstance.metadata.uuid
            version:   #moduleInstance.#moduleMetadata.version
            if #moduleInstance.metadata.labels != _|_ {labels: #moduleInstance.metadata.labels}
            if #moduleInstance.metadata.annotations != _|_ {annotations: #moduleInstance.metadata.annotations}
        }
        #componentMetadata: {
            name: #component.metadata.name
            if #component.metadata.labels != _|_ {labels: #component.metadata.labels}
            if #component.metadata.annotations != _|_ {annotations: #component.metadata.annotations}
        }
    }

    output: {...} | [...{...}]
}
```

The label and annotation folds inside `#TransformerContext` are unchanged: they were already projections of the two metadata blocks.

### Constraints

- **Added.** `#context.#moduleInstanceMetadata` and `#context.#componentMetadata` MUST be projections of `#transform`'s other two inputs. A runtime MUST NOT be required to supply them.
- **Added.** An optional source field that is absent MUST project as absent, not as an error or an empty struct. `labels` and `annotations` on either metadata block are the cases this covers.
- **Unchanged.** `#runtimeName` MUST be supplied by the runtime and MUST be present. It remains the only runtime-owned field, and it remains stamped verbatim onto every rendered object as `app.kubernetes.io/managed-by`.
- **Unchanged.** `matchLabels` MUST NOT reach `componentLabels` (enhancement 0010 D36).
- **Transitional.** While the migration is staged, a runtime MAY continue to fill the projected fields, provided every value it fills is identical to what the projection computes. It MUST stop once the differential parity harness reports agreement on every case.

### Rationale

- **Why a projection.** The context was already half a projection: its label and annotation folds are computed from the two metadata blocks. The half that was not is the half that needed `library/opm/schema/context.go`, a hand-maintained decode and re-encode mirror that can drift from the schema it mirrors. Experiment 01 derives every field in 18 lines of CUE against the real published catalog, so the derivation is demonstrated rather than argued.
- **Why it lands with the render-path collapse rather than separately.** Under 0019 D9 the render is one build, so a deferred projection would have the generated glue hand-roll in CUE exactly what `core` can compute, and a later enhancement move the same logic into `core`. That is churn in the glue this entry creates.
- **Why the migration can be staged.** Filling a value identical to what unification computes is a no-op under unification. That property is what lets the Go fills be removed on the harness's evidence rather than on a flag day.

## `#Component.metadata.resourceName` (CHANGED vs SPEC.md §3.1)

### Definition

The `resourceName` cascade's default changes from the bare component name to the instance-qualified name, `<instance>-<component>`. An explicit `resourceName` still wins; the change is default-only, so it is inert for any component that sets the field.

`#names.dns.*` inherits the change by construction, so a component's service DNS becomes `<instance>-<component>.<namespace>.svc.<clusterDomain>`.

### Shape

```cue
metadata: {
    name!: #NameType

    // CHANGED: was `*name | #NameType`.
    resourceName: *("\(#instance.name)-\(name)" & #NameType) | #NameType
}
```

The default branch is unified with `#NameType` rather than being a bare interpolation.

### Constraints

- **Changed.** When `resourceName` is not authored, it MUST default to `"\(#instance.name)-\(metadata.name)"`.
- **Added.** The default MUST be validated against `#NameType`. A qualified name that exceeds the 63-rune budget or otherwise violates the label grammar MUST refuse the render. It MUST NOT be exported.
- **Added.** The refusal MUST name the offending concatenation. On cue v0.17.1 the validated disjunction alone reports `incomplete value` naming `#NameType`'s constraints, because the failed default branch falls back to the non-concrete arm; the slice therefore owes a hidden assertion in the style of `_matchLabelsAreDerived`.
- **Added.** That assertion MUST NOT refuse a component that authored an explicit `resourceName`. A short authored name is legal even when the qualified concatenation would overflow, so an unconditional assertion over-refuses.
- **Unchanged.** An explicit `resourceName` wins. `#names.resourceName` reads `metadata.resourceName` and the DNS variants derive from it.

### Rationale

- **Why instance-qualified.** The bare default collides outright when two instances of one module share a namespace: both render a `web` Deployment and the second clobbers the first. Within one instance the components map's keys already prevent collision, so qualification is the only ambiguity the default has left to fix. The form matches the `<release>-<chart>` convention every Helm operator already knows.
- **Why the default branch is unified with `#NameType`.** Measured on cue v0.17.1: a chosen disjunction default is not unified with the other branch, so the unvalidated spelling `*"\(#instance.name)-\(name)" | #NameType` exports a 67-rune name with `cue export` exiting 0. The unification is the difference between refusing an invalid DNS label and shipping one to the API server.
- **Why the flip lands before the catalog sweep.** Rendered objects are already named `<instance>-<component>` by every hand-rolled catalog formula, while `#names` computes the bare name. That disagreement is the divergence reported as core#49. Flipping the default first closes it, which makes the flip output-neutral for rendered fleets and makes the subsequent sweep (0019 D15) a byte-identical refactor provable against the catalog's goldens. The reverse order renames every default-named object twice.
- **Why the escape hatch matters.** An explicit `resourceName` is what an exact-name contract needs (APIService, CRD, webhook configurations), and it is what lets the catalog's competing `#ResourceNameTrait` be deleted rather than reconciled: the core field subsumes the trait's one use case and carries the DNS variants the trait never did.
