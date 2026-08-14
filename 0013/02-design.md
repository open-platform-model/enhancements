# Design — Attribute-Declared Secret Fields

This document answers the question: "What is the proposed solution and how does it work?" Trade-off reasoning lives in [`03-decisions.md`](03-decisions.md); the full CUE surface lives in [`schemas/target.cue`](schemas/target.cue) with worked values in [`schemas/examples.cue`](schemas/examples.cue).

## Design Goals

- A secret's **routing** is stated once, on the field that declares it, and cannot drift from a second statement because there is no second statement.
- A secret's **fulfilment** is chosen by the deployer, per environment, and is type-checked by CUE rather than by OPM tooling.
- The same published module deploys against a supplied value in one environment and a pre-existing cluster object in another, with no republish.
- A Kubernetes Secret object's name is computed once, by one authority, and every consumer reads the same string.
- Secret plaintext never enters the component graph, so it cannot be rendered or logged by accident. (What a deployer chooses to write *into* a `ModuleInstance` CR is a frontend seam, stated honestly — D15.)
- A field that *is* a secret cannot be missed: discovery keys on the type as well as the marker, so forgetting the attribute degrades to default routing, never to a leak (D13).
- A deployer can keep supplied values encrypted at rest with SOPS: the file to encrypt is generatable from the module alone, and decryption happens at the CLI seam with no kernel involvement (D14).
- A secret that reaches a position the target cannot express as a reference is rejected at authoring time, by CUE, before the kernel is involved.
- Discovery has no depth ceiling and no blind spots for lists or pattern-constrained maps.
- Tooling can list a module's required secrets from the module alone, before any instance exists.
- Which secret **backend** materialises a supplied secret is a platform choice, extensible by publishing a catalog — not a kernel recompile and not an author decision.

## Non-Goals

- **Implementing cryptography.** SOPS support (D14) is in scope, but OPM ships no cipher code: the `getsops/sops/v3` library does encrypt/decrypt at the CLI seams, cluster-side decryption belongs to Flux, and key management (age keys, KMS) is deployer configuration. Export-side encryption of rendered Secret manifests rides enhancement 0014's export surface.
- **Protecting supplied-arm values inside a `ModuleInstance` CR.** A literal in a CR is plaintext in etcd — accepted and documented, with the referenced arm as the production posture on the operator path; no `valuesFrom` mechanism is added (D15).
- **Shipping an ESO / Vault / CSI backend.** The extension mechanism is in scope; additional backends are not. Two fulfilment arms ship (D7, D10).
- **Rotation, leasing, or dynamic secrets.** A secret is resolved once per render.
- **Retiring `#SecretSchema` / the secrets resource.** Modules that compute a whole file and want it stored as Secret data keep writing it by hand; that path is unaffected.
- **A general-purpose `@opm(...)` marker framework.** This entry defines the `secret` marker and reuses the existing namespace.

## High-Level Approach

The design rests on one split, and the split is the whole idea:

| | carries | written by | when | mechanism |
| --- | --- | --- | --- | --- |
| `@opm(secret, …)` | **routing** — group, key, type, immutable | module author | authoring | inert CUE attribute |
| `#Secret` | **fulfilment** — the data, or where it lives | deployer | per environment | CUE disjunction |

The author states *which object a key belongs in*. They never state *where the data comes from* — they cannot know it, and a published module that asserted it would stop being portable. The deployer states the opposite and knows nothing about grouping.

An author writes:

```cue
#config: db: password: #Secret @opm(secret, group=db-creds, key=password)
```

A deployer writes one of:

```cue
values: db: password: {value: "hunter2"}                              // supplied
values: db: password: {ref: "existing-db-creds", key: "password"}     // referenced
```

CUE attributes are metadata that "do not influence the evaluation of CUE" (language spec). They travel with the field through unification, through the `#Module` / `#ModuleInstance` shape, and across CUE module imports — measured in [`experiments/01-attribute-propagation`](experiments/01-attribute-propagation/), not assumed.

### The two arms are two statements about one secret

```
#SecretLiteral  {value}      says WHAT the data is       — the deployer has it
#SecretRef      {ref, key}   says WHERE the data lives   — the cluster has it
```

