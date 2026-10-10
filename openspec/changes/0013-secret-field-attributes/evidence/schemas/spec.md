# Specification changes: Attribute-Declared Secret Fields

This document pre-drafts the `core/SPEC.md` co-update for enhancement 0013, in core SPEC.md's four-part format (Definition / Shape / Constraints / Rationale). The baseline is `opmodel.dev/core@v2` at `core/src/schemas.cue` on `main`. The full CUE surface lives in [`target.cue`](target.cue) with worked, compiling values in [`examples.cue`](examples.cue); decision citations resolve against [`../03-decisions.md`](../03-decisions.md).

One piece of this entry's core delta has already landed: `core/SPEC.md` §1 classifies `#Secret` as a config-value contract type and not a Primitive. Its description of `#Secret`'s arms still names `#SecretK8sRef` and changes with this delta (see [SPEC.md §1 and §3.5 text](#specmd-1-and-35-text-changed-spec-text)). The schema delta itself has **not** landed: `core/src/schemas.cue` still carries the previous secret block (`#SecretType`, `#SecretK8sRef`, the `$`-fields, `#SecretSchema`, and the discovery pyramid), so every section below documents pending change. `#Secret` has never had a `§2.x` construct section, so the CHANGED sections are deltas against the *schema*, and their prose is written to be lifted into `core/SPEC.md` as new sections at implementation time.

**Two waves.** The entry is delivered in two waves (`06-operational.md`). Every section below ships in wave 1 unless its heading says **wave 2**. Wave 2 only widens `#Secret` by one arm and adds specification text; it changes the shape of nothing wave 1 ships.

Secret *methods* are not core surface. A method is a secret source: a `#Resource` a catalog defines, marked with a reserved annotation and fulfilled by that catalog's transformer (D18, D19). Core defines the arms a deployer writes and the one envelope every source receives, and never grows with new methods. The discovery and resolution mechanism (Discover, Resolve, group planning, object naming, component synthesis) is kernel surface implemented in `library`; its definitions appear only under [Not core surface](#not-core-surface).

---

## `#Secret` (CHANGED vs core@v2 `src/schemas.cue`; no existing SPEC.md §)

### Definition

`#Secret` is the config-value contract type a module author places on a sensitive field inside `#config`. It is not a primitive: it carries no `metadata`, no `apiVersion`, no contract key, and no `spec`. It is the **fulfilment** slot of a secret, the half a deployer fills, per environment, in `values`, and nothing else. All **routing** (which Kubernetes object the data lands in, under which key) lives in the inert `@opm(secret, …)` field attribute on the declaring field (D10).

Its arms are statements about the same secret, not kinds of secret: `#SecretLiteral` says *what* the data is, `#SecretRef` says *where* it already lives, and, from wave 2, `#SecretSource` says *which source* produces it and from what (D18).

### Shape

Wave 1:

```cue
#Secret: #SecretLiteral | #SecretRef
```

Wave 2:

```cue
#Secret: #SecretLiteral | #SecretRef | #SecretSource
```

Changed vs the current definition: the referenced arm is renamed and reshaped (`#SecretK8sRef` → `#SecretRef`), the shared `#SecretType` embedding with its `$opm` / `$secretName` / `$dataKey` fields is deleted, and every arm carries core's hidden tag `_opmSecret` (D33). Full surface: [`target.cue`](target.cue).

### Constraints

- A sensitive `#config` field MUST be typed `#Secret`. The schema, not the attribute and not the values, declares a secret: a field the `#config` schema types `#Secret`, through any disjunction, embedding, alias, pattern or list, is discovered, with all-default routing when unmarked (D13, D33). A secret-shaped value at a field the schema does not declare declares nothing.
- Every arm MUST carry the hidden `_opmSecret` tag, which only core can author. At render, the resolved value at every declared path MUST carry it; one that does not, such as a plain default left unset or the earlier core release's secret shape, is refused naming its path (D33).
- The deployer chooses the arm, per environment, in `values`. A published module MUST NOT fix the arm: which arm applies is a deployment fact the author cannot know (D10).
- Routing MUST NOT be stated in the value. `$opm`, `$secretName`, and `$dataKey` are removed; the arms carry fulfilment fields only (D10).
- Every arm MUST be a struct. A bare-scalar arm (`string | #SecretRef`) is rejected: the value's kind would change across resolution, so a module would only type-check with the kernel in the loop (D10).
- A malformed value (two arms at once, a bare string, an unknown field, a wrong type) MUST fail plain `cue vet -c` of the instance, whether or not a component reads it, through `#ModuleInstance`'s values check (D34). An unfulfilled secret MUST fail every render and every kernel validation. Plain `cue vet -c` reports it only when a component reads the path; one no component reads passes, because CUE does not check completeness under a hidden field (D34).
- Render-time values MUST hold the `#SecretRef` arm at every declared path (D11, D19). Every other arm is a pre-resolution shape only; the kernel rewrites it in place to the reference it resolves to.

### Rationale

- **Why the disjunction survives while the routing leaves.** The disjunction is the only part of a secret CUE itself can type-check, and it is the deployer's only slot for saying how the secret is fulfilled. Every replacement surface measured worse: an attribute argument bakes a cluster fact into a published module, a scheme-prefixed string makes the kernel parse semantics out of user data (D10).
- **Why the method is the deployer's arm and not a platform switch.** For supplied plaintext only a plain Secret is a sensible backend: SealedSecrets needs ciphertext, which a CUE transformer cannot produce, and external-store operators need a pointer into the store, not a value. Each method needs different data from the deployer, so the method belongs in the deployer's arm (D18).
- **Why widening in wave 2 is safe.** Modules type the field as `#Secret` and transformers only ever see the rewritten `#SecretRef`, so a new arm breaks no module and no transformer. `examples.cue` pins it: every wave-1 value is still a valid wave-2 value.
- **Why the tag and not a reference to `#Secret`.** Following references misses `let` aliases, and both core releases publish `#Secret` under one name; matching the arms' shape flags unrelated structs. A tag only core can write makes "is a core secret" a mechanical, version-aware fact (D33).
- **Why every arm is a struct.** Kind stability: a module vets standalone in any arm, with or without the kernel, and a secret interpolated into a rendered string (`"password=\(#config.db.password)"`) becomes a struct-in-string error at plain `cue vet`, at authoring time (D10, D11).

---

## `#SecretLiteral` (CHANGED vs core@v2 `src/schemas.cue`; no existing SPEC.md §)

### Definition

The supplied arm: the deployer has the data in hand and provides it inline. It is sugar for the platform's literal source: the kernel resolves it to the one contract annotated `opmodel.dev/secret-source: literal`, which materialises a plain Secret, then restates the literal as a `#SecretRef` to that object before anything renders (D11, D30).

### Shape

```cue
#SecretLiteral: {
    _opmSecret: "v2"
    value!:     string
}
```

Changed vs the current definition: the `#SecretType` embedding (and with it `$opm`, `$secretName`, `$dataKey`) is deleted, and the hidden tag is added.

### Constraints

- `value` is required and MUST be a string.
- The arm MUST NOT carry routing fields (D10).
- A `#SecretLiteral` MUST NOT survive into the component graph or any rendered output: resolution replaces it with the `#SecretRef` naming the object the kernel plans, and the plaintext leaves the pipeline out of band (D11, D16).
- A literal is accepted only from a values source the kernel assembles into the build: a `ModuleInstance` CR's values or a values file given alongside an instance. An authored instance package whose own files carry a literal at a declared path is refused (D25).
- A platform MUST carry at most one contract annotated `literal`; one carrying two is not routable, and a render using a literal on a platform with none fails naming the missing source (D30).

### Rationale

- **Why the shape shrinks to one field.** Everything else the arm carried was routing, and routing is the author's static declaration, not per-environment data (D10).
- **Why keep it as sugar at all.** It is the most common case. As a named source it would be three levels of nesting in every values file and CR (D18).
- **What migrates.** Today's fleet types its sensitive fields as plain strings, so instance files do change: `password: "…"` becomes `password: {value: "…"}`. `examples.cue` shows the migration on `modules/gotify`.

---

## `#SecretRef` (NEW; replaces removed `#SecretK8sRef`)

### Definition

The referenced arm: the data lives in an object that already exists, and OPM materialises nothing; it wires a reference. `#SecretRef` is also the shape the kernel *writes* for every resolved value, which is the design's central move: after resolution every declared path holds a `#SecretRef`, whichever arm the deployer wrote, and nothing downstream can tell them apart (D11, D19).

It replaces `#SecretK8sRef`, which is deleted. The fields are renamed: `secretName` → `ref`, `remoteKey` → `key` (D12).

### Shape

```cue
#SecretRef: {
    _opmSecret: "v2"
    ref!:       #ObjectNameType  // exact object name
    key!:       #SecretKeyType   // key inside that object's data map
}
```

`#ObjectNameType` is core's existing RFC 1123 subdomain type. `#SecretKeyType` is new in core; see its section below.

### Constraints

- `ref` is required and MUST be a valid `#ObjectNameType`: a Secret's `metadata.name` is a DNS subdomain, not a DNS label. When the deployer writes it, the name is the pre-existing object's exact name and MUST NOT be instance-prefixed by OPM; when the kernel writes it, it is the group's planned object name (D5, D6).
- `key` is required and MUST match the Kubernetes Secret data-key charset. It need not equal the declared config key: the module names its own slot, the cluster names its own.
- The struct is closed and MUST NOT carry a `value` field. Absence of plaintext after resolution is structural (D11).
- A deployer-written `#SecretRef` MUST pass through resolution unchanged (D11). Pinned in [`examples.cue`](examples.cue): the wildcard-certificate reference in `exResolvedProd` is what the deployer wrote.

### Rationale

- **Why `ref`/`key` rather than keeping `secretName`/`remoteKey`.** `secretName` collides with the removed `$secretName` and reads as "the name of the secret" when it means "the name of the object holding it" (D12).
- **Why `ref` is an object name and not a `#NameType`.** Two writers fill it, and both overflow a DNS label. A deployer may reference a Secret named `tls.example.com`, which the API server admits and a label refuses. The kernel writes `{instance}-{group}`, two labels of up to 63 runes each, plus an 11-rune suffix when immutable: 138 runes at worst, against `#NameType`'s cap of 63.
- **Why the struct is closed with no `value`.** It converts three classes of leak (a transformer reading `.value`, a string interpolation, a value-embedded error message) from silent plaintext into loud unification errors or unrepresentable states (D11).
- **Why every arm converges on this shape.** One branch in every consumer: a transformer reads `.ref` and `.key` with no variant dispatch. And because the kernel writes the object name *into the value*, there is one string, so an env reference and a volume reference to the same group cannot disagree (D11, D5).

---

## `#SecretSource` (NEW, **wave 2**)

### Definition

The named-source arm: the deployer names a secret source by its exact contract FQN and gives it what it needs. A source is a `#Resource` a catalog defines, marked with the `opmodel.dev/secret-source: source` annotation; its transformer turns the group's input into whatever produces the Secret (an ExternalSecret, a SealedSecret) (D19, D29).

### Shape

```cue
#SecretSource: {
    _opmSecret: "v2"
    source!:    #ContractFQNType  // the source's exact contract FQN
    settings?:  {...}             // how the group's one object is produced
    spec?:      {...}             // this key's own data
}
```

### Constraints

- `source` MUST be the exact FQN of a contract the platform defines and marks as a secret source, apiVersion included. Nothing resolves a short name and nothing picks a version (D29). A name the platform does not define, or one not so marked, fails listing the platform's installed sources.
- `settings` and `spec` are typed by the source's own resource schema, not by core. `settings` admits only what the source lets a deployer set (D21, D31).
- Every non-reference member of one group MUST name the same source with the same settings; a literal member counts as naming the literal source with empty settings, and a member with no settings block counts as `settings: {}`. Settings are compared as values, so field order and a setting written out at its default are not differences. A group that disagrees fails, naming the group and each member path (D19, D31).

### Rationale

- **Why an exact FQN.** Everywhere else OPM binds exactly: a component names a contract by its full FQN, and nothing picks a version. A short-name lookup was measured to break every deployer the day a catalog carries two apiVersions of one source (D29).
- **Why the open slots never need to grow.** A new method is a new catalog whose schema types `settings` and `spec`; core never learns its fields (D18).

---

## `#SecretSourceInput` (NEW)

### Definition

What the kernel hands every secret source, once per group: the target object, the group's settings, and one entry per data key (D18, D31). It ships in wave 1 in its final shape, so the literal source is written against the envelope wave 2 uses.

### Shape

```cue
#SecretSourceInput: {
    target!: {
        name!:     #ObjectNameType
        type:      #SecretObjectType | *"Opaque"
        immutable: bool | *false
    }
    settings: {...}
    entries!: [#SecretKeyType]: _
    for k in #SecretTypeRequiredKeys[target.type] {
        entries: (k)!: _
    }
}
```

### Constraints

- A source's resource schema MUST be `#SecretSourceInput` narrowed: `settings` to its own settings and `entries` to its own entry schema. A schema that does not accept the envelope fails to vet in its own catalog (D18).
- A source MUST end up producing, directly or through its own controller, a Kubernetes Secret named exactly `target.name` holding the entry keys. Every consumer's reference points there.
- A typed target MUST carry the data keys its type requires, whichever source produces it.
- The resource schema's `settings` MUST hold only deployer-settable settings, each optional or defaulted, so the input is complete without the platform's settings, which the source's transformer merges in (D31, D32).

### Rationale

- **Why core defines the envelope.** A catalog spelling it differently would fail only at render, and nothing would state the contract in code (D18). Defined once, it never grows: method-specific fields live only in `settings` and `entries`, which the catalog types.

---

## `#ModuleInstance` values check (CHANGED vs core@v2 `src/module_instance.cue`; SPEC.md §3.5)

### Definition

`#ModuleInstance` gains one hidden field that checks the deployer's values against the module's `#config` without changing what the instance exports (D34).

### Shape

```cue
_valuesCheck: #module.#config & values
```

Added beside `values: _`, which is unchanged. Modelled in [`target.cue`](target.cue) as `#ModuleInstanceValuesCheck`.

### Constraints

- The exported `values` MUST be exactly what the deployer wrote: no `#config` default is added.
- A value carrying two arms, a bare string at a secret path, an unknown field or a wrong type MUST fail plain `cue vet -c`, whether or not a component reads it.
- The kernel reports a failure under the check at the matching `values` path, redacted as a declared secret path (D28, D34).

### Rationale

- **Why beside `values` and not binding `values: #module.#config`.** Direct binding was measured to fill `#config` defaults into the exported values, which the CLI applies and hashes, and to reject even valid instances when values arrive as a separate file (D34).
- **Why this is not the addressable unified-config field D3 rejected.** The field is hidden and never exported, it is additive, and in the render build it holds only resolved references because the original values are omitted (D16). The kernel's own completeness check does not rely on it, since a hand-written instance need not embed `#ModuleInstance` at all.

---

## `@opm(secret, …)` field attribute: parsed form `#SecretMarker` (NEW)

### Definition

The routing half of a secret declaration: an inert CUE field attribute the module author writes on the declaring `#config` field. It states which Kubernetes Secret object the field's data lands in (`group`), under which key, with which object `type`, and whether the object is content-hash immutable: everything that is static, identical in every environment, and travels inside the published module. It never states where the data comes from; that is the type's job (D10).

An attribute is metadata attached to a field, not a field of its own, so `#SecretMarker` is not a value in any artifact and core evaluates nothing of it. It models the *parsed* form, what the kernel produces from every `opm` attribute on the field, so the argument grammar has one written-down contract that the Go parser and the docs both answer to. The kernel reads all of them (`cue.Value.Attributes`); `cue.Value.Attribute("opm")` returns only the first, which would hide a `secret` marker behind any other `@opm` kind.

### Shape

Grammar, as written on a `#config` field:

```cue
@opm(secret [, group=<name>] [, key=<key>] [, type=<k8s-type>] [, immutable=<bool>] [, description=<text>])
```

Parsed form (defaults applied):

```cue
#SecretMarker: {
    kind:      "secret"
    group:     #NameType | *"secrets"
    key?:      #SecretKeyType          // default: config path folded into the key charset (#DeriveKey)
    type:      #SecretObjectType | *"Opaque"
    immutable: bool | *false
    description?: string
}
```

### Constraints

- The attribute name MUST be `opm`, with the marker kind in position 0 (D2). The form comes from enhancement 0010's original identity design, `@opm(identity, owner=publish)`, which was later dropped; `secret` is the first live `@opm` marker. An `opm` attribute whose position 0 is another kind MUST be skipped, not rejected.
- The attribute MUST NOT influence CUE evaluation. It is metadata per the CUE language specification; the design depends on this inertness.
- Every argument past position 0 MUST be optional and derivable; `@opm(secret)` is the intended common case. `group` defaults to `secrets`, `key` to the config path folded into the key charset, `type` to `Opaque`, `immutable` to `false`. The fold is readable but not injective (`db.password` and a sibling `db_password` both give `db_password`), so two members of one group that land on the same key MUST be rejected, naming both paths. Nor is it total: a path whose fold passes 253 runes, or folds to nothing, has no default key, and that MUST be an error naming the path. An author resolves either case with `key=`.
- The parser MUST reject what it does not understand. An argument name other than `group`, `key`, `type`, `immutable` or `description` is an error, and so is a repeated argument. Every argument is `name=value` with a non-empty value, so a bare `immutable` or an empty `immutable=` is an error; `immutable` takes exactly `true` or `false`. A value containing `,`, `)` or `"` MUST be quoted.
- A field carrying two `secret` markers that disagree is a discovery error; identical markers collapse to one.
- A list element has no field-attribute slot. A `[...#Secret]` list is discovered by its element type with default routing (D13). Element routing is written as a declaration attribute inside an element struct that embeds `#Secret`, `[...{#Secret, @opm(secret, group=tokens)}]`. The kernel reads `opm` field and declaration attributes both; a declaration attribute is honoured only on a struct embedding `#Secret` and is a discovery error anywhere else.
- A `secret` marker MAY only appear on a field the schema declares a secret: a marked field of any other type is a discovery error. Conversely a declared secret with no marker is treated exactly as if it carried a bare `@opm(secret)` (D13). The marker is pure routing override; it is never load-bearing for the security property.
- All fields sharing a `group` MUST agree on `type` and on `immutable`: both are properties of the one object the group becomes.
- A `group` MUST be at most 51 runes, so the synthesised component's name `opm-secrets-<group>` stays a DNS label. Discovery refuses a longer one from the module alone, in every environment, rather than at render in only some of them.
- A marker MUST NOT name a source or a backend. The method is the deployer's choice, in the arm (D18).

### Rationale

- **Why an attribute and not a struct field.** Sensitivity routing is metadata about a field, not part of the field's data. Putting it in the value is what produced the old double statement and the unchecked drift between `$secretName` and the hand-written `spec.secrets` map.
- **Why one `@opm` namespace with position-0 dispatch.** A dedicated `@secret(...)` starts a second OPM attribute namespace for the second marker OPM has ever wanted. One namespace means one attribute name across OPM, one Go parse path, and a convention a reader learns once (D2).
- **Why discovery keys on the schema and fails closed.** Under marker-only discovery, forgetting the attribute would leave a secret invisible to the kernel and its literal would flow into the component graph. Keying on the schema's type makes "secret-typed but unhandled" structurally impossible (D13, D33).

---

## `#SecretKeyType` (NEW)

### Definition

The type of a key inside a Kubernetes Secret's `data` map. It enters core because `#SecretRef.key` carries it, and `#SecretRef` is core (D12).

### Shape

```cue
#SecretKeyType: string & =~"^[-._a-zA-Z0-9]+$" & !~"^\\.$" & !~"^\\.\\." & strings.MaxRunes(253)
```

### Constraints

- A key MUST match the charset Kubernetes admits for Secret data keys: alphanumerics, `-`, `_` and `.`.
- A key MUST NOT exceed 253 runes, MUST NOT be `.`, and MUST NOT start with `..`, all of which the API server refuses.

### Rationale

- **Why in core rather than the kernel.** A core definition cannot reference a type that lives only in `library`. Deleting `#SecretK8sRef` removes the untyped `remoteKey: string` it replaces, so the constraint either moves into core with `#SecretRef` or the reference arm loses the check.

---

## `#SecretObjectType` and `#SecretTypeRequiredKeys` (NEW; named from the inline set in removed `#SecretSchema`)

### Definition

The closed set of Kubernetes Secret `type` values OPM materialises, and the data keys the API server requires for each. Core carries a wider set today, inline in `#SecretSchema.type`, which is deleted. This names the part of it OPM can actually create.

### Shape

```cue
#SecretObjectType: "Opaque" | "kubernetes.io/dockercfg" | "kubernetes.io/dockerconfigjson" |
    "kubernetes.io/basic-auth" | "kubernetes.io/ssh-auth" | "kubernetes.io/tls"
```

`#SecretTypeRequiredKeys` maps each type to its required keys; see [`target.cue`](target.cue).

### Constraints

- A marker's `type=` argument MUST be a member of this set. `kubernetes.io/service-account-token` and `bootstrap.kubernetes.io/token` are excluded: the first needs annotations bound to a live ServiceAccount, the second is only read from `kube-system`. Either can still be consumed through a deployer-written `#SecretRef`, which carries no type.
- A typed target MUST carry the data keys its type requires: `tls.crt` and `tls.key` for `kubernetes.io/tls`, `ssh-privatekey` for `ssh-auth`, `.dockercfg` and `.dockerconfigjson` for the two registry types, and `username` or `password` for `basic-auth`. The default key fold never produces these, so a typed group's members set `key=`.
- All members of one group MUST agree on the type; the kernel rejects a group that disagrees.

### Rationale

- **Why name the type set in core.** Two parties read it: the kernel, when it parses `type=`, and every source's transformer through `#SecretSourceInput`. If each kept its own copy, a marker could pass the kernel and fail at a source (D12).
- **Why the required keys are in core.** The core envelope `#SecretSourceInput` enforces them for every source, so they must live where it does (D18 R4).

---

## Primitive annotations: the reserved `opmodel.dev/` prefix (CHANGED SPEC text; no schema change)

### Definition

Primitive `metadata.annotations` are definition behaviour hints. Keys under the `opmodel.dev/` prefix are reserved for keys the kernel interprets: a kernel feature that must find a primitive by what it is for reads such an annotation, never a new core field (D20). Each feature owns one key and its value vocabulary.

### Constraints

- The kernel MUST NOT interpret an annotation outside the reserved prefix.
- A primitive MAY carry several reserved keys, one per kernel feature.
- A reserved annotation is read by a kernel lookup, not by transformer matching; "not used for selection" continues to mean transformer matching.
- First key: `opmodel.dev/secret-source`, with value `source` for a secret source (wave 2) or `literal` for the one source a platform may carry to serve `#SecretLiteral` (D29, D30).

### Rationale

- **Why an annotation and not a field.** It lets later kernel features find what they need without growing core, which is the property this entry asks of the secret capability (D18, D20).

---

## Platform catalog entries may carry a settings fill (CHANGED SPEC text, **wave 2**; no schema change)

### Definition

Core documents a `#CatalogEntry`'s `#transformers` as a derived readout. From wave 2 a platform MAY also unify a secret source's settings into it, keyed by a reference to the catalog's exported transformer definition and wrapped in the source's own settings schema (D32).

### Constraints

- A source catalog exporting a settings-bearing transformer MUST export the transformer and its settings schema as named definitions.
- Every setting the platform must provide is required in the source's settings definition, so a missing or misspelled one fails rather than falling back to a default.

### Rationale

- **Why here.** The fill point was measured to reach the rendered output through the real render with no change to core, the kernel or the render glue; keyed by the exported definition, it survives catalog version bumps (D32).

---

## SPEC.md §1 and §3.5 text (CHANGED SPEC text)

Two existing SPEC passages become false with this delta and change with it:

- **§1, the `#Secret` description.** It names `#SecretK8sRef` as an arm. It becomes: `#Secret` is `#SecretLiteral | #SecretRef` (wave 2: `| #SecretSource`), each arm carrying core's hidden tag.
- **§3.5, `#ModuleInstance`.** Its constraint that a module with `#Secret` fields MUST declare its own secrets component against its catalog's secrets resource is replaced: modules declare no secrets component; the kernel synthesises one per group, outside `components` (D19, D35). Its rationale sentence that catalogs re-export `#AutoSecrets` is removed, since `#AutoSecrets` is deleted. The section also gains the values check above.

---

## Removed definitions (deletions from core@v2 `src/schemas.cue`)

Not constructs but part of the spec delta: `core` loses its entire legacy secret block. Deleted, with no aliases and no transition shims (D9, amended by D12):

| Definition | Disposition |
| --- | --- |
| `#SecretType` (the `$opm` / `$secretName` / `$dataKey` block) | Deleted: routing moves to the attribute (D10) |
| `#SecretK8sRef` | Deleted: replaced by `#SecretRef` (D12) |
| `#SecretSchema` | Deleted from core: the Kubernetes Secret *object* shape stays in `catalog_opm`, with `data` narrowed to `string` (D12) |
| `#SecretContentHash`, `#SecretImmutableName` | Deleted: content-hash naming moves to the kernel, the only party that can still see the input after resolution (D5) |
| `#AutoSecrets`, `#DiscoverSecrets`, `#GroupSecrets` | Deleted: the discovery pyramid has no call site anywhere in the workspace, walks only structs, and stops at ten levels; discovery becomes a kernel walk with no depth ceiling (D9, D3) |

`#ContentHash`, `#ConfigMapSchema`, and `#ImmutableName` are unaffected and stay in core.

Why delete rather than deprecate: the old and new shapes cannot coexist cleanly, and core's copy is already dead code that ships to every consumer (D9). Why `#Secret` itself nonetheless stays in core as the single definition: every catalog and every module needs the same fulfilment contract, and defining it once, upstream of all of them, stops the core/catalog duplication from diverging again (D12).

---

## Not core surface

The remaining top-level definitions in [`target.cue`](target.cue) are modelling aids for the kernel pass: behaviour contracts the `library` implements, not proposed `opmodel.dev/core` schema. They are listed here so the spec delta's boundary is explicit:

- **`#SecretDecl`, `#SecretDeclList`, `#DeriveKey`, `#GroupKeysUnique`**: Discover's output, its default-key derivation, and the per-group key-uniqueness check that makes the lossy derivation safe. The schema declares; discovery walks it with no values for listing and with the values unified at render (D3, D13, D33).
- **`#GroupSourcesAgree`** (wave 2): every non-reference member of a group names the same source with the same settings (D19, D31).
- **`#SecretGroupPlan`, `#ObjectName`, `#InputHash`, `#CanonicalJSON`, `#ImmutableObjectName`**: group planning and the single naming authority `{instance}-{group}`, with the content-hash suffix computed over the source input, in canonical JSON, before the rewrite (D5, D6).
- **`#ResolveInPlace`, `#SecretsResolution`**: the rewrite's pre/postcondition and the pass's one named result (D11, D16, D17, D34).
- **`#SynthesizedSecretComponent`**: the component the kernel synthesises per group, keyed `opm.secrets.<group>` outside the author key space, named `opm-secrets-<group>`, labelled by the kernel, carrying the chosen source's contract and its input (D23, D35). Its contract is reported among the render's required contracts (D24), its spec is never a readable field of the render build, and diagnostics at its path are redacted (D36).
- **`#SecretSourceAnnotation`**: the annotation key and role values a catalog uses to mark a source (D20, D29, D30).
- **`#NameType`, `#ObjectNameType`, `#ContractFQNType`, `#ContentHash`**: verbatim restatements of existing core definitions, which core keeps, so the delta compiles standalone.
- **`#ConfigPathType`, `#ConfigPathPatternType`**: the kernel's join key. A concrete path in CUE's own printed syntax, with quoted labels for non-identifier map keys (`extraSecrets."api-token"`), and a declaration form that may carry `[_]` for any key of a pattern map or any list element.
