# Design Decisions — Attribute-Declared Secret Fields

This document records every significant design choice with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. The log is **append-only** — never remove or renumber existing entries. If a decision is reversed, add a new decision that supersedes it (e.g. "D8 supersedes D3") and leave D3 in place as historical context.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source. The Source field is specific — `"User decision YYYY-MM-DD"`, a URL, or a file path — so the provenance of a choice never gets lost.

Several decisions below cite `experiments/01-attribute-propagation` and `experiments/02-resolve-in-place`. Those experiments measured CUE behaviour against the real `opmodel.dev/core@v1` schema; where a decision says a thing is or is not possible, it was run rather than reasoned about.

**D1 and D4 were superseded on the day they were written**, by D10 and D11, during the review that followed the first draft. They are retained in full because the reasoning that replaced them only makes sense against what they said, and because their rejected alternatives are still rejected for the reasons recorded there. The short version: D1 removed the `#Secret` contract type *and* the disjunction inside it, when only the routing metadata needed to move to the attribute. The disjunction was doing legitimate work — it is the fulfilment slot, and the only part of a secret CUE itself can type-check. D4's handle machinery existed to compensate for having thrown it away.

---

## Decisions

### D1: A sensitive field is marked with a CUE field attribute, not typed with a contract struct

**Decision:** Module authors mark a `#config` field sensitive by writing `@opm(secret, …)` on it. The field keeps its natural type (`string`), and `#Secret`, `#SecretLiteral`, `#SecretK8sRef`, and the `$opm` / `$secretName` / `$dataKey` meta-fields are removed. No `value:` wrapper is introduced on the values side.

**Alternatives considered:**

- **Keep the contract type and add cross-validation** comparing `$secretName` against the hand-written `spec.secrets` map key. Rejected: it closes the drift but leaves the field typed as a struct rather than the scalar it is, leaves plaintext in the render, leaves the definition duplicated across two published CUE modules, and adds a fourth thing to keep in sync rather than removing the second.
- **A parallel `#secrets:` block on `#Module`** listing sensitive paths as strings. Rejected: stringly-typed paths get no CUE checking, so a typo or a renamed config field fails silently — the same class of failure the current design already has.
- **A naming convention** (`passwordSecret`, `*_secret`). Rejected: unenforceable, collides with legitimate names, and carries no room for grouping or key overrides.

**Rationale:** Sensitivity is metadata about a field, not a change to what the field *is*. CUE attributes are exactly that — the language spec defines them as "meta information … [that] do not influence the evaluation of CUE". Marking rather than wrapping keeps `#config` readable as a schema, keeps instance values as plain data, and removes the whole `$`-field vocabulary.

**Source:** User decision 2026-07-27 ("I want to redesign the secret field from using a #Secret definition to use a @opm() metadata attribute").

---

### D2: The marker reuses the existing `@opm(...)` namespace, dispatched on position 0

**Decision:** The attribute name is `opm` and the first positional argument names the marker kind: `@opm(secret, …)`. Remaining arguments are `key=value` pairs specific to that kind. Unknown position-0 values are ignored by the secret pass.

**Alternatives considered:**

- **A dedicated `@secret(...)` attribute.** Rejected: it starts a second OPM attribute namespace for the second marker OPM has ever wanted, and a third for the third. One namespace with a dispatch slot scales; a name per concept does not.
- **`@opm(kind=secret, …)` with no positional slot.** Rejected: more to type in the common case, and it diverges from the form already in use.

**Rationale:** Enhancement 0011 D5 already establishes `@opm(identity, owner=publish)` for tool-owned identity fields, with the same shape — kind in position 0, key/value pairs after. Following it means one attribute name across OPM, one parse path in Go, and a reader who learns the convention once. Measured in experiment 01 that `Attribute.String(0)` cleanly separates `secret` from `identity` on a shared name, and that a field may carry `@opm(...)` alongside unrelated attributes without interference.

**Source:** Design proposal 2026-07-27, following the precedent in `enhancements/0011/02-design.md` and `enhancements/0003/experiments/06-identity-supply-mechanisms/`.

---

### D3: Discovery reads the module's `#config` schema, not the instance's values

**Decision:** The kernel's Discover phase walks `#module.#config` (`library/opm/schema/paths.go` `Config`). It never looks for marks in `values`.

**Alternatives considered:**

- **Walk the instance's `values`.** Rejected because it does not work: measured in experiment 01, the `values` vertex carries only its own conjunct, so an attribute declared in `#config` is absent there. The unified config is not addressable from a `#ModuleInstance` either — `let unifiedModule = #module & {#config: values}` is a let binding, invisible from outside.
- **Add an addressable unified-config field to `#ModuleInstance`** and walk that. Rejected: a breaking core change to obtain something the schema side already gives, and it would expose secret plaintext at a new addressable path — the opposite of what D11 is for.