For a literal, the kernel's entire job is to **turn a *what* into a *where***: decide which object holds the data, name that object, and put the data there. Once it has done that, the literal *also* has a location — so it can be restated as a `#SecretRef`.

That restatement is the design's central move.

### Resolve in place

The kernel runs two phases.

**Discover** walks the module's `#config` schema and returns one `#SecretDecl` per marked field. It reads the schema, not the values, because that is where the marks live (D3). Consequences fall out for free: no values are needed, so `opm module inspect` can list a module's secrets from the module alone; and the walk is ordinary Go recursion, so there is no depth ceiling and lists and pattern-constrained maps are covered.

Discovery keys on the type as well as the marker, and fails closed (D13): a field typed `#Secret` with no attribute is discovered with all-default routing (as if it carried a bare `@opm(secret)`), and a `secret` marker on a field not typed `#Secret` is a Discover error. Forgetting the mark can therefore never leak a literal into the graph — the marker only ever *overrides* routing, it never gates the security property.

**Resolve** groups the declarations, computes each object's final name exactly once, sends the plaintext out of band into a `#SecretGroupPlan`, and **rewrites every marked path in the render-time values to a `#SecretRef`** — whichever arm the deployer wrote. A literal becomes a reference to the object the kernel just decided to create; a deployer-written reference passes through as itself.

After that rewrite the two arms are indistinguishable, and the component graph contains no plaintext:

```
values (deployer)                    resolved values (render)
─────────────────                    ────────────────────────
db.password:  {value: "hunter2"}  ─► {ref: "myapp-db-creds", key: "password"}
tls.cert:     {ref: "wildcard",    ─► {ref: "wildcard",       key: "tls.crt"}
               key: "tls.crt"}
                                          │
                                          ▼
                         a transformer reads two fields, one branch:
                           valueFrom: secretKeyRef: {
                             name: e.from.ref
                             key:  e.from.key
                           }
```

The author's wiring is unchanged: `from: #config.db.password` still works, because by render time that reference holds the resolved `#SecretRef`.

### What this buys

**One name, in one place.** The kernel writes the object name into the value, so there is literally one string and every consumer reads it. The three divergent name derivations in `catalog_opm` today — including the live env-vs-volume mismatch — become unrepresentable rather than merely fixed (D5, D11).

**No variant dispatch anywhere.** Today the codebase discriminates the two kinds three different ways (`$opm` presence, `& #SecretLiteral != _|_`, and structural sniffing). After resolution nothing downstream can tell them apart, so the count goes to zero.

**Leaks caught by CUE, at authoring time.** A secret interpolated into a rendered file —

```cue
files: "app.conf": "password=\(#config.db.password)"
```

— is a struct-in-string error at plain `cue vet` against `debugValues`, before the kernel exists at all. The author cannot write it and have it vet.

**Instance files for supplied secrets do not change.** `{value: "…"}` is already what people write today. The migration is modules-only.

### Modularity

The current design conflates two decisions. This one separates them.

**The attribute is author intent** — this field is sensitive, and here is how it groups. True on every platform.

**Materialisation is a platform choice** — whether a supplied secret becomes a plain Kubernetes Secret, a SealedSecret, an ESO `ExternalSecret`, or a CSI mount. The module author must *not* pick this; they do not know whether the target cluster runs ESO.

So the extension point is the one OPM already has. The kernel synthesises a secrets component from the resolved plans and matches it against the platform's materialized catalogs by exact FQN, exactly like every other component. A third party extends the system by publishing a catalog whose transformer requires that resource. No new mechanism, no kernel recompile, no author-visible change.

The FQN comes from the platform, never from a literal. This answers enhancement 0010's still-open **OQ9** — its candidate (b), "have the synthesis take the secrets FQN as an input supplied by the platform's materialized catalogs rather than as a literal". It is natural here because the kernel is already the party doing discovery and already holds the platform, which was not true of the `core`-side synthesis that `7500c5d` removed.

## Schema / API Surface

Full surface in [`schemas/target.cue`](schemas/target.cue). The headline shapes:

