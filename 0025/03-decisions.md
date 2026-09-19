# Design Decisions: Self-Describing Modules and Self-Service Kinds

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent**, never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** While the entry is `draft`, decisions are living text: a changed choice is an in-place edit to the existing `DN`, and the log never contains two conflicting decisions. Evidence-backed old positions fold into *Alternatives considered* before overwriting. Once `accepted`, decision bodies are protected: a change lands as a new `DN` with `**Amends:**` / `**Supersedes:**` relation fields, and existing bodies are edited only through the `enhancement-compaction` skill.

Each decision carries a `**Kind:**` line (`contract` | `policy` | `scope`) and the four-field shape: Decision, Alternatives considered, Rationale, Source. A decision that rests on another entry's decision carries a `**Depends:** MMMM:DN` line, and `config.yaml.depends_on` lists exactly the entries those lines name.

**The Kind gate.** A decision belongs here only if a from-scratch rewrite of the affected repos would still be bound by it. Mechanism (how a repo achieves the contract) belongs in the implementing OpenSpec change in the target repo.

---

## Decisions

### D1: A platform-owned, cluster-scoped definition binds the module; the consumer never names a module path or version

**Kind:** contract

**Decision:** A cluster-scoped object owned by the platform team binds a module lineage (its major-free registry path), a major, a bound release and an update policy, and may carry platform-bound values. A consumer instantiates the definition and supplies values alone. No consumer-facing object carries a module path or a version; the coordinate has exactly one home per cluster per offering.

**Alternatives considered:**

- **A version allowlist on the existing `ModuleInstance`** (admission policy restricting which module and version a tenant may name). Closes the tenancy gap for one identity and leaves the coordinate in the consumer's object, so the fleet upgrade stays a per-consumer edit. Kept as the guardrail half of OQ8, not as the binding.
- **A namespaced definition.** Rejected for the same reason 0015 D3 rejects namespace-scoped registration: the definition is a platform-team privilege, and a namespaced object is one a tenant could create. A namespaced *instance* of the definition is exactly what the consumer gets.
- **Binding the coordinate in the Platform CR.** The Platform is a cluster singleton naming catalog subscriptions; adding N module bindings to it makes every offering change a Platform edit with the regeneration blast radius 0015 D13 accepts for registrations. A definition per offering keeps that blast radius per offering.

**Rationale:** The two facts a platform team owns, which module and which release are supported, need a home that is theirs and not the consumer's. Once the binding is the platform's, "a module never names a provider" (0015) extends one level up: an application team never names a module version.

**Source:** Design conversation 2026-09-08.

### D2: The consumer-facing schema is the module's `#config`, enforced at the API server; a non-structural `#config` is refused as a definition target

**Kind:** contract

**Depends:** 0008:D3

**Decision:** Where a definition names an API group and kind, the served CRD's schema is the bound module's `#config` encoded as a structural OpenAPI schema, and nothing else is authored. A definition whose module `#config` does not encode that way is refused at acceptance, naming the module and the reason. Core's existing declaration that `#config` is OpenAPIv3-compatible becomes load-bearing at that point and only there: a module that is never offered as a kind is unaffected.

**Alternatives considered:**

- **A hand-authored schema on the definition**, as Crossplane's XRD carries. Rejected because it drifts from the module's `#config` by construction; the whole point is that the consumer sees what the module accepts.
- **Preserve-unknown-fields when `#config` is not structural.** Legal Kubernetes, and it silently degrades every guarantee the kind exists to give: no admission validation, no `kubectl explain`. A loud refusal is better than a kind that validates nothing.
- **Refusing at publish time instead.** A publish-side gate is a good addition (OQ6) and does not replace acceptance-time refusal: modules published before the gate existed, and modules never intended as offerings, must keep publishing.

**Rationale:** The encoder 0008 chose for core's own CRDs is the same one this needs; the gap between "declared OpenAPIv3-compatible" and "encodes" is exactly what the refusal names. Structural schemas are also what admission policy engines and typed clients key on, so the promise is worth enforcing where it is used.

**Source:** Design conversation 2026-09-08; core's module schema comment declaring `#config` OpenAPIv3-compatible, read the same day.

### D3: An instance of a definition is a projected `#ModuleInstance`; there is no second render path

**Kind:** contract

