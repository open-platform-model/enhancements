# Specification changes: Attribute-Declared Secret Fields

This document pre-drafts the `core/SPEC.md` co-update for enhancement 0013, in core SPEC.md's four-part format (Definition / Shape / Constraints / Rationale). The baseline is `opmodel.dev/core@v2` at `core/src/schemas.cue` on `main`. The full CUE surface lives in [`target.cue`](target.cue) with worked, compiling values in [`examples.cue`](examples.cue); decision citations (`D1`–`D17`) resolve against [`../03-decisions.md`](../03-decisions.md).

One piece of this entry's core delta has already landed: `core/SPEC.md` §1 now states that `#Secret` is a config-value contract type and not a Primitive — the Primitives-sentence correction from the integration table in [`../02-design.md`](../02-design.md). The schema delta itself has **not** landed: as of 2026-08-20, `core/src/schemas.cue` still carries the previous secret block (`#SecretType`, `#SecretK8sRef`, the `$`-fields, `#SecretSchema`, and the discovery pyramid), so every section below documents pending change. `#Secret` has never had a `§2.x` construct section, so the CHANGED sections below are deltas against the *schema*, and their prose is written to be lifted into `core/SPEC.md` as new sections at implementation time.

The discovery and resolution mechanism (Discover, Resolve, group planning, object naming, component synthesis) is kernel surface implemented in `library`, not core schema; its definitions appear only under [Not core surface](#not-core-surface) at the end.

---

## `#Secret` (CHANGED vs core@v2 `src/schemas.cue`; no existing SPEC.md §)

### Definition

`#Secret` is the config-value contract type a module author places on a sensitive field inside `#config`. It is not a primitive: it carries no `metadata`, no `apiVersion`, no contract key, and no `spec` (as `SPEC.md` §1 already records). It is the **fulfilment** slot of a secret — the half a deployer fills, per environment, in `values` — and nothing else. All **routing** (which Kubernetes object the data lands in, under which key) moves out of the value and into the inert `@opm(secret, …)` field attribute on the declaring field (D10).

The change narrows the disjunction from today's `#SecretLiteral | #SecretK8sRef` — whose arms share a `$`-prefixed marker block (`$opm`, `$secretName`, `$dataKey`) — to exactly two struct arms carrying fulfilment only. The two arms are not two kinds of secret; they are two statements about the same secret: `#SecretLiteral` says *what* the data is, `#SecretRef` says *where* it lives.

### Shape

```cue
#Secret: #SecretLiteral | #SecretRef
```

Changed vs the current definition: the referenced arm is renamed and reshaped (`#SecretK8sRef` → `#SecretRef`, see its section), and the shared `#SecretType` embedding with its `$opm` / `$secretName` / `$dataKey` fields is deleted outright. Full surface: [`target.cue`](target.cue).

### Constraints

- A sensitive `#config` field MUST be typed `#Secret`. The type — not the attribute — is the load-bearing declaration: the kernel's discovery keys on it, so an unmarked `#Secret` field is still discovered, with all-default routing (D13). Tightened vs today, where detection keys on `$opm` presence in values.
- The deployer chooses the arm, per environment, in `values`. A published module MUST NOT fix the arm: which arm applies is a deployment fact the author cannot know (D10, OQ1).
- Routing MUST NOT be stated in the value. `$opm`, `$secretName`, and `$dataKey` are removed; the arms carry fulfilment fields only (D10). Removed constraint surface, called out as such: the entire `$`-field vocabulary.
- Both arms MUST be structs. A bare-scalar arm (`string | #SecretRef`) is rejected: the value's kind would change across resolution, so a module would only type-check with the kernel in the loop (D10).
- An unfulfilled secret MUST fail concreteness checking with no OPM tooling involved: both arms carry required fields, so an unsupplied secret is non-concrete and `cue vet -c` names it by path.
- Render-time values MUST hold the `#SecretRef` arm at every secret path (D11, D16). `#SecretLiteral` is a pre-resolution shape only; the kernel rewrites it in place to the reference it resolves to.

### Rationale

- **Why the disjunction survives while the routing leaves.** D1 removed both and D10 restored the narrowed type: the disjunction is the only part of a secret CUE itself can type-check, and it is the deployer's only slot for saying "this object already exists". Every replacement surface measured worse — an attribute argument bakes a cluster fact into a published module, a scheme-prefixed string makes the kernel parse semantics out of user data (D10).
- **Why routing must not live in the value.** With routing in the value it gets stated twice — once as `$`-fields, once as a hand-written `spec.secrets` map — and nothing checks agreement. The fleet's one secret-carrying module (`modules/metallb`) exhibits exactly this drift hazard today, plus a live env-vs-volume object-name mismatch derived from the same declaration ([`../01-problem.md`](../01-problem.md)). Removing the second statement makes the drift unrepresentable (D10, D5).
- **Why both arms are structs.** Kind stability: a module vets standalone in either arm, with or without the kernel. It also means instance files for supplied secrets do not change at all — `{value: "…"}` is already what deployers write — and a secret interpolated into a rendered string (`"password=\(#config.db.password)"`) becomes a struct-in-string error at plain `cue vet`, at authoring time (D10, D11).
- **Why exactly two arms.** They differ in *who owns the data*, which changes what the operator must supply. Backends (ESO, SealedSecrets, CSI) are a platform choice resolved through catalog subscription, never an arm of the author-facing type (D7, D8).

---

## `#SecretLiteral` (CHANGED vs core@v2 `src/schemas.cue`; no existing SPEC.md §)

### Definition

The supplied arm: the deployer has the data in hand and provides it inline. OPM materialises a Kubernetes Secret object to hold it, then restates the literal as a `#SecretRef` to that object before anything renders (D11). Unchanged in role from today's `#SecretLiteral`; changed in shape — it no longer embeds the `#SecretType` marker block.

### Shape

```cue
#SecretLiteral: {
    value!: string
}
```

Changed vs the current definition: the `#SecretType` embedding (and with it `$opm`, `$secretName`, `$dataKey`) is deleted. What remains is the one field that was always the deployer's to write.

### Constraints

- `value` is required and MUST be a string.
- The arm MUST NOT carry routing fields. Removed: `$opm`, `$secretName`, `$dataKey` (D10).
- A `#SecretLiteral` MUST NOT survive into the component graph or any rendered output: resolution replaces it with the `#SecretRef` naming the object the kernel materialises, and the plaintext leaves the pipeline out of band (D11, D16).

### Rationale

- **Why the shape shrinks to one field.** Everything else the arm carried was routing, and routing is the author's static declaration, not per-environment data. Moving it to the attribute leaves the arm holding exactly what only the deployer can know (D10).
- **Why instance files do not change.** `{value: "…"}` is byte-identical to what instances write today, so the migration is modules-only — pinned by `_assertMetallbValuesUnchanged` in [`examples.cue`](examples.cue) (D10).

---

## `#SecretRef` (NEW; replaces removed `#SecretK8sRef`)

### Definition

The referenced arm: the data lives in an object that already exists, and OPM materialises nothing — it wires a reference. `#SecretRef` is also the shape the kernel *writes* for a resolved literal, which is the design's central move: after resolution every secret path holds a `#SecretRef`, whichever arm the deployer wrote, and nothing downstream can tell the two apart (D11).

It replaces `#SecretK8sRef`, which is deleted. The fields are renamed: `secretName` → `ref`, `remoteKey` → `key` (D12).

### Shape

```cue
#SecretRef: {
    ref!: #ObjectNameType  // exact object name
    key!: #SecretKeyType   // key inside that object's data map
}
```

`#ObjectNameType` is core's existing RFC 1123 subdomain type (0019:D20). `#SecretKeyType` is new in core; see its section below.

### Constraints

- `ref` is required and MUST be a valid `#ObjectNameType`: a Secret's `metadata.name` is a DNS subdomain, not a DNS label. When the deployer writes it, the name is the pre-existing object's exact name and MUST NOT be instance-prefixed by OPM; when the kernel writes it, it is the group plan's computed object name (D5, D6).
- `key` is required and MUST match the Kubernetes Secret data-key charset. It need not equal the declared config key: the module names its own slot, the cluster names its own.
- The struct is closed and MUST NOT carry a `value` field. Absence of plaintext after resolution is structural: a resolved secret cannot hold data, rather than the kernel having to remember to strip it (D11).
- A deployer-written `#SecretRef` MUST pass through resolution unchanged (D11). Pinned in [`examples.cue`](examples.cue): the wildcard-certificate reference in `exResolvedProd` is byte-identical to what the deployer wrote.

### Rationale

- **Why `ref`/`key` rather than keeping `secretName`/`remoteKey`.** `secretName` collides with the removed `$secretName` and reads as "the name of the secret" when it means "the name of the object holding it". Supplied secrets — the overwhelming majority — already migrate with zero instance-file change under D10; the referenced arm is rare enough that the clearer names win (D12).
- **Why `ref` is an object name and not a `#NameType`.** Two writers fill it, and both overflow a DNS label. A deployer may reference a Secret named `tls.example.com`, which the API server admits and a label refuses. The kernel writes `{instance}-{group}`, two labels of up to 63 runes each, plus an 11-rune suffix when immutable: 138 runes at worst, against `#NameType`'s cap of 63. Under `#NameType` a legal 40-rune instance name with a 25-rune group would fail on the kernel's own output.
- **Why the struct is closed with no `value`.** It converts three classes of leak — a transformer reading `.value`, a string interpolation, a value-embedded error message — from silent plaintext into loud unification errors or unrepresentable states. The rejected `#SecretBase` coexistence alternative, which kept `value` alongside `ref`/`key`, demoted this property to convention (D11).
- **Why both arms converge on this shape.** One branch in every consumer: a transformer reads `.ref` and `.key` with no variant dispatch, replacing today's three discrimination techniques (`$opm` presence, `& #SecretLiteral != _|_`, structural sniffing) with none. And because the kernel writes the object name *into the value*, there is literally one string — the env-vs-volume name divergence live in the current catalog becomes unrepresentable (D11, D5).

---

## `@opm(secret, …)` field attribute — parsed form `#SecretMarker` (NEW)

### Definition

The routing half of a secret declaration: an inert CUE field attribute the module author writes on the declaring `#config` field. It states which Kubernetes Secret object the field's data lands in (`group`), under which key, with which object `type`, and whether the object is content-hash immutable — everything that is static, identical in every environment, and travels inside the published module. It never states where the data comes from; that is the type's job (D10).

An attribute is metadata attached to a field, not a field of its own, so `#SecretMarker` is not a value in any artifact and core evaluates nothing of it. It models the *parsed* form, what the kernel produces from every `opm` attribute on the field, so the argument grammar has one written-down contract that the Go parser and the docs both answer to. The kernel reads all of them (`cue.Value.Attributes`); `cue.Value.Attribute("opm")` returns only the first, which would hide a `secret` marker behind any other `@opm` kind. It is specified alongside `#Secret` because the two together are the declaration surface for a sensitive field.

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
- Every argument past position 0 MUST be optional and derivable; `@opm(secret)` is the intended common case. `group` defaults to `secrets`, `key` to the config path folded into the key charset, `type` to `Opaque`, `immutable` to `false` (D2, and `#DeriveKey` in [`target.cue`](target.cue)). The fold is readable but not injective (`db.password` and a sibling `db_password` both give `db_password`), so two members of one group that land on the same key MUST be rejected, naming both paths (`#GroupKeysUnique`). Nor is it total: a path whose fold passes 253 runes, or folds to nothing, has no default key, and that MUST be an error naming the path. An author resolves either case with `key=`.
- The parser MUST reject what it does not understand. An argument name other than `group`, `key`, `type`, `immutable` or `description` is an error (`grup=db` never falls back to the default group), and so is a repeated argument. Every argument is `name=value` with a non-empty value, so a bare `immutable` or an empty `immutable=` is an error; `immutable` takes exactly `true` or `false`. A value containing `,`, `)` or `"` MUST be quoted: unquoted, CUE splits it into a stray argument, which the unknown-argument rule then rejects.
- A field carrying two `secret` markers that disagree is a discovery error; identical markers collapse to one. Unification can place a marker from a definition and one from a use site on the same field.
- A list element has no field-attribute slot. A `[...#Secret]` list is discovered by its element type with default routing (D13). Element routing is written as a declaration attribute inside an element struct that embeds `#Secret`, `[...{#Secret, @opm(secret, group=tokens)}]`, which keeps the element's shape `#Secret`. The kernel reads `opm` field and declaration attributes both; a declaration attribute is honoured only on a struct embedding `#Secret` and is a discovery error anywhere else.
- A `secret` marker MAY only appear on a field typed `#Secret`: a marked field of any other type is a discovery error. Conversely a `#Secret`-typed field with no marker MUST be treated exactly as if it carried a bare `@opm(secret)` (D13). The marker is pure routing override; it is never load-bearing for the security property.
- All fields sharing a `group` MUST agree on `type` and on `immutable` — both are properties of the one object the group becomes; a group whose members disagree is rejected.
- A marker MUST NOT name a backend. Materialisation is a platform choice resolved through catalog subscription, never an author-side argument (D8).

### Rationale

- **Why an attribute and not a struct field.** Sensitivity routing is metadata about a field, not part of the field's data. Putting it in the value is what produced today's double statement and the unchecked drift between `$secretName` and the hand-written `spec.secrets` map (D1's diagnosis, retained through D10).
- **Why one `@opm` namespace with position-0 dispatch.** A dedicated `@secret(...)` starts a second OPM attribute namespace for the second marker OPM has ever wanted, and a third for the third. One namespace means one attribute name across OPM, one Go parse path, and a convention a reader learns once (D2).
- **Why discovery keys on the type and fails closed.** Under marker-only discovery, forgetting the attribute would leave a `#Secret` field invisible to the kernel and its `{value: …}` literal would flow into the component graph — plaintext in the render, silently. Keying on the type makes "secret-typed but unhandled" structurally impossible; the inverse check catches a marker on a field the fulfilment contract cannot type-check (D13).
- **Why no `provider=` argument.** The same published module must deploy to an ESO cluster and a plain one without republishing; the author does not know which they will hit. Backends extend through catalogs, the extension point OPM already has (D8).

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

## `#SecretObjectType` (NEW; named from the inline set in removed `#SecretSchema`)

### Definition

The closed set of Kubernetes Secret `type` values OPM materialises. Core carries a wider set today, inline in `#SecretSchema.type`, which is deleted. This names the part of it OPM can actually create.

### Shape

```cue
#SecretObjectType: "Opaque" | "kubernetes.io/dockercfg" | "kubernetes.io/dockerconfigjson" |
    "kubernetes.io/basic-auth" | "kubernetes.io/ssh-auth" | "kubernetes.io/tls"
```

### Constraints

- A marker's `type=` argument MUST be a member of this set. `kubernetes.io/service-account-token` and `bootstrap.kubernetes.io/token` are excluded: the first needs annotations bound to a live ServiceAccount, the second is only read from `kube-system`. Either can still be consumed through a deployer-written `#SecretRef`, which carries no type.
- A typed group MUST carry the data keys its type requires: `tls.crt` and `tls.key` for `kubernetes.io/tls`, `ssh-privatekey` for `ssh-auth`, `.dockercfg` and `.dockerconfigjson` for the two registry types, and `username` or `password` for `basic-auth`. The default key fold never produces these, so a typed group's members set `key=`.
- All members of one group MUST agree on it; the kernel rejects a group that disagrees.

### Rationale

- **Why name it in core.** Two parties read the set: the kernel, when it parses `type=`, and each backend catalog's materialising transformer (D8). If each keeps its own copy, a marker can pass the kernel and fail at the catalog. Naming it once, upstream of both, is the same reasoning that keeps `#Secret` in core (D12).

---

## Removed definitions (deletions from core@v2 `src/schemas.cue`)

Not constructs but part of the spec delta: `core` loses its entire legacy secret block. Deleted, with no aliases and no transition shims (D9, amended by D12):

| Definition | Disposition |
| --- | --- |
| `#SecretType` (the `$opm` / `$secretName` / `$dataKey` block) | Deleted — routing moves to the attribute (D10) |
| `#SecretK8sRef` | Deleted — replaced by `#SecretRef` (D12) |
| `#SecretSchema` | Deleted from core — the Kubernetes Secret *object* shape stays in `catalog_opm`, with `data` narrowed to `string` (D12) |
| `#SecretContentHash`, `#SecretImmutableName` | Deleted — content-hash naming moves to the kernel, the only party that can still see the data after resolution (D5) |
| `#AutoSecrets`, `#DiscoverSecrets`, `#GroupSecrets` | Deleted — the discovery pyramid has no call site anywhere in the workspace, walks only structs, and stops at ten levels; discovery becomes a kernel walk with no depth ceiling (D9, D3) |

`#ContentHash`, `#ConfigMapSchema`, and `#ImmutableName` are unaffected and stay in core.

Why delete rather than deprecate: the old and new shapes cannot coexist cleanly — `#EnvVarSchema.from` would have to accept both, reintroducing exactly the structural sniffing the design removes — and core's copy is already dead code that ships to every consumer while `SPEC.md` §1 (now corrected) misdescribed it (D9). Why `#Secret` itself nonetheless stays in core as the single definition: every catalog and every module needs the same fulfilment contract, and defining it once, upstream of all of them, is what stops the current core/catalog duplication from diverging again (D12).

---

## Not core surface

The remaining top-level definitions in [`target.cue`](target.cue) are modelling aids for the kernel pass — behaviour contracts the `library` implements in Go (`opm/secret/`), not proposed `opmodel.dev/core` schema. They are listed here so the spec delta's boundary is explicit:

- **`#SecretDecl`, `#SecretDeclList`, `#DeriveKey`, `#GroupKeysUnique`**: Discover's output, its default-key derivation, and the per-group key-uniqueness check that makes the lossy derivation safe; discovery reads the module's `#config` schema, not values (D3, D13).
- **`#SecretGroupPlan`, `#ObjectName`, `#ContentHash` (target.cue's kernel-side statement), `#ImmutableObjectName`** — group planning and the single naming authority `{instance}-{group}`, with the content-hash suffix computed before the rewrite (D5, D6).
- **`#ResolveInPlace`, `#SecretsResolution`** — the rewrite's pre/postcondition and the pass's one named result; implemented as omission at build assembly, one component-graph build, decode → splice → encode (D11, D16, D17).
- **`#SynthesizedSecretsComponent`, `#MaterializedSecret`** — the component the kernel synthesises to carry plans into the ordinary transformer pipeline, with `#secretsResourceFQN` as an input supplied by the platform's materialized catalogs, never a literal in core (D8, resolving enhancement 0010 OQ9 along its candidate (b)).
- **`#NameType`, `#ObjectNameType`**: verbatim restatements of existing core types, so the delta compiles standalone.
- **`#FQNType`**: a simplified local stand-in for core's `#ContractFQNType | #ImplFQNType`, present only so the delta compiles.
- **`#SecretTypeRequiredKeys`**: the data keys the API server requires per typed Secret, applied to every group plan.
- **`#ConfigPathType`, `#ConfigPathPatternType`**: the kernel's join key. A concrete path in CUE's own printed syntax, with quoted labels for non-identifier map keys (`extraSecrets."api-token"`), and a declaration form that may carry `[_]` for any key of a pattern map or any list element.
