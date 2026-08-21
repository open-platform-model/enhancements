# Design Decisions — Layered Defaults

This document records every significant design choice with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent** — never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** While the entry is `draft`, decisions are living text revised in place; from `accepted`, bodies are protected and changes land as new `DN`s with relation fields. Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source.

---

## Decisions

### D1: Four-layer precedence chain, composed from lattice behavior rather than a precedence feature

**Kind:** contract

**Decision:** The default precedence for a component field is **instance values > `#config` defaults > blueprint defaults > transformer fallbacks**, produced by composing three mechanisms: concrete data eliminates a marked disjunct (author beats blueprint), the kernel resolves `#config` defaults to data before composition (config beats blueprint, D4), and absence falls through to the transformer's guard (blueprint silence delegates per-kind, D5).

**Alternatives considered:**

- *In-language precedence via CUE's layer machinery* — rejected, see D4 alternatives.
- *Single defaulting layer (transformers only)* — status-quo intent; leaves blueprints unable to state per-kind starting values and keeps fresh modules unrenderable until the author sets every force-present field.
- *No defined precedence (document the annihilation, tell authors to avoid collisions)* — this was SPEC.md §6 L5 as first landed; rejected in favor of making the collision unrepresentable (D4), because an avoidance rule pushed onto every module author is the weakest kind of contract.

**Rationale:** CUE's unification is commutative, associative, and idempotent; "closest layer wins" requires provenance the lattice erases by construction. Any real precedence must therefore be assembled *around* the lattice — by controlling what each layer is allowed to contribute (bounds, one default, data, absence-keyed fallback) so that ordinary unification produces the intended order.

**Source:** research/cue/concepts/default-precedence.md (spec rules M0–M3, U0–U2, verified against cue v0.16.1 SDK and v0.17.1 CLI); measured probes 2026-08-18 (02-design.md Before/After); user decision 2026-08-18.

### D2: Primitives publish bounds, never defaults

**Kind:** contract

**Decision:** Trait and resource `spec` schemas MUST NOT mark defaults (`*`). They publish the union of what any target kind accepts. (SPEC.md §6 rule L1.)

**Alternatives considered:**

- *Default the trait schema* (`type: *"RollingUpdate" | …`) — measured to work mechanically for the defaultable subset (component goes concrete, catalog vet and transformer regression tests pass), but rejected: the default is a global claim across all kinds made by the one layer that cannot see the kind, and it permanently spends the field's single default slot so no downstream layer can re-default. It also cannot rescue undefaultable fields (`workloadIdentity.name!`, `disruptionBudget`'s `matchN`), and for object-emitting traits a default would materialize a resource (a PDB on every workload) rather than pick a value.
- *Per-kind schema variants inside the trait* — moves kind knowledge into the kind-agnostic layer; the blueprint already exists to hold exactly this.

**Rationale:** The default for a field is almost always kind-dependent; upstream CUE guidance (discussion 2159) states the general rule — a consumer cannot override a base schema's `*`, only collide with it. Publish bounds, let the leaf default.

**Source:** measured probe 2026-08-18 (trait-schema default variant); research/cue/concepts/default-precedence.md pitfalls; user decision 2026-08-18 ("if I add a default to the trait it will default for all workload types").

### D3: The blueprint is the single catalog-side defaulting layer — field-level defaults plus subtractive narrowing

**Kind:** contract