**Decision:** Every instance of a definition, in either layer, is projected to a complete `#ModuleInstance` and rendered by the render path unchanged. The render never learns about definitions or kinds. Whatever the render path does for a hand-authored instance (matching, transformers, diagnostics, ordering) it does identically for a projected one.

**Alternatives considered:**

- **Rendering a definition's instances through a dedicated composition path**, as Crossplane's composition functions and KRO's resource graph do. Rejected: it would be a second interpreter of `#components`, and every render-path guarantee (0019's single build, its parity oracle) would need restating for it.
- **Materialising the projected `#ModuleInstance` in memory only versus as a real `ModuleInstance` object.** Both satisfy this decision; which one is OQ7.

**Rationale:** The observation that started this entry: mechanically, deploying a module and instantiating a kind generated from it are the same render. The only things that move are who binds the coordinate (D1) and where `#config` is validated (D2). Keeping that literally true is what makes the entry small.

**Source:** Design conversation 2026-09-08.

### D4: Two layers, binding then kinds; the kind layer is a pure projection onto the binding layer

**Kind:** scope

**Decision:** The design has two layers. The binding layer is the definition, a definition reference on `ModuleInstance` as an alternative to a module reference, and a tenant guardrail. The kind layer adds an API group and kind on the definition, CRD generation from `#config`, and one data-driven controller that projects served-kind instances to `ModuleInstance` objects carrying the definition reference. The kind layer introduces no concept the binding layer lacks; it is a typed front over it. Whether the binding layer ships as a product on its own is OQ2.

**Alternatives considered:**

- **Kinds only, no binding layer.** Rejected: the projection function, the definition object and the guardrail are needed either way, and building them inside the dynamic-kind controller couples the render-facing contract to the most expensive part of the design.
- **Binding only, no kinds.** Delivers platform-owned versioning and the guardrail and leaves Gap 2 open: no schema at the API server, no per-kind RBAC. Recorded as the possible answer to OQ2, not as the design.

**Rationale:** The binding layer is a CR, a field and an admission rule. The kind layer is where dynamic CRD lifecycle, dynamic informers and status mirroring live, and it is the meta-controller shape 0009 leaves as a north star. Ordering them this way lets the expensive part be a projection rather than a foundation.

**Source:** Design conversation 2026-09-08.

### D5: The platform authors the binding; the module may declare its offering through an aspect, and never emits the definition

**Kind:** contract

**Depends:** 0015:D3, 0015:D9

**Revised:** 2026-09-19. Previously "the definition is never emitted by the module it offers, and `#Module` gains no authored field". The first half survives; the second is replaced by D11.

**Decision:** A definition is written by the platform team, either directly as a CR or as rendered output of a platform product module that attaches a definition resource contract, published by catalog_opm, to a component; a catalog_opm transformer renders the CR. In the rendered shape the CR reaches the cluster as ordinary rendered output applied under tenant impersonation, so the RBAC gate 0015 D3 rests on holds unchanged: only a platform-team identity can create one. The offered module MAY declare what it is when offered, through an `offering` module trait attached on an aspect (D11, D12): the intended API group and kind, a suggested update policy, and a status schema where one exists (OQ5). That declaration is input to authoring: the CLI drafts a definition from it, and the definition reconciler reports disagreement between a definition and the bound module's declaration. The module never emits the definition itself, and a declaration without a platform-authored definition offers nothing.

**Alternatives considered:**

- **No authored field on `#Module`; the offered module does not know it is offered** (previously adopted, 2026-09-08). Kept the module artifact free of any operator-shaped fact and the RBAC gate simple. Replaced because the same need recurs across entries (lifecycle placement in 0009, a status schema in OQ5, seed values in 0016) and answering it field by field is what D11's aspect map exists to stop; the RBAC argument survives untouched because a declaration is not a CR.
- **The offered module emits its own definition**, mirroring how a provider module ships its registration in 0015. Rejected on lifecycle: a provider runs once per cluster and its registration is a side effect of that one deployment, while an offered module runs N times and must be instantiable before any deployment of it exists. A module that publishes its own offering would have to be deployed first. This objection is why the declaration is read from the artifact and never rendered.
- **An authored field on `#Module` naming the intended kind.** Rejected as a bare field for the reasons 0015 D9 rejects an authored registration field: it bakes an operator CR shape into runtime-neutral core. As a catalog-published module trait the shape lives in the catalog, versioned under its own API version, which is the difference.
- **Operator-synthesised definitions from module metadata.** Rejected: privilege on a namespaced object and a second emission path, as 0015 D3 and D9 already record.