- **`#Secret` / `#SecretLiteral` / `#SecretRef`** — the fulfilment contract, six lines, living in `core` (D12). `#SecretRef` is closed and has no `value` field, so absence of plaintext after resolution is *structural* rather than something the kernel must remember to strip.
- **`#SecretMarker`** — the *parsed* form of the attribute. Grammar: `@opm(secret [, group=<name>] [, key=<key>] [, type=<k8s-type>] [, immutable] [, description=<text>])`. Position 0 is the marker kind, matching the `@opm(identity, owner=publish)` form enhancement 0011 D5 already uses. Every argument past position 0 is optional and derivable; `@opm(secret)` is the intended common case. Not a value in any artifact — an attribute is metadata attached to a field, not a field — it exists so the argument grammar has one written-down contract.
- **`#SecretDecl`** — Discover's output: `path`, parsed `marker`, resolved `key`. `key` defaults to the config path with separators folded to underscores (`#DeriveKey`), which is collision-free because the path is unique — `db.password` and `redis.password` cannot both become `password`.
- **`#SecretGroupPlan`** — one object OPM will write: group, final `objectName`, agreed `type` and `immutable`, `data`, and the `members` that fed it. Literals only.
- **`#ObjectName` / `#ContentHash` / `#ImmutableObjectName`** — the naming derivations, all kernel-side. The hash is computed *before* the rewrite, so a member's resolved `ref` already carries the suffix and every consumer follows the object when the data changes.
- **`#ResolveInPlace`** — the rewrite, stated as a pre/postcondition: in, every declared secret in either arm; out, the same paths all in the `#SecretRef` arm.
- **`#SecretsResolution`** — the whole pass's result, so the phases have one named return rather than several loose ones.
- **`#SynthesizedSecretsComponent`** — what the kernel builds to carry the plans into the ordinary pipeline, with `#secretsResourceFQN` as an **input** supplied by the platform.

Notably absent, and deliberately: any addition to `#TransformerContext`. Because the object name travels inside the value, `core` needs **no** new field (D11).

## Integration Points

### `core` (`opmodel.dev/core@v1`)

| Target | Change |
| --- | --- |
| `src/schemas.cue` | **Narrow** `#Secret` to `#SecretLiteral \| #SecretRef` (six lines). **Delete** `#SecretType`, `#SecretK8sRef`, `$opm`/`$secretName`/`$dataKey`, `#SecretSchema`, `#SecretContentHash`, `#SecretImmutableName`, `#AutoSecrets`, `#DiscoverSecrets`, `#GroupSecrets`. Keep `#ContentHash`, `#ConfigMapSchema`, `#ImmutableName`. |
| `src/transformer.cue` | **No change.** |
| `SPEC.md` §1 | **Correct** the Primitives sentence: `#Secret` is a type, not a Primitive — it has no `metadata`, no `fqn`, no version. Co-update gated by the pre-commit hook and CI; load `core-schema-edit` before touching `src/*.cue`. |
| `src/INDEX.md` | Regenerate (`task generate:index`). |
| `.claude/skills/core-schema-edit/SKILL.md:13` | **Remove** stale helper names `#OpmSecretsComponent`, `#SecretsResourceFQN` (already deleted) and the removed secret helpers. |

### `library` (the kernel)

| Target | Change |
| --- | --- |
| `opm/secret/` | **New package.** `Discover(configSchema cue.Value) ([]Decl, error)` and `Resolve(decls, values, instanceName) (*Resolution, error)`, where `Resolution` carries the rewritten values, the group plans, and the unfulfilled list. |
| `opm/schema/paths.go` | Reuse `Config` (`cue.MakePath(cue.Def("config"))`) as the discovery root — already defined and already used by `kernel.Validate`. |
| `opm/schema/context.go` | **No change.** |
| `opm/kernel/phases.go` | **Wire** Discover → Resolve before the component build. `Validate` keeps running against the *supplied* values, unchanged — see OQ2 for whether this needs a second build. |
| `opm/kernel/synth.go` | **Synthesise** the secrets component from the plans, with the resource FQN drawn from the materialized platform. |
| `opm/compile/execute.go` | **New diagnostic:** catch the "module read `.value` of a resolved secret" error and re-report it against the config path (see `05-risks.md`). |

### `catalog_opm` (`opmodel.dev/catalogs/opm@v1`)

