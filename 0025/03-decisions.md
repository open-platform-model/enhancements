# Design Decisions: Self-Describing Modules

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent**, never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** While the entry is `draft`, decisions are living text: a changed choice is an in-place edit to the existing `DN`, and the log never contains two conflicting decisions. Evidence-backed old positions fold into *Alternatives considered* before overwriting. Once `accepted`, decision bodies are protected: a change lands as a new `DN` with `**Amends:**` / `**Supersedes:**` relation fields, and existing bodies are edited only through the `enhancement-compaction` skill.

Each decision carries a `**Kind:**` line (`contract` | `policy` | `scope`) and the body fields: Decision, Requirements (numbered `Rn` items cited as `0025:DN:Rn`; `none` with a reason on a `policy` or `scope` decision), Alternatives considered, Rationale, Source. A decision that rests on another entry's decision carries a `**Depends:** MMMM:DN` line, and `config.yaml.depends_on` lists exactly the entries those lines name.

**The Kind gate.** A decision belongs here only if a from-scratch rewrite of the affected repos would still be bound by it. Mechanism (how a repo achieves the contract) belongs in the implementing OpenSpec change in the target repo.
**D1 to D10 are tombstones.** The self-service kinds half of this design is entry 0027, which carries those decisions under the same numbers, so a citation of `0025:D7` resolves by changing only the entry id.


---

## Decisions

### D1: (moved to 0027:D1, 2026-09-20)

A platform-owned, cluster-scoped definition binds the module and the consumer never names a module path or version: content now in entry 0027 under the same number. Number retired here.

---

### D2: (moved to 0027:D2, 2026-09-20)

The consumer-facing schema is the module's `#config`, enforced at the API server, and a non-structural `#config` is refused as a definition target: content now in entry 0027 under the same number. Number retired here.

---

### D3: (moved to 0027:D3, 2026-09-20)

An instance of a definition is a projected `#ModuleInstance`, and there is no second render path: content now in entry 0027 under the same number. Number retired here.

---

### D4: (moved to 0027:D4, 2026-09-20)

Two layers, binding then kinds, with the kind layer a pure projection onto the binding layer: content now in entry 0027 under the same number. Number retired here.

---

### D5: (moved to 0027:D5, 2026-09-20)

The platform authors the binding, the module may declare its offering through an aspect, and the module never emits the definition: content now in entry 0027 under the same number. Number retired here.

---

### D6: (moved to 0027:D6, 2026-09-20)

The projection from definition and instance to `#ModuleInstance` is a pure CUE function in core: content now in entry 0027 under the same number. Number retired here.

---

### D7: (moved to 0027:D7, 2026-09-20)

A served kind's API version is the bound module's major: content now in entry 0027 under the same number. Number retired here.

---

### D8: (moved to 0027:D8, 2026-09-20)

Replacing Crossplane means its composition layer, and managed-resource controllers stay external: content now in entry 0027 under the same number. Number retired here.

---

### D9: (moved to 0027:D9, 2026-09-20)

No composite-and-claim pair: the served-kind instance is namespaced and is the only consumer-facing object: content now in entry 0027 under the same number. Number retired here.

---

### D10: (moved to 0027:D10, 2026-09-20)

Operational primitives attach at the projected instance's transitions, and a served kind adds no hook surface: content now in entry 0027 under the same number. Number retired here.

---

### D11: `#Module` gains `#aspects`, a named map of module-scoped attachment units, sibling of `#components`

**Kind:** contract

**Depends:** 0010:D28, 0010:D36

**Decision:** `#Module` gains one optional map, `#aspects`, keyed like `#components`. Each entry is an `#Aspect`: a named bundle of module traits (D12) with a `resourceName` that defaults to the instance-qualified name, a `matchLabels` derived wholesale from its attached traits and enforced derived, an injected instance identity, and a closed `spec` unifying the attached traits' specs that the module author makes concrete. An aspect attaches at least one trait; it carries no resources, no blueprints, no name constraint and no DNS names. Its spec is authored inside the module and so reads `#config` and `#ctx.components` lexically.

**Requirements:**

- R1: A module without `#aspects` is valid and unchanged in meaning.
- R2: An aspect attaching no module trait is rejected at module validation.
- R3: An aspect declaring a resource or a blueprint is rejected at module validation.
- R4: An aspect's `matchLabels` is derived from its attached traits; an authored value that differs is rejected.
- R5: An aspect's rendered object name defaults to the instance-qualified name and may be set per aspect.
- R6: An aspect spec may read `#config` and the components' computed names, as a component spec does.
- R7: An aspect spec key that no attached trait declares is rejected at module validation.

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

**Requirements:**

- R1: A catalog publishes a module trait under the same identity, FQN and optional gates as a component trait.
- R2: A module trait cannot be attached to a component, and a component trait cannot be attached to an aspect.
- R3: An attachment may narrow a module trait's `optional` from true to false; widening is rejected.

**Alternatives considered:**