**Rationale:** The registration pair in 0015 is the existing answer to "a platform-level CR that is rendered output and RBAC-gated by that fact". Reusing it gives definitions the same authoring surface, the same gate and the same reproducibility. Letting the module declare its intent on top costs nothing at the gate (a declaration is data on an artifact, not an object in a cluster) and gives the platform team a draft instead of a blank page.

**Source:** Design conversation 2026-09-08; user decision 2026-09-19.

### D6: The projection from definition and instance to `#ModuleInstance` is a pure CUE function in core

**Kind:** contract

**Decision:** Core defines the projection: given a definition, an instance and the resolved `#Module`, it yields a `#ModuleInstance` whose name and namespace are the instance's, whose module is the bound one, and whose values are the unification of the definition's bound values with the instance's values. A conflict between a bound value and a consumer value is a refusal. The kernel reads the projection off a built value; the CLI computes it offline; the operator's controller applies it. No frontend implements the projection in Go.

**Alternatives considered:**

- **Projection in the operator's controller only.** Rejected: the CLI could not reproduce a render offline, and the kernel would render an input it cannot derive, breaking the reproducibility 0015 D6 and 0019 give the platform package.
- **Consumer values override bound values on conflict.** Rejected: a bound value is the platform's decision; an override is what the platform bound it to prevent. Unification refusing the conflict is CUE's native answer.

**Rationale:** Library neutrality (its first principle) and 0019's parity oracle both say the same thing: what is derivable in CUE is derived in CUE, once. The projection is small enough to be a definition and important enough that three implementations of it would drift.

**Source:** Design conversation 2026-09-08.

### D7: A served kind's API version is the bound module's major

**Kind:** contract

**Depends:** 0010:D1, 0010:D41, 0021:D2

**Decision:** The CRD a definition serves carries one version per bound module major, spelled `v` followed by the major. Within a major the served schema may change only additively, which is what 0021 D2 already requires of `#config` inside a major. Rebinding a definition to a new release inside the same major regenerates the CRD's schema in place; existing instances stay valid because the change is additive. Rebinding across a major is a new served version and is OQ4.

**Alternatives considered:**

- **CRD version from the module's full release** (`v1-4-2` or similar). Rejected: every patch release would be a new API version with no conversion path, and instance identity would move with it.
- **A single `v1alpha1` regardless of module major.** Rejected: it hides a breaking `#config` change behind an unchanged apiVersion, which is the one thing a CRD version exists to prevent.

**Rationale:** 0010 D1 makes the major the only artifact distinction and 0010 D41 makes instance identity survive a major bump; 0021 D2 makes `#config` the compatibility surface. Together they say exactly what a CRD version says: same major, compatible schema, same objects.

**Source:** Design conversation 2026-09-08.

### D8: Replacing Crossplane means its composition layer; managed-resource controllers stay external

**Kind:** scope

**Decision:** The scope of "OPM instead of Crossplane" is the composition layer: what XRD, Composition and Claim do. Managed-resource controllers (Crossplane providers, ACK, ASO, Config Connector) stay external, and the objects they reconcile are leaf resources OPM's transformers render. Neither this entry nor a successor of it rebuilds external-API reconciliation on the execution half of the kernel.

**Alternatives considered:**

- **Reconciling external APIs with 0009's `http` operations.** Rejected as scope: it is the multi-year part of Crossplane, it has no relation to the composition problem this entry solves, and the execution half is not designed for continuous reconciliation of external state.

**Rationale:** OPM's advantage over Crossplane is typed CUE composition against a module's `#config`, not provider breadth. Naming the boundary stops the entry from being read as a promise it does not make.

**Source:** Design conversation 2026-09-08.

### D9: No composite-and-claim pair; the served-kind instance is namespaced and is the only consumer-facing object

**Kind:** contract

**Decision:** An instance of a served kind is a namespaced object. There is no cluster-scoped composite behind it. The projected `ModuleInstance` is the render's input and the operator's existing reconcile surface, not a consumer-facing object; the consumer's object carries status mirrored from it (shape per OQ5).

