# Specification changes: Kernel render path parity with pure CUE

This document pre-drafts the `core/SPEC.md` co-update the core slices of enhancement 0019 need: `core-resourcename-default` for D16 (landed, core PR 51; its section below is kept aligned with what landed), `core-name-types-and-constraint` for D20, D21 and D23, `core-registry-import` for D5 and D17, and `core-context-projection` for D12. Each slice lands its own section under the `core-schema-edit` protocol; the CUE they land against is [`target.cue`](target.cue), exercised by [`examples.cue`](examples.cue).

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

## Name types and `#nameConstraint` (NEW / CHANGED vs SPEC.md §1, §2.1, §2.2, §3.1, §3.3)

### Definition

Three name types transcribe the three rules the API server actually enforces (0019 D20, measured by server-side dry-run): `#NameType` (RFC 1123 label, ≤63, unchanged) for everything that composes into DNS or into the D16 default; `#ObjectNameType` (NEW: RFC 1123 subdomain, dot-separated labels, ≤253) as the ceiling of an explicit `metadata.resourceName`; `#ServiceNameType` (NEW: RFC 1035 label, alphabetic lead, ≤63) for the kinds that refuse what `#NameType` admits.

A primitive that renders a dot-hostile kind declares the type its owning component's name must additionally satisfy, on a hidden slot `#nameConstraint` (D21). `#Component` collects every attached primitive's slot into one conjunction and asserts the resolved `resourceName` against it. Core carries no per-kind knowledge and no precedence rule: constraints compose by unification. A primitive MAY compute its slot from its own fields (D23); the container resource declares `#NameType` when its own `workload-type` key reads `stateful`, because the StatefulSet transformer keys on that label and a raw container answers it with no blueprint attached.

### Shape

```cue
#ObjectNameType:  string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$" & strings.MinRunes(1) & strings.MaxRunes(253)
#ServiceNameType: string & =~"^[a-z]([a-z0-9-]*[a-z0-9])?$" & strings.MinRunes(1) & strings.MaxRunes(63)

#Resource:  { ..., #nameConstraint: _ }   // likewise #Trait, #Blueprint
#Component: {
    metadata: resourceName: *"\(#instance.name)-\(name)" | #ObjectNameType | error("...")
    _nameConstraints: _
    for _, r in #resources  { _nameConstraints: r.#nameConstraint }
    if #traits != _|_     { for _, t in #traits     { _nameConstraints: t.#nameConstraint } }
    if #blueprints != _|_ { for _, b in #blueprints { _nameConstraints: b.#nameConstraint } }
    _nameFits: "\(metadata.resourceName)" & _nameConstraints
}
```

### Constraints

- `#nameConstraint` MUST be a hidden definition field defaulting to top, never optional and never guarded on existence: `x.#nameConstraint != _|_` is false for a non-concrete value on cue v0.17.1, so a guarded spelling silently never propagates.
- `#Component` MUST collect the slots unconditionally and MUST assert the conjunction on a hidden field against the interpolated `metadata.resourceName`. The conjunction MUST NOT be unified into `metadata.resourceName`: it distributes into the default arm, a failing default drops out of the disjunction, and the refusal degrades to `non-concrete value … in operand to ==` at the D16 guard with the string nowhere (experiment 11). A plain, un-interpolated `metadata.resourceName & _nameConstraints` MUST NOT be used: it silently admits every default-arm failure.
- A refusal reads `invalid value "<name>" (out of bound <regex>)` or `(does not satisfy strings.MaxRunes(63))` with the constraint type's definition site. It does not name the attached primitive or a remedy: an `error()` guard on this field fires on the bare `#Component` definition, because `(incomplete & C) == _|_` is true while `#instance.name` is unresolved.
- The D16 default is structurally dotless (both halves are `#NameType`), so only an explicit override can meet a dot constraint; the default can still meet a length constraint (a 64-to-127-rune default on a stateful component refuses), which the assertion covers.
- The catalog (not core) declares the constraints: Expose `#ServiceNameType`, the stateful-workload blueprint `#NameType`, the Namespace resource `#NameType`, the container resource the D23 conditional. `#ExposeSchema.name` is typed `#ServiceNameType` in the catalog (D20, D22).

### Rationale

- **Why three types.** They are the server's validators transcribed, not an OPM taxonomy: dots and 253 runes on Deployment, DaemonSet, ConfigMap, StorageClass, CSIDriver; DNS-1035 on Service; the label rule on both axes on StatefulSet and Namespace. A type system looser than the server validates nothing the server does not refuse later and worse; one stricter than the server forbids names the kinds admit.
- **Why the primitive declares and the component asserts.** The matchLabels precedent: facts live on the primitive that owns them, the component is a composition site, and the next dot-hostile kind is a catalog edit rather than a core edit. Constraining at the transformer would move refusal from `cue vet` to render time and hand write access on names back to transformers, which D15 just made read-only consumers.
- **Why a hidden assertion rather than the field's type.** Measured (experiment 11): it is the only spelling that refuses every must-fail case legibly, admits every must-pass case, and leaves the landed D16 mechanism (unvalidated default arm, guarded length assertion, `error()` arm) untouched.

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
- **Added (as landed).** The default arm is NOT unified with a type. When no `resourceName` is authored and the default exceeds the ceiling, the component MUST fail validation through the hidden guarded assertion `_resourceNameDefaultFits`, whose diagnostic names the concatenated string, its length, the limit and the remedy. It MUST NOT be exported.
- **Added (as landed).** That assertion MUST NOT refuse a component that authored an explicit `resourceName`; the guard compares the field against the default first. An invalid explicit value is reported by the disjunction's `error()` arm as a single message naming the value and the grammar.
- **Changed by D20.** The ceiling of the explicit value is `#ObjectNameType` (253 runes, dots admitted), no longer `#NameType`. The overlong-default guard is retired: both operands are `#NameType`, so the default is at most 127 runes and cannot reach the ceiling. A default of 64 to 127 runes is admitted unless an attached primitive narrows it (below).
- **Unchanged.** An explicit `resourceName` wins. `#names.resourceName` reads `metadata.resourceName` and the DNS variants derive from it.

### Rationale

- **Why instance-qualified.** The bare default collides outright when two instances of one module share a namespace: both render a `web` Deployment and the second clobbers the first. Within one instance the components map's keys already prevent collision, so qualification is the only ambiguity the default has left to fix. The form matches the `<release>-<chart>` convention every Helm operator already knows.
- **Why the default branch is NOT unified with a type (the landed form).** Measured on cue v0.17.1: a validated default that fails degrades to a bare `incomplete value` naming the constraints and never the string, and leaves the field non-concrete so no guard can compare against it. The unvalidated default plus the guarded hidden assertion refuses the same inputs with the string in the diagnostic. The assertion is what makes the unvalidated spelling safe: without it a 67-rune name exports clean.
- **Why the flip lands before the catalog sweep.** Rendered objects are already named `<instance>-<component>` by every hand-rolled catalog formula, while `#names` computes the bare name. That disagreement is the divergence reported as core#49. Flipping the default first closes it, which makes the flip output-neutral for rendered fleets and makes the subsequent sweep (0019 D15) a byte-identical refactor provable against the catalog's goldens. The reverse order renames every default-named object twice.
- **Why the escape hatch matters.** An explicit `resourceName` is what an exact-name contract needs (APIService, CRD, webhook configurations), and it is what lets the catalog's competing `#ResourceNameTrait` be deleted rather than reconciled: the core field subsumes the trait's one use case and carries the DNS variants the trait never did.
