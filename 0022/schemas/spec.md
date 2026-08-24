# Specification changes: Machine-Readable Artifact Metadata in cue.mod/module.cue

Two NEW constructs, both publish gates, pre-drafting the core/SPEC.md §5 co-update the core slice will make under the `core-schema-edit` protocol. The CUE shapes live in [`target.cue`](target.cue).

## `#ModuleFileCustom` (NEW, SPEC.md §5.4)

### Definition

`#ModuleFileCustom` is the shape of the metadata block an OPM artifact carries in its `cue.mod/module.cue`, under CUE's `custom` field at the key `#ModuleFileCustomKey` (`"opmodel.dev@v0"`). It states what the artifact is (`kind`), which artifact exactly (`identity`), which core line it was built against (`core`) and which catalogs it depends on (`catalogs`). It is plain data: CUE parses a module file in data mode, so an artifact never references this definition; it is the declared side of `#ModuleFileCustomGate`, which a publishing tool unifies externally, in the same way `#IdentityPackage` is validated.

### Shape

```cue
#ModuleFileCustomKey: "opmodel.dev@v0"
#ArtifactKind:        "module" | "catalog" | "template"

#ModuleFileCustom: {
    kind!:     #ArtifactKind
    identity!: {ModulePath!: #ModulePathType, Version!: #VersionType}
    core!:     {major!: =~"^v[0-9]+$", version!: #VersionType}
    catalogs!: [#ModulePathType]: #VersionType
}
```

### Constraints

- Every field is REQUIRED and every value MUST be concrete; the block MUST contain no references, definitions or defaults (CUE data mode).
- `identity.ModulePath` MUST be byte-identical to the module file's `module:` field; `identity.Version` MUST equal the identity package's `Version`. Both are asserted by `#ModuleFileCustomGate`, never here.
- `core.version` MUST equal the `deps` pin of `opmodel.dev/core@<core.major>`, without its `v` prefix.
- `catalogs` MUST contain every `opmodel.dev/catalogs/*` dependency at its pin and MUST NOT name a path that is not a dependency. Catalog dependencies outside that prefix: unresolved (OQ1).
- The key MUST be `"opmodel.dev@v0"`; the `@v0` suffix is bumped only on an incompatible change to this shape. Readers MUST ignore keys they do not know.
- `core` itself MUST NOT carry the block; module, catalog and template artifacts MUST (after the grace window 0022 D8 defines).

### Rationale

- **Why a block in the module file rather than a new artifact format.** CUE fetches the module file as its own OCI blob (226 bytes for cert_manager v2.0.1 against a 230 KB zip), reserves `custom` for third-party data, carries it through every `cue mod` rewrite and ships it verbatim. Nothing CUE-side changes; nothing OPM-specific fetches.
- **Why values the file already states are repeated.** A reader should not have to know how `deps` keys are spelled or where the identity version lives. The repetition is safe only because the gate asserts it at publish (0022 D2, D4).
- **Why no toolchain fields.** Publish never writes the tree (0011 D2), so the tree cannot know who publishes it; push-time provenance is carried in OCI manifest annotations (0022 D6).
- **Why the key carries `@v0`.** CUE's schema also defines a `#Strict` variant whose key regex requires the suffix; nothing enforces it today, and a published convention is permanent (0022 D1).

## `#ModuleFileCustomGate` (NEW, SPEC.md §5.5)

### Definition

`#ModuleFileCustomGate` is the rule a publishing tool unifies an artifact's block against. It takes what publish already holds (the module file's `module:` and `deps`, the identity package's `Version`) and states each duplicated field of the block twice: as declared and as implied. Unification is the check; CUE's diagnostic names the field.

### Shape

```cue
#ModuleFileCustomGate: {
    module!:          #ModulePathType
    identityVersion!: #VersionType
    deps!: [string]: v!: string
    declared!: #ModuleFileCustom

    declared: identity: ModulePath: module
    declared: identity: Version:    identityVersion
    declared: core: version: strings.TrimPrefix(deps["opmodel.dev/core@"+declared.core.major].v, "v")
    declared: catalogs: {for p, d in deps if strings.HasPrefix(p, "opmodel.dev/catalogs/") {(p): strings.TrimPrefix(d.v, "v")}}
    _catalogsAreDeps: {for p, v in declared.catalogs {(p): deps[p].v & ("v" + v)}}
}
```

### Constraints

- A publishing tool MUST unify the block against this gate when the block is present and MUST refuse on conflict; it MUST NOT edit the block (0011 D16).
- A missing block MUST be reported; whether it refuses is governed by the dated window 0022 D8 defines.
- `core` MUST NOT ship a procedural comparator for this relation; the consumer unifies and surfaces CUE's own error (the 0011 D21 posture).
- Open: whether `kind` is additionally asserted against the path prefix inside OPM-owned domains (OQ2).

### Rationale

- **Why declared beside implied.** The same form `#CatalogMemberFQNGate` uses: a string comparison in Go would discard the field-level diagnostic and be a second statement of the contract that drifts.
- **Why the gate is external.** The module file cannot import anything, and the identity package deliberately imports nothing within its module. Shipping the definition in `core` and unifying in the publisher keeps both invariants.