**Alternatives considered:**

- **Crossplane's topology**: a namespaced claim, a cluster-scoped composite resource, composed resources under the composite. Rejected: OPM's `#ModuleInstance` is already namespaced and already owns its rendered resources, so the composite has nothing left to hold.

**Rationale:** Every object that exists must be explained to a consumer. One object with the consumer's values and a status is the whole of what they need to see.

**Source:** Design conversation 2026-09-08.

### D10: Operational primitives attach at the projected instance's transitions; a served kind adds no hook surface

**Kind:** scope

**Decision:** Lifecycle phases and workflows, as 0009 designs them, attach to `#ModuleInstance` transitions. Because every served-kind instance is a projected `#ModuleInstance` (D3), those hooks fire for it without any addition on the definition or the served kind. This entry adds no hook vocabulary of its own; if 0009 changes where operational primitives attach, this entry follows and does not need amending.

**Alternatives considered:**

- **Definition-level hooks** (on bind, on rebind). Rejected for now: a rebind is a change to N instances, and the per-instance upgrade hooks 0009 provides already fire for each. A definition-level hook would be a fleet-wide operation with no instance to scope it; if one is needed it is a successor's design.

**Rationale:** The projection is what makes the execution half free for served kinds. Adding a second attachment point would recreate exactly the two-interpreter problem D3 avoids.

**Source:** Design conversation 2026-09-08.

### D11: `#Module` gains `#aspects`, a named map of module-scoped attachment units, sibling of `#components`

**Kind:** contract

**Depends:** 0010:D28, 0010:D36

**Decision:** `#Module` gains one optional map, `#aspects`, keyed like `#components`. Each entry is an `#Aspect`: a named bundle of module traits (D12) with a `resourceName` that defaults to the instance-qualified name, a `matchLabels` derived wholesale from its attached traits and enforced derived, an injected instance identity, and a closed `spec` unifying the attached traits' specs that the module author makes concrete. An aspect attaches at least one trait; it carries no resources, no blueprints, no name constraint and no DNS names. Its spec is authored inside the module and so reads `#config` and `#ctx.components` lexically.

**Alternatives considered:**

- **A flat `#traits` map plus `spec` at module root.** Rejected: nothing to name, so no second aspect of one kind with a different spec (an edge and an internal isolation policy), and no per-aspect rendered object name.
- **A trait-only `#Component`.** Rejected: it satisfies the component transformer contract (one workload, one component context) while lying about scope; every component transformer would have to know it might be looking at a fake.
- **`metadata.annotations` on `#Module`.** Rejected: untyped, unversioned, no consumer contract; the Kubernetes annotation sprawl this design exists to avoid.
- **A separate `#ServiceModule` schema.** Rejected: a second whole-object schema to maintain, sharing nothing with `#Module`, and needing a third for the next module kind.
- **Resources on an aspect.** Rejected: a resource is a workload demand the platform must satisfy (0010 D28); an aspect describes the module, it does not demand a workload.

**Rationale:** Four entries each wanted a top-level field on `#Module` (lifecycle in 0009, seed values in 0016, a status schema and an offerability flag here). One named extension point, filled from catalogs, is how 0010 already answered the same pressure for primitives: shapes in core, vocabulary in catalogs. Transposing `#Component` rather than inventing a shape keeps the derived-matchLabels rule (0010 D36), the name cascade and the closed spec as they are.

**Source:** User decision 2026-09-19.

### D12: `#ModuleTrait` is a sibling of `#Trait`, not a mode of it

**Kind:** contract

**Depends:** 0010:D4, 0010:D28

**Decision:** Core defines `#ModuleTrait` beside `#Trait`. It carries the same identity block (name, module path, API version, catalog version, FQN), the same `matchLabels`, `fulfilment`, `optional` and `spec`, and is published, keyed and gated the same way: `#CatalogMemberFQNGate` and `#TraitOptionalGate` apply unchanged. It has no `appliesTo` and no name constraint. A module trait's `optional` is stated by its catalog as a default and may be narrowed at the attachment site, never pinned, the rule 0010 D28 sets for traits.

**Alternatives considered:**

