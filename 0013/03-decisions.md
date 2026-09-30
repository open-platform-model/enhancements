# Design Decisions: Attribute-Declared Secret Fields

This document records every significant design choice with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent**: never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes. The *text* under a number states what is true now: a reversal is recorded as its own `DN` while the design is in motion, then woven into the decision it changes at the next compaction pass: the merged decision keeps the lower number, and the vacated number keeps a one-line tombstone. See the `enhancement-compaction` skill.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source. The Source field is specific (`"User decision YYYY-MM-DD"`, a URL, or a file path) so the provenance of a choice never gets lost.

Several decisions below cite `experiments/01-attribute-propagation` and `experiments/02-resolve-in-place`. Those experiments measured CUE behaviour against the real `opmodel.dev/core@v1` schema; where a decision says a thing is or is not possible, it was run rather than reasoned about.

**D1 and D4 were superseded on the day they were written**, by D10 and D11, during the review that followed the first draft. They are retained in full because the reasoning that replaced them only makes sense against what they said, and because their rejected alternatives are still rejected for the reasons recorded there. The short version: D1 removed the `#Secret` contract type *and* the disjunction inside it, when only the routing metadata needed to move to the attribute. The disjunction was doing legitimate work: it is the fulfilment slot, and the only part of a secret CUE itself can type-check. D4's handle machinery existed to compensate for having thrown it away.

---

## Decisions

### D1: A sensitive field is marked with a CUE field attribute, not typed with a contract struct

**Kind:** scope

**Decision:** Module authors mark a `#config` field sensitive by writing `@opm(secret, …)` on it. The field keeps its natural type (`string`), and `#Secret`, `#SecretLiteral`, `#SecretK8sRef`, and the `$opm` / `$secretName` / `$dataKey` meta-fields are removed. No `value:` wrapper is introduced on the values side.

**Requirements:** none (superseded by D10 on the day it was written; the attribute-marker rule it introduced is D10 R1 and R2, the no-`#Secret`-type half is withdrawn; what survives is its record of rejected alternatives)

**Alternatives considered:**

- **Keep the contract type and add cross-validation** comparing `$secretName` against the hand-written `spec.secrets` map key. Rejected: it closes the drift but leaves the field typed as a struct rather than the scalar it is, leaves plaintext in the render, leaves the definition duplicated across two published CUE modules, and adds a fourth thing to keep in sync rather than removing the second.
- **A parallel `#secrets:` block on `#Module`** listing sensitive paths as strings. Rejected: stringly-typed paths get no CUE checking, so a typo or a renamed config field fails silently: the same class of failure the current design already has.
- **A naming convention** (`passwordSecret`, `*_secret`). Rejected: unenforceable, collides with legitimate names, and carries no room for grouping or key overrides.

**Rationale:** Sensitivity is metadata about a field, not a change to what the field *is*. CUE attributes are exactly that: the language spec defines them as "meta information … [that] do not influence the evaluation of CUE". Marking rather than wrapping keeps `#config` readable as a schema, keeps instance values as plain data, and removes the whole `$`-field vocabulary.

**Source:** User decision 2026-07-27 ("I want to redesign the secret field from using a #Secret definition to use a @opm() metadata attribute").

---

### D2: The marker reuses the existing `@opm(...)` namespace, dispatched on position 0

**Kind:** contract

**Decision:** The attribute name is `opm` and the first positional argument names the marker kind: `@opm(secret, …)`. Remaining arguments are `key=value` pairs specific to that kind. Unknown position-0 values are ignored by the secret pass.

**Requirements:**

- R1: A secret marker is written as `@opm(secret, …)`: attribute name `opm`, the marker kind `secret` in position 0, and routing arguments as `key=value` pairs after it.
- R2: An `@opm(...)` attribute whose position-0 value is not `secret` is ignored by secret discovery, so a field may carry another `@opm` marker without being treated as a secret.
- R3: Every argument past position 0 is optional; `@opm(secret)` with no arguments is a complete declaration and resolves to group `secrets`, a key derived from the config path with separators folded to underscores, type `Opaque`, and not immutable.

**Alternatives considered:**

- **A dedicated `@secret(...)` attribute.** Rejected: it starts a second OPM attribute namespace for the second marker OPM has ever wanted, and a third for the third. One namespace with a dispatch slot scales; a name per concept does not.
- **`@opm(kind=secret, …)` with no positional slot.** Rejected: more to type in the common case, and it diverges from the form already in use.

**Rationale:** Enhancement 0010's original identity design used `@opm(identity, owner=publish)` for tool-owned identity fields, and 0011's publish design preserved it on write, with the same shape: kind in position 0, key/value pairs after. Enhancement 0010 later dropped that identity marker, so the shape is followed for its own merits rather than as a binding precedent. Following it means one attribute name across OPM, one parse path in Go, and a reader who learns the convention once. Measured in experiment 01 that `Attribute.String(0)` cleanly separates `secret` from `identity` on a shared name, and that a field may carry `@opm(...)` alongside unrelated attributes without interference.

**Source:** Design proposal 2026-07-27, following the precedent in `enhancements/archive/0010/03-decisions.md` (the identity-marker alternative, adopted and then dropped) and `enhancements/archive/0003/experiments/06-identity-supply-mechanisms/`.

**Revised:** 2026-09-29, Rationale only: the precedent was cited as a 0011 decision that concerns registry hosting; the marker came from 0010's original identity design, which later dropped it, and it is restated that way. The decision and its requirements are unchanged.

**Revised:** 2026-09-30, Source only: it cited a 0011 design document that carries no `@opm` marker, and a 0003 path from before that entry was archived. It now points at 0010's decision log, where the identity marker was adopted and then dropped, and at the archived 0003 experiment that wrote it. No answer changed.

---

### D3: Discovery reads the module's `#config` schema, not the instance's values

**Kind:** contract

**Decision:** The kernel's Discover phase walks `#module.#config` (`library/opm/schema/paths.go` `Config`). It never looks for marks in `values`.

**Requirements:**

- R1: A module's declared secrets (config path, group, key, type, immutability) are listable from the published module alone, with no instance values present.
- R2: A marker written in instance values rather than on the module's `#config` field declares nothing; only the schema-side declaration is honoured.
- R3: Discovery has no depth ceiling and covers list elements and the entries of a pattern-constrained map, so a deployer-added key under an open `[string]: #Secret` map is discovered.

**Alternatives considered:**

- **Walk the instance's `values`.** Rejected because it does not work: measured in experiment 01, the `values` vertex carries only its own conjunct, so an attribute declared in `#config` is absent there. The unified config is not addressable from a `#ModuleInstance` either: `let unifiedModule = #module & {#config: values}` is a let binding, invisible from outside.
- **Add an addressable unified-config field to `#ModuleInstance`** and walk that. Rejected: a breaking core change to obtain something the schema side already gives, and it would expose secret plaintext at a new addressable path: the opposite of what D11 is for.

**Rationale:** Attributes belong to the field that declares them, which is in `#config`. Reading the schema also buys two things for free: discovery works with no values present, so tooling can list a module's required secrets before anyone has fulfilled them (measured); and the join back to data is by config path, which is the same key fulfilment is expressed against.

**Source:** `experiments/01-attribute-propagation` (E3, E8), 2026-07-27.

---

### D4: The kernel substitutes an opaque handle for every marked value before components are built

**Kind:** scope

**Decision:** Before the component graph is constructed, the kernel rewrites the render-time values so every marked path holds a `#SecretHandle` (`opm:secret:v1:<10 hex>`, SHA-256 of the config path) instead of its plaintext. The kernel retains the plaintext out of band. Transformers resolve handles through `#TransformerContext.secrets`.

**Requirements:** none (superseded by D11 on the day it was written; the plaintext-never-enters-the-graph property it aimed at is D11 R2, delivered without a handle; what survives is its record of rejected alternatives)

**Alternatives considered:**

- **Let the reference carry the mark.** Rejected because it does not work: measured in experiment 01, `env: FOO: from: #config.db.password` produces a field with no attribute: a mark does not travel through a reference. Without substitution a transformer cannot distinguish a secret from any other string.
- **Have the author name the config path at the wiring site** (`from: "db.password"`). Rejected: stringly-typed, loses CUE's reference checking, and is worse ergonomics than what authors write today.
- **Post-process the render by matching plaintext values.** Rejected as actively dangerous: a secret whose value is `"true"` or `"admin"` would rewrite every unrelated occurrence of that string.
- **Substitute a struct rather than a scalar.** Rejected: the field is typed `string` under D1, so a struct does not unify.

**Rationale:** Substitution is the only mechanism that both preserves the author's existing ergonomics (`from: #config.db.password` is unchanged) and gives transformers something they can recognise. It also delivers two properties nothing else does: plaintext never enters the component graph, and a handle that survives into rendered output is *detectable* by substring scan: the case that is silently plaintext today. Handles are derived from the path rather than assigned positionally so renders stay byte-identical and reordering `#config` does not churn output.

**Source:** `experiments/01-attribute-propagation` (E3 — a reference carries neither the mark nor a way to recognise the value), 2026-07-27. The handle prototype that validated this decision was rebuilt as `experiments/02-resolve-in-place` when D11 replaced it, so the handle measurements are not preserved in the tree.