**Decision:** A `#Blueprint` MAY conjoin narrowing constraints onto composed fields (every admitted value MUST be admitted by the primitive's schema) and MAY mark at most one default per field, always field-level on a leaf, never a whole-struct marked disjunct. (SPEC.md §6 rules L2/L3.) The idiom, verified: `type: ("RollingUpdate" | "Recreate") & (*"RollingUpdate" | string)` — unset → default; author's concrete value → wins; kind-invalid value → vet-time conflict naming the blueprint line. The exhaustive per-kind audit across all five workload blueprints is tracked by catalog_opm issue 40.

**Alternatives considered:**

- *Whole-struct default* (`*{type: "RollingUpdate"} | Schema`) — measured working for full override, rejected for the partial-override pitfall: an author setting any one field eliminates the entire marked arm, silently discarding every other default it carried.
- *Blueprint-side `?` demotion of the trait projection* — measured no-op: unification keeps the stronger marker; the trait's required projection wins.
- *Narrowing without defaults (silent posture everywhere)* — remains available per field; a blueprint chooses per field between opinionated (default) and silent (absent, transformer decides). Whether the first-party workload blueprints default `updateStrategy` permanently or only until D5 lands is OQ1.

**Rationale:** The blueprint is the highest layer that knows the target kind, so both the legal menu and the sensible starting value belong to it. Field-level marks compose with author overrides; subtractive narrowing composes with everything by plain unification.

**Source:** measured probes 2026-08-18 against catalog_opm v2 blueprints (unset/override/invalid/partial); research/cue/concepts/default-precedence.md (whole-struct pitfall); catalog_opm issue 40.

### D4: The kernel finalizes validated `#config` to concrete data before composition

**Kind:** contract

**Decision:** Between config validation and `FillPath(schema.Values, …)` (`library/opm/kernel/process.go:42`), the kernel resolves every `#config` default to its concrete value, so the composition receives plain data. Applies identically to the `ValidateConfigDetailed` layered-sources path (finalize after the last source merges) and the debugValues/synth path. Consequence, accepted deliberately: a config default becomes a commitment — a default that violates a downstream constraint errors loudly instead of being silently replaced by a surviving disjunct. Under D8's compatibility contract this is divergence *elimination* (kernel stricter and louder than plain CUE, which silently substitutes); the collision case the finalize resolves is divergence *collision* (kernel succeeds where plain CUE fails loudly with `incomplete value`). Neither is a silent fork of plain-CUE semantics.

**Alternatives considered:**

- *CUE `SetLayer` per-file default priority* — the general in-language answer, rejected for now: single "rudimentary" commit, internal API ("may change at any time"), no design doc or spec text, and a documented soundness bug (a low layer combining constraint and default lets a high-layer default violate the constraint) whose trigger is adjacent to the D3 idiom. Revisit if upstream ships it properly; it would slot underneath this design without changing observable behavior.
- *Status quo* — defaulted references annihilate against blueprint defaults (measured: config `*"Recreate"` meeting blueprint `*"RollingUpdate"` → unresolved disjunction at render, an error pointing at neither author).
- *Author-side discipline* (SPEC §6 L5 as an obligation: interpolate strings, avoid defaulted references) — works only for strings and pushes a lattice subtlety onto every module author.

**Rationale:** The kernel is the compilation layer CUE's own design points at for precedence ("resolve precedence as data, before the lattice"). Public API only; order-independence is restored after the choice; ambiguous-default errors surface at the config boundary with config-shaped messages instead of deep inside a component. The silent-substitution case it removes was already indistinguishable from a bug.

**Source:** research/cue/concepts/default-precedence.md ("What to do instead"); measured probes 2026-08-18 (annihilation, interpolation escape, data-beats-default); kernel code reading (validate.go `runValidate` returns `schema.Unify(values)` — defaults travel unresolved); user decision 2026-08-18 ("I like option A").

### D5: Core's component projection honors trait optionality

**Kind:** contract

**Decision:** `#Component._allFields` projects an `optional: true` trait's spec through an optionalizing comprehension — `for k, v in trait.spec {(k)?: v}` — and embeds an `optional: false` trait's spec as-is. Attaching an optional trait constrains its field without forcing it present; a module demanding a trait makes the field required. A trait that never states a posture fails loudly at every consumer (today it is silently required). A single-regular-field guarantee on trait specs accompanies the change: nested `!`/`?` markers ride inside the projected value intact, but a top-level `req!` sibling would abort the comprehension and a top-level `?` sibling would be silently dropped — core's existing `spec!: (name): _` gate plus definition closedness prevents both, and the target schema pins the guarantee.

**Alternatives considered:**

- *Fix in the catalog* (`spec: updateStrategy?: …` across all 27 traits) — measured no-op: core's trait gate forces the projected field regular; the catalog cannot express optionality the projection discards.
- *Fix by defaults alone* (D2/D3 without D5) — leaves undefaultable optional traits (`workloadIdentity`, `disruptionBudget`) unattachable-without-configuring, keeps transformer fallbacks dead, and keeps `optional:` decorative.
- *Status quo plus documentation* — 11 of 20 traits force-set on attachment; the posture field would remain a false promise in a published contract.

**Rationale:** Absence is the signal the whole chain runs on — "in case no other is defined" is unrepresentable until a field can be undefined. This is also what makes 0010 D46's advisory posture real, and it is the only projection under which the transformers' existing absence-keyed guards do what their comments claim. Verified against a faithful replica of `#Trait`/`#Component`: unset→absent+concrete, set→enforced, `optional: false`→required, typo→still rejected by closedness, unstated posture→loud error.

**Source:** measured probes 2026-08-18 (five-case replica; comprehension marker semantics; catalog-side no-op); core/src/component.cue:128-151, core/src/trait.cue:104; enhancement 0010 D46.

### D6: The layer contract is specification with citable rules, enforced by the toolchain

**Kind:** policy

**Decision:** The who-writes-what contract is codified as core SPEC.md §6 with rule identifiers L1–L6 for CLI gates to cite (landed 2026-08-18, core 504e927, ahead of this entry). This enhancement rewrites L5 from an author obligation ("MUST NOT flow a defaulted reference into a defaulted field") into a kernel guarantee (D4 makes the collision unrepresentable). Enforcement points: catalog publish gates for L1–L3, module vet gates for L4, transformer review for L6.

**Alternatives considered:**

- *Enforce in CUE* — impossible for the load-bearing rules: they are all statements about which layer a value came from, and the lattice erases provenance by construction.
- *Convention only (no spec, no gates)* — the current state; produced 11 force-set traits, a non-rendering template, and fleet-wide boilerplate without any rule being visibly broken.

**Rationale:** Same enforcement model as core's §5 publish gates: shipped surface, toolchain-enforced, CUE's own error where CUE can check and a named rule where it cannot.

**Source:** core SPEC.md §6 (core 504e927); user decision 2026-08-18 ("we cannot use CUE to enforce these behaviors, we will have built-in gates in the CLI").

### D8: Plain-CUE compatibility is a hard constraint on every mechanism

**Kind:** policy

**Decision:** OPM artifacts remain stock-CUE evaluable. C1: plain `cue vet` MUST pass on every valid module and catalog package — all mechanisms preserve it, measured. C2: the kernel MUST NOT silently produce different values than plain CUE; every divergence has at least one loud side. C3: two loud divergences are accepted and documented — the kernel resolves the config-vs-blueprint default collision that plain `cue export` reports as `incomplete value` (kernel more capable), and the kernel rejects the eliminated-default substitution that plain CUE ships silently (kernel stricter). Modules needing plain-CUE export parity SHOULD avoid the collision pattern (OQ5 covers gate support). The core slice adds the compatibility clauses to SPEC.md §6.

**Alternatives considered:**

- *Kernel-only semantics without a compatibility contract* — the original D4 framing; rejected because nothing would stop future mechanisms from quietly forking the language, and the fleet's own CI is plain `cue vet`.
- *Full plain-CUE parity (no divergences at all)* — would forbid the D4 finalize entirely, reverting L5 to an author obligation and leaving the elimination case's silent substitution in place; rejected — both divergences are loud, and the silent substitution plain CUE performs is the worst behavior on the table.
- *Mirroring the finalize into a published CUE helper* so plain tooling could opt in — no mechanism: the finalize is an evaluation-order choice, not a value; CUE cannot express "resolve these defaults first".

**Rationale:** The schema is a published contract consumed by people who never install the OPM CLI; `cue vet`/`cue export` against GHCR-resolved modules must keep meaning something. The measured probes show the constraint is satisfiable without giving up D4: plain vet is untouched everywhere, and both export-level divergences fail loud on at least one side.

**Source:** user decision 2026-08-18 ("we cannot break regular cue vet; I still want to be compatible with plain CUE cli tools"); measured probes 2026-08-18 (collision → `incomplete value` under export, vet unaffected; elimination → silent `8080` under export, kernel-side error).

### D7: The retired `#*Defaults` definitions are removed

**Kind:** contract

**Decision:** The twelve unreferenced `#*Defaults` definitions (relics of the v1alpha1 trait-defaults idiom, retired when defaulting moved into transformers post-014) are deleted from catalog_opm. Landed: catalog_opm eab9b12 (`feat!`), 2026-08-18, after verifying zero references across the workspace and downstream consumers.

**Alternatives considered:**

- *Repurpose them as the blueprint defaults* — wrong layer and wrong shape: they are whole-struct values (D3's rejected form) defined in the trait files (D2's rejected layer).
- *Leave them* — dead published surface that misleads readers into the exact pattern this enhancement replaces.

**Rationale:** They were the previous, abandoned answer to this enhancement's question; keeping them alongside the new contract would document two conflicting mechanisms.

**Source:** reference audit 2026-08-18 (each name occurred exactly once — its definition site); user decision 2026-08-18.

---

## Open Questions

- **OQ1: Do the first-party workload blueprints keep their `updateStrategy` (and similar) defaults permanently, or drop them once D5 lands?** Status: open. Opinionated posture: rendered objects state their strategy explicitly; values identical to the K8s defaults; template renders before the core release ships. Silent posture (post-D5): leaner rendered output, Kubernetes owns its defaults, transformer fallbacks carry the per-kind decision. Both are correct under the contract; this is a taste call about what first-party rendered objects look like. Note `restartPolicy` needs no default under either posture — narrowing to the single legal value (`"Always"` for Deployment/STS/DS) makes it concrete by itself.
- **OQ2: How does the CLI gate detect an L4 violation (author-marked default on a `#components` field)?** Status: open. `hasDefault` inspection on component-spec leaves at module vet is the candidate; needs a feasibility spike — distinguishing an author-written `*` from one arriving through a legitimate `#config` reference requires positional/provenance info the evaluator may not expose cheaply. D4 removes the collision *consequence* either way; the gate would catch the intent violation.
- **OQ3: Exact kernel finalize mechanics.** Status: open. Candidates: recursive `Default()` walk versus export-and-rebuild via `Syntax(cue.Final(), …)`. Must preserve absence of unset optional fields (D5 depends on it), surface ambiguous-default errors with config-context messages, and interact correctly with `#Secret` contract values in `#config`. Needs an experiment under `experiments/` before the entry promotes.
- **OQ5: Should a vet gate warn when a module depends on kernel-only default resolution?** Status: open. The collision pattern (defaulted `#config` reference into a blueprint-defaulted field) renders under the kernel but is not plain-CUE-exportable (D8 C3). A gate could detect and warn for modules that declare plain-CUE parity matters. Interacts with OQ2's `hasDefault` feasibility spike — likely the same detection machinery.
- **OQ4: Sequencing of the core `feat!` relative to the catalog defaults.** Status: open. The catalog defaults (D3) work against the current core and unblock the template immediately; D5 changes what "silent posture" renders (fields the blueprint leaves undefaulted disappear from output when authors are silent). Decide whether catalog lands first (two observable output shifts) or waits for core (one).