- **A `scope: "component" | "module"` field on `#Trait`.** Rejected: `appliesTo!` and `#nameConstraint` would become conditional on the mode, and every consumer of `#Trait` (matching, the name assertion, the contract inventory) would have to branch on it.
- **Reusing `#Trait` unchanged with an empty `appliesTo`.** Rejected: `appliesTo!` is required, and an empty list reads as "applies to nothing".

**Rationale:** The same reasoning that named `#ComponentTransformer` rather than `#Transformer`: two definitions with one shared block cost less than one definition with a mode. Catalog gates keyed on the shared block keep holding.

**Source:** User decision 2026-09-19.

### D13: `#ModuleTransformer` is `#ComponentTransformer` transposed; it renders resources and never sees rendered output

**Kind:** contract

**Depends:** 0019:D2, 0019:D9

**Decision:** Core defines `#ModuleTransformer` beside `#ComponentTransformer`. It matches on an aspect's `matchLabels` and attached module traits (no resource buckets), executes once per matched (aspect, transformer) pair, and takes the concrete module instance and one aspect; whole-module facts reach it through the instance's module, never through a second input. Its output is rendered resources and nothing else. It never reads rendered component output: the render stays one build (0019 D9), and aspects join it.

**Requirements:**

- R1: A module transformer runs once per matched aspect and transformer pair, never per component.
- R2: A module transformer's output is resources only; any other output is refused at catalog validation.
- R3: Rendered component output is not an input to any module transformer; the render is one build.
- R4: A module's rendered set is the union of component and aspect output, with duplicate object identities refused as today.

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

**Requirements:**

- R1: A platform's contract inventory lists module traits defined by enabled catalogs and the module transformers requiring them.
- R2: An aspect attaching a required, catalog-fulfilled trait that no enabled transformer handles fails the render, naming the trait and the aspect.
- R3: The same case for an optional trait is reported, not refused, with the same naming.
- R4: A disabled catalog contributes no module transformers and no module traits.

**Alternatives considered:**

- **Aspects outside the inventory** (a module trait nobody handles is simply not rendered). Rejected: this is the silently-inert failure `optional` and `fulfilment` exist to prevent; a network-isolation aspect that renders nothing is a security hole with no diagnostic.

**Rationale:** Without a consumer contract a module-level attachment is an annotation with a schema. The inventory is what makes a module trait a contract.

**Source:** User decision 2026-09-19.

### D15: This entry ships the extension point and no vocabulary; the traits it shows are examples, and a module trait ships with the entry that consumes it

**Kind:** scope

**Revised:** 2026-09-20. Previously "the first module traits are `network-isolation` and `resource-budget`, rendered; `offering` ships with the binding layer". The declaration left with the scope split and the rendered pair became examples; what survives is the rule about where a module trait ships.

**Decision:** No catalog publishes a module trait or a module transformer under this entry. `network-isolation` and `resource-budget` appear throughout as worked examples of what the extension point is for, and `schemas/examples.cue` stands them up as fixtures beside a declaration-only trait and a module transformer, attaches them to a module, and pins the rendered object's name, labels and one field read from `#config`. Publishing any of them is a later catalog decision, made under the catalog's own API versions. A module trait ships in the catalog change that publishes it, alongside the entry that consumes it: the offering declaration with entry 0027, lifecycle and workflow traits with entry 0009, a rendered policy trait with the first platform that asks for one. Each carries a `**Depends:**` edge into D11 and D12 rather than a section here.

**Requirements:** none (ships no vocabulary; a module trait's requirements belong to the entry that publishes it)

**Alternatives considered:**

- **Ship two rendered traits in catalog_opm as this entry's proof** (previously adopted, 2026-09-19). Two rendered traits exercise the pass through machinery that exists today and make the capability visible with no second entry. Replaced because a vocabulary and its extension point are two questions: what those traits bind is the shape of a NetworkPolicy and a ResourceQuota on Kubernetes, which constrains nothing about `#Aspect`, and shipping them here puts the catalog in this entry's blast radius for content no decision here governs.
- **Ship the field with no exercise at all.** Rejected: an extension point nobody has used is a design, not a capability, and the `feature` gate asks for the latter. The fixtures and the transformer run in `examples.cue` are what keep that honest: they pin a rendered object end to end, which is the same evidence a published trait would give, and the kernel's matching pass is observable behaviour whether or not a catalog has published a word yet.
- **Make `lifecycle` the first instance.** Rejected: it needs the execution half, which does not exist. It ships with entry 0009, under this decision's rule.
- **Name a successor entry for the rendered pair now.** Rejected: a successor named before a consumer exists is a placeholder that ages. The durable statement is the rule; the entry that publishes the first policy trait writes itself when a platform needs one.

**Rationale:** A from-scratch rewrite would be bound by the extension point and by the matching discipline around it. It would not be bound by which two words a catalog happened to publish first, which is the catalog's decision under its own API versions. Splitting them keeps this entry's blast radius at core and library and puts each trait's contract next to the consumer that has to live with it.

**Source:** User decision 2026-09-19, revised by the scope split of 2026-09-20.

Open Questions live in [`07-questions.md`](07-questions.md), the entry-wide question register with its own numbering and status rules.