---

### D5: Secret object naming is owned solely by the kernel

**Kind:** contract

**Decision:** The Kubernetes object name for a secret is computed exactly once, by the kernel, during resolution. No transformer computes a name; every consumer reads the one string the kernel produced. How that string reaches consumers is a separate question, settled by D11.

**Requirements:**

- R1: An OPM-owned Secret object's name is computed once per instance and group, and every rendered reference to that group (environment variable, volume mount, any other consumer) carries the identical name.
- R2: When a group is declared immutable, its object name carries a content-hash suffix computed from the group's data before resolution, so every reference to the group already carries the suffixed name and follows the object when the data changes.

**Alternatives considered:**

- **Keep name computation in the transformers and fix the three formulas to agree.** Rejected: it repairs today's instance of the bug and leaves the mechanism that produced it: three derivations in two files, which drifted once and would drift again.
- **Keep the derivation in CUE but funnel every call site through one shared helper.** Rejected because that is already the situation and it did not hold: `catalog_opm` has `#SecretImmutableName`, and both consumption sites call it: with *different inputs*. The volume site passes `{instance}-{component}` while the environment-variable site builds `{instance}-{$secretName}` itself. A shared helper only guarantees agreement if every caller agrees on what to feed it, which is the thing that cannot be enforced from inside CUE.

**Rationale:** Three independent derivations of one name is the root cause of the live mismatch in `01-problem.md`. Collapsing them to one authority does not so much fix the bug as make it unrepresentable: the volume site and the env site necessarily read the same string, and `schemas/examples.cue` pins that with `_assertVolumeAgreesWithEnv`. It also relocates content-hash immutable naming to the only party that can still see the data, since transformers no longer can.

**Source:** Design proposal 2026-07-27, motivated by `catalog_opm/src/transformers/secret_transformer.cue:64-65` vs `container_helpers.cue:78` vs `:374-379`.

**Revised:** 2026-09-29, one Alternatives bullet: the two call sites are named by role (volume, environment variable) instead of by line; the line references remain in Source. No answer changed.

---

### D6: OPM-owned Secret objects are instance-scoped and group-named, not component-scoped

**Kind:** contract

**Decision:** An OPM-materialised Secret object is named `{instance}-{group}`, where `group` defaults to `secrets`. The component that happens to consume a secret plays no part in the name. The `opm-secrets` special-case component name is removed.

**Requirements:**

- R1: An OPM-materialised Secret object is named `{instance}-{group}`, with `group` defaulting to `secrets` when the declaring fields name none.
- R2: Two components of one instance consuming secrets from one group reach the same Secret object; the consuming component's name appears nowhere in the object name.
- R3: Fields sharing a group land in one object, and a group whose members disagree on the Secret `type` or on immutability is rejected.
- R4: An instance carries no `opm-secrets` component, and no object name is derived from a special-case component name.

**Alternatives considered:**

- **Keep component scoping** (`{instance}-{component}-{group}`). Rejected: a Kubernetes Secret is a namespaced object, not a component-owned one. Component scoping forces duplicate objects when two components share a secret, and it is exactly what makes the current env-vs-volume formulas disagree.
- **Keep the `opm-secrets` magic component name** as the un-prefixed branch. Rejected: nothing has produced a component with that name since `core 7500c5d`, so the branch is unreachable and the branch it falls through to is the one the env path does not use.

**Rationale:** Grouping is the author's declared intent about which keys share an object; the component is an implementation detail of who reads it. Naming by instance and group means two components of one instance referring to one group necessarily reach one object.

**Source:** Design proposal 2026-07-27.

---

### D7: Two fulfilment kinds ship, supplied and referenced

**Kind:** contract

**Decision:** `#SecretSource` has exactly two members. `#SuppliedSecret` carries a plaintext value the instance provides and causes OPM to materialise an object. `#ReferencedSecret` names a pre-existing object and remote key, and causes OPM to materialise nothing and wire a reference. No third kind ships in this enhancement.

**Requirements:**

- R1: A deployer fulfils a secret either by supplying its value inline or by naming an existing object and a key inside it; no third form is accepted.
- R2: A supplied secret causes OPM to materialise a Secret object holding the value; a referenced secret causes OPM to materialise nothing and wires a reference to the named object.

**Alternatives considered:**

- **Ship an ESO / external-secret-store kind now.** Deferred: RFC-0002 sketched `#SecretEsoRef` and it was never built. D8 makes it a catalog concern rather than a schema concern, so shipping it here would prejudge an extension the mechanism now supports properly.
- **Ship only the supplied kind** and treat existing objects as out of scope. Rejected: referencing a cluster-managed Secret (a wildcard TLS certificate, a shared pull credential) is the common case in every real deployment.

**Rationale:** These are the two kinds the current design already implements, so the enhancement can be judged on the redesign rather than on new capability. They are also genuinely distinct in a way a backend is not: they differ in *who owns the data*, which changes what the operator must supply.

**Source:** User decision 2026-07-27 ("The two first ones i want are what the current solution already does: 1. plain string … 2. k8s secret path and key reference").

---

### D8: How a supplied secret is materialised is a platform choice, resolved through catalog subscription

**Kind:** contract

**Decision:** The attribute expresses author intent (this field is sensitive, this is its group and key) and nothing about backends. The kernel synthesises a secrets component from the resolved plans and matches it against the platform's materialized catalogs by exact FQN, like any other component. A third party adds a backend (SealedSecrets, ESO, CSI) by publishing a catalog whose transformer requires that resource. The `#secretsResourceFQN` is an input supplied by the platform, never a literal in core or in this schema.

**Requirements:**

- R1: A marked field's declaration names no backend; the same published module renders on a platform whose catalog materialises plain Kubernetes Secrets and on one whose catalog materialises a different object kind, without republishing.
- R2: The secrets component the kernel synthesises matches a platform transformer by exact FQN like any other component, so a third party adds a backend by publishing a catalog whose transformer requires that resource, with no kernel change.
- R3: The secrets resource FQN is taken from the platform's subscribed catalogs at render time, so a catalog version change needs no change in core or in the kernel.

**Alternatives considered:**

- **A Go plugin registry in the kernel** (`RegisterSecretProvider("eso", impl)`). Rejected: extension would require recompiling the kernel, which contradicts the catalog model every other OPM primitive extends through.
- **A backend argument on the attribute** (`@opm(secret, provider=eso)`). Rejected: it puts a cluster-infrastructure decision in a published module. The same module should deploy to an ESO cluster and a plain one without republishing, and the author does not know which they will hit.
- **Hardcode the secrets resource FQN in core**, as before `7500c5d`. Rejected: a catalog stamps its own version into every FQN it publishes, so the constant went stale the moment the catalogs moved to `@v1`, and the synthesised component then matched no transformer at all.

**Rationale:** Separating author intent from platform choice is what makes the design modular in the way that matters. It also resolves enhancement **0010 OQ9** along that question's own candidate (b): the synthesis takes the FQN from the platform's materialized catalogs rather than a literal. That was impractical when the synthesis lived in `core`, since core does not hold a platform, and is natural here, because the kernel already does the discovery and already holds the platform.

**Source:** Design proposal 2026-07-27; problem framing from `enhancements/0010/03-decisions.md` OQ9 and `core/SPEC.md:521`.

---

### D9: The dead and duplicated secret machinery is deleted, not deprecated

**Kind:** contract

**Mechanism removed 2026-08-22**: construction detail recorded before the Kind gate (file names and layout) has been dropped from this decision. Nothing here is reversed; the contract and the evidence are unchanged.

**Decision:** Core withdraws its entire secret block and the catalog drops its duplicate of the contract type. No aliases, no transition shims: a module written against the withdrawn shapes stops type-checking rather than being carried by a compatibility layer. `#SecretsResource` / `#SecretSchema` survive in the catalog for hand-authored Secret data, with `data` narrowed from `#Secret | string` to `string`.

**Requirements:**

- R1: A module written against the withdrawn shapes (the `$opm`/`$secretName`/`$dataKey` marker fields, the old reference struct, the discovery and grouping helpers) fails to type-check against the new core; no alias or compatibility shim accepts them.
- R2: The catalog's hand-authored Secret object shape survives with `data` values typed `string` only; a `#Secret` value in that slot is rejected.

**Alternatives considered:**

- **Deprecate with a transition window,** keeping both shapes valid for a release. Rejected: the two shapes cannot coexist cleanly, because `#EnvVarSchema.from` would have to accept both a struct and a handle string, which reintroduces exactly the structural sniffing D1 removes.
- **Leave core's copy in place** since nothing references it. Rejected: it ships to every consumer of `opmodel.dev/core@v1`, and `SPEC.md` documents it as a Primitive it is not, so leaving it means publishing a contract that describes something untrue.

**Rationale:** Core's copy is already dead: no file under `core/src/*.cue` references it. The catalog's copy has one consumer shape and one fleet module. Deleting is cheaper than a compatibility window nobody needs: `cli` has no external users, so no deprecation is owed, and `modules/metallb` is the only artifact to migrate.

**Source:** Design proposal 2026-07-27; dead-code finding verified by grep across `core`, `catalog_opm`, `modules`, `library`, `cli`.

---
### D10: The secret field is typed `#Secret`, a two-arm disjunction; the attribute carries routing only