- **A `scope: "component" | "module"` field on `#Trait`.** Rejected: `appliesTo!` and `#nameConstraint` would become conditional on the mode, and every consumer of `#Trait` (matching, the name assertion, the contract inventory) would have to branch on it.
- **Reusing `#Trait` unchanged with an empty `appliesTo`.** Rejected: `appliesTo!` is required, and an empty list reads as "applies to nothing".

**Rationale:** The same reasoning that named `#ComponentTransformer` rather than `#Transformer`: two definitions with one shared block cost less than one definition with a mode. Catalog gates keyed on the shared block keep holding.

**Source:** User decision 2026-09-19.

### D13: `#ModuleTransformer` is `#ComponentTransformer` transposed; it renders resources and never sees rendered output

**Kind:** contract

**Depends:** 0019:D2, 0019:D9

**Decision:** Core defines `#ModuleTransformer` beside `#ComponentTransformer`. It matches on an aspect's `matchLabels` and attached module traits (no resource buckets), executes once per matched (aspect, transformer) pair, and takes the concrete module instance and one aspect; whole-module facts reach it through the instance's module, never through a second input. Its output is rendered resources and nothing else. It never reads rendered component output: the render stays one build (0019 D9), and aspects join it.

**Alternatives considered:**

- **A post-processor over rendered component output** (a module-level pass that sees the components' objects). Rejected: a second build after the first, which breaks the single build and the parity oracle 0019 D1 rests on.
- **Non-resource output (a plan, a CRD) from the same transformer.** Rejected: the render half renders; the execution half 0009 designs reads the same aspects for operational intent. A transformer with two output types is a third interpreter.
- **Component transformers reading `#moduleInstance.#module.#aspects` directly**, with no module transformer at all. Rejected: every component transformer would re-implement the module-scoped concern per component, and nothing would render an object that belongs to no component.

**Rationale:** Symmetry is the whole point: one matching discipline, one inventory, one parity oracle. The kernel adds one matching pass keyed on aspects and emits into the same output set; frontends observe nothing new.

**Source:** User decision 2026-09-19.

### D14: Aspects participate in the platform's matching and contract inventory; an unhandled aspect demand is never silent

**Kind:** contract

**Depends:** 0015:D1, 0015:D18

**Decision:** `#Catalog` carries module transformers beside component transformers, stamped the same way. `#Platform` folds enabled catalogs' module transformers as it folds component transformers, and its contract inventory covers module traits and the module transformers that require them. An aspect whose demand no enabled transformer handles is reported or refused by the trait's `optional` and `fulfilment`, exactly as an unhandled component demand is (0015 D18).

**Alternatives considered:**

- **Aspects outside the inventory** (a module trait nobody handles is simply not rendered). Rejected: this is the silently-inert failure `optional` and `fulfilment` exist to prevent; a network-isolation aspect that renders nothing is a security hole with no diagnostic.

**Rationale:** Without a consumer contract a module-level attachment is an annotation with a schema. The inventory is what makes a module trait a contract.

**Source:** User decision 2026-09-19.

### D15: The first module traits are `network-isolation` and `resource-budget`, rendered; `offering` ships with the binding layer; `lifecycle` and a status schema are named successors

**Kind:** scope

**Decision:** catalog_opm's abstraction family publishes two module traits with module transformers rendering them on Kubernetes: `network-isolation` (a module-scoped default-deny NetworkPolicy whose allowed CIDRs the module reads from `#config`) and `resource-budget` (a ResourceQuota across the module's components). They are this entry's proof that the aspect pass works end to end. The `offering` module trait (D5) ships with the binding layer and is consumed by the CLI and the definition reconciler, not by a transformer. Lifecycle and workflow traits belong to 0009, and a module-declared status schema waits for OQ5; both are named consumers, not deliverables.

**Alternatives considered:**

- **Ship the field with no rendered instance.** Rejected: an extension point nobody has used is a design, not a capability, and the `feature` gate asks for the latter.
- **Make `lifecycle` the first instance.** Rejected: it needs the execution half, which does not exist; the two rendered traits exercise the pass with machinery that does.

**Rationale:** Two rendered traits prove the pass through code that exists today; one declaration-only trait proves the module can say what it is. Together they cover both things an aspect is for.

**Source:** User decision 2026-09-19.

Open Questions live in [`07-questions.md`](07-questions.md), the entry-wide question register with its own numbering and status rules.