**Rationale:** Attributes belong to the field that declares them, which is in `#config`. Reading the schema also buys two things for free: discovery works with no values present, so tooling can list a module's required secrets before anyone has fulfilled them (measured); and the join back to data is by config path, which is the same key fulfilment is expressed against.

**Source:** `experiments/01-attribute-propagation` (E3, E8), 2026-07-27.

---

### D4: The kernel substitutes an opaque handle for every marked value before components are built

**Decision:** Before the component graph is constructed, the kernel rewrites the render-time values so every marked path holds a `#SecretHandle` (`opm:secret:v1:<10 hex>`, SHA-256 of the config path) instead of its plaintext. The kernel retains the plaintext out of band. Transformers resolve handles through `#TransformerContext.secrets`.

**Alternatives considered:**

- **Let the reference carry the mark.** Rejected because it does not work: measured in experiment 01, `env: FOO: from: #config.db.password` produces a field with no attribute — a mark does not travel through a reference. Without substitution a transformer cannot distinguish a secret from any other string.
- **Have the author name the config path at the wiring site** (`from: "db.password"`). Rejected: stringly-typed, loses CUE's reference checking, and is worse ergonomics than what authors write today.
- **Post-process the render by matching plaintext values.** Rejected as actively dangerous: a secret whose value is `"true"` or `"admin"` would rewrite every unrelated occurrence of that string.
- **Substitute a struct rather than a scalar.** Rejected: the field is typed `string` under D1, so a struct does not unify.

**Rationale:** Substitution is the only mechanism that both preserves the author's existing ergonomics (`from: #config.db.password` is unchanged) and gives transformers something they can recognise. It also delivers two properties nothing else does: plaintext never enters the component graph, and a handle that survives into rendered output is *detectable* by substring scan — the case that is silently plaintext today. Handles are derived from the path rather than assigned positionally so renders stay byte-identical and reordering `#config` does not churn output.

**Source:** `experiments/01-attribute-propagation` (E3 — a reference carries neither the mark nor a way to recognise the value), 2026-07-27. The handle prototype that validated this decision was rebuilt as `experiments/02-resolve-in-place` when D11 replaced it, so the handle measurements are not preserved in the tree.

---

### D5: Secret object naming is owned solely by the kernel

**Decision:** The Kubernetes object name for a secret is computed exactly once, by the kernel, during resolution. No transformer computes a name; every consumer reads the one string the kernel produced. How that string reaches consumers is a separate question, settled by D11.

**Alternatives considered:**

- **Keep name computation in the transformers and fix the three formulas to agree.** Rejected: it repairs today's instance of the bug and leaves the mechanism that produced it — three derivations in two files, which drifted once and would drift again.
- **Keep the derivation in CUE but funnel every call site through one shared helper.** Rejected because that is already the situation and it did not hold: `catalog_opm` has `#SecretImmutableName`, and both consumption sites call it — with *different inputs*. `container_helpers.cue:374` passes `{instance}-{component}` while `:78` builds `{instance}-{$secretName}` itself. A shared helper only guarantees agreement if every caller agrees on what to feed it, which is the thing that cannot be enforced from inside CUE.

**Rationale:** Three independent derivations of one name is the root cause of the live mismatch in `01-problem.md`. Collapsing them to one authority does not so much fix the bug as make it unrepresentable — the volume site and the env site necessarily read the same string, and `schemas/examples.cue` pins that with `_assertVolumeAgreesWithEnv`. It also relocates content-hash immutable naming to the only party that can still see the data, since transformers no longer can.

**Source:** Design proposal 2026-07-27, motivated by `catalog_opm/src/transformers/secret_transformer.cue:64-65` vs `container_helpers.cue:78` vs `:374-379`.

---

### D6: OPM-owned Secret objects are instance-scoped and group-named, not component-scoped

**Decision:** An OPM-materialised Secret object is named `{instance}-{group}`, where `group` defaults to `secrets`. The component that happens to consume a secret plays no part in the name. The `opm-secrets` special-case component name is removed.

**Alternatives considered:**

- **Keep component scoping** (`{instance}-{component}-{group}`). Rejected: a Kubernetes Secret is a namespaced object, not a component-owned one. Component scoping forces duplicate objects when two components share a secret, and it is exactly what makes the current env-vs-volume formulas disagree.
- **Keep the `opm-secrets` magic component name** as the un-prefixed branch. Rejected: nothing has produced a component with that name since `core 7500c5d`, so the branch is unreachable and the branch it falls through to is the one the env path does not use.