**Kind:** contract

**Supersedes D1.** Closes **OQ1**.

**Decision:** A sensitive `#config` field is declared as `#Secret @opm(secret, …)`. The contract type returns, narrowed to a two-arm disjunction that carries *only* fulfilment:

```
#Secret:         #SecretLiteral | #SecretRef
#SecretLiteral:  {value!: string}
#SecretRef:      {ref!: string, key!: string}
```

All routing (`group`, `key`, `type`, `immutable`, `description`) lives in the attribute. `$opm`, `$secretName`, and `$dataKey` are removed. The deployer chooses the arm, per environment, in `values`.

Both arms are structs. The bare-scalar form (`string | #SecretRef`) was considered and rejected below.

**Requirements:**

- R1: A sensitive `#config` field is declared with type `#Secret`, optionally carrying an `@opm(secret, …)` attribute; the type accepts exactly two struct arms, `{value}` and `{ref, key}`, and a bare scalar is rejected.
- R2: Routing (group, key, type, immutable, description) is stated only in the attribute; a value carrying routing fields such as `$opm`, `$secretName` or `$dataKey` is rejected.
- R3: The deployer chooses the arm per environment in the instance values; a published module fixes neither arm, and moving an environment between arms needs no republish.
- R4: An instance values file that supplies a secret as `{value: "…"}` today is accepted unchanged.
- R5: A module carrying either arm vets standalone without the kernel in the loop.
- R6: An unfulfilled secret is non-concrete, so plain `cue vet -c` names it by config path with no OPM tooling involved.

**Alternatives considered:**

- **D1's shape: field typed `string`, no contract type at all.** Rejected on review: it removes the only slot in which the deployer can express "this Secret already exists". Every replacement surface then costs more than the disjunction did: an attribute argument bakes a cluster fact into a published module, a scheme-prefixed string means the kernel parses semantics out of user data, and a sibling block reintroduces stringly-typed config paths. D1 diagnosed the routing metadata correctly and then removed one thing too many.
- **`string | #SecretRef`: bare scalar for the common case.** Rejected: the value's *kind* would change across resolution for the referenced arm (struct in, string out), so a module carrying a referenced secret would only type-check with the kernel in the loop, and every consumption site in the catalog (`from`, volume sources, …) would have to be retyped to accept the union. Keeping both arms structs holds the kind stable, so a module vets standalone in either arm. The cost is `password: {value: hunter2}` rather than `password: hunter2` in a `ModuleInstance` CR.
- **A three-arm disjunction including an ESO/external-store arm.** Deferred to D8's mechanism: backends are a platform choice resolved through catalog subscription, not an arm of the author-facing type.

**Rationale:** The split that falls out is the design. The **attribute** carries what is metadata: static, identical in every environment, travelling inside the published module. The **type** carries what is data: per-environment, filled by the deployer, and (crucially) type-checked by CUE itself rather than by OPM tooling. Each mechanism does what it is good at, and the routing/fulfilment boundary is exactly the author/deployer boundary.

Keeping both arms as structs has a second effect that was not the goal but is worth more than the ergonomic cost: **instance files for supplied secrets do not change at all**. `{value: "…"}` is already what people write. The migration becomes modules-only.

**Source:** User decision 2026-07-27, during review of the first draft ("Maybe my ask 'we do not have to add the extra value field' was too much… 1. D2 … whichever is most CUE native. We don't want to break CUE"), and the follow-up naming `#SecretLiteral` and `{ref, key}`.

---

### D11: The kernel resolves in place; it rewrites each secret value to its `#SecretRef` form

**Kind:** contract

**Supersedes D4.** Implements D5's single naming authority.

**Decision:** Before the component graph is built, the kernel rewrites every marked path in the render-time values to a `#SecretRef`, whichever arm the deployer wrote. A `#SecretLiteral` is replaced by a reference to the object the kernel has decided to create; a `#SecretRef` passes through as itself. The plaintext leaves through `#SecretGroupPlan.data` to the materialising component and never enters the graph.

There is no handle format, no `#TransformerContext.secrets` lookup, and no prefix scanning. A transformer reads `.ref` and `.key` from a single branch.

**Requirements:**

- R1: At render, every marked path holds the `{ref, key}` form whichever arm the deployer wrote: a supplied value is replaced by a reference to the object OPM materialises, and a deployer-written reference passes through byte-identical and is never instance-prefixed.
- R2: No `value` field exists at any marked path in the render-time values, and the supplied plaintext appears in no rendered manifest other than the materialised Secret's own data.
- R3: A module that interpolates a secret into a string (`"\(#config.db.password)"`) fails at plain `cue vet` at authoring time, before any kernel is involved.
- R4: A module or transformer that reads a resolved secret's literal value is told so against the config path it wrote, not through an error about a missing field.

**Alternatives considered:**

