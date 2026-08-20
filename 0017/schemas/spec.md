# Specification changes: Layered Defaults

One section per CHANGED construct, in core SPEC.md's four-part format, framed as a delta against the current section. Sources: this entry's `01-problem.md`, `02-design.md`, `03-decisions.md` (D1–D8), and the CUE in `target.cue` / `examples.cue`.

MIRROR definitions (no spec section): `#Trait` is restated in `target.cue` unchanged — the stated-posture field and the single-regular-field `spec!` gate pinned for self-containment. The core slice touches SPEC.md §2.2 only as prose: the `optional` rationale gains the posture-required consequence (an unstated posture now fails at every consumer, not only at publish).

## #Component (CHANGED vs SPEC.md §3.1)

### Definition

The trait branch of `#Component._allFields` changes meaning: a composed trait's field goes from unconditionally present to posture-dependent. An `optional: true` trait contributes its field as a constraint that stays absent until someone sets it; an `optional: false` (demanded) trait contributes it required, as today. This makes `#Trait.optional` (0010 D46) load-bearing and makes absence representable on the composed spec — absence is what arms the transformers' existing per-kind, absence-keyed fallbacks (rule L6) and what lets blueprint silence delegate a field's value downstream. Resource and blueprint branches are unchanged.

### Shape

The changed trait branch (full surface in `target.cue`; today's branch is the unconditional `trait.spec` embedding):

```cue
for _, trait in #traits {
	if trait.spec != _|_ {
		if trait.optional {
			for k, v in trait.spec {(k)?: v}
		}
		if !trait.optional {
			trait.spec
		}
	}
}
```

- `trait.optional` guard — NEW: the projection branches on the trait's stated posture.
- `(k)?: v` comprehension — NEW: the optionalizing projection; only the top-level field gains the `?`, nested `!`/`?` markers inside the schema value ride through intact.
- `spec: close({_allFields})` — unchanged: composed specs stay closed.

### Constraints

- CHANGED: an `optional: true` trait's projected field MUST be optional on the composed `spec` — it constrains the field without forcing it present, and it MUST be genuinely absent until the module (or a downstream layer) sets it. Previously every composed trait field was required.
- Unchanged, now load-bearing: an `optional: false` trait's spec MUST embed as-is, keeping the field required — a module demanding a trait makes its field required.
- ADDED: a trait that never states a posture MUST fail loudly at every consumer (the projection's guards require a concrete bool). Previously an unstated posture was silently treated as required and failed only at the publish gate.
- ADDED (companion single-regular-field guarantee, pinned by `target.cue`): a trait `spec` MUST carry exactly one top-level regular field. Definition closedness MUST reject top-level siblings, and the `spec!: (strings.ToCamel(name)): _` gate forces an authored top-level `?` back to regular — so the optionalizing comprehension is total (a top-level `req!` sibling would abort iteration; a `?` sibling would be silently dropped).
- Unchanged: `spec: close({_allFields})` MUST keep rejecting fields no attached resource, trait, or blueprint declares (typo protection) — measured in `examples.cue`'s must-fail case.
- OQ-gated: the landing order of this change relative to the catalog-side blueprint defaults is OQ4 (the change alters what "silent posture" renders — undefaulted fields disappear from output when authors are silent). Whether first-party blueprints keep their own defaults once this lands is OQ1.

### Rationale

- Why a posture-dependent projection. Absence is the signal the whole precedence chain (D1) runs on — "in case no other is defined" is unrepresentable until a field can be undefined. This is the only projection under which the transformers' existing absence-keyed guards do what their comments claim; today those fallbacks are dead code because presence is unconditional.
- Why fail loudly on an unstated posture. The posture field was a false promise: measured 2026-08-18, 11 of 20 v1beta1 traits force the author to set their field on every attachment while `optional` stays decorative. Failing at the consumer surfaces the breach where it bites instead of only at publish.
- Why the single-regular-field guarantee rides along. Without it the comprehension is not total — a top-level `req!` sibling aborts iteration and a top-level `?` sibling is silently dropped; core's existing trait gate plus definition closedness already prevent both, and pinning the guarantee keeps them from regressing.
- Why not fix this in the catalog instead. Blueprint- or trait-side `?` demotion is a measured no-op — unification keeps the stronger marker, and core's trait gate forces the projected field regular at the source. The projection is the one place optionality can be honored (D5 alternatives).

## Companion prose deltas (no construct)

- SPEC.md §6 rule L5 is rewritten from an author obligation ("MUST NOT flow a defaulted reference into a defaulted field") into a kernel guarantee: validated `#config` is finalized to concrete data before composition, making the two-default collision unrepresentable (D4/D6).
- SPEC.md §6 gains D8's plain-CUE compatibility clauses: C1 (plain `cue vet` MUST pass on every valid package), C2 (the kernel MUST NOT silently diverge from plain CUE), C3 (the two documented loud divergences — collision resolved by the kernel, eliminated-default substitution rejected by the kernel).