**Rationale:** Grouping is the author's declared intent about which keys share an object; the component is an implementation detail of who reads it. Naming by instance and group means two components of one instance referring to one group necessarily reach one object.

**Source:** Design proposal 2026-07-27.

---

### D7: Two fulfilment kinds ship — supplied and referenced

**Decision:** `#SecretSource` has exactly two members. `#SuppliedSecret` carries a plaintext value the instance provides and causes OPM to materialise an object. `#ReferencedSecret` names a pre-existing object and remote key, and causes OPM to materialise nothing and wire a reference. No third kind ships in this enhancement.

**Alternatives considered:**

- **Ship an ESO / external-secret-store kind now.** Deferred: RFC-0002 sketched `#SecretEsoRef` and it was never built. D8 makes it a catalog concern rather than a schema concern, so shipping it here would prejudge an extension the mechanism now supports properly.
- **Ship only the supplied kind** and treat existing objects as out of scope. Rejected: referencing a cluster-managed Secret — a wildcard TLS certificate, a shared pull credential — is the common case in every real deployment.

**Rationale:** These are the two kinds the current design already implements, so the enhancement can be judged on the redesign rather than on new capability. They are also genuinely distinct in a way a backend is not: they differ in *who owns the data*, which changes what the operator must supply.

**Source:** User decision 2026-07-27 ("The two first ones i want are what the current solution already does: 1. plain string … 2. k8s secret path and key reference").

---

### D8: How a supplied secret is materialised is a platform choice, resolved through catalog subscription

**Decision:** The attribute expresses author intent — this field is sensitive, this is its group and key — and nothing about backends. The kernel synthesises a secrets component from the resolved plans and matches it against the platform's materialized catalogs by exact FQN, like any other component. A third party adds a backend (SealedSecrets, ESO, CSI) by publishing a catalog whose transformer requires that resource. The `#secretsResourceFQN` is an input supplied by the platform, never a literal in core or in this schema.

**Alternatives considered:**

- **A Go plugin registry in the kernel** (`RegisterSecretProvider("eso", impl)`). Rejected: extension would require recompiling the kernel, which contradicts the catalog model every other OPM primitive extends through.
- **A backend argument on the attribute** (`@opm(secret, provider=eso)`). Rejected: it puts a cluster-infrastructure decision in a published module. The same module should deploy to an ESO cluster and a plain one without republishing, and the author does not know which they will hit.
- **Hardcode the secrets resource FQN in core**, as before `7500c5d`. Rejected: a catalog stamps its own version into every FQN it publishes, so the constant went stale the moment the catalogs moved to `@v1`, and the synthesised component then matched no transformer at all.

**Rationale:** Separating author intent from platform choice is what makes the design modular in the way that matters. It also resolves enhancement **0010 OQ9** along that question's own candidate (b): the synthesis takes the FQN from the platform's materialized catalogs rather than a literal. That was impractical when the synthesis lived in `core` — core does not hold a platform — and is natural here, because the kernel already does the discovery and already holds the platform.

**Source:** Design proposal 2026-07-27; problem framing from `enhancements/0010/03-decisions.md` OQ9 and `core/SPEC.md:521`.

---

### D9: The dead and duplicated secret machinery is deleted, not deprecated

**Decision:** `core/src/schemas.cue` loses its entire secret block, and `catalog_opm/src/resources/secret.cue` loses the duplicate. No aliases, no transition shims. `#SecretsResource` / `#SecretSchema` survive in the catalog for hand-authored Secret data, with `data` narrowed from `#Secret | string` to `string`.

**Alternatives considered:**

- **Deprecate with a transition window,** keeping both shapes valid for a release. Rejected: the two shapes cannot coexist cleanly, because `#EnvVarSchema.from` would have to accept both a struct and a handle string, which reintroduces exactly the structural sniffing D1 removes.
- **Leave core's copy in place** since nothing references it. Rejected: it ships to every consumer of `opmodel.dev/core@v1`, and `SPEC.md` documents it as a Primitive it is not — so leaving it means publishing a contract that describes something untrue.

**Rationale:** Core's copy is already dead: no file under `core/src/*.cue` references it. The catalog's copy has one consumer shape and one fleet module. Deleting is cheaper than a compatibility window nobody needs — `cli` has no external users, so no deprecation is owed, and `modules/metallb` is the only artifact to migrate.

**Source:** Design proposal 2026-07-27; dead-code finding verified by grep across `core`, `catalog_opm`, `modules`, `library`, `cli`.