- **D4's opaque handle plus a context map.** Rejected as machinery invented to work around D1: with the field typed `string`, a substituted value had to be a string, so it could not carry the object name, so a side table was needed to map it back. Once the value is a struct the object name fits inside the value and the whole apparatus (the `opm:secret:v1:` format, the SHA-256 derivation, collision handling, the additive core `#TransformerContext` field, the `owned` flag, and the rendered-output scanner) is unnecessary.
- **Leaving the literal in place and letting the transformer read `.value`.** Rejected: that is plaintext in the component graph, which is the security property the design exists to deliver.
- **Resolving to `{ref, key}` only for literals, leaving deployer-written refs untouched.** No practical difference (a deployer-written ref already *is* the resolved form) but stating the pass as "every marked path is rewritten" makes the postcondition uniform and checkable.
- **Module-level context fill: `#ctx.secrets` (proposed 2026-08-13).** The kernel fills a kernel-owned `#ctx.secrets.<path>` subtree with each resolved `{ref, key}` and authors wire consumption sites through it instead of through `#config`. Unification-clean (filling an empty kernel-owned slot has no conflicting conjunct), but rejected on three grounds: the author wiring moves to `from: #ctx.secrets.db.password` (rejected ergonomics: the natural reference is `#config.db.password`); unlike `#ctx.components` (a pure CUE projection over CUE-visible `#names`) the secrets subtree cannot be a projection because attributes are evaluation-inert, so secret wiring would neither vet nor complete standalone without the kernel in the loop; and the plaintext stays live at the `#config` paths.
- **Legalising coexistence via a shared `#SecretBase`, `ref?`/`key?` optional on the literal arm (proposed and retracted 2026-08-14).** Makes the rewrite a pure fill: `{value: …} & {ref: …, key: …}` unifies (the union selects the literal arm), dissolving the OQ2 collision while keeping the author wiring unchanged. Rejected because the plaintext then remains in the component graph, demoting structural absence to convention. A `.value` read in any transformer (third-party catalogs included, per D8's open ecosystem), a `\(#config.….value)` interpolation, or a value-embedding CUE error message would all leak silently. The closed two-field `#SecretRef` instead makes each of those a loud error or unrepresentable. Retracted by its proposer on review; retained as the strongest measured fallback should OQ2 rule out clean omission, since it beats `#ctx.secrets` on wiring ergonomics.

**Rationale:** The two arms are not two kinds of secret; they are two statements about one secret. `#SecretLiteral` says *what* the data is, `#SecretRef` says *where* it lives. For a literal, the kernel's entire job is to turn a *what* into a *where*: pick the object, name it, put the data there. Once it has, the literal *also* has a location, so it can be restated in the second arm. Resolve-in-place is just performing that restatement and handing the result to the render.

Three consequences follow:

1. **Both arms converge before anything renders.** Nothing downstream can tell them apart, so there is no variant dispatch anywhere: replacing the three different discrimination techniques (`$opm` presence, `& #SecretLiteral != _|_`, and structural sniffing) with none.
2. **It settles how D5's single name reaches consumers.** The kernel computes each object name exactly once and writes the answer *into the value*, so there is literally one string and every consumer reads it by construction: no side table to keep in sync, and no call site that could pass different inputs. Divergence is unrepresentable rather than merely fixed.
3. **The leak case is caught earlier and by CUE.** A secret interpolated into a rendered file (`"password=\(#config.db.password)"`) is a struct-in-string error at plain `cue vet` against `debugValues`: at authoring time, before the kernel exists. Under D4 that module vetted clean and failed only at render.

**Source:** Design discussion 2026-07-27; user decision the same day ("Ok, i want resolve-in-place"). Mechanics of the CUE-side rewrite measured in `experiments/02-resolve-in-place`; the one unverified step is recorded as OQ2.

---

### D12: `#Secret` lives in `core`, and `core` is its only definition

**Kind:** contract

**Amends D9.**

**Decision:** `#Secret`, `#SecretLiteral`, and `#SecretRef` are defined in `opmodel.dev/core@v1` and imported by catalogs. `catalog_opm` does not redeclare them. D9's deletions stand for everything else: `$opm`/`$secretName`/`$dataKey`, `#AutoSecrets`, `#DiscoverSecrets`, `#GroupSecrets`, `#SecretContentHash`, `#SecretImmutableName`, and the duplicated copies of all of it. `#SecretSchema` (the Kubernetes Secret *object* shape) stays in the catalog, with `data` narrowed to `string`.

The `#SecretRef` arm's fields are named `ref` and `key`.

**Requirements:**

- R1: `#Secret`, `#SecretLiteral` and `#SecretRef` are published by core and imported by catalogs; no catalog publishes a definition of its own for them.
- R2: The referenced arm's fields are named `ref` and `key`; `secretName` and `remoteKey` are not accepted.
- R3: Core publishes none of `$opm`, `$secretName`, `$dataKey`, `#SecretK8sRef`, `#AutoSecrets`, `#DiscoverSecrets`, `#GroupSecrets`, `#SecretContentHash`, `#SecretImmutableName` or `#SecretSchema`; the Kubernetes Secret object shape lives in the catalog only.
- R4: `#Secret` carries no `metadata`, no FQN and no version, and core's specification lists it as a config-value type, not a primitive.

**Alternatives considered:**

- **D9's shape: delete `#Secret` from core, keep a narrowed copy in the catalog.** Rejected once D10 restored the type: it would preserve today's duplication, which is one of the defects in `01-problem.md`.
- **Keeping the arm fields named `secretName` / `remoteKey`,** as `#SecretK8sRef` does today, so referenced secrets migrate with zero instance-file change too. Rejected: `secretName` is one of the names that collides with `$secretName` in the current design and reads as "the name of the secret" when it means "the name of the object holding it". Supplied secrets (the overwhelming majority) already migrate unchanged under D10; the referenced arm is rare enough that the clearer name wins.

**Rationale:** With routing gone the type is six lines and names nothing Kubernetes-specific: `{ref, key}` is "an object and a key inside it", which is as generic as `#NameType`. It has no `metadata`, no `fqn`, and no version, so it is a pure type rather than a primitive, which means core owning it does *not* repeat the layering error of enhancement 0010 OQ9, where core hardcoded a versioned catalog FQN. Every catalog and every module needs the same fulfilment contract; defining it once, upstream of all of them, is what stops the two copies diverging again.

**Source:** Design discussion 2026-07-27; user decision the same day (`#SecretLiteral` naming, `{ref, key}` field names).

**Revised:** 2026-09-30, core surface widened by two named types: core also publishes `#SecretKeyType`, which `#SecretRef.key` carries, and `#SecretObjectType`, the Secret `type` values OPM materialises, named so the marker's `type=` argument and backend catalogs read one set. Both are value types, not the Kubernetes Secret object shape, so R3 holds. The Decision, the requirements and the arm field names are unchanged.

---

### D13: Discovery keys on the type and the marker, and fails closed

**Kind:** contract

**Decision:** Discover recognises a declaration by either signal. A `#config` field typed `#Secret` with no `@opm(secret, …)` attribute is discovered with all-default routing, exactly as if it carried a bare `@opm(secret)`: group `secrets`, key derived from the path (`#DeriveKey`). A field carrying the `secret` marker whose type is not `#Secret` is a Discover error. The marker is therefore pure override; it is never load-bearing for the security property.

**Requirements:**

- R1: A `#config` field typed `#Secret` with no `@opm(secret, …)` attribute is discovered and resolved with default routing, exactly as if it carried a bare `@opm(secret)`.
- R2: A field carrying the `secret` marker whose type is not `#Secret` is rejected at discovery.

**Alternatives considered:**

- **Marker-only discovery**: the shape D3 implied. Rejected: a field typed `#Secret` without the marker would be invisible to Discover, never resolved, and the deployer's `{value: …}` literal would flow into the component graph as an ordinary struct: plaintext in the render, silently. Forgetting the mark would produce exactly the leak the design exists to prevent.
- **Making the unmarked `#Secret` field a hard error** instead of applying defaults. Rejected: `@opm(secret)` with every argument defaulted is already the documented common case (D2), so an unmarked `#Secret` field has one unambiguous meaning; erroring would add authoring friction without adding safety.
- **Type-only discovery, deleting the marker.** Rejected: the routing overrides (`group`, `key`, `type`, `immutable`, `description`) need a home, and D10's split, type carries fulfilment and attribute carries routing, is the design.

**Rationale:** Fail closed. The failure mode of forgetting an annotation must be a loud error or a safe default, never a silent leak. Keying discovery on the type makes "secret-typed but unhandled" structurally impossible: the same move D11 makes for name divergence. The inverse check (marker without type) catches the author who marked a plain `string`: a declaration the fulfilment contract cannot type-check and resolve-in-place cannot rewrite.

**Source:** User decision 2026-08-13, during the guarantee-by-guarantee review (fail-closed discovery suggestion accepted).

---

### D14: SOPS support lands at the file seams, decrypt on input, encrypt on export; never an arm, a backend, or kernel code

**Kind:** contract

**Depends:** 0014:D1

**Decision:** Encrypted-at-rest instance values are supported via SOPS at exactly two seams, both outside the kernel.

**Input:** the CLI accepts a SOPS-encrypted values file (YAML/JSON, SOPS's native formats) and decrypts it with the `github.com/getsops/sops/v3` library before the values become a `cue.Value`; the kernel receives plain values and is unchanged.

**Export:** when rendered output is written for GitOps consumption (enhancement 0014's flow), Secret manifests can be SOPS-encrypted on write for cluster-side decryption by Flux's kustomize-controller; the placement is recorded here, the implementation rides 0014's export surface.

**CLI UX:** `opm secrets template <module>` walks Discover's output with no values present and emits a skeleton values file containing exactly the marked paths, ready to populate and `sops -e`. Unfulfilled-secret reporting lives in `opm module vet`: Discover's path list lets vet intercept CUE's incompleteness errors at marked paths and replace them with one grouped "unfulfilled secrets" message naming each path, group, and key. No standalone `opm secrets verify` command ships.

**Requirements:**

- R1: A SOPS-encrypted values file (YAML or JSON) is accepted wherever a plain values file is, and the render is identical whether the values arrived encrypted or plain.
- R2: `opm secrets template <module>` emits, from the module alone with no values present, a skeleton values file containing exactly the marked paths.
- R3: `opm module vet` reports unfulfilled secrets as one grouped message naming each path, group and key, in place of CUE's per-field incompleteness errors.
- R4: When an instance is exported for GitOps consumption, its Secret-bearing output can be SOPS-encrypted on write for cluster-side decryption.

**Alternatives considered:**

- **A third fulfilment arm** (`{sopsRef: …}` or similar). Rejected: encryption at rest is a property of the *file*, not of the fulfilment. After decryption a SOPS-supplied secret *is* a `#SecretLiteral`; an arm would bake a tooling choice into instance values: the same category error as `provider=eso` on the attribute, rejected in D8.
- **SOPS as a D8 catalog backend.** Rejected: SealedSecrets and ESO change what object is materialised *in the cluster*; SOPS changes nothing in the cluster: it protects files. There is no `#SecretGroupPlan` for it to consume.
- **Kernel-side decryption.** Rejected: kernel neutrality (library Principle I): no I/O, no crypto, no ambient key material in the kernel. Decryption needs key access (age keys, KMS credentials), which is frontend configuration.
- **A standalone `opm secrets verify` command.** Rejected in favour of vet: an unfulfilled secret *is* a non-concrete field, so `opm module vet` already detects the condition structurally: only the message needed to become secrets-aware. A second tool to explain what the first should have said is surface without capability. If plaintext-hygiene checking (a marked path fulfilled from an unencrypted file) is ever wanted, it is a warning inside vet/plan, not a command.

**Rationale:** OPM gets encryption at rest without implementing cryptography: the sops library does encrypt/decrypt, Flux already handles cluster-side decryption, and OPM contributes the one thing no other tool can: knowing exactly which fields are secret. That knowledge makes the encrypted file *generatable* (`template`) and the gap report *exact* (vet), which is what turns "you can use SOPS next to it" (true of every competitor) into first-class support. The seam placement keeps D7's two arms and D8's backend mechanism intact, and the kernel contract is identical whether values arrived encrypted or not.

**Source:** User decision 2026-08-13 ("I would like to support encryption, but not by developing it myself. I want SOPS support"; template generator adopted; vet integration preferred over a verify command).

---

### D15: The operator path accepts literals in the CR, documented as plaintext at rest; no `valuesFrom` indirection

**Kind:** contract

**Decision:** A `ModuleInstance` CR may carry supplied-arm secrets (`{value: …}`) in its values, and that is accepted as-is: the plaintext sits in the CR object in etcd. Documentation states this plainly and directs production deployments on the operator path to the referenced arm (`{ref, key}` against an existing Secret). No `valuesFrom` mechanism (merging values from Kubernetes Secrets, as Flux HelmRelease does) is added.

**Requirements:**

- R1: A `ModuleInstance` CR carrying supplied-arm secrets (`{value: …}`) in its values is accepted and renders exactly as the same values given to the CLI would.
- R2: The operator documentation states that a supplied-arm literal in a CR is plaintext at rest in etcd and directs production deployments to the referenced arm.

**Alternatives considered:**

- **`valuesFrom: [{secretRef: …}]` on the CR**, Flux HelmRelease's shape. Rejected by user decision: not wanted. It stays purely additive if ever revisited, so declining it now costs nothing structurally. The etcd caveat it would have addressed is real and is documented instead: CR read access is typically broader than `get secrets`, and etcd encryption-at-rest usually covers only the `secrets` resource, so a literal in a CR is readable by personas who deliberately cannot read Secrets. The referenced arm is the answer for that posture.
- **Rejecting the supplied arm on the operator path.** Rejected: it would fork the values contract per frontend (the same instance values would be valid for the CLI and invalid as a CR) breaking the "same module, same values, any frontend" property.

**Rationale:** The design's security property is scoped to the render pipeline: plaintext never enters the component graph. How values *reach* the kernel is a frontend seam: the CLI's seam gets SOPS (D14); the operator's seam is the Kubernetes API, where the referenced arm already provides the secure posture with zero new mechanism. Guidance over machinery.

**Source:** User decision 2026-08-13 ("I don't want to add ValuesFrom"; documentation-first posture).

---

### D16: The rewrite is omission at build assembly, measured viable on the real kernel path, one graph build, no new kernel seams

**Kind:** contract

**Resolves OQ2.**

**Mechanism removed 2026-08-22**: construction detail recorded before the Kind gate (file names and layout) has been dropped from this decision. Nothing here is reversed; the contract and the evidence are unchanged.

**Decision:** Resolve-in-place is achieved by assembling the render build **without** the deployer's original values conjunct, never by overriding it. That is the constraint; which of the two viable mechanisms delivers it is the kernel's to choose. Measured against the published kernel (`github.com/open-platform-model/library v1.0.0-alpha.12`, `opmodel.dev/core@v2` at `v2.0.0-alpha.4`), both work today through existing public entry points, with no new seam required. A **fill-style** path loads the instance spec with values omitted and fills the resolved ones through the existing validate-and-fill seam; it's the natural fit for parameter-carried values such as CLI flags and CR decode. A **bake-style** path bakes them at load time through the overlay mechanism synthetic instances already use; it's the natural fit for package-staged loads. The pipeline needs exactly **one component-graph build**: the deployer's raw values are validated in their own evaluation by the existing, separate validation phase, and the render build carries the resolved statement only.

**Requirements:**

- R1: The deployer's values as written are validated against the module's `#config` schema, and a validation error names the path and value as the deployer wrote them, not the resolved form.
- R2: The instance artifact carrying the deployer's supplied values (instance file or CR) builds and validates as its own artifact, independent of the render.

**Alternatives considered:**

- **Override-in-place**: filling the resolved arm over the raw-baked package. Measured refuted (experiment 03, M2): the kernel's own fill seam fails with the closed-arm collision (`values.db.password: 3 errors in empty disjunction`), the production-scale twin of the two-statement conflict CUE's disjunction semantics guarantee. This is a feature: the seam structurally enforces that omission is the only implementation.
- **Two full graph builds** (validate build + render build). Unnecessary: `Kernel.Validate` is already a separate, cheap evaluation against the `#config` schema; it never needed the component graph. So validating raw values and rendering resolved ones costs one graph build plus the validation that exists today.
- **The `#SecretBase` coexistence fill and `#ctx.secrets` fill**: the fallbacks recorded in D11's alternatives, held in reserve for the case where omission measured unclean. Not needed: it measured clean on both candidates.

**Rationale:** OQ2 was the last mechanical unknown: whether anything downstream re-unifies the original values against the rewritten ones. The measurement answers it precisely: the original conjunct collides if and only if it is in the build (M2), and both omission mechanisms keep it out (M3/M4) while the raw artifact remains fully validatable on its own (M1). The render artifact carries `{ref, key}` at every marked path, the deployer-written ref passes through unchanged (the arms converge), no `.value` field exists on a resolved secret, and the plaintext string is absent from the exported values subtree. No new kernel machinery is required for the swap itself: the implementation's work reduces to Discover + Resolve plus choosing which existing assembly path feeds the render build.

**Source:** `experiments/03-kernel-omission/` — outcome 2026-08-14; 17/17 assertions passed on library v1.0.0-alpha.12, re-verified 17/17 on v1.0.0-alpha.13 the same day.

---

### D17: The Resolve rewrite mechanism is decode → splice → encode, on evaluated data, not AST, not FillPath-graft

**Kind:** contract

**Mechanism removed 2026-08-22**: construction detail recorded before the Kind gate (file names and layout) has been dropped from this decision. Nothing here is reversed; the contract and the evidence are unchanged.

**Decision:** Resolution operates on *evaluated data*, never on source. Two properties are contract: **the deployer's file is untouched on disk**, and marked-field attributes are read from values rather than from parsed source, so nothing in the pass parses, patches or round-trips an AST. The mechanism that delivers them (decode the concrete values to Go data, splice `{ref, key}` at each marked path, encode a fresh value) is experiment 02's prototype and is also the measured-fastest; it is recorded below as evidence that resolution costs nothing the design has to bend around, not as a constraint on the implementing repo.

**Requirements:**

- R1: Resolution never modifies the deployer's values file on disk.

**Alternatives considered:**

- **Prune-graft**: `FillPath` untouched subtrees wholesale onto an empty struct, descending only into branches containing marked paths. Measured 12–39× slower than decode-encode on every shape in `experiments/04-rewrite-performance/`, *including* the large-sparse case constructed to favor it: per-`FillPath` construction/re-unification overhead dominates the savings from not decoding untouched data, and deep paths are its worst case. Refuted the scaling hypothesis it was proposed under.
- **AST surgery** (export via `Syntax()`, patch, rebuild). Rejected without measurement on two grounds: the values are concrete data by the time Resolve runs (`ProcessModuleInstance` enforces it), so there are no expressions whose structure needs preserving; and enhancement 0011's `StripProvenance` work measured CUE's value→AST→value round-trip as fragile for anything beyond concrete data (unbuildable let-bound references; export profiles that silently open closed definitions). The one legitimate value→source export in this design, bake-style delivery serializing resolved values to bytes, stays inside the safe concrete-data subset and costs about one extra decode-encode pass (measured).

**Rationale:** Both mechanisms passed the correctness gate (JSON-identical output, no surviving plaintext), so the choice fell to cost and simplicity, and they agree: the simple mechanism is the fast one, resolving a 2000-field config in ~4ms: noise next to registry pulls and module evaluation. Performance neither constrains the design nor justifies the graft's complexity. Delivery-seam pricing from the same measurement: fill-style needs no serialization at all; bake-style adds roughly one decode-encode-equivalent: both negligible, fill-style strictly cheaper where the seam permits.

**Source:** `experiments/04-rewrite-performance/` — outcome 2026-08-14 (graft-scaling hypothesis refuted; decode-encode wins 12–39× on every shape); mechanism proven correct in `experiments/02-resolve-in-place/`; AST fragility evidence from enhancement 0011's compat work.

---

### D18: `#Secret` gains an open source arm; the literal stays as sugar; core defines the source input once

**Kind:** contract

**Supersedes:** D7

**Amends:** D10, D12

**Decision:** `#Secret` is `#SecretLiteral | #SecretRef | #SecretSource`. `#SecretSource` is an open envelope, `{source!: string, spec?: {...}}`: `source` names a secret method and `spec` carries whatever that method needs. Core never names a method. `#SecretLiteral` (`{value}`) stays as sugar for the method a platform marks as the literal source, and `#SecretRef` stays as the escape hatch to an existing object. Core also defines, once, `#SecretSourceInput`: the envelope the kernel hands every method, a `target` (object name, type, immutable) plus `entries` (data key to that member's source spec). A method's own schema types `entries`; the envelope itself never grows.

What survives of D10: the attribute carries routing only, and the deployer chooses fulfilment in the type. What changes against D10 is the arm set, which is no longer closed at two. What survives of D12: core is the only definition of `#Secret`; what changes is that core also defines `#SecretSource` and `#SecretSourceInput`.

**Requirements:**

- R1: A deployer fulfils a secret with a literal value, a reference to an existing object, or a named secret source with that source's own data; each is accepted by the same published module without republishing it.
- R2: Adding a secret method needs no change to core and no change to the kernel.
- R3: A literal value renders through whichever source the platform marks as the literal source, exactly as the equivalent named-source form would.
- R4: Every secret method receives the same input envelope, a target object and a map of entries, and a method whose schema does not accept that envelope fails to vet in its own catalog.

**Alternatives considered:**

- **The shipped rule (D7): exactly two arms, supplied and referenced.** Replaced: it forced the backend to be a platform-wide switch, and for a supplied plaintext only a plain Secret is a sensible backend. SealedSecrets needs ciphertext, which a CUE transformer cannot produce (no asymmetric encryption in CUE's standard library, and randomised output would break the render digest). External-store operators need a pointer into the store, not a value. Each method needs different data from the deployer, so the method belongs in the deployer's arm.
- **Product-named arms in core** (`sealed`, `eso`, …). Rejected: core would name third-party products, and every new product would be a core change.
- **Data-kind arms in core** (`external`, `encrypted`) with the product chosen by provider fulfilment. Rejected: better, but a new kind of data would still be a core change, and the arm set would still be closed.
- **No literal sugar**, the literal being only a named source. Rejected: the most common case would become three levels of nesting in every values file and CR.
- **The input envelope as a catalog convention.** Rejected: a catalog spelling it differently would fail only at render, and nothing would state the contract in code.

**Rationale:** Core defines envelopes and catalogs define the concrete kinds, identified by FQN, and matched by the kernel. That is how OPM already extends workloads, traits and blueprints; secret methods now extend the same way. Core adds this capability once and does not grow with it.

**Source:** User decisions 2026-09-30, after the feasibility review of this entry: the deployer chooses the method; core must be extendable after the fact without new fields; literal kept as sugar; envelope defined by core.

---

### D19: A secret source is a catalog-defined resource; the platform installs any number side by side; the deployer chooses per value

**Kind:** contract

**Supersedes:** D8

**Amends:** D11

**Decision:** A secret method is a `#Resource` defined by a catalog and annotated `opmodel.dev/secret-source: <name>` (D20), with a spec of `#SecretSourceInput` whose `entries` it types. Its transformer turns the input into whatever materialises a Kubernetes Secret named `target.name` holding the `target` keys: a plain Secret, an ExternalSecret, a SealedSecret. A platform installs sources by enabling catalogs, several at once; each source is its own contract, so ordinary matching keeps them apart.

The deployer names the source per value. `source` resolves against the platform's defined contracts by the annotation's value; a name no installed source carries is refused, listing the installed ones; a name two sources carry is refused as ambiguous, and the contract FQN is accepted in its place. All non-reference members of one group must name the same source with the same settings, since one object has one producer; a group that disagrees is refused, naming the group and its paths.

The kernel synthesises one component per group carrying the chosen source's contract, fills its input out of band, and rewrites every member's value to `{ref, key}` naming the target object. What survives of D11: every marked path holds the reference form at render and plaintext never enters the component graph. What changes against D11: the reference is produced for every source, not only for a literal.

**Requirements:**

- R1: A platform can carry several secret sources at once, and each renders only the secrets whose deployer named it.
- R2: The same module instance can use different sources for different secrets, and different sources per environment, with no change to the module.
- R3: A value naming a source the platform does not carry fails the render with an error listing the sources the platform does carry.
- R4: A short source name carried by two installed sources fails the render as ambiguous, and the full contract name is accepted instead.
- R5: A group whose non-reference members name different sources, or the same source with different settings, fails with an error naming the group and each member path.
- R6: Every consumer of a secret reads the same reference form whichever source produced it.

**Alternatives considered:**

- **The shipped rule (D8): the backend is a platform-wide choice through catalog subscription.** Replaced for the reason given in D18: the backend depends on what data the deployer holds, which varies per secret and per environment.
- **Provider fulfilment as the only mechanism**: one abstract secrets contract, one provider enabled per platform. Rejected as the mechanism: it permits one backend per platform. It stays available inside one source, when two products should be interchangeable behind one name.
- **FQN-only source names.** Rejected: long catalog-bound strings in every values file and CR.
- **Platform-defined aliases** (a name-to-contract map on the platform). Rejected: a new platform-side map, either a core field or a convention; the annotation already names the source.
- **The source chosen per group in a separate values block.** Rejected: it exposes the author's routing to the deployer and adds a second place to look.

**Rationale:** Every source being its own contract is what lets them coexist: there is nothing to over-subscribe. The kernel still only resolves, names and rewrites; what a source does with its input is the catalog's.

**Source:** User decisions 2026-09-30: sources coexist on a platform; the deployer chooses per value; short name with FQN fallback; per-value choice that must agree per group.

---

### D20: Kernel-interpreted primitive annotations live under a reserved `opmodel.dev/` prefix, one key per feature

**Kind:** contract

**Decision:** A kernel feature that must find a primitive by what it is for reads a primitive annotation, never a new core field. Core's specification reserves the `opmodel.dev/` annotation prefix for keys the kernel interprets. Each feature owns one key and its value vocabulary. The first key is `opmodel.dev/secret-source`, whose value is the source's short name, with `literal` reserved for the source that serves `#SecretLiteral`. Primitives already carry `metadata.annotations` as definition behaviour hints, so this needs no core schema change; the clarification that such a key is read by a kernel lookup, not by transformer matching, is a specification sentence.

**Requirements:**

- R1: A catalog marks a primitive for a kernel feature by an annotation under the reserved prefix, with no core schema change.
- R2: A primitive may serve several kernel features at once, one key each.
- R3: Annotations outside the reserved prefix are never interpreted by the kernel.

**Alternatives considered:**

- **A role field on primitives in core.** Rejected: a new core field, and one role per primitive.
- **A single shared role key** (`opmodel.dev/role`). Rejected: one role per primitive, and every future feature would compete for one key's values.
- **The kernel hardcoding a catalog contract FQN.** Rejected: the kernel would depend on one catalog's paths.
- **A platform field naming the contract.** Rejected: one more thing every platform must configure, failing only at render when wrong.

**Rationale:** This is the extension point that lets later kernel features find what they need without growing core, which is the property D18 asks of the secret capability.

**Source:** User decision 2026-09-30 (primitive annotation, proposed by the user as a pattern for future features; feature-scoped key).

---

### D21: A source's settings default at the platform; the source decides what a deployer may override

**Kind:** contract

**Decision:** Settings a source needs that belong to the platform, such as which external store or which vault role, are set once per installed source by the platform. Each source's own schema decides which of them a deployer may override per secret. Core says nothing about settings.

**Requirements:**

- R1: A platform can set a source's settings once, and every secret using that source inherits them.
- R2: A deployer can override a setting only where that source's schema allows it.

**Alternatives considered:**

- **Platform only.** Rejected: a deployer needing a second store would need the platform team to install a preset source.
- **Deployer only.** Rejected: every values file would repeat store names and roles, and a platform change would mean editing every instance.

**Rationale:** The knowledge of which settings exist, and which are safe to vary, is the source's, so the source decides; the platform owns the defaults because it owns the infrastructure they name.

**Source:** User decision 2026-09-30. Whether platform defaults can be set by unifying into the enabled catalog's transformer is measured by OQ4.

---

### D22: catalog_opm ships the literal source as a new resource, beside the hand-authored secrets resource

**Kind:** contract

**Decision:** catalog_opm defines a new secret-source resource annotated `literal`, fulfilled by its own transformer that renders a plain Secret named exactly `target.name`, never prefixing or re-hashing it. The existing hand-authored secrets resource, for modules that compute whole Secret objects, is unchanged.

**Requirements:**

- R1: A platform that enables catalog_opm renders literal secrets with no further catalog.
- R2: The rendered Secret carries exactly the name the kernel computed, so every reference to it resolves.
- R3: Modules using the hand-authored secrets resource render unchanged.

**Alternatives considered:**

- **Reuse the hand-authored secrets resource.** Rejected: one contract would serve two naming rules and two input shapes.
- **A separate plain-secrets catalog.** Rejected: every platform would need one more catalog before the most common case works.

**Rationale:** The literal is the most common case, so it ships with the first-party catalog every platform already enables.

**Source:** User decision 2026-09-30.

---

### D23: The synthesised secrets component uses a key no author can write

**Kind:** contract

**Decision:** Each component the kernel synthesises for a secret group is keyed outside the set of keys an author can declare, so it can never merge with an author component. Its identity name remains an ordinary name.

**Requirements:**

- R1: An author component with any valid key coexists with the synthesised secrets components of the same instance, and neither absorbs the other.

**Alternatives considered:**

- **A reserved ordinary key** such as `opm-secrets`, with authors refused it. Rejected: it takes a name from authors and needs a check on every entry path.
- **A per-instance generated key.** Rejected: unstable across instances and module versions, which hurts inventory diffs and addressing.

**Rationale:** Measured in the feasibility review: merging author and synthesised components by key unifies rather than conflicts, so a shared key silently merges two components. A key outside the author key space makes the collision unrepresentable. Whether every tool that addresses components accepts such a key is measured by OQ6.

**Source:** User decision 2026-09-30; unification behaviour measured in the 2026-09-30 feasibility review.

---

### D24: The kernel reports every contract a render required, synthesised components included

**Kind:** contract

**Decision:** The render result lists every contract the render required, including those of components the kernel synthesised. Frontends read an instance's contract demand from there instead of walking the instance's own components.

**Requirements:**

- R1: An instance using a secret source is recorded as depending on that source's contract, so a guard that protects contracts in use refuses to remove it.

**Alternatives considered:**

- **The operator recomputes the demand itself.** Rejected: it duplicates kernel knowledge in a frontend, and the CLI would need it too.
- **Accept the gap.** Rejected: removing a source would break every dependent instance at its next render.

**Rationale:** A component that exists only inside the render is invisible to any frontend that reads the instance; the kernel is the one party that sees it.

**Source:** User decision 2026-09-30; the blind spot measured in the 2026-09-30 feasibility review.

---

### D25: An authored instance package refuses literal secrets

**Kind:** contract

**Amends:** D16

**Decision:** A literal secret value is accepted only from a values source the kernel assembles into the build itself: a `ModuleInstance` CR's values, or a values file given alongside an instance. An authored instance package, whose own files carry its values, refuses a literal at a marked path with an error naming the path and the two allowed alternatives: a reference, or the literal supplied through a values source. A package-only delivery path with no values channel therefore fulfils secrets by reference or by a named source only.

What survives of D16: the render is assembled without the deployer's original values, never by overriding them. What changes against D16: an authored package is no longer an artifact that can carry supplied values, so R2's instance file no longer includes packages with literals.

**Requirements:**

- R1: An authored instance package carrying a literal at a marked path fails with an error naming that path and the allowed alternatives.
- R2: The same literal supplied through a CR's values or a values file renders normally.

**Alternatives considered:**

- **Support literals in packages by evaluating the package, extracting its values and re-assembling.** Rejected: new internal machinery that bypasses the loader's own checks, carries metadata by hand, adds a build, and loses source positions for values written as expressions.
- **Allow them as a documented exception.** Rejected: it breaks the no-plaintext-in-the-render guarantee on one path.

**Rationale:** The kernel can keep plaintext out of the build only where it assembles the values itself. An authored package is committed to version control or published to a registry, so a literal in it is plaintext at rest there as well.

**Source:** User decision 2026-09-30, holding after the cost was restated: a package-only operator path cannot supply literals at all.

---

### D26: Exported instances encrypt the literal values at marked paths

**Kind:** contract

**Depends:** 0014:D1

**Amends:** D14, 0014:D3

**Decision:** When an instance is exported for GitOps, the `value` field of every literal at a marked path is SOPS-encrypted in the exported `ModuleInstance`; everything else stays readable. Cluster-side decryption is the GitOps tool's. What survives of D14: SOPS stays at the file seams, never an arm, a backend or kernel code. What changes against D14 R4: the encrypted artifact is the exported instance, not rendered Secret manifests. What changes against 0014 D3: exported values are no longer written verbatim where a marked path holds a literal.

**Requirements:**

- R1: An exported instance carries no plaintext secret value, and every other field of it stays readable and diffable.
- R2: The exported instance, once decrypted by the GitOps tool, renders exactly as the unexported one.

**Alternatives considered:**

- **Encrypt rendered Secret manifests.** Rejected: rendering happens in the cluster on the CR-export path, so the committed artifact is the instance, not its manifests.
- **Leave export encryption out of this entry.** Rejected: the export path would commit literals to git until another entry took it up.

**Rationale:** Discover already yields exactly the paths to encrypt. Flux's decryptor keys on the SOPS metadata, not on the object kind, so an encrypted `ModuleInstance` is decrypted before it reaches the API server.

**Source:** User decision 2026-09-30; Flux decryption behaviour read from the kustomize-controller source during the 2026-09-30 feasibility review.

---

### D27: The CLI writes raw values to the instance it applies; plaintext at rest covers that path too

**Kind:** contract

**Amends:** D15

**Decision:** When the CLI applies an instance to a cluster it writes the deployer's values as given, literals included, never the resolved references. The documentation that a literal in a `ModuleInstance` is plaintext at rest in etcd names the CLI apply path, including values the CLI decrypted from SOPS, and recommends a reference or a named source for production on both paths.

**Requirements:**

- R1: An instance applied by the CLI and then rendered by the operator produces the same output as the CLI's own render.
- R2: The documentation of plaintext at rest names both the operator path and the CLI apply path.

**Alternatives considered:**

- **Refuse literals on apply.** Rejected: CLI and operator paths would accept different inputs, and a developer on a real cluster would have to pre-create every Secret.
- **The CLI creates the Secrets itself and writes references.** Rejected: the operator would materialise nothing, the handoff's output identity would break, and the Secrets would sit outside the inventory.

**Rationale:** The operator re-renders what the CLI applied; it can only reproduce the Secret if it receives the literal the CLI received.

**Source:** User decision 2026-09-30.

---

### D28: Diagnostics never carry a value at a marked path

**Kind:** contract

**Amends:** D16

**Decision:** Every diagnostic the kernel returns replaces any value at a marked path with a fixed placeholder, keeping the path and the reason. Every frontend inherits this. What changes against D16 R1: an error at a marked path names the path and the reason, not the value as written.

**Requirements:**

- R1: No validation or render error, event or status condition carries the value written at a marked path, including a malformed one.
- R2: Such an error still names the path and why it failed.

**Alternatives considered:**

- **The operator redacts its own findings.** Rejected: every other frontend would need the same code, and CLI output in CI logs would still leak.
- **Document the echo.** Rejected: the leak is on the most common mistake, a bare string where a secret is expected.

**Rationale:** Measured in the feasibility review: that mistake produces a conflict error quoting the value, which the operator writes to Events, often readable by people who cannot read Secrets.

**Source:** User decision 2026-09-30; the echo measured in the 2026-09-30 feasibility review.

---

### D29: A secret source is named by its exact contract FQN; the annotation only marks what is a source

**Kind:** contract

**Amends:** D19, D20

**Decision:** A deployer names a secret source by the exact FQN of its contract, apiVersion included, the way a component names a resource. A values file written in CUE may take it from the catalog's definition by import. Nothing resolves a short name and nothing picks a version. The `opmodel.dev/secret-source` annotation only marks a resource as a secret source: value `source` for a named source, `literal` for the one that serves `#SecretLiteral` (D30). The kernel refuses a `source` that is not a defined contract on the platform, or is one without the annotation, and lists the installed sources in that error.

What survives of D19: sources coexist, the deployer chooses per value, and every consumer reads the reference form. What changes against D19: R3's refusal now names an FQN, and R4's ambiguity cannot arise, so its fallback is moot. What survives of D20: the reserved prefix and one key per feature. What changes: this key's value is a role, not a name.

**Requirements:**

- R1: A value names its source by the contract's full name, and the same value renders the same source on every platform that carries it.
- R2: A value naming a contract the platform does not define, or one not marked as a secret source, fails with an error listing the platform's installed sources.
- R3: A catalog adding a new apiVersion of a source changes nothing for a value that names the old one.

**Alternatives considered:**

- **Short names resolved through the annotation (D19 as written).** Replaced: measured to break every deployer the day a catalog carries two apiVersions of one source, and fixing it needed either an implicit "take the highest version" rule or a catalog naming discipline. Both are resolution OPM does nowhere else.
- **Take the highest apiVersion of an ambiguous name.** Rejected: OPM's apiVersion ladder only orders diagnostics and never selects; this would be the first implicit version choice, and a catalog adding a version would silently change what existing instances render.
- **One annotated apiVersion per source, enforced at catalog publish.** Rejected with short names as a whole: it keeps an implicit lookup and moves the discipline onto every catalog.

**Rationale:** Everywhere else OPM binds exactly and explicitly; the short-name lookup was the one place it would not, and every defect found in it came from that. Verbosity in a JSON CR is the cost; CUE values files avoid it by import, and the template generator writes the names.

**Source:** User decision 2026-09-30, after `research/2026-09-30-feasibility-experiments.md` (OQ7) measured the ambiguity on apiVersion graduation.

---

### D30: `#SecretLiteral` resolves to the one source marked `literal`; a platform with two is not routable

**Kind:** contract

**Amends:** D18, D22

**Decision:** `{value}` resolves to the single defined contract annotated `opmodel.dev/secret-source: literal`. The kernel, not core's contract report, refuses a platform defining two such contracts as not routable, before any render; core never reads the annotation (D20). A platform defining none refuses a render that uses `{value}`, naming the missing literal source. A catalog annotates `literal` on exactly one apiVersion of its literal resource: graduating it moves the annotation in a catalog release and removes it from the older version, and the catalog's own vet enforces that. This is the one lookup by annotation that remains, and it has at most one answer by construction.

What changes against D22: its R1 holds while no other enabled catalog carries a literal source. A third-party literal source cannot sit beside catalog_opm's; a different materialisation for supplied plaintext is a named source (D18), not a second literal.

**Requirements:**

- R1: A platform carrying two literal sources is refused as a platform, before any instance renders against it.
- R2: A render using a literal value on a platform without a literal source fails naming the missing source.
- R3: A catalog graduating its literal source leaves every platform that enables it routable.

**Alternatives considered:**

- **Refuse per render instead of per platform.** Rejected: every instance would fail separately for a fault that is the platform's.
- **Pin the literal to a fixed catalog FQN in the kernel.** Rejected: the kernel would depend on one catalog's paths.

**Rationale:** Keeping the sugar needs one implicit lookup; making its answer unique at the platform keeps it deterministic and puts the fault where it belongs.

**Source:** User decision 2026-09-30.

---

### D31: A source's settings are their own field; a group agrees on source and settings

**Kind:** contract

**Amends:** D18, D19, D21

**Decision:** `#SecretSource` is `{source!, settings?: {...}, spec?: {...}}` and `#SecretSourceInput` is `{target, settings, entries}`: settings describe how the group's one object is produced, entries carry each key's own data. All non-reference members of a group must carry the same `source` and the same `settings`; a literal member counts as naming the literal source (D30) with empty settings. The kernel hands the source one settings block per group. The source's resource schema types `settings` and holds only the settings a deployer may set, each optional or defaulted there; the source's transformer merges them over the platform's settings (D32). So the synthesised spec is complete without the platform's settings, and D35's completeness check applies to it unchanged.

What survives of D18: core adds the arm and the envelope once and they never grow. What changes: both gain the `settings` slot now, open, so they need not grow later. What survives of D19 R5 and D21: group agreement, and the source deciding what a deployer may override. What changes: an override is written in `settings`, never inside an entry, and D21's "core says nothing about settings" no longer holds: core carries an open settings slot, which only the source types.

**Requirements:**

- R1: A group whose members name the same source with different settings fails, naming the group and each member path.
- R2: A setting a source does not allow a deployer to set fails at the member that set it.
- R3: Every object a source renders for a group receives one settings block, the deployer's allowed settings over the platform's defaults.

**Alternatives considered:**

- **Settings inside each entry, the source schema marking which fields are group-level.** Rejected: the kernel would have to read a per-source declaration to know what to compare.
- **No deployer settings at all.** Rejected: a second store for one instance would need the platform to install a preset source.

**Rationale:** Measured under the closed envelope: a per-secret override placed inside an entry cannot be told apart from data, so "same settings" could not be checked. A separate slot makes it a plain equality.

**Source:** User decision 2026-09-30; the entry-level ambiguity measured in `research/2026-09-30-feasibility-experiments.md` (OQ4).

---

### D32: A platform fills a source's settings through its catalog entry, and the operator and CLI carry that fill

**Kind:** contract

**Amends:** D21

**Decision:** A source catalog exports its transformer and its settings schema as named definitions. The transformer declares its settings as a closed definition, with every setting the platform must provide required. A platform fills it through the enabling catalog entry's transformers, keyed by a reference to the catalog's exported transformer definition and wrapped in the source's own settings schema. Core's specification states that a catalog entry's transformers may carry such a fill, which it currently calls a derived readout. The operator's platform subscription gains a field carrying a source's settings, named by that exported definition rather than by a pattern, and the CLI's platform generator emits it, so the fill is not limited to hand-authored platforms. The carrier's round trip is not yet measured. None of this is a core schema field.

**Requirements:**

- R1: A platform's settings for a source reach every object that source renders.
- R2: A catalog version bump neither loses the platform's settings nor applies them to the wrong transformer.
- R3: A misspelled or wrongly typed setting fails rather than falling back to a default, wherever the setting is required.
- R4: A platform declared through the operator or generated by the CLI can carry a source's settings, not only one written by hand.

**Alternatives considered:**

- **Key the fill by the transformer's FQN.** Rejected: measured to be silently lost on a catalog version bump.
- **Key it by a pattern on the transformer name.** Rejected: survives the bump, but a misspelled pattern is silently lost too.
- **Leave the carrier for later.** Rejected: D21 would hold only for platforms written by hand.

**Rationale:** The fill point needs nothing new from core or the kernel, measured through the real render. The failures found were all silent losses, so the chosen shape is the one that turns each into an error.

**Source:** User decision 2026-09-30 (carrier in scope); mechanism and failure modes measured in `research/2026-09-30-feasibility-experiments.md` (OQ4).

---

### D33: Core tags each `#Secret` arm; discovery walks the schema for listing and the unified values for completeness

**Kind:** contract

**Amends:** D3, D13, D14, D18

**Decision:** Each arm of core's `#Secret` carries a hidden tag only core can author. The schema declares secrets: a path is a secret when the `#config` schema, followed through disjunctions, embeddings, aliases, patterns and lists to core's tagged arms, declares it. Discovery walks that schema twice. Before values exist it lists every declaration it can reach, for templates and inspection. At render it walks the schema with the values unified, so conditions are resolved and patterns and lists expand to concrete paths. Every declared path's resolved value must carry the tag; one that does not, such as a plain default left unset or the earlier core release's secret shape, is refused naming its path. A tag arriving in values at a path the schema does not declare declares nothing.

What survives of D3: the schema declares, values declare nothing, and no values are needed to list declarations. What changes: a declaration under a condition on a deployer value is invisible until values exist, so the no-values listing covers every declaration except those. What changes against D14 R2: the template holds every marked path the no-values walk reaches, with conditional ones added once values select them. What survives of D13: discovery keys on the type and fails closed. What changes: "typed `#Secret`" means "carries core's tag", not a reference to `#Secret`.

**Requirements:**

- R1: A secret-typed field is discovered in every form a module can declare it, including aliases, embedding, patterns, lists and conditional fields, at render.
- R2: A structure that merely resembles a secret, or a tag written outside core, is never discovered as one.
- R3: A declared secret whose resolved value is not a core secret, including the earlier core release's shape and a plain default left unset, fails the render naming its path.
- R4: Every declaration not under a condition on a deployer value is listable from the module alone, with no values present.
- R5: A secret shape supplied in values at a field the module does not declare as a secret declares nothing.

**Alternatives considered:**

- **Follow references to `#Secret`.** Rejected: measured to miss `let` aliases, and it cannot tell core releases apart, since both publish `#Secret` under one name.
- **Match the arms' shape.** Rejected: measured to flag unrelated structs and open values.
- **Walk the unified values only, a field being a secret when its value carries the tag.** Rejected: measured to let values written in CUE declare secrets in untyped fields, and to miss a declared secret whose unset default is a plain struct; templates and inspection also need a no-values listing.

**Rationale:** The tag makes "typed `#Secret`" a mechanical, version-aware fact; the two walks cover the two moments discovery serves.

**Source:** `research/2026-09-30-feasibility-experiments.md` (OQ8); user decision 2026-09-30.

---

### D34: A deployer's values are checked against `#config` on every path, without changing what the instance exports

**Kind:** contract

**Amends:** D3, D10, D28

**Decision:** Core's `#ModuleInstance` carries a hidden check that unifies the values with the module's `#config` beside `values`, never into it, so plain `cue vet -c` rejects mixed arms, bare strings, unknown fields and wrong types whether or not a component reads them. The kernel additionally checks that every declared secret path holds a complete value, on every entry path and independent of that hidden check, because CUE does not check completeness under a hidden field and a hand-written instance may not carry the check at all. A general completeness check for every required config field is outside this entry. The kernel reports any failure under the hidden check at the corresponding `values` path, and redacts it there as a marked path.

What survives of D10: CUE type-checks the deployer's choice of arm. What changes: completeness of an unread secret is the kernel's check, not plain `cue vet`. What changes against D3: D3 rejected an addressable unified-config field on `#ModuleInstance` as a breaking change that would expose plaintext at a new path. The check is hidden and never exported, it is additive, and in the render build it holds only resolved references because the original values are omitted (D16); the kernel's own check does not rely on it. What changes against D28: its redaction also covers the hidden check's paths.

**Requirements:**

- R1: Plain validation of an instance rejects a secret value carrying two arms, a bare string, an unknown field or a wrong type, whether or not a component reads it.
- R2: An unfulfilled secret fails every render and every kernel validation, whether or not a component reads it.
- R3: The instance's exported values are exactly what the deployer wrote: no module defaults are added.
- R4: A failure of the hidden check at a secret path names the deployer's values path and carries no value.

**Alternatives considered:**

- **Bind `values` to `#config` directly.** Rejected: measured to fill module defaults into the exported values the CLI applies and hashes, and to reject valid instances when values arrive as a separate file.
- **Gate a regular field on the check's completeness.** Rejected: measured to report an unfulfilled secret as a wrong artifact kind.

**Rationale:** Measured: the hidden check changes no exported field and catches every malformed value early; only completeness needs the kernel.

**Source:** `research/2026-09-30-feasibility-experiments.md` (OQ3).

---

### D35: A synthesised component is held to what an authored one is

**Kind:** contract

**Amends:** D19, D23

**Decision:** The kernel validates each synthesised component's spec (its target and entries; settings are complete by construction, D31) for completeness before matching, as authored components are at acquisition, and reports a failure at the member's values path. It stamps the component-name label on each synthesised component, and refuses a render in which a synthesised component's name equals an authored one. Its key is emitted quoted. A synthesised component is never omitted by the skip-unprovided switch: a source with no provider refuses the render. The kernel also refuses an instance whose component keys differ from its module's, with an error naming the extra keys.

**Requirements:**

- R1: A source entry missing a required field fails at the deployer's values path, whether or not the source's transformer reads the field.
- R2: Every object a synthesised component renders is recorded under that component in every inventory.
- R3: A synthesised component's name never matches an authored component's name in one render.
- R4: A secret whose source has no provider fails the render even when unprovided demands are otherwise skipped.
- R5: An instance declaring a component its module does not declare fails with an error naming it.

**Alternatives considered:**

- **Rely on the transformer reading every required field.** Rejected: measured to render silently when it does not.
- **Rely on closedness to refuse extra instance components.** Rejected: measured to refuse every pair with a misleading message.

**Rationale:** Synthesised components enter after acquisition and so skip every gate authored components pass; each finding here is one of those gates, restored.

**Source:** `research/2026-09-30-feasibility-experiments.md` (OQ5, OQ6, OQ7).

---

### D36: Redaction covers synthesised components, whose spec is never a readable field

**Kind:** contract

**Amends:** D28

**Decision:** Diagnostics are redacted at synthesised-component paths as at marked paths, and the kernel never exposes a synthesised spec as a regular, readable field of the render build.

**Requirements:**

- R1: No error from a source's schema or transformer carries a value the deployer supplied, including a literal failing a source's own constraint.

**Alternatives considered:**

- **Redact only at the deployer's marked paths.** Rejected: measured to leak the plaintext when a literal source's constraint fails, at the synthesised path.

**Rationale:** The plaintext travels into the synthesised component by design, so that path needs the same protection as the one it came from.

**Source:** `research/2026-09-30-feasibility-experiments.md` (OQ5).

Open Questions live in [`07-questions.md`](07-questions.md): the entry's question register.