| Target | Change |
| --- | --- |
| `src/resources/secret.cue` | **Delete** the duplicated contract type and the discovery pyramid; import `#Secret` from core (D12). Keep `#SecretsResource`, `#Secrets`, `#SecretSchema`, `#SecretDefaults` for the hand-authored path, with `data` narrowed to `string`. |
| `src/transformers/container_helpers.cue:52-89` | **Replace** `$secretName`/`$dataKey` dispatch with a two-field read of `.ref` / `.key`. |
| `src/transformers/container_helpers.cue:368-388` | **Replace** the volume-side name computation with a read of `.ref`. Deletes the second derivation. |
| `src/transformers/secret_transformer.cue:63-66` | **Delete** the `opm-secrets` branch and all name computation; render `spec.secrets` entries verbatim. |
| `src/resources/container.cue:109` | `#EnvVarSchema.from` stays typed `#Secret` — now core's narrowed one. |
| `src/INDEX.md` | Regenerate (`task generate:index`). |

### `modules`

| Target | Change |
| --- | --- |
| `metallb/module.cue` | `memberlistKey` becomes `#Secret @opm(secret, group=memberlist, key=secretkey)`. |
| `metallb/components.cue:374-378` | **Delete** the hand-written `spec.secrets` map. |
| `metallb/components.cue` RBAC | Rendered object name changes `metallb-speaker-memberlist` → `metallb-memberlist`; the `resourceNames` scoping must move with it. |
| Instance values | **No change** — `{value: "…"}` is already the shape. |
| `DESIGN_PATTERNS.md:84-110` | Rewrite the `schemas.#Secret` pattern section. |

### `cli`

| Target | Change |
| --- | --- |
| `tests/fixtures/valid/secrets-module/module.cue` | Port to the attribute form. |
| `openspec/specs/auto-secrets-injection/spec.md` | Already marked Superseded and pointing at the retired `v1alpha1/`; retire the spec. |
| `opm module inspect` | **New output section** listing declared secrets, their groups and keys, and which are unfulfilled. |
| `opm secrets template` | **New command** (D14). Walks Discover with no values present; emits a skeleton values file (YAML/JSON) containing exactly the marked paths, ready to populate and encrypt with `sops -e`. |
| `opm module vet` | **Secrets-aware messaging** (D14). Intercept CUE incompleteness errors at marked paths; report one grouped "unfulfilled secrets" list naming each path, group, and key, pointing at `opm secrets template`. |
| Values input | **SOPS decrypt** (D14). Accept a SOPS-encrypted values file, decrypted via the `getsops/sops/v3` library before values enter the kernel. The kernel contract is unchanged. |

## Before / After

Same metallb secret as `01-problem.md`. Both shapes compile in [`schemas/examples.cue`](schemas/examples.cue) as `exMetallbBefore` and `exMetallbAfter`.

**Before** — four statements, two of which must agree and are not checked:

```cue
// module.cue
memberlistKey: res.#Secret & {$secretName: "memberlist", $dataKey: "secretkey"}
// components.cue
secrets: memberlist: data: secretkey: #config.speaker.memberlistKey
// instance values
speaker: memberlistKey: value: "BASE64GOSSIPKEY"
```

**After** — one statement, and the instance is untouched:

```cue
// module.cue
memberlistKey: #Secret @opm(secret, group=memberlist, key=secretkey)
// instance values — byte-identical to before
speaker: memberlistKey: value: "BASE64GOSSIPKEY"
```

`components.cue` loses the `spec.secrets` map outright and keeps only the volume that mounts it. `examples.cue` pins the unchanged instance values with `_assertMetallbValuesUnchanged`.

The wider example in `examples.cue` (`#ExampleConfig` onward) walks the whole grammar on one config — a derived-everything secret, a `kubernetes.io/basic-auth` group, an immutable TLS group, a twelve-level nested secret, and a pattern-constrained open map — then shows what Discover returns with no values present, **the same module fulfilled two different ways** (`exValuesDev` supplies the TLS pair inline, `exValuesProd` references a platform-managed wildcard certificate), the resolved plans, the rewrite in which both arms converge (`exResolvedProd`), and both consumption sites reading the same string (`_assertVolumeAgreesWithEnv`).