---
### D10: The secret field is typed `#Secret`, a two-arm disjunction; the attribute carries routing only

**Supersedes D1.** Closes **OQ1**.

**Decision:** A sensitive `#config` field is declared as `#Secret @opm(secret, …)`. The contract type returns, narrowed to a two-arm disjunction that carries *only* fulfilment:

```
#Secret:         #SecretLiteral | #SecretRef
#SecretLiteral:  {value!: string}
#SecretRef:      {ref!: string, key!: string}
```

All routing — `group`, `key`, `type`, `immutable`, `description` — lives in the attribute. `$opm`, `$secretName`, and `$dataKey` are removed. The deployer chooses the arm, per environment, in `values`.

Both arms are structs. The bare-scalar form (`string | #SecretRef`) was considered and rejected below.

**Alternatives considered:**

- **D1's shape — field typed `string`, no contract type at all.** Rejected on review: it removes the only slot in which the deployer can express "this Secret already exists". Every replacement surface then costs more than the disjunction did — an attribute argument bakes a cluster fact into a published module, a scheme-prefixed string means the kernel parses semantics out of user data, and a sibling block reintroduces stringly-typed config paths. D1 diagnosed the routing metadata correctly and then removed one thing too many.
- **`string | #SecretRef` — bare scalar for the common case.** Rejected: the value's *kind* would change across resolution for the referenced arm (struct in, string out), so a module carrying a referenced secret would only type-check with the kernel in the loop, and every consumption site in the catalog (`from`, volume sources, …) would have to be retyped to accept the union. Keeping both arms structs holds the kind stable, so a module vets standalone in either arm. The cost is `password: {value: hunter2}` rather than `password: hunter2` in a `ModuleInstance` CR.
- **A three-arm disjunction including an ESO/external-store arm.** Deferred to D8's mechanism — backends are a platform choice resolved through catalog subscription, not an arm of the author-facing type.

**Rationale:** The split that falls out is the design. The **attribute** carries what is metadata: static, identical in every environment, travelling inside the published module. The **type** carries what is data: per-environment, filled by the deployer, and — crucially — type-checked by CUE itself rather than by OPM tooling. Each mechanism does what it is good at, and the routing/fulfilment boundary is exactly the author/deployer boundary.

Keeping both arms as structs has a second effect that was not the goal but is worth more than the ergonomic cost: **instance files for supplied secrets do not change at all**. `{value: "…"}` is already what people write. The migration becomes modules-only.

**Source:** User decision 2026-07-27, during review of the first draft ("Maybe my ask 'we do not have to add the extra value field' was too much… 1. D2 … whichever is most CUE native. We don't want to break CUE"), and the follow-up naming `#SecretLiteral` and `{ref, key}`.

---

### D11: The kernel resolves in place — it rewrites each secret value to its `#SecretRef` form

**Supersedes D4.** Implements D5's single naming authority.

**Decision:** Before the component graph is built, the kernel rewrites every marked path in the render-time values to a `#SecretRef`, whichever arm the deployer wrote. A `#SecretLiteral` is replaced by a reference to the object the kernel has decided to create; a `#SecretRef` passes through as itself. The plaintext leaves through `#SecretGroupPlan.data` to the materialising component and never enters the graph.

There is no handle format, no `#TransformerContext.secrets` lookup, and no prefix scanning. A transformer reads `.ref` and `.key` from a single branch.

**Alternatives considered:**

- **D4's opaque handle plus a context map.** Rejected as machinery invented to work around D1: with the field typed `string`, a substituted value had to be a string, so it could not carry the object name, so a side table was needed to map it back. Once the value is a struct the object name fits inside the value and the whole apparatus — the `opm:secret:v1:` format, the SHA-256 derivation, collision handling, the additive core `#TransformerContext` field, the `owned` flag, and the rendered-output scanner — is unnecessary.
- **Leaving the literal in place and letting the transformer read `.value`.** Rejected: that is plaintext in the component graph, which is the security property the design exists to deliver.
- **Resolving to `{ref, key}` only for literals, leaving deployer-written refs untouched.** No practical difference — a deployer-written ref already *is* the resolved form — but stating the pass as "every marked path is rewritten" makes the postcondition uniform and checkable.

**Rationale:** The two arms are not two kinds of secret; they are two statements about one secret. `#SecretLiteral` says *what* the data is, `#SecretRef` says *where* it lives. For a literal, the kernel's entire job is to turn a *what* into a *where* — pick the object, name it, put the data there. Once it has, the literal *also* has a location, so it can be restated in the second arm. Resolve-in-place is just performing that restatement and handing the result to the render.

Three consequences follow:

