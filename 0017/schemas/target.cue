// Core-schema delta for enhancement 0017 — Layered Defaults.
//
// Delta manifest (classified against core/src on the v2 line):
//
//   #Trait     — MIRROR (unchanged restatement of core/src/trait.cue for
//                self-containment; simplified to the two properties D5's
//                projection depends on — the stated posture and the
//                single-regular-field spec gate). The core slice changes no
//                trait shape; only rationale prose gains the posture-required
//                consequence.
//   #Component — CHANGED vs core@v2 (core/src/component.cue `_allFields`
//                trait branch): the unconditional `trait.spec` embedding
//                becomes the D5 optionality-aware projection — an
//                `optional: true` trait's field is projected optional
//                (absent until set), an `optional: false` trait's spec
//                embeds as-is (required). Resource and blueprint branches
//                unchanged (elided here).
//
// These are illustrative replica restatements, not imports — CUE cannot
// "edit" an imported closed definition, and the restatement IS the proposal;
// core is the source of truth once the slices land. Non-core material (the
// L1–L6 layer contract as rule data, the blueprint narrowing/default idiom)
// lives in ../contracts/. examples.cue in this package exercises the CHANGED
// projection. Marker comments reference Open Questions in ../03-decisions.md.
package schema

import "strings"

/////////////////////////////////////////////////////////////////
// MIRROR — replica of the core #Trait surface this design relies on
// (unchanged by this enhancement — pinned here because D5's projection
// depends on both properties).
/////////////////////////////////////////////////////////////////

#Trait: {
	metadata: #definitionName: string

	// Posture MUST be stated by the catalog and stay overridable by the
	// module (0010 D46 / core #TraitOptionalGate). Under D5 an unstated
	// posture fails at every consumer, not only at publish.
	optional: bool

	// Exactly one top-level REGULAR field. This is D5's single-regular-field
	// guarantee: definition closedness rejects siblings, and unification
	// forces an authored `?` on the projected field back to regular — so the
	// optionalizing comprehension below is total (a top-level `req!` sibling
	// would abort iteration; a `?` sibling would be silently dropped).
	spec!: (strings.ToCamel(metadata.#definitionName)): _

	...
}

/////////////////////////////////////////////////////////////////
// CHANGED vs core@v2 — D5, the optionality-aware projection in core
// #Component. Replaces the unconditional `trait.spec` embedding.
/////////////////////////////////////////////////////////////////

#Component: {
	#traits: [string]: #Trait

	_allFields: {
		for _, trait in #traits {
			if trait.spec != _|_ {
				// optional trait: field exists as a constraint, absent until
				// set. Nested !/? markers inside the schema value ride through
				// intact — only the top-level field gains the `?`.
				if trait.optional {
					for k, v in trait.spec {(k)?: v}
				}
				// demanded trait: embedding preserves the required marker.
				if !trait.optional {
					trait.spec
				}
			}
		}
		// resource and blueprint branches unchanged (resources are the
		// component's reason to exist; blueprints propagate through their
		// own guarded wrappers).
	}

	spec: close({
		_allFields
	})

	...
}