1. **Both arms converge before anything renders.** Nothing downstream can tell them apart, so there is no variant dispatch anywhere — replacing the three different discrimination techniques (`$opm` presence, `& #SecretLiteral != _|_`, and structural sniffing) with none.
2. **It settles how D5's single name reaches consumers.** The kernel computes each object name exactly once and writes the answer *into the value*, so there is literally one string and every consumer reads it by construction — no side table to keep in sync, and no call site that could pass different inputs. Divergence is unrepresentable rather than merely fixed.
3. **The leak case is caught earlier and by CUE.** A secret interpolated into a rendered file (`"password=\(#config.db.password)"`) is a struct-in-string error at plain `cue vet` against `debugValues` — at authoring time, before the kernel exists. Under D4 that module vetted clean and failed only at render.

**Source:** Design discussion 2026-07-27; user decision the same day ("Ok, i want resolve-in-place"). Mechanics of the CUE-side rewrite measured in `experiments/02-resolve-in-place`; the one unverified step is recorded as OQ2.

---

### D12: `#Secret` lives in `core`, and `core` is its only definition

**Amends D9.**

**Decision:** `#Secret`, `#SecretLiteral`, and `#SecretRef` are defined in `opmodel.dev/core@v1` and imported by catalogs. `catalog_opm` does not redeclare them. D9's deletions stand for everything else: `$opm`/`$secretName`/`$dataKey`, `#AutoSecrets`, `#DiscoverSecrets`, `#GroupSecrets`, `#SecretContentHash`, `#SecretImmutableName`, and the duplicated copies of all of it. `#SecretSchema` — the Kubernetes Secret *object* shape — stays in the catalog, with `data` narrowed to `string`.

The `#SecretRef` arm's fields are named `ref` and `key`.

**Alternatives considered:**

- **D9's shape — delete `#Secret` from core, keep a narrowed copy in the catalog.** Rejected once D10 restored the type: it would preserve today's duplication, which is one of the defects in `01-problem.md`.
- **Keeping the arm fields named `secretName` / `remoteKey`,** as `#SecretK8sRef` does today, so referenced secrets migrate with zero instance-file change too. Rejected: `secretName` is one of the names that collides with `$secretName` in the current design and reads as "the name of the secret" when it means "the name of the object holding it". Supplied secrets — the overwhelming majority — already migrate unchanged under D10; the referenced arm is rare enough that the clearer name wins.

**Rationale:** With routing gone the type is six lines and names nothing Kubernetes-specific: `{ref, key}` is "an object and a key inside it", which is as generic as `#NameType`. It has no `metadata`, no `fqn`, and no version, so it is a pure type rather than a primitive — which means core owning it does *not* repeat the layering error of enhancement 0010 OQ9, where core hardcoded a versioned catalog FQN. Every catalog and every module needs the same fulfilment contract; defining it once, upstream of all of them, is what stops the two copies diverging again.

**Source:** Design discussion 2026-07-27; user decision the same day (`#SecretLiteral` naming, `{ref, key}` field names).

---

## Open Questions

- **OQ1: Which surface chooses between the supplied and referenced fulfilment kinds?** Status: resolved-by-D10.

  Resolved by keeping the choice in the field's *type*. D1 had removed the disjunction along with the routing metadata, leaving nowhere for the deployer to express "this object already exists"; D10 restores a narrowed `#Secret` whose two arms are exactly that choice, so CUE resolves it by unification as it does today. The three candidate surfaces this question weighed — an attribute argument, a scheme-prefixed value string, and a sibling block on `#ModuleInstance` — are all rejected in D10's alternatives, the first because it bakes a cluster fact into a published module, the other two because they cost more than the disjunction they were replacing.

- **OQ2: Is replacing a user-supplied arm with the kernel-resolved arm a clean value replacement?** Status: open.

  The kernel rewrites `values.<path>` from `{value: …}` to `{ref: …, key: …}` (D11). `experiments/02-resolve-in-place` performs this by decode → mutate → encode, which sidesteps unification entirely and works. What is unverified is whether anything downstream re-unifies the *original* values against the rewritten ones — the instance file's own conjunct on the `values` vertex, a `ModuleInstance` CR round-trip, or `kernel.Validate` running against real values in the same build — and produces a conflict, since `{value: …} & {ref: …, key: …}` is bottom under `#Secret`'s closed arms.

  Resolving this requires a measurement against the real `library/opm/kernel` path rather than a synthetic one, and it determines whether the kernel needs two builds (one to validate against supplied values, one to render against resolved values) or can do both in one. It is a research item rather than a judgement call, and it is the last mechanical unknown in the design.

  This is the sole blocker to `draft → accepted`.
